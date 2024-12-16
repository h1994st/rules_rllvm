"rllvm-wrapped LLVM"

load(
    "@toolchains_llvm//toolchain/internal:common.bzl",
    _arch = "arch",
    _canonical_dir_path = "canonical_dir_path",
    _exec_os_arch_dict_value = "exec_os_arch_dict_value",
    _is_absolute_path = "is_absolute_path",
    _os = "os",
    _pkg_path_from_label = "pkg_path_from_label",
)
load("@toolchains_llvm//toolchain/internal:configure.bzl", "BZLMOD_ENABLED")
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
rllvm_wrapper_repo_attrs.update({
    "rllvm_log_level": attr.int(
        mandatory = False,
        doc = ("Override the log level of `rllvm` (0: nothing, 1: error, 2: warn, 3: info, 4: debug, 5: trace)"),
        values = [0, 1, 2, 3, 4, 5],
    ),
})
rllvm_wrapper_repo_attrs.update({
    "skip_bitcode_generation": attr.bool(
        mandatory = False,
        doc = ("Skip the bitcode generation of `rllvm`"),
    ),
})

def _empty_repository(rctx):
    rctx.file("BUILD.bazel", executable = False)

def rllvm_wrapper_repo_impl(rctx):
    """
    Download LLVM binaries/libraries and update necessary symlinks to inject rllvm wrapper
    """

    os = _os(rctx)
    if os == "windows":
        _empty_repository(rctx)
        return None
    arch = _arch(rctx)

    # Create BUILD.bazel
    rctx.file(
        "BUILD.bazel",
        content = rctx.read(Label("//toolchain:BUILD.llvm_repo.bazel")),
        executable = False,
    )

    updated_attrs = None
    if not rctx.attr.toolchain_roots:
        updated_attrs = _download_llvm(rctx)
        toolchain_root = ("@" if BZLMOD_ENABLED else "") + "@%s//" % rctx.attr.name
    else:
        (_key, toolchain_root) = _exec_os_arch_dict_value(rctx, "toolchain_roots")

    if not toolchain_root:
        fail("LLVM toolchain root missing for ({}, {})".format(os, arch))

    system_llvm = False
    use_absolute_paths_llvm = rctx.attr.absolute_paths
    if _is_absolute_path(toolchain_root):
        use_absolute_paths_llvm = True
        system_llvm = True

    # Paths for LLVM distribution:
    rllvm_dist_label = Label("@rllvm//:BUILD.bazel")
    if system_llvm:
        llvm_dist_path_prefix = _canonical_dir_path(toolchain_root)
    elif use_absolute_paths_llvm:
        llvm_dist_path_prefix = _canonical_dir_path(str(rctx.path(rllvm_dist_label).dirname)) + "../" + rctx.attr.name + "/"
    else:
        llvm_dist_path_prefix = _pkg_path_from_label(rllvm_dist_label) + "../" + rctx.attr.name + "/"
    llvm_dist_absolute_path_prefix = _canonical_dir_path(str(rctx.path(rllvm_dist_label).dirname)) + "../" + rctx.attr.name + "/"

    # Create rllvm-cc wrapper
    rctx.template(
        "bin/rllvm_config.yml",
        Label("//toolchain:rllvm_config.yml.tpl"),
        {
            "%{llvm_dist_path_prefix}": llvm_dist_absolute_path_prefix,
            "%{rllvm_log_level}": str(rctx.attr.rllvm_log_level),
            "%{skip_bitcode_generation}": "true" if rctx.attr.skip_bitcode_generation else "false",
        },
    )
    rctx.template(
        "bin/rllvm_cc_wrapper.sh",
        Label("//toolchain:rllvm_cc_wrapper.sh.tpl"),
        {
            "%{llvm_dist_path_prefix}": llvm_dist_path_prefix,
            "%{rllvm_dist_path_prefix}": _pkg_path_from_label(Label("@rllvm//:rllvm-cc")),
        },
    )

    (_key, llvm_version) = _exec_os_arch_dict_value(rctx, "llvm_versions")
    if not llvm_version:
        # LLVM version missing for (os, arch)
        _empty_repository(rctx)
        return None
    major_llvm_version = int(llvm_version.split(".")[0])

    # Override symlinks for clang
    if rctx.delete("bin/clang"):
        rctx.symlink("bin/clang-{}".format(major_llvm_version), "bin/clang-orig")
    rctx.symlink("bin/rllvm_cc_wrapper.sh", "bin/clang")
    if rctx.delete("bin/clang++"):
        rctx.symlink("bin/clang-orig", "bin/clang++-orig")
    rctx.symlink("bin/rllvm_cc_wrapper.sh", "bin/clang++")
    if rctx.delete("bin/clang-cpp"):
        rctx.symlink("bin/clang-orig", "bin/clang-cpp-orig")
    rctx.symlink("bin/rllvm_cc_wrapper.sh", "bin/clang-cpp")

    # TODO: what is the purpose of returning?
    return updated_attrs
