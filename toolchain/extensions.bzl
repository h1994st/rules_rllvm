"""rllvm module extension for use with bzlmod"""

load(
    "//toolchain:rules.bzl",
    _rllvm_toolchain = "rllvm_toolchain",
)
load(
    "//toolchain:repo.bzl",
    _rllvm_wrapper_repo_attrs = "rllvm_wrapper_repo_attrs",
)

def _root_dict(roots, cls, name):
    """Collapse repeated `sysroot`/`toolchain_root` tags into a target-keyed dict.

    An empty `targets` list means the entry applies to every target, which the
    underlying repo rule spells as the empty key.
    """
    res = {}
    for root in roots:
        targets = list(root.targets) or [""]
        for target in targets:
            if target in res:
                fail("duplicate target '%s' found for %s with name '%s'" % (target, cls, name))
            if bool(root.path) == bool(root.label):
                fail("target '%s' for %s with name '%s' must have either path or label, but not both" % (target, cls, name))
            if root.path:
                if not root.path.startswith("/"):
                    fail("target '%s' for %s with name '%s' must have an absolute path value" % (target, cls, name))
                res[target] = root.path
            else:
                # `str()` on the resolved label gives the canonical form, which
                # is what lets a label written in the root module resolve inside
                # the toolchain repo, whose repo mapping is a different one.
                res[target] = str(root.label)
    return res

def _rllvm_impl(module_ctx):
    for mod in module_ctx.modules:
        if not mod.is_root:
            fail("Only the root module can use the 'rllvm' extension")

        toolchain_names = []
        for toolchain_attr in mod.tags.toolchain:
            name = toolchain_attr.name
            toolchain_names.append(name)
            attrs = {
                key: getattr(toolchain_attr, key)
                for key in dir(toolchain_attr)
                if not key.startswith("_")
            }
            attrs["sysroot"] = _root_dict(
                [t for t in mod.tags.sysroot if t.name == name],
                "sysroot",
                name,
            )
            attrs["toolchain_roots"] = _root_dict(
                [t for t in mod.tags.toolchain_root if t.name == name],
                "toolchain_root",
                name,
            )
            _rllvm_toolchain(**attrs)

        # A tag naming a toolchain that was never declared is a typo that would
        # otherwise be silently ignored, leaving the target without its sysroot
        # and failing much later during compilation.
        for tag in mod.tags.sysroot:
            if tag.name not in toolchain_names:
                fail("sysroot '%s' does not have a corresponding toolchain" % tag.name)
        for tag in mod.tags.toolchain_root:
            if tag.name not in toolchain_names:
                fail("toolchain_root '%s' does not have a corresponding toolchain" % tag.name)

# Build the tag class attrs from the LLVM repo attrs (which already include
# _common_attrs, _llvm_repo_attrs, _llvm_config_attrs). We also add
# llvm_version as a convenient scalar alternative to llvm_versions.
_toolchain_attrs = {
    "name": attr.string(
        doc = "Base name for the generated repositories.",
        default = "rllvm_toolchain",
    ),
    "llvm_version": attr.string(
        doc = "Scalar LLVM version string (e.g. '19.1.0'). Converted to llvm_versions dict internally.",
        default = "",
    ),
}

# Pull in the attrs that rllvm_toolchain() forwards to the underlying repo
# rules, excluding ones we handle explicitly.
_toolchain_attrs.update({
    k: v
    for k, v in _rllvm_wrapper_repo_attrs.items()
    if k not in _toolchain_attrs
})

# These two are dicts of labels keyed by target. As plain `string_dict` attrs
# their values would be resolved against the toolchain repo's mapping rather
# than the root module's, so they get tag classes of their own that take a real
# `attr.label`.
_toolchain_attrs.pop("sysroot", None)
_toolchain_attrs.pop("toolchain_roots", None)

_root_attrs = {
    "name": attr.string(
        doc = "Same name as the toolchain tag.",
        default = "rllvm_toolchain",
    ),
    "targets": attr.string_list(
        doc = "Specific targets, if any; an empty list applies to all of them.",
    ),
    "path": attr.string(doc = "Absolute path."),
}

rllvm = module_extension(
    implementation = _rllvm_impl,
    tag_classes = {
        "toolchain": tag_class(attrs = _toolchain_attrs),
        "sysroot": tag_class(attrs = dict(
            _root_attrs,
            label = attr.label(
                doc = "Label whose files form the sysroot and whose package path is the sysroot path.",
            ),
        )),
        "toolchain_root": tag_class(attrs = dict(
            _root_attrs,
            label = attr.label(
                doc = "Dummy label whose package path is the toolchain root package.",
            ),
        )),
    },
)
