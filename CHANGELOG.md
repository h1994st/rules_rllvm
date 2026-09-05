# Changelog

## [0.1.1](https://github.com/h1994st/rules_rllvm/compare/v0.1.0...v0.1.1) (2026-09-05)


### Features

* extract bitcode from Rust crates ([#31](https://github.com/h1994st/rules_rllvm/issues/31)) ([9a49255](https://github.com/h1994st/rules_rllvm/commit/9a49255a0d9dd57cd8afd90b721df32c3871be8b))
* support wasm targets via platform resolution ([#29](https://github.com/h1994st/rules_rllvm/issues/29)) ([f812042](https://github.com/h1994st/rules_rllvm/commit/f812042ca01c910c90f7dd66caf0b657128a668e))


### Bug Fixes

* expose aspect output groups so one-off extraction works ([#32](https://github.com/h1994st/rules_rllvm/issues/32)) ([9b03d81](https://github.com/h1994st/rules_rllvm/commit/9b03d81282e8984254890526120c830ff8bdb5d4))

## [0.1.0](https://github.com/h1994st/rules_rllvm/compare/v0.0.1...v0.1.0) (2026-09-03)


### ⚠ BREAKING CHANGES

* Bazel-native bitcode extraction, Bazel 9, and Apache-2.0 ([#19](https://github.com/h1994st/rules_rllvm/issues/19))

### Features

* add a simple example ([2b5b41e](https://github.com/h1994st/rules_rllvm/commit/2b5b41e66a46422f6898fe54147a6590d67d2a33))
* Bazel-native bitcode extraction, Bazel 9, and Apache-2.0 ([#19](https://github.com/h1994st/rules_rllvm/issues/19)) ([9a82b35](https://github.com/h1994st/rules_rllvm/commit/9a82b35b53769fb2c923d8a30ca26385db5f7b0c))
* finish rllvm-wrapped llvm toolchain ([ab82c46](https://github.com/h1994st/rules_rllvm/commit/ab82c4697e63e6d84e72a72e6565a22020e414f7))
* hack rllvm with llvm distributions ([d441d43](https://github.com/h1994st/rules_rllvm/commit/d441d43a233b77b0d79b50e6d2ac5aa2dedd6bde))
* include rllvm and add overlay BUILD ([ccf8156](https://github.com/h1994st/rules_rllvm/commit/ccf8156afb01f6e423ba6dadaa994a42c4bd6aad))
* rely on toolchains_llvm to implement rllvm rules ([e3b35f5](https://github.com/h1994st/rules_rllvm/commit/e3b35f5fcc4410935d331298edf4d5598a13db2d))


### Bug Fixes

* declare Bazel 9 as the minimum supported version ([#26](https://github.com/h1994st/rules_rllvm/issues/26)) ([8ee6efd](https://github.com/h1994st/rules_rllvm/commit/8ee6efde8b761fc440bb520639126cc5d659c03f))
* rllvm dependencies and visibility ([91ea2f7](https://github.com/h1994st/rules_rllvm/commit/91ea2f74fe1b8d40c60e9824bcc3285b61829fd1))
* the absolute inclusion issue in toolchain ([d301f70](https://github.com/h1994st/rules_rllvm/commit/d301f70422a0c08061556715a75690ef82288a82))
