"""Public API: rllvm_cc_bitcode."""

load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load(":aspect.bzl", "bitcode_aspect")
load(":providers.bzl", "BitcodeInfo")

def _rllvm_cc_bitcode_impl(ctx):
    info = ctx.attr.target[BitcodeInfo]
    bt = ctx.toolchains["//bitcode:toolchain_type"].bitcode

    out = ctx.actions.declare_file(ctx.label.name + ".bc")
    manifest = ctx.actions.declare_file(ctx.label.name + ".bc.manifest.json")

    records = info.manifest.to_list()
    ctx.actions.write(manifest, "\n".join(records) + ("\n" if records else ""))

    if ctx.attr.strategy == "staged":
        inputs = info.modules
    else:
        inputs = info.tu_bitcode

    args = ctx.actions.args()
    if ctx.attr.strategy == "archive":
        tool = bt.llvm_ar
        args.add("rcs", out)
        args.add_all(inputs)
    else:
        tool = bt.llvm_link
        args.add("-o", out)
        args.add_all(inputs)

    ctx.actions.run(
        outputs = [out],
        inputs = depset(transitive = [inputs, bt.runtime_libs]),
        executable = tool,
        arguments = [args],
        mnemonic = "CcBitcodeMerge",
        progress_message = "Merging bitcode for %s (%s)" % (ctx.label, ctx.attr.strategy),
    )

    return [
        DefaultInfo(files = depset([out, manifest])),
        OutputGroupInfo(
            bitcode_files = info.tu_bitcode,
            modules = info.modules,
            manifest = depset([manifest]),
        ),
    ]

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
        "strategy": attr.string(
            default = "flat",
            values = ["flat", "staged", "archive"],
        ),
    },
    toolchains = ["//bitcode:toolchain_type"],
)
