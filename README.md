# rules_rllvm

Bazel rules that extract whole-program LLVM bitcode from C, C++, Objective-C and Rust targets.

An aspect shadows the dependency graph and declares one bitcode action per translation unit, built from the toolchain's own compile command. The actions run only when something asks for their output, so an ordinary build runs none of them. Every node in the graph is an extraction point: a library is as addressable as a binary.

There is no compiler wrapper, nothing is injected into object-file sections, and no absolute paths reach the build outputs.

Bzlmod only. Bazel 9 removed `WORKSPACE`.

## The name

These rules began as a Bazel wrapper around [rllvm](https://github.com/h1994st/rllvm), a wllvm/gllvm port for non-Bazel builds. That dependency is gone: nothing here invokes the binary, and rllvm continues independently.

The `r` now reads as *recursive*. The aspect follows the dependency graph recursively, and every node it reaches contributes bitcode to the merged module.

## Setup

Add the dependency to `MODULE.bazel`:

<!-- x-release-please-start-version -->
```starlark
bazel_dep(name = "rules_rllvm", version = "0.1.2")
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

Both `register_toolchains` lines are required. The bitcode toolchain lives in the LLVM distribution repo, which is a different repo from the cc toolchain config repo.

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

`bazel build //:app_bc` writes `app_bc.bc` and `app_bc.bc.manifest.json`.

A rule cannot set its own tags, so an untagged `rllvm_cc_bitcode` target is built by `bazel build //...`. Tag it `manual`, or keep these targets in a package of their own.

Per-TU bitcode, without the merge:

```
bazel build //:app_bc --output_groups=bitcode_files
```

One-off extraction without editing BUILD files, at the cost of running the aspect over everything it reaches:

```
bazel build //:app \
  --aspects=@rules_rllvm//bitcode:aspect.bzl%bitcode_aspect \
  --output_groups=bitcode_files
```

## Targets

`rllvm_cc_bitcode` covers C, C++ and Objective-C, and Rust has a rule of its own. Each subsection below changes the target rather than the shape above.

### WebAssembly

Each action is built from whichever cc toolchain the platform resolved, so the bitcode follows the target:

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

`sysroot` and `stdlib` are keyed by target pair, so one toolchain serves the host and wasm together and the wasm entries leave the host defaults alone. See [`examples/wasm/`](examples/wasm/).

### Rust

```starlark
load("@rules_rllvm//rust:defs.bzl", "rllvm_rust_bitcode")

rllvm_rust_bitcode(
    name = "app_bc",
    target = ":app",
    tags = ["manual"],
)
```

One-off extraction uses the crate aspect:

```
bazel build //:app \
  --aspects=@rules_rllvm//rust:aspect.bzl%rust_bitcode_aspect \
  --output_groups=bitcode_files
```

Output groups and merge strategies match the cc rule. One crate is already one module, so `flat` and `staged` differ only where a crate graph also reaches C/C++ targets.

Loading `//rust:defs.bzl` is what pulls `rules_rust` into a build. A project that extracts only C/C++ bitcode never loads it and never registers a Rust toolchain.

`std` arrives as prebuilt rlibs rather than as a Bazel dependency. Its generic and `#[inline]` code is monomorphised into the crates that use it and does reach the merged module; the rest does not, and the manifest does not record it as a gap. Covering it would need a `-Zbuild-std` toolchain.

See [`examples/rust/`](examples/rust/).

### Objective-C

`.m` and `.mm` are already compilable sources and `objc_library` provides `CcInfo`, so `rllvm_cc_bitcode` takes an `objc_library` like any other target. There is nothing Objective-C-specific to load.

`objc_library` refuses any toolchain that does not enable the `objc-compile` action, which in practice means the Apple CC toolchain from `apple_support`. Registering that toolchain would outrank the LLVM one for every C/C++ target in the workspace, so pass it for the single invocation instead:

```
bazel build //objc:greeter_bc \
  --extra_toolchains=@local_config_apple_cc_toolchains//:all
```

macOS only. See [`examples/objc/`](examples/objc/).

## LLVM versions

`llvm-link` and `llvm-ar` come from `llvm_version`. C and C++ compile with that same LLVM, but Rust and Objective-C do not: rustc carries its own, and `objc_library` compiles with Apple's clang. LLVM reads bitcode backwards only — a newer reader accepts an older producer, not the reverse.

Measured against `llvm_version = "19.1.0"`: `llvm-link` and `llvm-ar` read both Apple clang 21 output and rustc 1.98 output, which is LLVM 22.

`llvm-dis` is stricter. It reads the Objective-C bitcode and the merged Rust module, but rejects the per-crate Rust files under `--output_groups=bitcode_files` with `Invalid summary version 12`. `llvm-link` skips the module summary it cannot parse and writes none of its own, so the merge is clean where its inputs are not.

LLVM does not document how far apart the two may drift. When a merge does fail, raise `llvm_version` toward the compiler.

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

`flat` and `staged` cover the same translation units and differ in cost. `archive` writes an archive of modules rather than a single merged module.

## Manifest

`app_bc.bc.manifest.json` is a default output, written beside the merged module.

A dependency that contributes code to the link but yields no bitcode — `cc_import`, a prebuilt archive, a system library — is recorded as a gap:

```json
{"kind":"cc_library","reason":"no_sources","target":"@@//:asm_only"}
```

Header-only libraries contribute no code and are not recorded.

Missing bitcode is recorded. Broken bitcode is an error: a translation unit that fails to compile, or a failing `llvm-link`, fails the build.

## Requirements

Bazel 9 and `toolchains_llvm` 1.6.0 or later. Any platform `toolchains_llvm` supports; verified on darwin/arm64 and linux/x86_64.

rules_rllvm reads internal APIs of `toolchains_llvm` and, for Rust, of `rules_rust`, so a release of either can require updates here.

## License

Apache-2.0. See [LICENSE](LICENSE).
