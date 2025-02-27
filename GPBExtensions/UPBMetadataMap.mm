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

#import "GPBExtensions/UPBMetadataMap.h"

#include <objc/runtime.h>

#include "external/abseil-cpp+/absl/container/fixed_array.h"
#include "external/abseil-cpp+/absl/container/flat_hash_map.h"
#include "external/abseil-cpp+/absl/container/flat_hash_set.h"
#include "external/protobuf+/objectivec/GPBDescriptor.h"
#include "external/protobuf+/objectivec/GPBMessage.h"
#include "external/protobuf+/upb/mini_table/field.h"
#include "external/protobuf+/upb/mini_table/internal/field.h"
#include "external/protobuf+/upb/mini_table/message.h"

static inline absl::flat_hash_map<Class, UPBMetadata> *Map() {
  static absl::flat_hash_map<Class, UPBMetadata> map;
  return &map;
}

UPBMetadata *UPBKitMetadataMapGet(Class cls) {
  const auto it = Map()->find(cls);
  if (it == Map()->cend())
    return nullptr;

  UPBMetadata *metadata = &it->second;

  return metadata;
}
