"h1994st/rules_rllvm/toolchain"

load("@toolchains_llvm//toolchain:rules.bzl", "llvm_toolchain")
load(
    "@toolchains_llvm//toolchain/internal:configure.bzl",
    _llvm_config_impl = "llvm_config_impl",
)
load(
    "@toolchains_llvm//toolchain/internal:repo.bzl",
    _common_attrs = "common_attrs",
    _llvm_config_attrs = "llvm_config_attrs",
    _llvm_repo_attrs = "llvm_repo_attrs",
)
load("//toolchain:repo.bzl", _rllvm_wrapper_repo_impl = "rllvm_wrapper_repo_impl")

LLVM_TOOLCHAIN_INTERNAL = "llvm_toolchain_internal"

llvm = repository_rule(
    local = False,
    implementation = _rllvm_wrapper_repo_impl,
)
toolchain = repository_rule(
    attrs = _llvm_config_attrs,
    local = True,
    configure = True,
    implementation = _llvm_config_impl,
)

def rllvm_toolchain(name, **kwargs):
    """
    Reuse `toolchains_llvm` and configure `rllvm` as the compiler
    """

    # `llvm_toolchain` may download LLVM if specified, and a LLVM
    # toolchain is created
    llvm_toolchain(name = LLVM_TOOLCHAIN_INTERNAL, **kwargs)

    # Recrate a new repository for rllvm-wrapped LLVM files
    llvm(name = name + "_llvm")

    if not kwargs.get("llvm_versions"):
        kwargs.update(llvm_versions = {"": kwargs.get("llvm_version")})

    toolchain_args = {
        k: v
        for k, v in kwargs.items()
        if (k not in _llvm_repo_attrs.keys()) or (k in _common_attrs.keys())
    }
    toolchain(name = name, **toolchain_args)
