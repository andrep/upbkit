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

#import "external/protobuf+/objectivec/GPBMessage.h"

#include "GPBExtensions/UPBMetadata.h"

typedef struct upb_MiniTable upb_MiniTable;

NS_ASSUME_NONNULL_BEGIN

@class UPBArena;

@interface GPBMessage (UPBMetadata)

+ (UPBMetadata *)upb_runtimeMetadata;

// For benchmarking only. Do not use otherwise.
+ (UPBMetadata *)upb_runtimeMetadataNoMemoize;

@end

NS_ASSUME_NONNULL_END

// The word `NSAffineTransform` in this comment is to force parsing this as
// Objective-C.
