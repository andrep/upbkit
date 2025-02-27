# protos-serialized

Put serialized protos in this directory. Serialized protos are used for:

* unit tests: protos will be parsed with both GPB and upb, and checked for
  equality.
* benchmarks: protos will be benchmarked with GPB and upb.

Proto _definitions_ for serialized protos go into the `protos-definitions`
directory, not this directory.

Only filenames with `.pb.br` will be picked up by the unit tests and benchmarks,
so feel free to put anything else here that you think would help give context to
the protos or describe them. `.pb` is a fairly standard filename extension for a
serialized binary protobuf, and `.br` is the standard extension for
Brotli-compressed files.

If you'd like to skip benchmarks
You will need to compress your serialized protos with Brotli, whose CLI is
thankfully similar to gzip. On macOS:

```sh
brew install brotli
```

## Swift

Unfortunately, I haven't quite yet spent the time to make the Swift benchmarking
code automagically pick up new serialized protos for testing. You'll need to
edit the `SwiftProtobufParser.swift` and manually add the parsing code for each
serialized proto.

Have fun benchmarking!
# protos-definitions

Put .proto definitions in this directory, and run `amalgamation.create.sh` to
create the `.pbobjc.{h,m}` files. All the `.pbobjc.{h,m}` files are concatenated
into a single `amalgamation.{h,m}` file, so that the UPBKit code can `#import` a
single header file for everything.

Swift should also pick up new .proto definitions here; the `swift_proto_library`
build rule should find all `.proto` files in this directory and link the
Swift-generated code into the benchmarks and tests.
