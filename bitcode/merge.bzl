"""Merge step shared by the cc and Rust extraction rules.

The aspects differ -- one shadows a C/C++ dependency graph, the other a crate
graph -- but both hand back a `BitcodeInfo`, so everything downstream of that
provider is the same code.
"""

STRATEGY_ATTR = attr.string(
    default = "flat",
    values = ["flat", "staged", "archive"],
    doc = "flat | staged | archive.",
)

def merge_bitcode(ctx, info, mnemonic):
    """Merge a `BitcodeInfo` into one module plus its manifest.

    Args:
        ctx: the merging rule's context.
        info: the `BitcodeInfo` collected by an aspect.
        mnemonic: action mnemonic, so cc and Rust merges stay distinguishable
          in an execution log.

    Returns:
        A list of providers for the rule to return.
    """
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
        mnemonic = mnemonic,
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
