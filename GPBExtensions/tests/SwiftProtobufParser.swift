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

import Foundation

import GPBExtensions_tests_protos_swift_protos

// This was a quick way to get the Swift protobuf library callable from Objective-C. Making this a class with methods means that we can also dynamically contruct selectors to invoke the different method names.

public class SwiftProtobufParser : NSObject {
  @objc
  public class func parseGPBFileDescriptorSet(_ data: Data) {
    do {
      _ = try Google_Protobuf_FileDescriptorSet.init(serializedData: data)
    } catch let error {
      print("\(#function): \(error.localizedDescription)")
    }
  }
}
