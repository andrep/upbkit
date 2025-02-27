#!/bin/bash -eu
#
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

#!/bin/bash

readonly out_pbobjc_h="$1"
readonly out_pbobjc_m="$2"

shift  # remove $1
shift  # remove $2

headers=()
implementations=()

for file in "$@"; do
    case "$file" in
    *.h) headers+=("$file");;
    *.m) implementations+=("$file");;
    esac
done

cat "${headers[@]}" > "$out_pbobjc_h"
cat "${implementations[@]}" > "$out_pbobjc_m"
