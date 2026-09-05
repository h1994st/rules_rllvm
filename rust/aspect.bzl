"""Aspect that shadows the Rust crate graph with bitcode nodes.

The cc aspect rebuilds a compile command from the cc toolchain. This one does
the same thing one level up: `construct_arguments` is how rules_rust builds
every rustc invocation it makes, so asking it for the same command with a
different `--emit` keeps the bitcode in step with whatever flags, features and
`--extern` paths the real compile would have used. rules_rust's own clippy
aspect re-runs rustc the same way.

One crate is one codegen unit here, so unlike C++ there is no per-node merge:
the crate's `.bc` is already the node's module.
"""

load("@rules_rust//rust/private:common.bzl", "rust_common")
load(
    "@rules_rust//rust/private:rustc.bzl",
    "collect_deps",
    "collect_inputs",
    "construct_arguments",
)
load(
    "@rules_rust//rust/private:utils.bzl",
    "determine_output_hash",
    "find_cc_toolchain",
    "find_toolchain",
)
load("//bitcode:providers.bzl", "BitcodeInfo")

# A proc-macro is compiled for the machine running the compiler and never
# reaches the program under analysis, so its absence is not a gap. Same
# reasoning as header-only libraries in the cc aspect.
_HOST_CRATE_TYPES = ["proc-macro"]

def _providers(info):
    """Pair the provider with the output groups that expose its files.

    Without these, `--aspects=...%rust_bitcode_aspect
    --output_groups=bitcode_files` matches no group, runs no action and still
    reports success.
    """
    return [
        info,
        OutputGroupInfo(
            bitcode_files = info.tu_bitcode,
            modules = info.modules,
        ),
    ]

def _skip_record(label, reason, kind):
    return json.encode({"target": str(label), "reason": reason, "kind": kind})

def _crate_info(target):
    if rust_common.crate_info in target:
        return target[rust_common.crate_info]
    if rust_common.test_crate_info in target:
        return target[rust_common.test_crate_info].crate
    return None

def _rust_bitcode_aspect_impl(target, ctx):
    deps = getattr(ctx.rule.attr, "deps", []) + \
           getattr(ctx.rule.attr, "proc_macro_deps", [])
    dep_infos = [d[BitcodeInfo] for d in deps if BitcodeInfo in d]

    transitive_tu = [d.tu_bitcode for d in dep_infos]
    transitive_mod = [d.modules for d in dep_infos]
    transitive_man = [d.manifest for d in dep_infos]

    def _passthrough(direct_man = []):
        return _providers(BitcodeInfo(
            tu_bitcode = depset(transitive = transitive_tu),
            module = None,
            modules = depset(transitive = transitive_mod),
            manifest = depset(direct = direct_man, transitive = transitive_man),
        ))

    crate = _crate_info(target)
    if crate == None:
        return _passthrough([_skip_record(target.label, "no_crateinfo", ctx.rule.kind)])
    if crate.type in _HOST_CRATE_TYPES:
        return _passthrough()

    toolchain = find_toolchain(ctx)
    cc_toolchain, feature_configuration = find_cc_toolchain(ctx)

    dep_info, build_info, _ = collect_deps(
        deps = crate.deps.to_list(),
        proc_macro_deps = crate.proc_macro_deps.to_list(),
        aliases = crate.aliases,
        extra_named_deps = crate.extra_named_deps,
    )

    compile_inputs, out_dir, build_env_files, build_flags_files, linkstamp_outs, ambiguous_libs = collect_inputs(
        ctx,
        ctx.rule.file,
        ctx.rule.files,
        # Nothing is linked, so there are no linkstamps to compile.
        depset([]),
        toolchain,
        cc_toolchain,
        feature_configuration,
        crate,
        dep_info,
        build_info,
        # No lint configuration is applied: this action exists to produce
        # bitcode, and a lint denial here would fail a build that compiles.
        [],
    )

    # A sibling of the crate's own output, so the directory exists on a remote
    # executor before rustc writes into it.
    bc = ctx.actions.declare_file(ctx.label.name + ".crate.bc", sibling = crate.output)

    args, env = construct_arguments(
        ctx = ctx,
        attr = ctx.rule.attr,
        file = ctx.file,
        toolchain = toolchain,
        tool_file = toolchain.rustc,
        cc_toolchain = cc_toolchain,
        feature_configuration = feature_configuration,
        crate_info = crate,
        dep_info = dep_info,
        linkstamp_outs = linkstamp_outs,
        ambiguous_libs = ambiguous_libs,
        output_hash = determine_output_hash(crate.root, ctx.label),
        rust_flags = [],
        out_dir = out_dir,
        build_env_files = build_env_files,
        build_flags_files = build_flags_files,
        # No "link": emitting bitcode alone keeps this off the linker, which is
        # what makes the action cheap and what keeps it from racing the real
        # build for the same output paths.
        emit = [("llvm-bc", bc)],
        skip_expanding_rustc_env = True,
    )

    # rustc writes one module per codegen unit, and with more than one it
    # reports "ignoring emit path because multiple .bc files were produced" and
    # writes none of them where we asked, failing the action. rules_rust forces
    # a single unit for `obj` but not for `llvm-bc`, so it is set here, after
    # construct_arguments, where it overrides the toolchain's own setting.
    args.rustc_flags.add("-Ccodegen-units=1")

    if crate.is_test:
        args.rustc_flags.add("--test")

    ctx.actions.run(
        executable = ctx.executable._process_wrapper,
        inputs = compile_inputs,
        outputs = [bc],
        env = env,
        tools = [toolchain.rustc],
        arguments = args.all,
        mnemonic = "RustBitcode",
        progress_message = "Generating bitcode for %{label}",
        toolchain = "@rules_rust//rust:toolchain_type",
    )

    return _providers(BitcodeInfo(
        tu_bitcode = depset(direct = [bc], transitive = transitive_tu),
        module = bc,
        modules = depset(direct = [bc], transitive = transitive_mod),
        manifest = depset(transitive = transitive_man),
    ))

rust_bitcode_aspect = aspect(
    implementation = _rust_bitcode_aspect_impl,
    attr_aspects = ["deps", "proc_macro_deps"],
    fragments = ["cpp"],
    attrs = {
        "_error_format": attr.label(
            default = Label("@rules_rust//rust/settings:error_format"),
        ),
        "_extra_rustc_flag": attr.label(
            default = Label("@rules_rust//rust/settings:extra_rustc_flag"),
        ),
        "_extra_rustc_flags": attr.label(
            default = Label("@rules_rust//rust/settings:extra_rustc_flags"),
        ),
        "_per_crate_rustc_flag": attr.label(
            default = Label("@rules_rust//rust/settings:per_crate_rustc_flag"),
        ),
        "_process_wrapper": attr.label(
            default = Label("@rules_rust//util/process_wrapper"),
            executable = True,
            cfg = "exec",
        ),
    },
    required_providers = [
        [rust_common.crate_info],
        [rust_common.test_crate_info],
    ],
    toolchains = [
        "@rules_rust//rust:toolchain_type",
        config_common.toolchain_type(
            "@bazel_tools//tools/cpp:toolchain_type",
            mandatory = False,
        ),
    ],
)
