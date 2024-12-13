"h1994st/rules_rllvm/toolchain"

load("@toolchains_llvm//toolchain:rules.bzl", "llvm_toolchain")

def rllvm_toolchain(name, llvm_version, **kwargs):
    llvm_toolchain(
        name = name,
        llvm_version = llvm_version,
        **kwargs
    )

    # TODO: load rllvm, rewrite llvm toolchain to use rllvm-cc

    load("@{}//:toolchains.bzl".format(name), "llvm_register_toolchains")

    llvm_register_toolchains()
