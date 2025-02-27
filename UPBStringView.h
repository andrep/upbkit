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

#include "external/protobuf+/upb/base/string_view.h"

NS_ASSUME_NONNULL_BEGIN

@class UPBArena;

// Subclassing is restricted, since direct methods are used here. This is
// trading off extensibility for performance, but this can be revisited if
// people do want to subclass.
__attribute__((objc_subclassing_restricted))
@interface UPBStringView : NSString

// Not currently thread-safe.
@property(atomic, readonly, direct) NSString *NSStringRepresentation;

// You may pass in nil for `arena`, in which case UPBStringView will do no
// memory management of the upb_StringView when the receiver is deallocated.
+ (instancetype)stringView:(upb_StringView)stringView
                 withArena:(nullable UPBArena *)arena
    __attribute__((objc_direct));

@end

NS_ASSUME_NONNULL_END
