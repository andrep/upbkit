
* A random idea for a "zero-parse" protobuf format, when parse time really
  matters. (This is similar to
  [FlatBuffers](https://github.com/google/flatbuffers) and [Cap'n
  Proto](https://capnproto.org/).) This could be achieved by using the same
  layout for both an in-memory protobuf structure and the wire format. This
  could be achieved using [redundant
  varints](https://github.com/protocolbuffers/protobuf/issues/1530), which allow
  varints to be padded to a statically-known size.
