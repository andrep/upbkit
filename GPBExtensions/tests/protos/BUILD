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

load("@rules_proto_grpc_objc//:defs.bzl", "objc_proto_compile", "objc_proto_library")
load("@rules_swift//proto:swift_proto_library.bzl", "swift_proto_library")

package(default_visibility = ["//visibility:public"])

filegroup(
    name = "definitions",
    srcs = glob(
        ["**/*.proto"],
        exclude = ["*osm*"],
    ),
)

filegroup(
    name = "test_protos",
    srcs = glob(["**/*.pb.br"]),
)

proto_library(
    name = "all_protos",
    srcs = [":definitions"],
)

swift_proto_library(
    name = "swift_protos",
    protos = [":all_protos"],
)

objc_proto_compile(
    name = "objc_protos_compile",
    protos = [":all_protos"],
)

genrule(
    name = "amalgamated_pbobjc_genrule",
    srcs = [
        "amalgamate_pbobjc.sh",
        ":objc_protos_compile",
    ],
    outs = [
        "Amalgamated.pbobjc.h",
        "Amalgamated.pbobjc.m",
    ],
    cmd = "$(location amalgamate_pbobjc.sh) $(location Amalgamated.pbobjc.h) $(location Amalgamated.pbobjc.m) $(locations :objc_protos_compile)",
    output_to_bindir = True,
)

objc_proto_library(
    name = "objc_protos",
    protos = [":all_protos"],
    deps = [
        ":amalgamated_pbobjc",
    ],
)

cc_library(
    name = "amalgamated_pbobjc",
    hdrs = [
        ":amalgamated_pbobjc_genrule",
    ],
)
