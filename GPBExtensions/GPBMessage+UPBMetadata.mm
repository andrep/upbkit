// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "GPBExtensions/GPBMessage+UPBMetadata.h"

#include <cstddef>
#include <dlfcn.h>
#include <objc/message.h>
#include <objc/runtime.h>
#include <vector>

#import "GPBExtensions/UPBMetadata.h"
#import "GPBExtensions/UPBMetadataMap.h"
#import "UPBArena.h"
#include "external/abseil-cpp+/absl/container/fixed_array.h"
#include "external/abseil-cpp+/absl/container/flat_hash_map.h"
#include "external/abseil-cpp+/absl/container/inlined_vector.h"
#include "external/abseil-cpp+/absl/strings/ascii.h"
#import "external/protobuf+/objectivec/GPBDescriptor.h"
#include "external/protobuf+/upb/base/descriptor_constants.h"
#include "external/protobuf+/upb/mini_descriptor/decode.h"
#include "external/protobuf+/upb/mini_descriptor/internal/encode.hpp"
#include "external/protobuf+/upb/mini_descriptor/internal/modifiers.h"
#include "external/protobuf+/upb/mini_descriptor/link.h"
#include "external/protobuf+/upb/mini_table/message.h"

// 256 here is taken from absl::FixedArray::kInlineBytesDefault, which seems
// like a reasonable default to use.
template <typename T>
using InlinedVector = absl::InlinedVector<T, 256 / sizeof(T)>;

static inline upb_Arena *StaticArena() {
  static upb_Arena *arena;

  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    arena = upb_Arena_New();
  });

  return arena;
}

static inline upb_FieldType UPBFieldTypeFromGPBFieldType(GPBDataType type) {
  // Indexed by the raw integer value of the GPBDataType enum.
  static constexpr upb_FieldType UPBFieldTypes[] = {
      kUpb_FieldType_Bool,    kUpb_FieldType_Fixed32, kUpb_FieldType_SFixed32,
      kUpb_FieldType_Float,   kUpb_FieldType_Fixed64, kUpb_FieldType_SFixed64,
      kUpb_FieldType_Double,  kUpb_FieldType_Int32,   kUpb_FieldType_Int64,
      kUpb_FieldType_SInt32,  kUpb_FieldType_SInt64,  kUpb_FieldType_UInt32,
      kUpb_FieldType_UInt64,  kUpb_FieldType_Bytes,   kUpb_FieldType_String,
      kUpb_FieldType_Message, kUpb_FieldType_Group,   kUpb_FieldType_Enum,
  };

  assert(type <= GPBDataTypeEnum);

  return UPBFieldTypes[type];
}

@implementation GPBMessage (UPBMiniDescriptor)

static inline absl::flat_hash_map<
    Class, std::tuple<const upb_MiniTable *, UPBMetadata *>> &
SeenClasses() {
  // TODO: thread safety
  static auto seenClasses =
      new absl::flat_hash_map<Class,
                              std::tuple<const upb_MiniTable *, UPBMetadata *>>;
  return *seenClasses;
}

static inline const upb_MiniTable *GetMiniTable(Class cls) {
  const auto it = SeenClasses().find(cls);
  if (it == SeenClasses().end())
    return Nil;

  return std::get<const upb_MiniTable *>(it->second);
}

static inline void SetMiniTable(Class cls, const upb_MiniTable *miniTable) {
  auto it = SeenClasses().find(cls);
  if (it == SeenClasses().end()) {
    SeenClasses().insert({cls, {miniTable, nullptr}});
  } else {
    it->second =
        std::make_tuple(miniTable, std::get<UPBMetadata *>(it->second));
  }
}

+ (const upb_MiniTable *)upb_runtimeMiniTable {
  {
    const upb_MiniTable *cachedMiniTable = GetMiniTable(self);
    if (cachedMiniTable)
      return cachedMiniTable;
  }

  GPBDescriptor *descriptor = [self descriptor];

  uint64_t messageModifiers = 0;
  // TODO: is this correct?
  if (descriptor.extensionRangesCount)
    messageModifiers |= kUpb_MessageModifier_IsExtendable;

  upb::MtDataEncoder encoder;
  encoder.StartMessage(0);

  InlinedVector<std::pair<GPBEnumDescriptor *, uint32_t>> closedEnumDescriptors;
  InlinedVector<std::pair<Class, uint32_t>> subMessageClasses;
  absl::flat_hash_map<GPBOneofDescriptor *, InlinedVector<uint32_t>>
      oneofFieldNumbers;

  upb_Status status;
  const auto checkStatus = [&status] {
    // TODO: Add out NSError param that wraps upb_Status
    assert(status.ok);
  };

  std::vector<void (^)(upb_MiniTable *)> linkMaps;

  for (GPBFieldDescriptor *field in descriptor.fields) {
    const GPBFieldType fieldType = field.fieldType;

    const uint32_t fieldNumber = field.number;
    GPBEnumDescriptor *enumDescriptor = field.enumDescriptor;

    if (enumDescriptor && enumDescriptor.isClosed)
      closedEnumDescriptors.push_back({enumDescriptor, fieldNumber});

    if (Class cls = field.msgClass)
      subMessageClasses.push_back({cls, fieldNumber});

    uint64_t modifiers = 0;
    if (fieldType == GPBFieldTypeRepeated)
      modifiers |= kUpb_FieldModifier_IsRepeated;
    if (field.packable)
      modifiers |= kUpb_FieldModifier_IsPacked;
    if (enumDescriptor.isClosed)
      modifiers |= kUpb_FieldModifier_IsClosedEnum;

    // TODO: dunno if this is correct.
    if (field.required) {
      modifiers |= kUpb_FieldModifier_IsRequired;
    } else if (field.optional) {
      // No-op.
    } else if (fieldType == GPBFieldTypeSingle) {
      // Neither required nor optional, and it's a single field -- so it must be
      // a proto3 singular field (since proto2 fields must be either required or
      // optional).
      modifiers |= kUpb_FieldModifier_IsProto3Singular;
      // NSLog(@"proto3 singular field number %u in %@", fieldNumber,
      // self.descriptor.fullName);
    }

    upb_FieldType type = UPBFieldTypeFromGPBFieldType(field.dataType);
    if (fieldType == GPBFieldTypeMap) {
      // TODO: key_mod is 0 here, is that correct?
      encoder.PutField(kUpb_FieldType_Message, fieldNumber, modifiers);
      {
        upb::MtDataEncoder mapEncoder;
        mapEncoder.StartMessage(0);
        mapEncoder.EncodeMap(UPBFieldTypeFromGPBFieldType(field.mapKeyDataType),
                             type, 0, 0);

        upb_Status_Clear(&status);
        const std::string mapMiniDescriptor = mapEncoder.data();
        upb_MiniTable *mapMiniTable = upb_MiniTable_Build(
            mapMiniDescriptor.data(), mapMiniDescriptor.length(), StaticArena(),
            &status);
        assert(mapMiniTable);
        checkStatus();

        auto linkMap = ^(upb_MiniTable *miniTable) {
          upb_MiniTable_SetSubMessage(
              miniTable,
              const_cast<upb_MiniTableField *>(
                  upb_MiniTable_FindFieldByNumber(miniTable, fieldNumber)),
              mapMiniTable);
          // NSLog(@"%@ link map number=%u", self, fieldNumber);
        };
        linkMaps.push_back(linkMap);
      }
    } else {
      encoder.PutField(type, fieldNumber, modifiers);
    }

    if (field.containingOneof) {
      oneofFieldNumbers[field.containingOneof].push_back(fieldNumber);
    }

    // NSLog(@"%@ number=%u enum=%d/%d type=%d modifiers=%llu oneof=%d
    // submsgclass=%@", self,
    //       fieldNumber, bool(enumDescriptor), enumDescriptor.isClosed, type,
    //       modifiers, bool(field.containingOneof), field.msgClass);
  }

  // TODO: messagesets

  InlinedVector<std::pair<uint32_t, upb_MiniTableEnum *>> enumMiniTables;

  static auto cachedEnumMiniTables =
      new absl::flat_hash_map<std::string, upb_MiniTableEnum *>;

  for (auto [enumDescriptor, fieldNumber] : closedEnumDescriptors) {
    const uint32_t count = enumDescriptor.enumNameCount;
    absl::FixedArray<uint32_t> enumValues(count);
    for (uint32_t i = 0; i < count; i++) {
      int32_t value;

      // TODO: ask the GPB team if they can give us an API to make this
      // more efficient.
      NSString *enumName = [enumDescriptor getEnumNameForIndex:i];
      const BOOL __unused success =
          [enumDescriptor getValue:&value forEnumName:enumName];
      assert(success);

      enumValues[i] = static_cast<uint32_t>(value);
    }

    upb::MtDataEncoder enumEncoder;
    enumEncoder.StartEnum();
    std::sort(enumValues.begin(), enumValues.end());
    for (uint32_t value : enumValues)
      enumEncoder.PutEnumValue(value);
    enumEncoder.EndEnum();

    const std::string &enumMiniDescriptor = enumEncoder.data();

    // TODO: inefficient. replace with a better cache, since we need to
    // build the encoded string before looking this up.
    upb_MiniTableEnum *enumMiniTable;
    const auto &enumIt = cachedEnumMiniTables->find(enumMiniDescriptor);
    if (enumIt != cachedEnumMiniTables->end()) {
      enumMiniTable = enumIt->second;
    } else {
      upb_Status_Clear(&status);
      enumMiniTable = upb_MiniTableEnum_Build(enumMiniDescriptor.data(),
                                              enumMiniDescriptor.length(),
                                              StaticArena(), &status);
      cachedEnumMiniTables->insert({enumMiniDescriptor, enumMiniTable});
      checkStatus();
    }
    enumMiniTables.push_back({fieldNumber, enumMiniTable});
  }

  for (const auto &[_, fieldNumbers] : oneofFieldNumbers) {
    encoder.StartOneof();

    for (uint32_t fieldNumber : fieldNumbers) {
      encoder.PutOneofField(fieldNumber);
    }
  }

  const std::string &messageMiniDescriptor = encoder.data();
  upb_Status_Clear(&status);
  upb_MiniTable *miniTable = upb_MiniTable_Build(messageMiniDescriptor.data(),
                                                 messageMiniDescriptor.length(),
                                                 StaticArena(), &status);
  checkStatus();

#ifndef NDEBUG
  for (GPBFieldDescriptor *fieldDescriptor in [self descriptor].fields) {
    assert(upb_MiniTable_FindFieldByNumber(miniTable, fieldDescriptor.number));
  }
#endif // NDEBUG

  for (const auto [fieldNumber, enumMiniTable] : enumMiniTables) {
    upb_MiniTableField *field = const_cast<upb_MiniTableField *>(
        upb_MiniTable_FindFieldByNumber(miniTable, fieldNumber));
    __unused bool success =
        upb_MiniTable_SetSubEnum(miniTable, field, enumMiniTable);
    // NSLog(@"%@ link enum number=%u", self, fieldNumber);

    assert(success);
  }

  SetMiniTable(self, miniTable);

  for (const auto &[cls, fieldNumber] : subMessageClasses) {
    bool success = upb_MiniTable_SetSubMessage(
        miniTable,
        const_cast<upb_MiniTableField *>(
            upb_MiniTable_FindFieldByNumber(miniTable, fieldNumber)),
        [cls upb_runtimeMiniTable]);
    // NSLog(@"%@ link table number=%u", self, fieldNumber);
    if (!success) { // TODO: handle error
      assert(success);
    }
  }

  for (auto linkMap : linkMaps) {
    linkMap(miniTable);
  }

  return miniTable;
}

// TODO: should be able to replace the UPBMetadata* with a UPBMetadata
// (non-pointer) value here
static absl::flat_hash_map<Class, UPBMetadata *> &Map() {
  static auto map = new absl::flat_hash_map<Class, UPBMetadata *>;
  return *map;
}

+ (UPBMetadata *)upb_runtimeMetadata {
  auto it = Map().find(self);
  if (it != Map().end())
    return it->second;

  UPBMetadata *metadata;

  if (true) {
    metadata = [self upb_runtimeMetadataNoMemoize];
  } else {
#pragma clang diagnostic ignored "-Wunreachable-code"

    // Unused code, but keeping it around for reference.
    NSString *upbMiniTableSymbolName = self.descriptor.fullName;
    upbMiniTableSymbolName =
        [upbMiniTableSymbolName stringByReplacingOccurrencesOfString:@"_"
                                                          withString:@"_0"];
    upbMiniTableSymbolName =
        [upbMiniTableSymbolName stringByReplacingOccurrencesOfString:@"."
                                                          withString:@"__"];
    upbMiniTableSymbolName =
        [upbMiniTableSymbolName stringByAppendingString:@"_msg_init"];

    const upb_MiniTable *miniTablePtr = static_cast<upb_MiniTable *>(
        dlsym(RTLD_DEFAULT, upbMiniTableSymbolName.UTF8String));
    if (miniTablePtr) {
      NSLog(@"Found static minitable %@", upbMiniTableSymbolName);
      metadata =
          [self upb_metadataWithMinitable:miniTablePtr runtimeGenerated:NO];
    } else {
      NSLog(@"Generating runtime metadata for %@ (%@)", self,
            self.descriptor.fullName);
      metadata = [self upb_runtimeMetadataNoMemoize];
    }
  }

  // This cast is needed since `self` is some sort of Class*& type in C++, so
  // absl::flat_map's .insert() method complains about storing a reference. (We
  // can fix this with std::remove_reference<decltype(self)>::type, but that's
  // even worse.)
  __unused const auto didEmplace =
      Map().emplace(static_cast<Class>(self), metadata);
  assert(didEmplace.second);

  return metadata;
}

+ (UPBMetadata *)upb_metadataWithMinitable:(const upb_MiniTable *)miniTable
                          runtimeGenerated:(BOOL)runtimeGenerated {
  // TODO: thread safety
  const uint32_t count = upb_MiniTable_FieldCount(miniTable);

  UPBMetadata *metadata = new UPBMetadata;
  metadata->miniTable = miniTable;

  // The field metadata array here is intentionally never free'd/deleted: once
  // the UPB runtime metadata is generated for this class, it's effectively
  // cached forever.
  metadata->fieldMetadataArray = new UPBFieldMetadata[count];

  GPBDescriptor *descriptor = [self descriptor];

  uint32_t i = 0;
  while (i < count) {
    const upb_MiniTableField *field =
        upb_MiniTable_GetFieldByIndex(miniTable, i);

    // TODO: ask GPB team to add .setter selector to
    // GPBFieldDescriptor. this is slow.
    GPBFieldDescriptor *fieldDescriptor =
        [descriptor fieldWithNumber:upb_MiniTableField_Number(field)];

    SEL setter = NULL;
    Class submessageClass = fieldDescriptor.msgClass;
    if (fieldDescriptor) {
      const char *fieldName = fieldDescriptor.name.UTF8String;
      std::string setterName = "set";
      setterName += absl::ascii_toupper(fieldName[0]);
      if (fieldDescriptor.name.length > 1)
        setterName += &fieldName[1];
      setterName += ":";

      setter = sel_registerName(setterName.c_str());
      if (!class_respondsToSelector(self, setter))
        setter = NULL;
    }

    ((UPBFieldMetadata *)metadata->fieldMetadataArray)[i] = (UPBFieldMetadata){
        .setter = setter,
        .submessageClass = submessageClass,
    };

    i++;
  }

  return metadata;
}

+ (UPBMetadata *)upb_runtimeMetadataNoMemoize {
  return [self upb_metadataWithMinitable:[self upb_runtimeMiniTable]
                        runtimeGenerated:YES];
}

@end
