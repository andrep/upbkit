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

#import <XCTest/XCTest.h>

#include <objc/runtime.h>

#import "GPBExtensions/GPBMessage+UPBDecoding.h"
#import "GPBExtensions/UPBMetadata.h"
#import "GPBExtensions/UPBMetadataMap.h"
#import "GPBExtensions/tests/UPBKitTestProtos.h"
#import "GPBExtensions/tests/protos/Amalgamated.pbobjc.h"

@interface GPBMessageUPBTest : XCTestCase
@end

@implementation GPBMessageUPBTest

static void AssertEqualObjectsFromDeserializedProtobufData(Class protobufClass,
                                                           NSData *data,
                                                           UPBParsing options) {
  NSError *error;

  id gpbObject = [protobufClass parseFromData:data error:&error];
  XCTAssertNil(error);
  XCTAssert(gpbObject);

  id upbObject =
      [protobufClass upb_parseFromData:data options:options error:&error];
  XCTAssertNil(error);
  XCTAssert(upbObject);

  XCTAssertEqualObjects(gpbObject, upbObject);
}

+ (NSArray<NSInvocation *> *)testInvocations {
  NSMutableArray<NSInvocation *> *invocations =
      [[super testInvocations] mutableCopy];

  for (UPBKitTestProto *testProto in
       [UPBKitTestProto allTestProtos:UPBKitTestsProtosTargetUnitTests]) {
    IMP imp = imp_implementationWithBlock(^{
      AssertEqualObjectsFromDeserializedProtobufData(
          testProto.messageClass, testProto.data, UPBParsingNone);
      AssertEqualObjectsFromDeserializedProtobufData(
          testProto.messageClass, testProto.data, UPBParsingLazySubmessages);
    });

    NSMutableString *testName = [@"test" mutableCopy];
    [testName appendString:testProto.identifier];
    [testName appendString:@"GPBEqualToUPB"];
    SEL sel = sel_registerName(testName.UTF8String);

    BOOL success = class_addMethod(self, sel, imp, "v@:");
    XCTAssertTrue(success);

    NSInvocation *invocation = [NSInvocation
        invocationWithMethodSignature:[NSMethodSignature
                                          signatureWithObjCTypes:"v@:"]];
    invocation.selector = sel;
    invocation.target = self;

    [invocations addObject:invocation];
  }

  return invocations;
}

- (void)testBasic {
  UPBKitTestProto *testProto =
      [UPBKitTestProto testProtoForIdentifier:@"UPBKitTestBasic-no_benchmark"];
  UPBKitTestBasic *basic =
      [testProto.messageClass upb_parseFromData:testProto.data
                                        options:0
                                          error:NULL];
  XCTAssertEqual(basic.b, YES);
  XCTAssertEqual(basic.i32, 61);
}

- (void)testFileDescriptorSet {
  UPBKitTestProto *testProto =
      [UPBKitTestProto testProtoForIdentifier:@"GPBFileDescriptorSet"];
  GPBFileDescriptorSet *fileDescriptorSet =
      [testProto.messageClass upb_parseFromData:testProto.data
                                        options:0
                                          error:NULL];
  XCTAssertEqualObjects(fileDescriptorSet.fileArray[0].messageTypeArray[0].name,
                        @"ComplexMessage");
}

@end
