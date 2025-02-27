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

#import "UPBArena.h"
#include "external/protobuf+/upb/base/string_view.h"

static inline upb_StringView UPBStringViewFromNSData(NSData *data,
                                                     UPBArena *arena) {
  const size_t size = data.length;
  char *buffer = (char *)upb_Arena_Malloc(arena.arena, size);
  [data getBytes:buffer length:size];

  return upb_StringView_FromDataAndSize(buffer, size);
}

static inline upb_StringView UPBStringViewFromNSDataNoCopy(NSData *data) {
  return upb_StringView_FromDataAndSize((const char *)data.bytes, data.length);
}

static inline NSData *NSDataFromUPBStringViewNoCopy(upb_StringView sv) {
  return [NSData dataWithBytesNoCopy:(void *)sv.data
                              length:sv.size
                        freeWhenDone:NO];
}

static inline NSData *NSDataFromUPBStringViewCopy(upb_StringView sv) {
  return [NSData dataWithBytes:sv.data length:sv.size];
}
