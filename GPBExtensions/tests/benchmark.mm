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

#import <Foundation/Foundation.h>

#import <UIKit/UIKit.h>

#include <objc/message.h>
#include <objc/runtime.h>
#include <string>

#import "GPBExtensions/GPBMessage+UPBDecoding.h"
#import "GPBExtensions/GPBMessage+UPBMetadata.h"
#import "GPBExtensions/tests/UPBKitTestProtos.h"
#import "GPBExtensions/tests/protos/Amalgamated.pbobjc.h"
#import "GPBExtensions/tests/swift_protobuf_parser_lib-Swift.h"
#include "UPBArena.h"
#include "external/google_benchmark+/include/benchmark/benchmark.h"
#include "external/protobuf+/upb/message/message.h"
#include "external/protobuf+/upb/wire/decode.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  NSArray<UPBKitTestProto *> *protos =
      [UPBKitTestProto allTestProtos:UPBKitTestsProtosTargetBenchmarks];
  for (UPBKitTestProto *proto in protos) {
    CreateBenchmark(proto.messageClass, proto.identifier, proto.data);
  }

  benchmark::RunSpecifiedBenchmarks();

  NSLog(@"Benchmark finished.");

  return YES;
}

enum class Parser {
  GPB,
  UPB,
  Swift,
  // TODO: Add C++ protobuf.
};

template <Parser E>
std::function<void(benchmark::State &)>
CreateBenchmark2(Class cls, UPBParsing options, NSData *data) {
  auto fn = [=](benchmark::State &state) {
    NSError *error;
    // BenchmarkMemoryUsage();
    for (auto _ : state) {
      @autoreleasepool {
        if constexpr (E == Parser::GPB) {
          (void)[cls parseFromData:data error:&error];
        } else if constexpr (E == Parser::UPB) {
          (void)[cls upb_parseFromData:data options:options error:&error];
        } else if constexpr (E == Parser::Swift) {
          std::string parserMethodName =
              std::string("parse") + class_getName(cls) + ":";
          SEL sel = sel_registerName(parserMethodName.c_str());
          reinterpret_cast<void (*)(Class, SEL, NSData *)>(objc_msgSend)(
              [SwiftProtobufParser class], sel, data);
        }
      }
      if (error)
        abort();
    }

    state.SetLabel(
        [NSString stringWithFormat:@"size:%lu", data.length].UTF8String);

    // TODO: print CSV data for easy export to Sheets

    // {
    //   GPBMessage *proto = [cls parseFromData:data error:NULL];

    //   unsigned propertyCount;
    //   objc_property_t *properties = class_copyPropertyList(cls,
    //   &propertyCount); for (unsigned i = 0; i < propertyCount; i++) {
    //     const char* propertyName = property_getName(properties[i]);
    //   }
    //   free(properties);

    //   state.SetLabel([NSString stringWithFormat:@"gpbfields:%lu",
    //   [proto.descriptor fields].count].UTF8String);
    // }
  };

  return std::function(fn);
}

static void CreateBenchmark(Class cls, NSString *identifier, NSData *data) {
  auto foo = [&](Parser engine, UPBParsing options = 0) {
    std::string family = [&] {
      switch (engine) {
      case Parser::GPB:
        return std::string("GPB");
      case Parser::UPB: {
        std::string s = "UPB";
        if (options & UPBParsingNoOpWalk)
          s += "_NoOp";
        if (options & UPBParsingLazySubmessages)
          s += "_LazySubmessages";
        if (options & UPBParsingLazyObjects)
          s += "_Lazy";
        if (options & UPBParsingUnknownDataSkip)
          s += "_SkipUnknown";
        return s;
      }
      case Parser::Swift:
        return std::string("Swift");
      }
    }();

    auto fn = CreateBenchmark2<Parser::UPB>(cls, options, data);
    NSString *name =
        [NSString stringWithFormat:@"%@/%s", identifier, family.c_str()];
    benchmark::RegisterBenchmark(name.UTF8String, fn);
  };

  foo(Parser::GPB);
  foo(Parser::Swift);
  foo(Parser::UPB, UPBParsingNone);
  foo(Parser::UPB, UPBParsingUnknownDataSkip);
  foo(Parser::UPB, UPBParsingUnknownDataSkip | UPBParsingNoOpWalk);
  foo(Parser::UPB, UPBParsingUnknownDataSkip | UPBParsingLazySubmessages);
  foo(Parser::UPB, UPBParsingUnknownDataSkip | UPBParsingLazyObjects);
}

- (UISceneConfiguration *)application:(UIApplication *)application
    configurationForConnectingSceneSession:
        (UISceneSession *)connectingSceneSession
                                   options:(UISceneConnectionOptions *)options {
  return
      [[UISceneConfiguration alloc] initWithName:@"Default Configuration"
                                     sessionRole:connectingSceneSession.role];
}

- (void)application:(UIApplication *)application
    didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions {
}

@end

// void BM_UPBRuntimeMetadataDescriptor(benchmark::State &state) {
//   for (auto _ : state) {
//     UPBMetadata *metadata = [UPBBFileDescriptorProto
//     upb_runtimeMetadataNoMemoize]; if (!metadata) raise(SIGINT);
//   }
// }
// BENCHMARK(BM_UPBRuntimeMetadataDescriptor);

int main(int argc, char *argv[]) {
  NSString *appDelegateClassName;
  @autoreleasepool {
    appDelegateClassName = NSStringFromClass([AppDelegate class]);
  }
  return UIApplicationMain(argc, argv, nil, appDelegateClassName);
}
