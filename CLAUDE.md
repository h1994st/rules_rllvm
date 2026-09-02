# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

Bazel rules that extract whole-program LLVM bitcode from `cc_library` /
`cc_binary` / `cc_test`. An aspect shadows the C/C++ dependency graph and
declares one bitcode action per translation unit, built from the toolchain's own
compile command. Actions run only when an output group asks for them, so a
normal build runs **zero** bitcode actions.

There is no compiler wrapper and no dependency on the rllvm binary. Bzlmod only,
Bazel 9.

## Layout

| path | role |
|---|---|
| `bitcode/defs.bzl` | public API: the `rllvm_cc_bitcode` rule |
| `bitcode/aspect.bzl` | `bitcode_aspect`, propagates `BitcodeInfo` |
| `bitcode/compile.bzl` | one `.bc` per translation unit |
| `bitcode/providers.bzl` | `BitcodeInfo`, source classification |
| `bitcode/toolchain.bzl` | carries `llvm-link` and `llvm-ar` |
| `toolchain/` | LLVM download, bzlmod extension, toolchain registration |
| `examples/` | diamond fixture and invariant tests |

## Build & test

```bash
bazel build //... && bazel test //bitcode/tests:all
cd examples && bazel build //:diamond_bc && ./tests/bitcode_test.sh
```

`tests/bitcode_test.sh` runs bazel internally, so it is a plain script, not a
`sh_test`. Do not nest it inside a Bazel test.

## Git workflow

- **One long-lived branch: `main`.** Temporary feature branches off `main`,
  merged by PR, deleted on merge. There is no `dev` branch.
- **Conventional Commits, always**: `<type>: <summary>`. Use `!` and a
  `BREAKING CHANGE:` footer for breaking changes.
- **Keep the body short, or empty.** Most commits need no body at all.

## Traps

Each of these has already cost a debugging session.

- **`CcInfo` and `cc_common` are not Bazel 9 globals.** Load them from
  `@rules_cc//cc/common:cc_info.bzl` and `@rules_cc//cc/common:cc_common.bzl`.
  `providers = [CcInfo]` fails loudly; `CcInfo not in target` fails *silently*.
- **Do not vendor toolchains_llvm's `BUILD.llvm_repo.tpl`.** `repo.bzl` reads it
  at fetch time and appends `toolchain/BUILD.llvm_repo.additions.bazel`. A
  vendored copy goes stale and fails at analysis with a missing-target error far
  from the version bump that caused it.
- **The bitcode toolchain lives in the LLVM distribution repo** (`<name>_llvm`),
  not the cc_toolchain config repo (`<name>`), so it needs its own
  `register_toolchains` line.
- **A rule cannot set its own tags.** `rllvm_cc_bitcode` targets need
  `tags = ["manual"]` or a wildcard build will build them.
- **Each aspect node merges only its own sources.** Including deps' modules
  would embed a shared dependency twice and break `llvm-link` on a diamond.
