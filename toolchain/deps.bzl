"rules_rllvm dependencies"

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def rules_rllvm_dependencies():
    """
    Load dependencies of `rules_rllvm`
    """

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
