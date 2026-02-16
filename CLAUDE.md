# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Project Overview

rules_rllvm provides Bazel rules for integrating [rllvm](https://github.com/h1994st/rllvm) into the build process. It wraps `toolchains_llvm` to transparently inject rllvm compiler wrappers (rllvm-cc/rllvm-cxx) so that whole-program LLVM bitcode is generated alongside normal compilation within Bazel builds.

## Key Architecture

- **`toolchain/rules.bzl`** — Main entry point: `rllvm_toolchain()` macro that creates both the rllvm wrapper repo and the LLVM toolchain config
- **`toolchain/repo.bzl`** — `rllvm_wrapper_repo_impl`: downloads LLVM, creates rllvm config, sets up wrapper scripts, overrides clang symlinks to point through rllvm
- **`toolchain/extensions.bzl`** — Bzlmod module extension
- **`toolchain/deps.bzl`** — WORKSPACE dependency setup
- **`rllvm/BUILD.rllvm.bazel`** — Build file for the rllvm binary distribution
- **`examples/`** — Example project demonstrating usage (both WORKSPACE and Bzlmod)

## How It Works

1. `rllvm_toolchain()` downloads LLVM binaries via `toolchains_llvm`
2. The rllvm wrapper repo (`rllvm_wrapper_repo_impl`) replaces `clang`/`clang++` symlinks with `rllvm_cc_wrapper.sh`
3. The wrapper script invokes rllvm-cc/rllvm-cxx which transparently call the real clang while also generating bitcode
4. Configuration is generated from `rllvm_config.yml.tpl` with log level and bitcode skip options

## Build & Test

```bash
# Build the rules (validation only, no compiled output)
bazel build //...

# Test with the example project
cd examples && bazel build //...
```

Requires Bazel >= 3.7.0. Currently only supports Linux x86_64 (rllvm binary distribution).

## Conventions

- Starlark (.bzl) files follow standard Bazel style
- Uses `toolchains_llvm` internal APIs (pinned to version 1.5.0)
- `absolute_paths = True` is forced because rllvm uses absolute paths to call clang
- Template files (`.tpl`) use `%{variable}` substitution syntax
