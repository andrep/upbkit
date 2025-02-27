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
    name = "UPBArena",
    srcs = ["UPBArena.m"],
    hdrs = ["UPBArena.h"],
    deps = [
        "@protobuf//upb/mem",
    ],
)

objc_library(
    name = "NSData+UPBStringView",
    hdrs = ["NSData+UPBStringView.h"],
    deps = [
        ":UPBArena",
        "@protobuf//upb/base",
    ],
)

objc_library(
    name = "NSString+UPBStringView",
    srcs = ["NSString+UPBStringView.m"],
    hdrs = ["NSString+UPBStringView.h"],
    deps = [
        ":UPBArena",
        "@protobuf//upb/base",
    ],
)

objc_library(
    name = "UPBStringView",
    srcs = ["UPBStringView.m"],
    hdrs = ["UPBStringView.h"],
    deps = [
        ":UPBArena",
        "@protobuf//upb/base",
    ],
)
