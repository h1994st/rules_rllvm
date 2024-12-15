"h1994st/rules_rllvm/toolchain"

load("@toolchains_llvm//toolchain:rules.bzl", "llvm_toolchain")

def rllvm_toolchain(name, **kwargs):
    llvm_toolchain(
        name = name,
        llvm_version = llvm_version,
        **kwargs
    )

    # TODO: load rllvm, rewrite llvm toolchain to use rllvm-cc
