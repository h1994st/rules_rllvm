"""Public API: rllvm_rust_bitcode.

Loading this file is what pulls `rules_rust` into a build. A project that only
extracts C/C++ bitcode never loads it and never registers a Rust toolchain.
"""

load("@rules_rust//rust/private:common.bzl", "rust_common")
load("//bitcode:merge.bzl", "STRATEGY_ATTR", "merge_bitcode")
load("//bitcode:providers.bzl", "BitcodeInfo")
load(":aspect.bzl", "rust_bitcode_aspect")

def _rllvm_rust_bitcode_impl(ctx):
    return merge_bitcode(ctx, ctx.attr.target[BitcodeInfo], "RustBitcodeMerge")

rllvm_rust_bitcode = rule(
    implementation = _rllvm_rust_bitcode_impl,
    doc = "Extract LLVM bitcode for a rust_* target and its transitive crates.",
    attrs = {
        "target": attr.label(
            mandatory = True,
            aspects = [rust_bitcode_aspect],
            doc = "Any rust_library, rust_binary or rust_test.",
        ),
        "strategy": STRATEGY_ATTR,
    },
    toolchains = ["//bitcode:toolchain_type"],
)
