"h1994st/rules_rllvm/toolchain"

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
load(
    "//toolchain:repo.bzl",
    _rllvm_wrapper_repo_attrs = "rllvm_wrapper_repo_attrs",
    _rllvm_wrapper_repo_impl = "rllvm_wrapper_repo_impl",
)

rllvm = repository_rule(
    attrs = _rllvm_wrapper_repo_attrs,
    local = False,
    implementation = _rllvm_wrapper_repo_impl,
)
toolchain = repository_rule(
    attrs = _llvm_config_attrs,
    local = True,
    configure = True,
    implementation = _llvm_config_impl,
)

def rllvm_toolchain(name, rllvm_log_level = 0, skip_bitcode_generation = False, **kwargs):
    """
    Reuse `toolchains_llvm` and configure `rllvm` as the compiler
    """

    if kwargs.get("llvm_version") == kwargs.get("llvm_versions"):
        fail("Exactly one of llvm_version or llvm_versions must be set")
    if not kwargs.get("llvm_versions"):
        kwargs.update(llvm_versions = {"": kwargs.get("llvm_version")})

    # TODO: separate rllvm toolchain into a different repository so that the
    # modifications on this file will not trigger any re-fetching for the
    # underlying llvm binaries

    # Use absolute paths
    # `rllvm` uses absolute path to call `clang`. However, this results in
    # absolute includsion error in Bazel, because these absoluate inclusion
    # paths are not included in the toolchain config file (i.e.,
    # cxx_builtin_include_directories)
    kwargs.update(absolute_paths = True)

    # `llvm_toolchain` may download LLVM if specified, and a LLVM
    # toolchain is created
    rllvm_args = {
        k: v
        for k, v in kwargs.items()
        if (k in _rllvm_wrapper_repo_attrs.keys())
    }
    rllvm(
        name = name + "_llvm",
        rllvm_log_level = rllvm_log_level,
        skip_bitcode_generation = skip_bitcode_generation,
        **rllvm_args
    )

    toolchain_args = {
        k: v
        for k, v in kwargs.items()
        if (k not in _llvm_repo_attrs.keys()) or (k in _common_attrs.keys())
    }
    toolchain(name = name, **toolchain_args)
