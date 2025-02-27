# TODOs

Until we have a bug tracker set up:

*   try futzing with GPB to direct-add setters (avoid objc global lock)
*   Cache IMPs for frequently called methods. (Something something thread safety...)
*   run with ASAN, MSAN, TSAN, UBSAN
*   Try MRR instead of ARC.
*   replace absl::flat_hash_map with binary search or linear search (then convert to C?)
