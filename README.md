# rules_rllvm

Bazel rules that extract whole-program LLVM bitcode from `cc_library`,
`cc_binary` and `cc_test` targets.

An aspect shadows the C/C++ dependency graph and declares one bitcode action per
translation unit, built from the toolchain's own compile command. Actions are
declared during analysis and executed only when something asks for their
outputs, so a normal build runs **zero** bitcode actions.

There is no compiler wrapper. The `clang` drivers are left exactly as the LLVM
distribution ships them, nothing is injected into object-file sections, and no
absolute paths are embedded in build outputs. rules_rllvm does not depend on the
[rllvm](https://github.com/h1994st/rllvm) binary; rllvm continues independently
as a wllvm/gllvm port for non-Bazel builds.

Bzlmod only — Bazel 9 removed `WORKSPACE`.

## Setup

In your `MODULE.bazel`:

```starlark
bazel_dep(name = "rules_rllvm", version = "<version>")

rllvm = use_extension("@rules_rllvm//toolchain:extensions.bzl", "rllvm")
rllvm.toolchain(
    name = "rllvm_toolchain",
    llvm_version = "19.1.0",
)

use_repo(rllvm, "rllvm_toolchain")
use_repo(rllvm, "rllvm_toolchain_llvm")

register_toolchains("@rllvm_toolchain//:all")

# The bitcode toolchain instance lives in the LLVM distribution repo, which is
# separate from the cc_toolchain config repo registered above.
register_toolchains("@rllvm_toolchain_llvm//:bitcode_toolchain")
```

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

Any node is a valid extraction point — a library is as addressable as a binary.

Per-TU bitcode without merging:

```
bazel build //:app_bc --output_groups=bitcode_files
```

**Note:** a rule cannot set its own tags. A `rllvm_cc_bitcode` target in a
normal package will be built by `bazel build //...`. Tag it `manual` or keep
these targets in a separate package if you want strictly on-demand behaviour.

Dependencies with no sources (`cc_import`, prebuilt archives, system
libraries) are excluded from the bitcode and listed in the manifest.

One-off extraction without editing BUILD files:

```
bazel build //:app \
  --aspects=@rules_rllvm//bitcode:aspect.bzl%bitcode_aspect \
  --output_groups=bitcode_files
```

Command-line attachment runs the aspect across everything it reaches, so
prefer the rule for anything repeated.

## Output groups

| output group | contents |
|---|---|
| *(default)* | merged module + manifest |
| `bitcode_files` | every per-TU `.bc` in the closure |
| `modules` | per-node merged modules (staged spine) |
| `manifest` | skip record alone |

## Merge strategies

| strategy | behaviour |
|---|---|
| `flat` | one `llvm-link` over the transitive per-TU bitcode |
| `staged` | `llvm-link` over per-node modules, so a one-line edit re-merges one library plus the top |
| `archive` | `llvm-ar` over the transitive per-TU bitcode, for tools that select modules rather than consume one |

Correctness does not depend on the choice — all three consume deduplicated
depsets — only cost does.

## The manifest

The manifest is a **default output**, not an opt-in group: a record of what is
missing only does its job if it sits next to the artifact.

A dependency that contributes code to the link but yields no bitcode is a real
gap and is recorded:

```json
{"kind":"cc_library","reason":"no_sources","target":"@@//:asm_only"}
```

Header-only libraries contribute no code, so their absence is not a gap and
they are deliberately **not** recorded — logging them would bury the entries
that matter.

Missing bitcode is expected and recorded; *broken* bitcode is an error. A
translation unit that fails to compile, or an `llvm-link` failure, fails the
build rather than being silently omitted.

## Configuration options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `llvm_version` | `string` | — | LLVM version to download (e.g. `"19.1.0"`) |
| `llvm_versions` | `dict` | — | Per-(os, arch) LLVM versions, as an alternative to `llvm_version` |

## Supported platforms

Any platform `toolchains_llvm` supports. The old `x86_64-linux` restriction is
gone: it came from the rllvm binary distribution, which is no longer a
dependency. Verified on darwin/arm64 and linux/x86_64.

## Requirements

- Bazel 9 (`.bazelversion` pins `9.0.0`)
- `toolchains_llvm` >= 1.6.0 — 1.5.0 is incompatible with Bazel 9

Depends on `toolchains_llvm` internal APIs, so a future `toolchains_llvm`
release may require updates here.

## License

See [LICENSE](LICENSE) for details.
