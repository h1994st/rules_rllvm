"""Aspect that shadows the C/C++ dep graph with bitcode nodes."""

load("@rules_cc//cc:find_cc_toolchain.bzl", "find_cc_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load(":compile.bzl", "compile_tu_to_bitcode")
load(":providers.bzl", "BitcodeInfo", "is_compilable_source")

_PIC_RULES = ["cc_library"]

def _skip_record(label, reason, kind):
    return json.encode({"target": str(label), "reason": reason, "kind": kind})

def _contributes_code(target):
    """True if the target puts libraries into the link but produced no bitcode.

    Args:
        target: the target under inspection.

    Returns:
        bool
    """
    if CcInfo not in target:
        return False
    for li in target[CcInfo].linking_context.linker_inputs.to_list():
        if li.libraries:
            return True
    return False

def _providers(info):
    """Pair the provider with the output groups that expose its files.

    Without these, `--aspects=...%bitcode_aspect --output_groups=bitcode_files`
    matches no group, runs no action and still reports success -- the aspect
    equivalent of building nothing on purpose.
    """
    return [
        info,
        OutputGroupInfo(
            bitcode_files = info.tu_bitcode,
            modules = info.modules,
        ),
    ]

def _bitcode_aspect_impl(target, ctx):
    deps = getattr(ctx.rule.attr, "deps", []) + \
           getattr(ctx.rule.attr, "implementation_deps", [])
    dep_infos = [d[BitcodeInfo] for d in deps if BitcodeInfo in d]

    transitive_tu = [d.tu_bitcode for d in dep_infos]
    transitive_mod = [d.modules for d in dep_infos]
    transitive_man = [d.manifest for d in dep_infos]

    if CcInfo not in target:
        return _providers(BitcodeInfo(
            tu_bitcode = depset(transitive = transitive_tu),
            module = None,
            modules = depset(transitive = transitive_mod),
            manifest = depset(
                direct = [_skip_record(target.label, "no_ccinfo", ctx.rule.kind)],
                transitive = transitive_man,
            ),
        ))

    srcs = []
    for s in getattr(ctx.rule.attr, "srcs", []):
        srcs += [f for f in s.files.to_list() if is_compilable_source(f)]

    if not srcs:
        # Header-only libraries contribute no code, so they are NOT a gap and
        # are not recorded. Precompiled targets DO contribute code and are.
        direct_man = []
        if _contributes_code(target):
            direct_man = [_skip_record(target.label, "no_sources", ctx.rule.kind)]
        return _providers(BitcodeInfo(
            tu_bitcode = depset(transitive = transitive_tu),
            module = None,
            modules = depset(transitive = transitive_mod),
            manifest = depset(direct = direct_man, transitive = transitive_man),
        ))

    cc_toolchain = find_cc_toolchain(ctx)
    feature_config = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    cc_ctx = target[CcInfo].compilation_context
    copts = getattr(ctx.rule.attr, "copts", [])
    use_pic = ctx.rule.kind in _PIC_RULES

    tu_files = [
        compile_tu_to_bitcode(ctx, cc_toolchain, feature_config, cc_ctx, s, copts, use_pic)
        for s in srcs
    ]

    bt = ctx.toolchains["//bitcode:toolchain_type"].bitcode
    module = ctx.actions.declare_file("_bc/{}.module.bc".format(ctx.label.name))
    link_args = ctx.actions.args()
    link_args.add("-o", module)
    link_args.add_all(tu_files)
    ctx.actions.run(
        outputs = [module],
        inputs = depset(tu_files, transitive = [bt.runtime_libs]),
        executable = bt.llvm_link,
        arguments = [link_args],
        mnemonic = "CcBitcodeModule",
        progress_message = "Merging bitcode module for %s" % ctx.label,
    )

    return _providers(BitcodeInfo(
        tu_bitcode = depset(direct = tu_files, transitive = transitive_tu),
        module = module,
        modules = depset(direct = [module], transitive = transitive_mod),
        manifest = depset(transitive = transitive_man),
    ))

bitcode_aspect = aspect(
    implementation = _bitcode_aspect_impl,
    attr_aspects = ["deps", "implementation_deps"],
    fragments = ["cpp"],
    toolchains = [
        "@bazel_tools//tools/cpp:toolchain_type",
        "//bitcode:toolchain_type",
    ],
)
