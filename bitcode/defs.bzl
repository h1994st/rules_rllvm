"""Public API: rllvm_cc_bitcode."""

load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load(":aspect.bzl", "bitcode_aspect")
load(":merge.bzl", "STRATEGY_ATTR", "merge_bitcode")
load(":providers.bzl", "BitcodeInfo")

def _rllvm_cc_bitcode_impl(ctx):
    return merge_bitcode(ctx, ctx.attr.target[BitcodeInfo], "CcBitcodeMerge")

# Both tools come from //bitcode:toolchain_type (Task 4b). Label defaults cannot
# work here: the LLVM repo's apparent name is user-chosen and is not visible in
# rules_rllvm's own repo mapping.
rllvm_cc_bitcode = rule(
    implementation = _rllvm_cc_bitcode_impl,
    doc = "Extract LLVM bitcode for a cc_* target and its transitive sources.",
    attrs = {
        "target": attr.label(
            mandatory = True,
            aspects = [bitcode_aspect],
            providers = [CcInfo],
            doc = "Any cc_library, cc_binary or cc_test.",
        ),
        "strategy": STRATEGY_ATTR,
    },
    toolchains = ["//bitcode:toolchain_type"],
)
