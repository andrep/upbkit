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

#import "GPBExtensions/GPBMessage+UPBDecoding.h"

#import <Foundation/Foundation.h>

#include <assert.h>
#include <dispatch/dispatch.h>
#include <objc/message.h>
#include <objc/runtime.h>

#import "GPBExtensions/GPBMessage+UPBMetadata.h"
#import "GPBExtensions/UPBMetadata.h"
#import "GPBExtensions/UPBMetadataMap.h"
#import "NSData+UPBStringView.h"
#import "UPBArena.h"
#import "UPBStringView.h"
#include "external/abseil-cpp+/absl/container/flat_hash_map.h"
#import "external/protobuf+/objectivec/GPBArray.h"
#import "external/protobuf+/objectivec/GPBDescriptor.h"
#import "external/protobuf+/objectivec/GPBMessage.h"
#import "external/protobuf+/objectivec/GPBUnknownField.h"
#import "external/protobuf+/objectivec/GPBUnknownFields.h"
#include "external/protobuf+/upb/message/accessors.h"
#include "external/protobuf+/upb/message/promote.h"
#include "external/protobuf+/upb/wire/eps_copy_input_stream.h"
#include "external/protobuf+/upb/wire/reader.h"

// TODO: Thread-safety.
// TODO: Memory management (reconciling arenas & ARC)

@interface UPBLazyMessage : NSProxy

+ (instancetype)lazyMessageWithMessage:(upb_Message *)message
                                 class:(Class)cls
                                 arena:(UPBArena *)arena
                               options:(UPBParsing)options
    __attribute__((objc_direct));

- (void)morphToGPBMessage __attribute__((objc_direct));

@end

@interface UPBAssociation : NSObject {
@package
  upb_Message *_message;
  UPBArena *_arena;
}

@end

static inline void ParseUnknownData(__kindof GPBMessage *object,
                                    const upb_Message *message,
                                    UPBParsing options, NSError **errorPtr) {
  if (!upb_Message_HasUnknown(message))
    return;

  if (options & UPBParsingUnknownDataSkip)
    return;

  GPBUnknownFields *unknownFields = [[GPBUnknownFields alloc] init];

  uintptr_t it = kUpb_Message_UnknownBegin;
  upb_StringView unknownData;
  while (upb_Message_NextUnknown(message, &unknownData, &it)) {
    uint32_t tag;
    const char *data = upb_WireReader_ReadTag(unknownData.data, &tag);
    assert(data);

    const uint32_t field_number = upb_WireReader_GetFieldNumber(tag);
    const uint8_t wire_type = upb_WireReader_GetWireType(tag);

    switch (wire_type) {
    case 0: { // varint
      uint64_t varint;
      (void)upb_WireReader_ReadVarint(data, &varint);
      [unknownFields addFieldNumber:field_number varint:varint];
      break;
    }
    case 1: // 64-bit
      [unknownFields addFieldNumber:field_number
                            fixed64:*(const uint64_t *)data];
      break;
    case 2: { // length-delimited
      uint64_t length;
      const char *payload = upb_WireReader_ReadVarint(data, &length);
      assert(length <= INT32_MAX);
      [unknownFields
           addFieldNumber:field_number
          lengthDelimited:[NSData dataWithBytes:payload length:length]];
      break;
    }
    case 3: // start group
    case 4: // end group
      // TODO
      abort();
    case 5: // 32-bit
      [unknownFields addFieldNumber:field_number
                            fixed32:*(const uint32_t *)data];
      break;
    default:
#pragma clang diagnostic ignored "-Wunreachable-code"
      __builtin_unreachable();
      abort();
    }
  }

  NSError *error = nil;
  BOOL success = [object mergeUnknownFields:unknownFields
                          extensionRegistry:nil
                                      error:&error];
  if (!success) {
    NSLog(@"Failed to merge unknown fields: %@", error);
  }
}

// TODO: I think upb will validate enums on decode, so we don't need
// to check anything here. Need to double-check though.
static inline BOOL PassthroughInt32ToEnum(int32_t value) { return YES; }

static inline const UPBMetadata *GetMetadata(Class cls, UPBParsing options) {
  const UPBMetadata *metadata = UPBKitMetadataMapGet(cls);
  if (metadata)
    return metadata;

  return [cls upb_runtimeMetadata];
}

static inline void MergeFromUPBMessage(const upb_Message *message,
                                       const UPBMetadata *metadata,
                                       __kindof GPBMessage *object,
                                       UPBArena *arena, UPBParsing options,
                                       NSError **errorPtr);

static inline id Merge(upb_Message *submessage, Class subMessageClass,
                       UPBArena *arena, UPBParsing options,
                       NSError **errorPtr) {
  if ((options & UPBParsingLazySubmessages) ||
      (options & UPBParsingLazyObjects)) {
    return [UPBLazyMessage lazyMessageWithMessage:submessage
                                            class:subMessageClass
                                            arena:arena
                                          options:options];
  }

  id objCSubmessage = [[subMessageClass alloc] init];

  MergeFromUPBMessage(submessage, GetMetadata(subMessageClass, options),
                      objCSubmessage, arena, options, errorPtr);

  return objCSubmessage;
};

enum class SetterStrategy {
  kNoOp,
  kAccessor,
};

template <SetterStrategy strategy>
static inline void
MergeFromUPBMessage(const upb_Message *message, const UPBMetadata *metadata,
                    __kindof GPBMessage *object, UPBArena *arena,
                    UPBParsing options, NSError **errorPtr) {
  assert([object isKindOfClass:[GPBMessage class]]);

  const upb_MiniTable *miniTable = metadata->miniTable;
  int count = upb_MiniTable_FieldCount(miniTable);

  for (uint_fast16_t i = 0; i < count; i++) {
    const UPBFieldMetadata *fieldMetadata = &metadata->fieldMetadataArray[i];
    if (!fieldMetadata->setter) {
      continue;
    }

#ifndef NDEBUG
    Class objectClass = object_getClass(object);
    GPBFieldDescriptor *fieldDescriptor = [[objectClass descriptor]
        fieldWithNumber:upb_MiniTableField_Number(
                            upb_MiniTable_GetFieldByIndex(miniTable, i))];
    assert(fieldDescriptor);
    assert(fieldMetadata->submessageClass == fieldDescriptor.msgClass);
    assert([[[NSString stringWithUTF8String:sel_getName(fieldMetadata->setter)]
        lowercaseString] containsString:fieldDescriptor.name.lowercaseString]);
#endif // NDEBUG

    const upb_MiniTableField *field =
        upb_MiniTable_GetFieldByIndex(miniTable, i);

    if (upb_MiniTableField_IsArray(field) || upb_MiniTableField_IsMap(field)) {
      if (options & UPBParsingLazyObjects) {
        // TODO
        continue;
      }

      const upb_Array *array = upb_Message_GetArray(message, field);

      if (!array || upb_Array_Size(array) == 0) {
        continue;
      }

      const void *contents_begin = upb_Array_DataPtr(array);

      const size_t count = upb_Array_Size(array);

      id objCValue;
      upb_CType cType = upb_MiniTableField_CType(field);
      switch (cType) {
      case kUpb_CType_Bool:
        objCValue = [[GPBBoolArray alloc]
            initWithValues:static_cast<const BOOL *>(contents_begin)
                     count:count];
        break;
      case kUpb_CType_Float:
        objCValue = [[GPBFloatArray alloc]
            initWithValues:static_cast<const float *>(contents_begin)
                     count:count];
        break;
      case kUpb_CType_Int32:
        objCValue = [[GPBInt32Array alloc]
            initWithValues:static_cast<const int32_t *>(contents_begin)
                     count:count];
        break;
      case kUpb_CType_UInt32:
        objCValue = [[GPBUInt32Array alloc]
            initWithValues:static_cast<const uint32_t *>(contents_begin)
                     count:count];
        break;
      case kUpb_CType_Enum:
        objCValue = [[GPBEnumArray alloc]
            initWithValidationFunction:&PassthroughInt32ToEnum
                             rawValues:static_cast<const int32_t *>(
                                           contents_begin)
                                 count:count];
        break;
      case kUpb_CType_Message: {
        // TODO: Can probably remove fieldMetadata->submessageClass.
        // Instead, we can have a "reverse-map" (i.e.
        // absl::flat_hash_map<upb_Minitable*, Class>). Will probably save on
        // binary size.

        Class subMessageClass = fieldMetadata->submessageClass;
        assert(subMessageClass);

        objCValue = [NSMutableArray arrayWithCapacity:count];

        const auto tags =
            static_cast<const upb_TaggedMessagePtr *>(contents_begin);
        for (size_t j = 0; j < count; j++) {
          const upb_TaggedMessagePtr tag = tags[j];
          if (!upb_TaggedMessagePtr_IsEmpty(tag)) {
            upb_Message *upbSubmessage =
                upb_TaggedMessagePtr_GetNonEmptyMessage(tag);

            id objCSubmessage =
                Merge(upbSubmessage, subMessageClass, arena, options, errorPtr);
            [objCValue addObject:objCSubmessage];
          }
        }
        break;
      }
      case kUpb_CType_Double:
        objCValue = [[GPBDoubleArray alloc]
            initWithValues:static_cast<const double *>(contents_begin)
                     count:count];
        break;
      case kUpb_CType_Int64:
        objCValue = [[GPBInt64Array alloc]
            initWithValues:static_cast<const int64_t *>(contents_begin)
                     count:count];
        break;
      case kUpb_CType_UInt64:
        objCValue = [[GPBUInt64Array alloc]
            initWithValues:static_cast<const uint64_t *>(contents_begin)
                     count:count];
        break;
      case kUpb_CType_String: {
        objCValue = [NSMutableArray arrayWithCapacity:count];
        const auto stringViews =
            static_cast<const upb_StringView *>(contents_begin);
        for (size_t j = 0; j < count; j++) {
          const upb_StringView *sv = &stringViews[j];
          [objCValue addObject:[UPBStringView stringView:*sv withArena:arena]];
        }
        break;
      }
      case kUpb_CType_Bytes: {
        objCValue = [NSMutableArray arrayWithCapacity:count];
        const auto stringViews =
            static_cast<const upb_StringView *>(contents_begin);
        for (size_t j = 0; j < count; j++) {
          const upb_StringView *sv = &stringViews[j];

          [objCValue addObject:NSDataFromUPBStringViewCopy(*sv)];
        }
        break;
      }
      default:
        __builtin_unreachable();
        abort();
      }

      if constexpr (strategy == SetterStrategy::kAccessor) {
        reinterpret_cast<void (*)(id, SEL, id)>(objc_msgSend)(
            object, fieldMetadata->setter, objCValue);
      }
    } else {
      if (upb_MiniTableField_HasPresence(field) &&
          !upb_Message_HasBaseField(message, field)) {
        continue;
      }

      // Note that the `default_value` passed to upb_Message_Get*() is ignored
      // if the field is present.
      switch (upb_MiniTableField_CType(field)) {
      case kUpb_CType_Bool:
        if constexpr (strategy == SetterStrategy::kAccessor) {
          reinterpret_cast<void (*)(id, SEL, BOOL)>(objc_msgSend)(
              object, fieldMetadata->setter,
              upb_Message_GetBool(message, field, false));
        }
        break;
      case kUpb_CType_Float:
        if constexpr (strategy == SetterStrategy::kAccessor) {
          reinterpret_cast<void (*)(id, SEL, float)>(objc_msgSend)(
              object, fieldMetadata->setter,
              upb_Message_GetFloat(message, field, 0.0f));
        }
        break;
      case kUpb_CType_Enum:
      case kUpb_CType_Int32:
        if constexpr (strategy == SetterStrategy::kAccessor) {
          reinterpret_cast<void (*)(id, SEL, int32_t)>(objc_msgSend)(
              object, fieldMetadata->setter,
              upb_Message_GetInt32(message, field, 0));
        }
        break;
      case kUpb_CType_UInt32:
        if constexpr (strategy == SetterStrategy::kAccessor) {
          reinterpret_cast<void (*)(id, SEL, uint32_t)>(objc_msgSend)(
              object, fieldMetadata->setter,
              upb_Message_GetUInt32(message, field, 0U));
        }
        break;
      case kUpb_CType_Message: {
        upb_TaggedMessagePtr tag =
            upb_Message_GetTaggedMessagePtr(message, field, nullptr);
        if (!upb_TaggedMessagePtr_IsEmpty(tag)) {
          upb_Message *submessage =
              upb_TaggedMessagePtr_GetNonEmptyMessage(tag);

          Class subMessageClass = fieldMetadata->submessageClass;
          assert(subMessageClass);

          id objCValue =
              Merge(submessage, subMessageClass, arena, options, errorPtr);

          if constexpr (strategy == SetterStrategy::kAccessor) {
            reinterpret_cast<void (*)(id, SEL, __kindof GPBMessage *)>(
                objc_msgSend)(object, fieldMetadata->setter, objCValue);
          }
        }
        break;
      }
      case kUpb_CType_Double:
        if constexpr (strategy == SetterStrategy::kAccessor) {
          reinterpret_cast<void (*)(id, SEL, double)>(objc_msgSend)(
              object, fieldMetadata->setter,
              upb_Message_GetDouble(message, field, 0.0));
        }
        break;
      case kUpb_CType_Int64:
        if constexpr (strategy == SetterStrategy::kAccessor) {
          reinterpret_cast<void (*)(id, SEL, int64_t)>(objc_msgSend)(
              object, fieldMetadata->setter,
              upb_Message_GetInt64(message, field, 0LL));
        }
        break;
      case kUpb_CType_UInt64:
        if constexpr (strategy == SetterStrategy::kAccessor) {
          reinterpret_cast<void (*)(id, SEL, uint64_t)>(objc_msgSend)(
              object, fieldMetadata->setter,
              upb_Message_GetUInt64(message, field, 0ULL));
        }
        break;
      case kUpb_CType_String: {
        if (options & UPBParsingLazyObjects) {
          // TODO
          break;
        }
        UPBStringView *stringView = [UPBStringView
            stringView:upb_Message_GetString(message, field,
                                             (upb_StringView){nullptr, 0})
             withArena:arena];
        if constexpr (strategy == SetterStrategy::kAccessor) {
          reinterpret_cast<void (*)(id, SEL, NSString *)>(objc_msgSend)(
              object, fieldMetadata->setter, stringView);
        }
        break;
      }
      case kUpb_CType_Bytes: {
        if (options & UPBParsingLazyObjects) {
          // TODO
          break;
        }
        NSData *data = NSDataFromUPBStringViewCopy(upb_Message_GetString(
            message, field, (upb_StringView){nullptr, 0}));
        if constexpr (strategy == SetterStrategy::kAccessor) {
          reinterpret_cast<void (*)(id, SEL, NSData *)>(objc_msgSend)(
              object, fieldMetadata->setter, data);
        }
        break;
      }
      // TODO: this will remove compiler warnings about missing enum
      // cases.
      default:
        __builtin_unreachable();
        abort();
      }
    }
  }

  ParseUnknownData(object, message, options, errorPtr);
}

static inline void MergeFromUPBMessage(const upb_Message *message,
                                       const UPBMetadata *metadata,
                                       __kindof GPBMessage *object,
                                       UPBArena *arena, UPBParsing options,
                                       NSError **errorPtr) {
  if (options & UPBParsingNoOpWalk) {
    MergeFromUPBMessage<SetterStrategy::kNoOp>(message, metadata, object, arena,
                                               options, errorPtr);
  } else {
    MergeFromUPBMessage<SetterStrategy::kAccessor>(message, metadata, object,
                                                   arena, options, errorPtr);
  }
}

static inline SEL UPBAssociationKey() {
  static SEL sel;

  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sel = @selector(upb_parseFromData:options:error:);
  });

  return sel;
}

@implementation GPBMessage (UPBExtensions)

+ (nullable instancetype)upb_parseFromData:(NSData *)data
                                   options:(UPBParsing)options
                                     error:(NSError **)errorPtr {
  UPBArena *arena = [UPBArena arena];
  if (!arena) {
    // TODO: set error
    abort();
  }

  const UPBMetadata *metadata = GetMetadata([self class], options);
  if (!metadata) {
    // TODO: set error
    abort();
  }

  const upb_MiniTable *miniTable = metadata->miniTable;
  if (!miniTable) {
    // TODO: set error
    abort();
  }

  upb_Message *message = upb_Message_New(miniTable, arena.arena);
  if (!message) {
    // TODO: set error
    abort();
  }

  const upb_DecodeStatus status =
      upb_Decode(static_cast<const char *>(data.bytes), data.length, message,
                 miniTable, nullptr,
                 kUpb_DecodeOption_AliasString |
                     kUpb_DecodeOption_ExperimentalAllowUnlinked,
                 arena.arena);
  if (status != kUpb_DecodeStatus_Ok) {
    // TODO: set error
    fprintf(stderr, "status: %d\n", status);
    abort();
  }

  id object = [[self alloc] init];
  if (options & UPBParsingSkipMerge) {
    return nil;
  }

  [object upb_mergeFromMessage:message
                         arena:arena
                       options:options
                         error:errorPtr];
  return object;
}

- (void)upb_mergeFromMessage:(upb_Message *)message
                       arena:(UPBArena *)arena
                     options:(UPBParsing)options
                       error:(NSError **)errorPtr {
  const UPBMetadata *metadata = GetMetadata([self class], options);

  MergeFromUPBMessage(message, metadata, self, arena, options, errorPtr);

  UPBAssociation *association = [[UPBAssociation alloc] init];
  association->_message = message;
  association->_arena = arena;

  objc_setAssociatedObject(self, UPBAssociationKey(), association,
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UPBAssociation *)upb_info __attribute__((objc_direct)) {
  return objc_getAssociatedObject(self, UPBAssociationKey());
}

- (UPBArena *)upb_arena {
  return [self upb_info]->_arena;
}

- (upb_Message *)upb_message {
  UPBAssociation *info = [self upb_info];
  if (!info)
    return nullptr;

  return info->_message;
}

+ (const upb_MiniTable *)upb_miniTable {
  const UPBMetadata *metadata = GetMetadata(self, 0);
  if (!metadata)
    return nullptr;

  return metadata->miniTable;
}

@end

@implementation UPBAssociation
@end

@interface UPBLazyMessageStorage : NSObject
@end

@implementation UPBLazyMessageStorage {
@package
  Class _messageClass;
  upb_Message *_UPBMessage;
  UPBArena *_arena;
  UPBParsing _options;
}

@end

static const SEL kUPBLazyMessageAssociationKey = @selector(isProxy);

@implementation UPBLazyMessage

+ (instancetype)lazyMessageWithMessage:(upb_Message *)message
                                 class:(Class)messageClass
                                 arena:(UPBArena *)arena
                               options:(UPBParsing)options {
  UPBLazyMessage *lazyMessage = [[messageClass alloc] init];
  object_setClass(lazyMessage, self);

  UPBLazyMessageStorage *storage = [[UPBLazyMessageStorage alloc] init];
  storage->_messageClass = messageClass;
  storage->_UPBMessage = message;
  storage->_arena = arena;
  storage->_options = options;
  objc_setAssociatedObject(lazyMessage, kUPBLazyMessageAssociationKey, storage,
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);

  return lazyMessage;
}

- (void)morphToGPBMessage __attribute__((objc_direct)) {
  assert(object_getClass(self) == [UPBLazyMessage class]);

  UPBLazyMessageStorage *storage =
      objc_getAssociatedObject(self, kUPBLazyMessageAssociationKey);
  objc_setAssociatedObject(self, kUPBLazyMessageAssociationKey, nil,
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);

  __unused Class previousClass = object_setClass(self, storage->_messageClass);
  assert(previousClass == [UPBLazyMessage class]);

  NSError *error = nil;
  [(id)self upb_mergeFromMessage:storage->_UPBMessage
                           arena:storage->_arena
                         options:storage->_options
                           error:&error];
  assert(!error);
}

- (BOOL)isKindOfClass:(Class)aClass {
  [self morphToGPBMessage];
  return [self isKindOfClass:aClass];
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
  [self morphToGPBMessage];
  return self;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
  [self morphToGPBMessage];
  return [self methodSignatureForSelector:sel];
}

- (Class)class {
  UPBLazyMessageStorage *storage =
      objc_getAssociatedObject(self, kUPBLazyMessageAssociationKey);
  return storage->_messageClass;
}

- (BOOL)respondsToSelector:(SEL)aSelector {
  [self morphToGPBMessage];
  return [self respondsToSelector:aSelector];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
  [self morphToGPBMessage];
  anInvocation.target = self;
  [anInvocation invoke];
}

// UPBLazyMessage doesn't need an explicit dealloc. Rationale:
//
// 1.  The associated object for this class will be released by the
// Objective-C
//     runtime when the
//     lazy message goes out of scope.
// 2.  The factory class method that creates a UPBLazyMessage actually
// allocate a _GPBMessage_
//     subclass, but then uses object_setClass() to change the class of the
//     allocated object to a UPBLazyMessage. That's very odd, but should
//     correctly, for two reasons:
// 2a. malloc() has internal data structures that track the size of the
// allocation for a specific
//     pointer. So, even though we allocate a GPBMessage subclass then change
//     the class to a UPBLazyMessage, free() will correctly unallocate the
//     correct size, because the initial allocation was for the GPBMessage
//     subclass.
// 2b. We don't need to call -[GPBMessage dealloc]. That would be required if
// there was any internal
//     ivars in the GPBMessage object that needed to be released properly, but
//     if -[UPBLazyMessage dealloc] is called, that means that the object
//     hasn't transformed to a GPBMessage yet (because we're still a
//     UPBLazyMessage), so it's impossible for any GPBMessage ivars to be set
//     yet.

@end
