# rules_rllvm

Bazel rules that extract whole-program LLVM bitcode from `cc_library`, `cc_binary` and `cc_test`.

An aspect shadows the C/C++ dependency graph and declares one bitcode action per translation unit, built from the toolchain's own compile command. Actions execute only when something requests their output, so a normal build runs no bitcode actions. Any node is a valid extraction point — a library is as addressable as a binary.

There is no compiler wrapper, nothing is injected into object-file sections, and no absolute paths are embedded in build outputs. rules_rllvm does not depend on the [rllvm](https://github.com/h1994st/rllvm) binary, which continues independently as a wllvm/gllvm port for non-Bazel builds.

Bzlmod only. Bazel 9 removed `WORKSPACE`.

## Setup

Add the dependency to `MODULE.bazel`:

<!-- x-release-please-start-version -->
```starlark
bazel_dep(name = "rules_rllvm", version = "0.1.1")
```
<!-- x-release-please-end -->

Then register the toolchains:

```starlark
rllvm = use_extension("@rules_rllvm//toolchain:extensions.bzl", "rllvm")
rllvm.toolchain(
    name = "rllvm_toolchain",
    llvm_version = "19.1.0",
)

use_repo(rllvm, "rllvm_toolchain")
use_repo(rllvm, "rllvm_toolchain_llvm")

register_toolchains("@rllvm_toolchain//:all")
register_toolchains("@rllvm_toolchain_llvm//:bitcode_toolchain")
```

The second `register_toolchains` is required: the bitcode toolchain lives in the LLVM distribution repo, which is separate from the cc toolchain config repo.

## Usage

```starlark
load("@rules_rllvm//bitcode:defs.bzl", "rllvm_cc_bitcode")

rllvm_cc_bitcode(
    name = "app_bc",
    target = "//:app",
    strategy = "flat",   # flat | staged | archive
    tags = ["manual"],
)
```

`bazel build //:app_bc` produces `app_bc.bc` and `app_bc.bc.manifest.json`.

A rule cannot set its own tags, so a `rllvm_cc_bitcode` target in a normal package is built by `bazel build //...`. Tag it `manual`, or keep these targets in a separate package.

Per-TU bitcode without merging:

```
bazel build //:app_bc --output_groups=bitcode_files
```

One-off extraction without editing BUILD files, at the cost of running the aspect across everything it reaches:

```
bazel build //:app \
  --aspects=@rules_rllvm//bitcode:aspect.bzl%bitcode_aspect \
  --output_groups=bitcode_files
```

## WebAssembly

Nothing in the aspect is wasm-specific. Each action is built from whichever cc toolchain the platform resolved, so the bitcode follows the target:

```
bazel build //wasm:app_bc --platforms=@toolchains_llvm//platforms:wasip1-wasm32
```

wasm targets need a sysroot, which the toolchain takes as its own tag:

```starlark
rllvm.sysroot(
    name = "rllvm_toolchain",
    label = "@wasi_sdk_sysroot//wasm32-wasip1",
    targets = ["wasip1-wasm32"],
)
```

One toolchain covers both the host and wasm: `sysroot` and `stdlib` are keyed by target pair, so wasm entries leave the host defaults alone. See [`examples/wasm/`](examples/wasm/).

## Rust

```starlark
load("@rules_rllvm//rust:defs.bzl", "rllvm_rust_bitcode")

rllvm_rust_bitcode(
    name = "app_bc",
    target = ":app",
    tags = ["manual"],
)
```

One-off extraction works the same way, with the crate aspect:

```
bazel build //:app \
  --aspects=@rules_rllvm//rust:aspect.bzl%rust_bitcode_aspect \
  --output_groups=bitcode_files
```

Output groups and merge strategies match the cc rule. One crate is already one module, so `flat` and `staged` differ only where a crate graph also reaches C/C++ targets.

Loading `//rust:defs.bzl` is what pulls `rules_rust` into a build. A project that extracts only C/C++ bitcode never loads it and never registers a Rust toolchain.

Generic and `#[inline]` code from `std` is monomorphised into the crates that use it, so it does reach the extracted module. What is missing is the rest: `std` arrives as prebuilt rlibs rather than as a Bazel dependency, so the aspect never sees those and cannot record them as a gap either. Reaching them would need a `-Zbuild-std` toolchain.

rustc brings its own LLVM, and it need not match the one `llvm_version` names. Today rustc writes a bitcode summary newer than LLVM 19 accepts: `llvm-link` ignores it and the merge works, while `llvm-dis` rejects the same file. That is two tools disagreeing about strictness rather than a compatibility guarantee, so a much newer Rust toolchain against a much older `llvm_version` is the combination to be careful with.

## Objective-C

`.m` and `.mm` are already compilable sources and `objc_library` provides `CcInfo`, so the aspect reaches Objective-C with no rules of its own — `rllvm_cc_bitcode` takes an `objc_library` like any other target.

`objc_library` refuses any toolchain that does not enable the `objc-compile` action, which in practice means the Apple CC toolchain from `apple_support`. Registering that would outrank the LLVM toolchain for every C/C++ target in the workspace, so pass it for the one invocation instead:

```
bazel build //objc:greeter_bc \
  --extra_toolchains=@local_config_apple_cc_toolchains//:all
```

The compiler and the merge tools are then different LLVM builds. Xcode 21 emitting for LLVM 19 tools works, but LLVM guarantees only that newer readers read older writers, not the reverse, so a newer Xcode against an old `llvm_version` may not. macOS only. See [`examples/objc/`](examples/objc/).

## Output groups

| group | contents |
|---|---|
| *(default)* | merged module and manifest |
| `bitcode_files` | every per-TU `.bc` in the closure |
| `modules` | per-node merged modules |
| `manifest` | skip record alone |

## Merge strategies

| strategy | behaviour |
|---|---|
| `flat` | one `llvm-link` over the transitive per-TU bitcode |
| `staged` | `llvm-link` over per-node modules, so an edit re-merges one library plus the top |
| `archive` | `llvm-ar` over the transitive per-TU bitcode, for tools that select modules |

All three consume deduplicated depsets, so the choice affects cost, not correctness.

## Manifest

The manifest is a default output rather than an opt-in group, because a record of what is missing only does its job next to the artifact.

A dependency that contributes code to the link but yields no bitcode — `cc_import`, a prebuilt archive, a system library — is a real gap and is recorded:

```json
{"kind":"cc_library","reason":"no_sources","target":"@@//:asm_only"}
```

Header-only libraries contribute no code, so their absence is not a gap and they are deliberately not recorded.

Missing bitcode is expected and recorded. Broken bitcode is an error: a translation unit that fails to compile, or a failing `llvm-link`, fails the build.

## Requirements

Bazel 9 and `toolchains_llvm` 1.6.0 or later. Any platform `toolchains_llvm` supports; verified on darwin/arm64 and linux/x86_64.

rules_rllvm uses `toolchains_llvm` internal APIs, so a future release of it may require updates here.

## License

Apache-2.0. See [LICENSE](LICENSE).
