# Zig SQLite

This runner calls the SQLite C API directly from Zig through `@cImport`, which
is how Zig code normally uses SQLite. There's no wrapper library.

Build and run it inside the Nix shell:

```sh
./build.sh
./benchmark 5000
```

`build.sh` compiles with `-O ReleaseSafe` against the flake's shared SQLite
3.51.0. `ReleaseSafe` keeps Zig's runtime safety checks: bounds checks,
integer-overflow checks and null unwrapping panic instead of corrupting memory.
That's the closest match to a Rust release build, which keeps bounds checks
but wraps on overflow, so Zig here is slightly stricter than Rust. `ReleaseFast`
removes the checks, turning those cases into undefined behaviour as in C. The
2-vCPU report used `ReleaseFast`. The runner creates `zig_benchmark.sqlite3` in this directory and prints
`zig_sqlite/app_request/*` rows.

Like the C runner, each connection prepares its statements once and reuses
them, so Zig should land on top of C. It's included to confirm that.
