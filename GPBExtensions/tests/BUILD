# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# load(
#     "@build_bazel_rules_swift//swift:repositories.bzl",
#     "swift_rules_dependencies",
# )
load("@protobuf//bazel:proto_library.bzl", "proto_library")
load("@rules_apple//apple:ios.bzl", "ios_application", "ios_unit_test")
load("@rules_swift//proto:swift_proto_library.bzl", "swift_proto_library")
load("@rules_swift//swift:swift_library.bzl", "swift_library")
load(
    "@rules_xcodeproj//xcodeproj:defs.bzl",
    "top_level_target",
    "xcodeproj",
)

package(default_visibility = ["//visibility:public"])

objc_library(
    name = "GPBMessage_UPBDecodingTest_lib",
    testonly = 1,
    srcs = [
        "GPBMessage+UPBDecodingTest.m",
    ],
    deps = [
        ":test_protos_lib",
        "//GPBExtensions:GPBMessage+UPBDecoding",
        "//GPBExtensions:UPBMetadata",
        "//GPBExtensions:UPBMetadataMap",
        "//GPBExtensions/tests/protos:objc_protos",
        "@protobuf//objectivec",
    ],
)

ios_unit_test(
    name = "GPBMessage_UPBDecodingTest",
    size = "small",
    testonly = 1,
    minimum_os_version = "14.0",
    deps = [
        ":GPBMessage_UPBDecodingTest_lib",
    ],
)

xcodeproj(
    name = "GPBMessage_UPBDecodingTest_xcodeproj",
    project_name = "GPBMessage_UPBDecodingTest",
    tags = ["manual"],
    top_level_targets = [
        ":GPBMessage_UPBDecodingTest",
    ],
)

objc_library(
    name = "brotli",
    testonly = 1,
    srcs = ["UPBKitBrotli.m"],
    hdrs = ["UPBKitBrotli.h"],
    deps = [
        "@brotli//:brotlidec",
    ],
)

objc_library(
    name = "test_protos_lib",
    testonly = 1,
    srcs = ["UPBKitTestProtos.m"],
    hdrs = ["UPBKitTestProtos.h"],
    data = [
        "//GPBExtensions/tests/protos:test_protos",
    ],
    deps = [
        ":brotli",
    ],
)

# don't build this manually, since the Apple platform type isn't specified. if you want to build this target, build :benchmark_app instead.
objc_library(
    name = "benchmark",
    testonly = 1,
    srcs = [
        "benchmark.mm",
    ],
    sdk_frameworks = ["UIKit"],
    tags = ["manual"],
    deps = [
        ":swift_protobuf_parser_lib",
        ":test_protos_lib",
        "//:UPBArena",
        "//GPBExtensions:GPBMessage+UPBDecoding",
        "//GPBExtensions:GPBMessage+UPBMetadata",
        "//GPBExtensions/tests/protos:objc_protos",
        "//GPBExtensions/tests/protos:swift_protos",
        "@google_benchmark//:benchmark",
        "@protobuf//upb/message",
        "@protobuf//upb/wire",
    ],
)

ios_application(
    name = "benchmark_app",
    testonly = 1,
    bundle_id = "upbkit.benchmark",
    families = ["iphone"],
    infoplists = ["Info.plist"],
    minimum_os_version = "14.0",
    deps = [
        ":benchmark",
    ],
)

xcodeproj(
    name = "benchmark_xcodeproj",
    default_xcode_configuration = "Release",
    project_name = "benchmark",
    tags = ["manual"],
    top_level_targets = [
        ":benchmark_app",
    ],
    xcode_configurations = {
        "Debug": {
            "//command_line_option:compilation_mode": "dbg",
        },
        "Release": {
            "//command_line_option:compilation_mode": "opt",
        },
    },
)

swift_library(
    name = "swift_protobuf_parser_lib",
    srcs = [
        "SwiftProtobufParser.swift",
    ],
    generates_header = True,
    deps = [
        "//GPBExtensions/tests/protos:swift_protos",
    ],
)
