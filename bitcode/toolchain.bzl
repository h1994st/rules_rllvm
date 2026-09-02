"""Toolchain carrying the LLVM tools the bitcode rules need.

A label default such as `@llvm_toolchain_llvm//:bin/llvm-link` cannot work here:
the generated repo's apparent name is user-chosen via `rllvm.toolchain(name =
...)`, and it is visible only through the ROOT module's `use_repo`. A label
written in this package resolves against rules_rllvm's own repo mapping, which
has no `use_extension` at all. Aspects additionally cannot take user-supplied
attributes, so there is no per-call-site workaround that preserves the per-node
module. Toolchain resolution is the mechanism that does work.
"""

def _rllvm_bitcode_toolchain_impl(ctx):
    return [platform_common.ToolchainInfo(
        bitcode = struct(
            llvm_link = ctx.executable.llvm_link,
            llvm_ar = ctx.executable.llvm_ar,
            runtime_libs = ctx.attr.runtime_libs.files if ctx.attr.runtime_libs else depset(),
        ),
    )]

rllvm_bitcode_toolchain = rule(
    implementation = _rllvm_bitcode_toolchain_impl,
    doc = "Supplies llvm-link and llvm-ar to the bitcode aspect and rule.",
    attrs = {
        "llvm_link": attr.label(
            mandatory = True,
            executable = True,
            cfg = "exec",
            allow_single_file = True,
        ),
        "llvm_ar": attr.label(
            mandatory = True,
            executable = True,
            cfg = "exec",
            allow_single_file = True,
        ),
        "runtime_libs": attr.label(allow_files = True),
    },
)
