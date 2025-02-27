# third_party/protobuf

This project uses a single file from [Google's Protocol
Buffers](https://github.com/protocolbuffers/protobuf/) repository:
`descriptor.proto`, which is used for unit testing and benchmarking purposes.

For ease of maintenance and clear separation of ownership, the
`descriptor.proto` file lives here, underneath a `third_party` directory. The
directory structure in the protobuf repo is mirrored here, so descriptor.proto
lives in `src/google/protobuf/`.
