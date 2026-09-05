# CLAUDE.md

Bazel rules that extract whole-program LLVM bitcode from `cc_library`, `cc_binary` and `cc_test`. An aspect shadows the C/C++ dependency graph and declares one bitcode action per translation unit, built from the toolchain's own compile command. No compiler wrapper, no dependency on the rllvm binary. Bzlmod only, Bazel 9.

## Layout

| path | role |
|---|---|
| `bitcode/defs.bzl` | public API: the `rllvm_cc_bitcode` rule |
| `bitcode/aspect.bzl` | the aspect; propagates `BitcodeInfo` |
| `bitcode/compile.bzl` | one `.bc` per translation unit |
| `bitcode/providers.bzl` | `BitcodeInfo`, source classification |
| `bitcode/toolchain.bzl` | supplies `llvm-link` and `llvm-ar` |
| `bitcode/merge.bzl` | merge step shared by the cc and Rust rules |
| `rust/` | the crate-graph aspect and `rllvm_rust_bitcode` |
| `toolchain/` | LLVM download, bzlmod extension, toolchain registration |
| `examples/wasm/` | wasm32-wasip1 fixture and its WASI sysroot |
| `examples/` | diamond fixture and invariant tests |

## Build and test

```bash
bazel build //... && bazel test //bitcode/tests:all
cd examples && bazel build //:diamond_bc && ./tests/bitcode_test.sh
```

`tests/bitcode_test.sh` drives Bazel itself, so it is a plain script rather than a `sh_test`. Nesting it inside a Bazel test deadlocks on the server lock.

## Git workflow

One long-lived branch, `main`, with temporary feature branches merged by squash PR and deleted on merge. Conventional Commits always; `!` or a `BREAKING CHANGE:` footer for breaking changes. Below 1.0 a plain `feat:` is a patch bump, so an unmarked breaking change cannot be corrected after release.

## Invariants

**Laziness is the whole design.** Bitcode actions are declared during analysis and execute only when an output group requests them. A stray default output turns every build into the second compile this ruleset exists to avoid, so `examples/tests/bitcode_test.sh` asserts a wildcard build runs none.

**Each aspect node merges only its own sources.** Folding dependencies' modules into a node would embed a shared library twice, and `llvm-link` fails on the duplicate definitions. Depset propagation deduplicates by file identity instead, which is what makes a diamond work.

**The LLVM overlay is read from `toolchains_llvm` at fetch time, never vendored.** A vendored copy silently goes stale across a version bump and then fails during analysis, far from the change that caused it.

**`CcInfo` and `cc_common` come from `rules_cc`, not from Bazel globals.** Bazel 9 removed them. A missing load surfaces as a loud error in a rule attribute but as a *silently false* membership test inside the aspect, which yields empty bitcode rather than a failure.

**The bitcode toolchain is registered separately from the cc toolchain.** It lives in the LLVM distribution repo, not the cc_toolchain config repo, so a single `register_toolchains` line covering the latter does not reach it.

**The Rust aspect asks `rules_rust` for the command it would already have run.** `construct_arguments` is how every rustc invocation in that ruleset is built, so borrowing it and changing only `--emit` keeps the bitcode in step with the features, `--extern` paths and flags of the real compile. Re-deriving that command would drift silently. This is the same bargain as the `toolchains_llvm` internals: an upstream release can require updates here.

**Rust bitcode needs exactly one codegen unit.** With more than one, rustc reports `ignoring emit path because multiple .bc files were produced` and writes none of them where the action declared its output. `rules_rust` forces a single unit for `obj` but not for `llvm-bc`, so the aspect sets it after `construct_arguments`, where it wins.

**Cross-compilation needs no code here, so the test asserts the triple.** A host-targeted module builds and links exactly as a wasm one does, so "the build succeeded" would pass while the wrong thing was extracted. `examples/tests/bitcode_test.sh` reads the target triple back out of the merged module instead.

**A rule cannot set its own tags.** `rllvm_cc_bitcode` targets are built by a wildcard build unless the caller tags them `manual`; this is documented in the README rather than worked around.
