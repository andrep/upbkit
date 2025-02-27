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

#import "NSString+UPBStringView.h"

#import <objc/runtime.h>

upb_StringView UPBStringViewFromNSString(NSString *string, UPBArena *arena) {
  const size_t size =
      [string lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + sizeof('\0');
  char *buffer = (char *)upb_Arena_Malloc(arena.arena, size);
  if (!buffer) {
    [NSException raise:NSMallocException
                format:@"upb_Arena_Malloc(%p, %zu)", arena.arena, size];
  }

  BOOL success =
      [string getCString:buffer maxLength:size encoding:NSUTF8StringEncoding];
  if (!success) {
    [NSException raise:NSInternalInconsistencyException
                format:@"-[%s %s] failed", class_getName([NSString class]),
                       sel_getName(@selector(getCString:maxLength:encoding:))];
  }

  return upb_StringView_FromDataAndSize(buffer, size);
}
