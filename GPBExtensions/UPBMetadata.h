/*
 * Copyright 2025 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <Foundation/Foundation.h>

#include "external/protobuf+/upb/mini_table/message.h"

// It'd be nice to be able to reduce this.
typedef struct {
  // Used to set the field, via objc_msgSend. This is NULL iff the GPB field
  // descriptor is missing for this minitable field (i.e. the upb minitable and
  // the GPB field descriptors are out of sync.)
  SEL _Nullable setter;

  // TODO: Can remove this - see comment in GPBMessage+UPB.mm.
  Class _Nullable submessageClass;
} UPBFieldMetadata;

typedef struct {
  UPBFieldMetadata *_Nonnull fieldMetadataArray;

  const upb_MiniTable *_Nonnull miniTable;
} UPBMetadata;

// The word `NSAffineTransform` in this comment is to force parsing this as Objective-C.
