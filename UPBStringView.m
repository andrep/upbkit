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

#import "UPBStringView.h"

#import "UPBArena.h"

@implementation UPBStringView {
  upb_StringView _stringView;
  UPBArena *_arena;
  NSString *_NSStringRepresentation;
}

+ (instancetype)stringView:(upb_StringView)stringView
                 withArena:(UPBArena *)arena {
  UPBStringView *object = [[self alloc] init];
  object->_stringView = stringView;
  object->_arena = arena;

  return object;
}

- (NSString *)NSStringRepresentation {
  if (_NSStringRepresentation)
    return _NSStringRepresentation;

  _NSStringRepresentation =
      [[NSString alloc] initWithBytes:_stringView.data
                               length:_stringView.size
                             encoding:NSUTF8StringEncoding];

  return _NSStringRepresentation;
}

- (NSUInteger)length {
  return self.NSStringRepresentation.length;
}

- (unichar)characterAtIndex:(NSUInteger)index {
  return [self.NSStringRepresentation characterAtIndex:index];
}

- (void)getCharacters:(unichar *)buffer range:(NSRange)range {
  [self.NSStringRepresentation getCharacters:buffer range:range];
}

// TODO: Could probably implement lots more of these. Or use
// -forwardingTargetForSelector: (but that's slower. Maybe.)
// - (BOOL)isEqualToString:(NSString *)aString {
//   return [self.NSStringRepresentation isEqualToString:aString];
// }

// - (NSUInteger)hash {
//   return self.NSStringRepresentation.hash;
// }

// - (NSString *)description {
//   return [NSString stringWithFormat:@"(UPBStringView)%@",
//   self.NSStringRepresentation.description];
// }

@end
