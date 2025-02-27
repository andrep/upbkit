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

#import "GPBExtensions/UPBMetadata.h"
#import "external/protobuf+/objectivec/GPBMessage.h"
#include "external/protobuf+/upb/message/message.h"

NS_ASSUME_NONNULL_BEGIN

@class UPBArena;

typedef NS_OPTIONS(NSUInteger, UPBParsing) {
  UPBParsingNone = 0,
  UPBParsingLazySubmessages = 1 << 2,
  UPBParsingLazyObjects = 1 << 3, // NSArray, NSData, NSString.

  // For benchmarking purposes.
  UPBParsingSkipMerge = 1 << 4,
  UPBParsingNoOpWalk = 1 << 1,
  UPBParsingUnknownDataSkip = 1 << 0,
};

@interface GPBMessage (UPBDecoding)

// `message` MUST be upb_Decode()d with
// kUpb_DecodeOption_ExperimentalAllowUnlinked.
- (void)upb_mergeFromMessage:(upb_Message *)message
                       arena:(UPBArena *)arena
                     options:(UPBParsing)options
                       error:(NSError **)errorPtr;

// TODO: add convenience mergeFromData and initWithData ctors
+ (nullable instancetype)upb_parseFromData:(NSData *)data
                                   options:(UPBParsing)options
                                     error:(NSError **)errorPtr;

+ (nullable const upb_MiniTable *)upb_miniTable;
- (nullable UPBArena *)upb_arena;
- (nullable upb_Message *)upb_message;

@end

NS_ASSUME_NONNULL_END
