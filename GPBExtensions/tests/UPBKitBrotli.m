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

#include "external/brotli+/c/include/brotli/decode.h"

NSMutableData *UPBKitBrotliDecompress(size_t compressedSize,
                                      const char *compressedBytes) {
  static const size_t kInitialBufferSize = 1024 * 1024; // 1MB

  NSMutableData *data = [NSMutableData dataWithLength:kInitialBufferSize];

  {
    BrotliDecoderState *state = BrotliDecoderCreateInstance(NULL, NULL, NULL);
    size_t decodedSize = kInitialBufferSize;

    // TODO: I feel like there has to be a more efficient way to do
    // this...
    int errorCount = 0;
    for (;;) {
      BrotliDecoderResult result = BrotliDecoderDecompress(
          compressedSize, (const uint8_t *)compressedBytes, &decodedSize,
          (uint8_t *)data.mutableBytes);
      if (result == BROTLI_DECODER_RESULT_SUCCESS)
        break;
      if (result == BROTLI_DECODER_RESULT_ERROR) {
        if (errorCount >= 5) {
          NSLog(@"UPBBrotli encountered 5 errors decompressing %zu bytes. (If "
                @"your deserialized proto is >=32MB, bump up the errorCount in "
                @"UPBBrotli.m.)",
                compressedSize);
          return nil;
        }

        decodedSize *= 2;
        data.length = decodedSize;
        errorCount++;
        continue;
      }

      // TODO: Handle BROTLI_DECODER_RESULT_NEEDS_MORE_(INPUT|OUTPUT)
      // returns.
      assert(false);
    }

    data.length = decodedSize;

    BrotliDecoderDestroyInstance(state);
  }

  return data;
}
