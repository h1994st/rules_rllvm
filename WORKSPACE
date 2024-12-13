workspace(name = "rules_rllvm")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

# bazel_skylib
http_archive(
    name = "bazel_skylib",
    sha256 = "bc283cdfcd526a52c3201279cda4bc298652efa898b10b4db0837dc51652756f",
    url = "https://github.com/bazelbuild/bazel-skylib/releases/download/1.7.1/bazel-skylib-1.7.1.tar.gz",
)

load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")

bazel_skylib_workspace()

# bazel version check
load("@bazel_skylib//lib:versions.bzl", "versions")

versions.check(minimum_bazel_version = "3.7.0")

# toolchains_llvm
http_archive(
    name = "toolchains_llvm",
    canonical_id = "v1.2.0",
    sha256 = "e3fb6dc6b77eaf167cb2b0c410df95d09127cbe20547e5a329c771808a816ab4",
    strip_prefix = "toolchains_llvm-v1.2.0",
    url = "https://github.com/bazel-contrib/toolchains_llvm/releases/download/v1.2.0/toolchains_llvm-v1.2.0.tar.gz",
)

load("@toolchains_llvm//toolchain:deps.bzl", "bazel_toolchain_dependencies")

bazel_toolchain_dependencies()

# rules_rust
http_archive(
    name = "rules_rust",
    integrity = "sha256-gnStljEH4UDf911b/+nRt7CaV5WPHqNhYhQr0OevUjI=",
    urls = ["https://github.com/bazelbuild/rules_rust/releases/download/0.55.6/rules_rust-0.55.6.tar.gz"],
)

load("@rules_rust//rust:repositories.bzl", "rules_rust_dependencies", "rust_register_toolchains")

rules_rust_dependencies()

rust_register_toolchains(
    edition = "2021",
    versions = ["1.83.0"],
)

# rllvm
http_archive(
    name = "rllvm",
    build_file = "//rllvm:BUILD.rllvm.bazel",
    strip_prefix = "rllvm-0.1.2",
    type = "tar.gz",
    urls = ["https://static.crates.io/crates/rllvm/rllvm-0.1.2.crate"],
)

load("@rules_rust//crate_universe:defs.bzl", "crates_repository")

crates_repository(
    name = "rllvm_deps",
    cargo_lockfile = "@rllvm//:Cargo.lock",
    generate_binaries = True,
    manifests = ["@rllvm//:Cargo.toml"],
)

load("@rllvm_deps//:defs.bzl", rllvm_deps = "crate_repositories")

rllvm_deps()
