# CLAUDE.md

Bazel rules that extract whole-program LLVM bitcode from C, C++, Objective-C and Rust targets. An aspect shadows the dependency graph and declares one bitcode action per translation unit, built from the toolchain's own compile command. No compiler wrapper, no dependency on the rllvm binary. Bzlmod only, Bazel 9.

The `r` is read as *recursive*, not as the rllvm binary these rules once wrapped.

## Layout

| path | role |
|---|---|
| `bitcode/defs.bzl` | public API: the `rllvm_cc_bitcode` rule |
| `bitcode/aspect.bzl` | the cc aspect; propagates `BitcodeInfo` |
| `bitcode/compile.bzl` | one `.bc` per translation unit |
| `bitcode/providers.bzl` | `BitcodeInfo`, source classification |
| `bitcode/toolchain.bzl` | supplies `llvm-link` and `llvm-ar` |
| `bitcode/merge.bzl` | merge step shared by the cc and Rust rules |
| `rust/` | the crate-graph aspect and `rllvm_rust_bitcode` |
| `toolchain/` | LLVM download, bzlmod extension, toolchain registration |
| `site/` | GitHub Pages source |
| `examples/` | diamond fixture and the invariant tests |
| `examples/wasm/`, `examples/rust/`, `examples/objc/` | per-language fixtures |

## Build and test

```bash
bazel build //... && bazel test //bitcode/tests:all
cd examples && bazel build //:diamond_bc && ./tests/bitcode_test.sh
```

`tests/bitcode_test.sh` drives Bazel itself, so it is a plain script rather than a `sh_test`. Nesting it inside a Bazel test deadlocks on the server lock.

The Objective-C fixture needs `--extra_toolchains=@local_config_apple_cc_toolchains//:all` and only builds on macOS; the test script skips it elsewhere.

## Documentation

The README is the user-facing document and carries facts, usage and limitations only. Design rationale belongs here instead.

`site/index.md` is generated from README.md by `site/build.py` and is gitignored, so the published page cannot drift from the front page. The version in the hero is read from `.release-please-manifest.json` rather than `MODULE.bazel`: both carry the same number, but the manifest is release-please's record of what it actually published, and reading `MODULE.bazel` would rebuild the site on dependency bumps that change nothing on the page.

## CI

The required status contexts are `build`, `bitcode (ubuntu-latest)` and `bitcode (macos-latest)`, matched by exact string. Renaming a job or giving one a `name:` blocks every pull request on a status that can never arrive.

Guards sit on steps rather than on jobs, because a skipped required check counts as passing, and they read `!= 'false'` so that a failed classifier builds everything.

## Git workflow

One long-lived branch, `main`, with temporary feature branches merged by squash PR and deleted on merge. Conventional Commits always; `!` or a `BREAKING CHANGE:` footer for breaking changes. Below 1.0 a plain `feat:` is a patch bump, so an unmarked breaking change cannot be corrected after release.

Pull requests follow `.github/PULL_REQUEST_TEMPLATE.md` — Problem, Cause, Fix, Verification, with sections that do not apply deleted rather than left empty — and issues follow the matching form in `.github/ISSUE_TEMPLATE/`. `gh pr create --body` bypasses the template, so the body has to be written to it deliberately.

## Invariants

**Laziness is the whole design.** Bitcode actions are declared during analysis and execute only when an output group requests them. A stray default output turns every build into the second compile this ruleset exists to avoid, so `examples/tests/bitcode_test.sh` asserts a wildcard build runs none.

**Each aspect node merges only its own sources.** Folding dependencies' modules into a node would embed a shared library twice, and `llvm-link` fails on the duplicate definitions. Depset propagation deduplicates by file identity instead, which is what makes a diamond work.

**Every aspect returns `OutputGroupInfo` as well as `BitcodeInfo`.** Without it, `--aspects` plus `--output_groups` matches no group, runs no action and still exits 0 — a documented workflow that silently does nothing.

**The manifest is a default output, not an opt-in group.** A record of what is missing only does its job next to the artifact it describes.

**The LLVM overlay is read from `toolchains_llvm` at fetch time, never vendored.** A vendored copy silently goes stale across a version bump and then fails during analysis, far from the change that caused it.

**`CcInfo` and `cc_common` come from `rules_cc`, not from Bazel globals.** Bazel 9 removed them. A missing load surfaces as a loud error in a rule attribute but as a *silently false* membership test inside the aspect, which yields empty bitcode rather than a failure.

**The bitcode toolchain is registered separately from the cc toolchain.** It lives in the LLVM distribution repo, not the cc_toolchain config repo, so a single `register_toolchains` line covering the latter does not reach it.

**The Rust aspect asks `rules_rust` for the command it would already have run.** `construct_arguments` is how every rustc invocation in that ruleset is built, so borrowing it and changing only `--emit` keeps the bitcode in step with the features, `--extern` paths and flags of the real compile. Re-deriving that command would drift silently. This is the same bargain as the `toolchains_llvm` internals: an upstream release can require updates here.

**Rust bitcode needs exactly one codegen unit.** With more than one, rustc reports `ignoring emit path because multiple .bc files were produced` and writes none of them where the action declared its output. `rules_rust` forces a single unit for `obj` but not for `llvm-bc`, so the aspect sets it after `construct_arguments`, where it wins.

**Cross-compilation needs no code here, so the test asserts the triple.** A host-targeted module builds and links exactly as a wasm one does, so "the build succeeded" would pass while the wrong thing was extracted. `examples/tests/bitcode_test.sh` reads the target triple back out of the merged module instead.

**Objective-C needs no code, only a different cc toolchain.** `objc_library` fails unless the resolved toolchain enables the `objc-compile` action, which the LLVM toolchain does not. The fixture is `manual` and opts in with `--extra_toolchains`, because registering the Apple toolchain would outrank the LLVM one for every other C/C++ target and quietly change what the rest of the suite exercises.

**Producer and reader LLVM versions diverge outside C and C++, and only backwards compatibility is guaranteed.** rustc 1.98 emits LLVM 22 bitcode and Apple clang 21 emits its own, both read by `llvm_version = "19.1.0"` tools. `llvm-dis` is the strict one: `llvm-link`, `llvm-ar` and `llvm-nm` all read rustc's output, and `llvm-link` writes no summary of its own, so a merged module disassembles while the per-crate file it came from fails with `Invalid summary version 12`. Swift is out of reach for the same reason and at a level `llvm-link` cannot skip: `swiftc -emit-bc` output fails with `Unknown attribute kind (102)`. Raising `llvm_version` is the lever.

**A rule cannot set its own tags.** `rllvm_cc_bitcode` targets are built by a wildcard build unless the caller tags them `manual`; this is documented in the README rather than worked around.

**Every new assertion is falsified before it ships.** A test that passes for the wrong reason is worse than no test: break the thing it checks, watch it fail, then restore. The wasm triple, the Rust laziness check, `-Ccodegen-units=1`, the aspect output groups and the Objective-C class symbol were each caught or confirmed this way.
