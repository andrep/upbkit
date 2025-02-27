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

#import "UPBArena.h"

@implementation UPBArena {
  upb_Arena *_arena;
}

+ (instancetype)arena {
  upb_Arena *arena = upb_Arena_New();
  if (!arena) return nil;

  return [self arenaWithArena:arena];
}

+ (instancetype)arenaWithArena:(upb_Arena *)upbArena __attribute__((objc_direct)) {
  assert(upb_Arena_DebugRefCount(upbArena) == 1);

  UPBArena *arena = [[self alloc] init];
  arena->_arena = upbArena;

  return arena;
}

// There's no need to override -retain & -release to call upb_Arena_(Fuse|Free), since upb arenas
// are kept alive as long as their refcount is above zero. This class effectively replaces the calls
// to upb_Arena_(Fuse|Free) with ARC. The important thing is that when this object's refcount hits
// zero, we free the arena.
- (void)dealloc {
  upb_Arena_Free(_arena);
}

@end
