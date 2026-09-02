# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Project Overview

rules_rllvm provides Bazel rules that extract whole-program LLVM bitcode from
`cc_library` / `cc_binary` / `cc_test` targets. An aspect shadows the C/C++
dependency graph and declares one bitcode action per translation unit, built
from the toolchain's own compile command. Actions are declared during analysis
and executed only when an output group asks for them, so a normal build runs
**zero** bitcode actions.

**rules_rllvm does not depend on the rllvm binary.** There is no compiler
wrapper, no clang substitution, and nothing injected into object-file sections.
rllvm continues independently as a wllvm/gllvm port for non-Bazel builds.

Bzlmod only — Bazel 9 removed `WORKSPACE`.

## Key Architecture

- **`bitcode/defs.bzl`** — Public API: the `rllvm_cc_bitcode` rule. Merges via
  `flat` (transitive per-TU), `staged` (per-node modules) or `archive`
  (`llvm-ar`). Writes the merged module and the manifest.
- **`bitcode/aspect.bzl`** — `bitcode_aspect`: walks `deps` and
  `implementation_deps`, declares per-TU actions plus one per-node `llvm-link`
  module, and propagates `BitcodeInfo`.
- **`bitcode/compile.bzl`** — `compile_tu_to_bitcode`: builds the compile
  command from `cc_common.create_compile_variables` +
  `get_memory_inefficient_command_line`, with `-emit-llvm` appended.
- **`bitcode/providers.bzl`** — `BitcodeInfo` and source classification.
- **`bitcode/toolchain.bzl`** — `rllvm_bitcode_toolchain`, carrying `llvm-link`,
  `llvm-ar` and `runtime_libs`.
- **`toolchain/rules.bzl`** — `rllvm_toolchain()` macro; registers a stock LLVM
  toolchain via `toolchains_llvm` with no driver substitution.
- **`toolchain/repo.bzl`** — downloads the LLVM distribution and overlays
  `BUILD.llvm_repo.bazel` on it.
- **`toolchain/extensions.bzl`** — the bzlmod module extension.
- **`examples/`** — the diamond fixture and the invariant tests.

## How It Works

1. `rllvm_toolchain()` downloads LLVM via `toolchains_llvm` and registers it
   unmodified. `repo.bzl` also emits a `bitcode_toolchain` instance in the LLVM
   distribution repo.
2. `rllvm_cc_bitcode(target = ...)` attaches `bitcode_aspect` to that target's
   closure only — never repo-wide.
3. Each node declares one `.bc` per compilable source in `srcs`, plus a
   `llvm-link` merge of *its own sources only*. Own-sources-only is load-bearing:
   it is what keeps a diamond from embedding a shared dependency twice.
4. `rllvm_cc_bitcode` merges the deduplicated depset and writes a manifest.
5. Dependencies that contribute code to the link but no bitcode (`cc_import`,
   prebuilt archives) are skipped and recorded. Header-only libraries contribute
   no code, so they are deliberately *not* recorded.

## Build & Test

```bash
# Build the rules and run the analysis tests
bazel build //...
bazel test //bitcode/tests:all

# The fixture and the invariant tests
cd examples
bazel build //:diamond_bc
./tests/bitcode_test.sh    # laziness, content, diamond dedup, skip recording
```

`tests/bitcode_test.sh` runs bazel internally, so it is a plain script, not a
`sh_test` — do not nest it inside a Bazel test.

## Conventions

- Starlark (.bzl) files follow standard Bazel style.
- **`CcInfo` and `cc_common` are not Bazel 9 globals.** Load them from
  `@rules_cc//cc/common:cc_info.bzl` and `@rules_cc//cc/common:cc_common.bzl`.
  `providers = [CcInfo]` fails loudly when unloaded; `CcInfo not in target`
  fails *silently*, which is the dangerous half.
- Uses `toolchains_llvm` internal APIs (pinned to 1.6.0; 1.5.0 is
  Bazel-9-incompatible).
- The LLVM repo's BUILD is toolchains_llvm's own `BUILD.llvm_repo.tpl`, read at
  fetch time, plus `toolchain/BUILD.llvm_repo.additions.bazel`. Do **not**
  vendor a copy of the upstream template: a stale copy fails at analysis with a
  missing-target error far from the version bump that caused it, which is
  exactly how `extra_config_site` broke. Only the upstream half is
  `.format()`-substituted for `{LLVM_VERSION}`.
- The bitcode toolchain instance lives in the LLVM **distribution** repo
  (`<name>_llvm`), not the cc_toolchain **config** repo (`<name>`), so it needs
  its own `register_toolchains` line.
- A rule cannot set its own tags: `rllvm_cc_bitcode` targets need
  `tags = ["manual"]` or a wildcard build will build them.
- Conventional Commits: `<type>: <summary>`.
