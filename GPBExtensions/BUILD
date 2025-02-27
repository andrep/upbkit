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

package(default_visibility = ["//visibility:public"])

objc_library(
    name = "UPBMetadataMap",
    hdrs = ["UPBMetadataMap.h"],
    non_arc_srcs = ["UPBMetadataMap.mm"],
    deps = [
        ":UPBMetadata",
        "@abseil-cpp//absl/container:fixed_array",
        "@abseil-cpp//absl/container:flat_hash_map",
        "@abseil-cpp//absl/container:flat_hash_set",
        "@protobuf//objectivec",
        "@protobuf//upb/mini_table:mini_table",
        "@protobuf//upb/mini_table:internal",
    ],
)

objc_library(
    name = "UPBMetadata",
    hdrs = ["UPBMetadata.h"],
    deps = [
        "@protobuf//upb/mem",
        "@protobuf//upb/mini_table:mini_table",
    ],
)

objc_library(
    name = "GPBMessage+UPBMetadata",
    srcs = ["GPBMessage+UPBMetadata.mm"],
    hdrs = ["GPBMessage+UPBMetadata.h"],
    visibility = ["//visibility:public"],
    deps = [
        ":UPBMetadata",
        ":UPBMetadataMap",
        "//:UPBArena",
        "@abseil-cpp//absl/container:fixed_array",
        "@abseil-cpp//absl/container:flat_hash_map",
        "@abseil-cpp//absl/container:inlined_vector",
        "@abseil-cpp//absl/strings",
        "@protobuf//objectivec",
        "@protobuf//upb/base",
        "@protobuf//upb/mini_descriptor",
        "@protobuf//upb/mini_descriptor:internal",
        "@protobuf//upb/mini_table",
    ],
)

objc_library(
    name = "GPBMessage+UPBDecoding",
    srcs = ["GPBMessage+UPBDecoding.mm"],
    hdrs = [
        "GPBMessage+UPBDecoding.h",
    ],
    deps = [
        ":GPBMessage+UPBMetadata",
        ":UPBMetadata",
        ":UPBMetadataMap",
        "//:NSData+UPBStringView",
        "//:UPBArena",
        "//:UPBStringView",
        "@abseil-cpp//absl/container:flat_hash_map",
        "@protobuf//objectivec",
        "@protobuf//upb:eps_copy_input_stream",
        "@protobuf//upb:message_promote",
        "@protobuf//upb:wire_reader",
        "@protobuf//upb/message",
    ],
)
