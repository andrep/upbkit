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

#import "GPBExtensions/tests/UPBKitTestProtos.h"

#include <objc/runtime.h>

#import "GPBExtensions/tests/UPBKitBrotli.h"

@implementation UPBKitTestProto

+ (NSArray<UPBKitTestProto *> *)allTestProtos:(UPBKitTestsProtosTarget)target {
  // This function isn't thread-safe.

  static NSMutableArray<UPBKitTestProto *> *protos = nil;
  if (protos) {
    return protos;
  }

  protos = [[NSMutableArray alloc] init];

  NSArray<NSString *> *paths = [[NSBundle
      bundleForClass:self] pathsForResourcesOfType:@"pb.br" inDirectory:nil];
  for (NSString *path in paths) {
    // Remove .pb.br from filename
    NSString *basename = [[[path lastPathComponent]
        stringByDeletingPathExtension] stringByDeletingPathExtension];

    if (target == UPBKitTestsProtosTargetBenchmarks &&
        [basename containsString:@"no_benchmark"]) {
      continue;
    }

    // Ignore everything after a - or _ in the filename.
    NSString *classname = [[basename componentsSeparatedByString:@"-"][0]
        componentsSeparatedByString:@"_"][0];

    Class cls = objc_getClass([classname UTF8String]);
    if (!cls) {
      NSLog(@"%s: Couldn't find class %@", __func__, classname);
      continue;
    }

    UPBKitTestProto *proto = [[UPBKitTestProto alloc] init];
    proto.messageClass = cls;
    proto.identifier = basename;

    NSData *compressedData = [NSData dataWithContentsOfFile:path];
    proto.data =
        UPBKitBrotliDecompress(compressedData.length, compressedData.bytes);
    [protos addObject:proto];
  }

  return protos;
}

+ (UPBKitTestProto *)testProtoForIdentifier:(NSString *)identifier {
  for (UPBKitTestProto *proto in
       [self allTestProtos:UPBKitTestsProtosTargetUnitTests]) {
    if ([proto.identifier isEqual:identifier]) {
      return proto;
    }
  }
}

@end
