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

#include "external/protobuf+/upb/mem/arena.h"

// This class serves as a way for Objective-C's refcounting (typically ARC) to
// refcount an arena. This should (1) make things easier to manage when
// interoperating with Objective-C code, since this object follows standard ObjC
// refcount semantics, and (2) be generally more performant than managing arenas
// manually, since upb_Arena_Fuse() and upb_Arena_New() aren't as optimized as
// the ObjC 64-bit runtime's refcount mechanisms. (Remember that ARC also elides
// refcount calls when it can prove that e.g. local variables don't escape.)
//
// Subclassing is restricted, since direct methods are used here. This is
// trading off extensibility for performance, but this can be revisited if
// people do want to subclass.
__attribute__((objc_subclassing_restricted))
@interface UPBArena : NSObject

+ (instancetype)arena __attribute__((objc_direct));

// Callers MUST pass an arena to this factory method with a refcount of 1.
+ (instancetype)arenaWithArena:(upb_Arena *)UPBArena
    __attribute__((objc_direct));

@property(nonatomic, readonly, assign, direct) upb_Arena *arena;

@end
