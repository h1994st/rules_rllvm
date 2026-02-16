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
            canonical_id = "v1.5.0",
            sha256 = "49e69c011bcaa4c9a7246a287ab1fb4f7ed3fde7cbd7300374c1030f40d2bb95",
            strip_prefix = "toolchains_llvm-v1.5.0",
            url = "https://github.com/bazel-contrib/toolchains_llvm/releases/download/v1.5.0/toolchains_llvm-v1.5.0.tar.gz",
        )

    if not native.existing_rule("rllvm"):
        # rllvm
        http_archive(
            name = "rllvm",
            build_file = Label("//rllvm:BUILD.rllvm.bazel"),
            sha256 = "02dd14c23fac8807a0fac5918d615fa7431b4103696ae77b3ee9f32502fbedf4",
            strip_prefix = "rllvm-x86_64-unknown-linux-gnu",
            urls = ["https://github.com/h1994st/rllvm/releases/download/v0.1.6/rllvm-x86_64-unknown-linux-gnu.tar.xz"],
        )
