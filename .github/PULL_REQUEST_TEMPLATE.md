<!--
Title must be a Conventional Commit: `<type>: <summary>`
Types in use: feat, fix, refactor, chore, ci, docs, test

Breaking change? Use `feat!:` or a `BREAKING CHANGE:` footer. Below 1.0 a plain
`feat:` is only a patch bump, and that cannot be corrected after release.

Keep this short: problem, cause, fix, verification. Delete sections that do not apply.
-->

## Problem

## Cause

## Fix

## Verification

<!--
- [ ] New tests confirmed to fail before the fix
- [ ] `bazel build //... && bazel test //bitcode/tests:all`
- [ ] `cd examples && bazel build //:diamond_bc && ./tests/bitcode_test.sh`
- [ ] Toolchain or overlay change? Verified after a clean fetch, not incrementally
-->
