"rules_rllvm dependencies"

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

_DEFAULT_RLLVM_VERSION = "0.1.6"
_DEFAULT_RLLVM_SHA256 = "02dd14c23fac8807a0fac5918d615fa7431b4103696ae77b3ee9f32502fbedf4"

def rules_rllvm_dependencies(rllvm_version = "", rllvm_sha256 = ""):
    """
    Load dependencies of `rules_rllvm`

    Args:
        rllvm_version: Version of rllvm to download (e.g. "0.1.6").
            Defaults to the version this rules_rllvm release was tested with.
        rllvm_sha256: SHA256 checksum of the rllvm release archive.
            Defaults to the known checksum for the default version.
            Pass an empty string to skip checksum verification (useful for new versions).
    """

    if not rllvm_version:
        rllvm_version = _DEFAULT_RLLVM_VERSION
    if not rllvm_sha256:
        if rllvm_version == _DEFAULT_RLLVM_VERSION:
            rllvm_sha256 = _DEFAULT_RLLVM_SHA256

    if not native.existing_rule("bazel_skylib"):
        http_archive(
            name = "bazel_skylib",
            sha256 = "6e78f0e57de26801f6f564fa7c4a48dc8b36873e416257a92bbb0937eeac8446",
            urls = [
                "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.8.2/bazel-skylib-1.8.2.tar.gz",
                "https://github.com/bazelbuild/bazel-skylib/releases/download/1.8.2/bazel-skylib-1.8.2.tar.gz",
            ],
        )

    if not native.existing_rule("toolchains_llvm"):
        http_archive(
            name = "toolchains_llvm",
            canonical_id = "v1.6.0",
            sha256 = "2b298a1d7ea99679f5edf8af09367363e64cb9fbc46e0b7c1b1ba2b1b1b51058",
            strip_prefix = "toolchains_llvm-v1.6.0",
            url = "https://github.com/bazel-contrib/toolchains_llvm/releases/download/v1.6.0/toolchains_llvm-v1.6.0.tar.gz",
        )

    if not native.existing_rule("rllvm"):
        http_archive(
            name = "rllvm",
            build_file = Label("//rllvm:BUILD.rllvm.bazel"),
            sha256 = rllvm_sha256,
            strip_prefix = "rllvm-x86_64-unknown-linux-gnu",
            urls = ["https://github.com/h1994st/rllvm/releases/download/v{version}/rllvm-x86_64-unknown-linux-gnu.tar.xz".format(version = rllvm_version)],
        )
