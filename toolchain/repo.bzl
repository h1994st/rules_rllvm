"LLVM distribution repository for rules_rllvm"

load(
    "@toolchains_llvm//toolchain/internal:common.bzl",
    _arch = "arch",
    _exec_os_arch_dict_value = "exec_os_arch_dict_value",
    _os = "os",
)
load(
    "@toolchains_llvm//toolchain/internal:llvm_distributions.bzl",
    _download_llvm = "download_llvm",
)
load(
    "@toolchains_llvm//toolchain/internal:repo.bzl",
    _common_attrs = "common_attrs",
    _llvm_config_attrs = "llvm_config_attrs",
    _llvm_repo_attrs = "llvm_repo_attrs",
)

rllvm_wrapper_repo_attrs = dict(_common_attrs)
rllvm_wrapper_repo_attrs.update(_llvm_repo_attrs)
rllvm_wrapper_repo_attrs.update(_llvm_config_attrs)

def _empty_repository(rctx):
    rctx.file("BUILD.bazel", executable = False)

def rllvm_wrapper_repo_impl(rctx):
    """
    Download the LLVM distribution and overlay our BUILD file on it.

    The drivers are left exactly as the distribution ships them. Bitcode is
    produced by the aspect in //bitcode, not by substituting the compiler.
    """

    os = _os(rctx)
    if os == "windows":
        _empty_repository(rctx)
        return None
    arch = _arch(rctx)

    (_key, llvm_version) = _exec_os_arch_dict_value(rctx, "llvm_versions")
    if not llvm_version:
        # LLVM version missing for (os, arch)
        _empty_repository(rctx)
        return None
    major_llvm_version = int(llvm_version.split(".")[0])

    # Create BUILD.bazel. This overlay tracks toolchains_llvm's own
    # BUILD.llvm_repo.tpl and must be substituted the same way it is upstream --
    # the versioning scheme changed at LLVM 16.
    rctx.file(
        "BUILD.bazel",
        content = rctx.read(Label("//toolchain:BUILD.llvm_repo.bazel")).format(
            LLVM_VERSION = major_llvm_version if major_llvm_version >= 16 else llvm_version,
        ),
        executable = False,
    )

    updated_attrs = None
    if not rctx.attr.toolchain_roots:
        updated_attrs = _download_llvm(rctx)
        toolchain_root = "@@%s//" % rctx.attr.name
    else:
        (_key, toolchain_root) = _exec_os_arch_dict_value(rctx, "toolchain_roots")

    if not toolchain_root:
        fail("LLVM toolchain root missing for ({}, {})".format(os, arch))

    return updated_attrs
