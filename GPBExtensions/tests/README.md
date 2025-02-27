# UPBKit > GPBExtensions > tests

The unit tests and benchmarks for UPBKit needs proto definitions and serialized
protos to work:

* `protos-definitions` contains the protobuf definitions, and
* `protos-serialized` contains (compressed) serialized protos.

The eventual intention is to be able to add arbitrary new `.proto` definitions
and serialized protos, and the unit tests and benchmarks will just pick them up
without needing to edit the source code. It's not quite there, but it works well
enough for the moment.

The serialized protos are stored compressed with
[Brotli](https://github.com/google/brotli), to save on repo space. (During
development, your author had megabytes of serialized protos for benchmarking
purposes, which made this repo much larger.)

See the README.md files in the `protos-definitions` and `protos-serialized`
directories for more info on the file organization and how they're used.
