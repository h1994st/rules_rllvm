"h1994st/rules_rllvm/toolchain"

load("@toolchains_llvm//toolchain:rules.bzl", "llvm_toolchain")

LLVM_TOOLCHAIN_INTERNAL = "llvm_toolchain_internal"

def rllvm_toolchain(name, **kwargs):
    """
    Reuse `toolchains_llvm` and configure `rllvm` as the compiler
    """

    # `llvm_toolchain` may download LLVM if specified, and a LLVM
    # toolchain is created
    llvm_toolchain(name = LLVM_TOOLCHAIN_INTERNAL, **kwargs)

    # TODO: Recrate a new repository for rllvm-wrapped LLVM files
