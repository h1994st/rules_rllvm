"""rllvm module extension for use with bzlmod"""

load(
    "//toolchain:rules.bzl",
    _rllvm_toolchain = "rllvm_toolchain",
)
load(
    "//toolchain:repo.bzl",
    _rllvm_wrapper_repo_attrs = "rllvm_wrapper_repo_attrs",
)

def _rllvm_impl(module_ctx):
    for mod in module_ctx.modules:
        if not mod.is_root:
            fail("Only the root module can use the 'rllvm' extension")
        for toolchain_attr in mod.tags.toolchain:
            attrs = {
                key: getattr(toolchain_attr, key)
                for key in dir(toolchain_attr)
                if not key.startswith("_")
            }
            _rllvm_toolchain(**attrs)

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

rllvm = module_extension(
    implementation = _rllvm_impl,
    tag_classes = {
        "toolchain": tag_class(
            attrs = _toolchain_attrs,
        ),
    },
)
