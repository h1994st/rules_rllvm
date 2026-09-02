"""Builds one .bc per translation unit using the toolchain's own command line."""

load("@rules_cc//cc:action_names.bzl", "C_COMPILE_ACTION_NAME", "CPP_COMPILE_ACTION_NAME")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load(":providers.bzl", "is_cxx_source")

def compile_tu_to_bitcode(ctx, cc_toolchain, feature_config, cc_ctx, src, copts, use_pic):
    """Compile one source to LLVM bitcode.

    Args:
        ctx: the aspect context.
        cc_toolchain: CcToolchainInfo for the current target.
        feature_config: a configured feature configuration.
        cc_ctx: the target's CcInfo.compilation_context.
        src: the source File to compile.
        copts: the rule's copts, passed through verbatim.
        use_pic: whether to request the PIC variant of the compile.

    Returns:
        The declared .bc File.
    """
    bc = ctx.actions.declare_file("_bc/{}/{}.bc".format(ctx.label.name, src.short_path))
    action_name = CPP_COMPILE_ACTION_NAME if is_cxx_source(src) else C_COMPILE_ACTION_NAME

    # NOTE: no dependency_file is supplied. The dependency_file feature uses
    # expand_if_available, so -MD/-MF are never emitted. This is deliberate:
    # reusing the object action's -MF path would declare a duplicate output.
    variables = cc_common.create_compile_variables(
        feature_configuration = feature_config,
        cc_toolchain = cc_toolchain,
        source_file = src.path,
        output_file = bc.path,  # drives both -o and -frandom-seed=
        user_compile_flags = copts + ["-emit-llvm"],
        include_directories = cc_ctx.includes,
        quote_include_directories = cc_ctx.quote_includes,
        system_include_directories = cc_ctx.system_includes,
        preprocessor_defines = cc_ctx.defines,
        use_pic = use_pic,
    )
    args = cc_common.get_memory_inefficient_command_line(
        feature_configuration = feature_config,
        action_name = action_name,
        variables = variables,
    )
    env = cc_common.get_environment_variables(
        feature_configuration = feature_config,
        action_name = action_name,
        variables = variables,
    )
    ctx.actions.run(
        outputs = [bc],
        inputs = depset(
            direct = [src],
            transitive = [cc_ctx.headers, cc_toolchain.all_files],
        ),
        executable = cc_common.get_tool_for_action(
            feature_configuration = feature_config,
            action_name = action_name,
        ),
        arguments = args,
        env = env,
        mnemonic = "CcBitcode",
        progress_message = "Generating bitcode for %s" % src.short_path,
    )
    return bc
