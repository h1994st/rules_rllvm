"rules_rllvm dependencies"

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def rules_rllvm_dependencies():
    """
    Load dependencies of `rules_rllvm`
    """

    if not native.existing_rule("bazel_skylib"):
        http_archive(
            name = "bazel_skylib",
            sha256 = "bc283cdfcd526a52c3201279cda4bc298652efa898b10b4db0837dc51652756f",
            url = "https://github.com/bazelbuild/bazel-skylib/releases/download/1.7.1/bazel-skylib-1.7.1.tar.gz",
        )

    if not native.existing_rule("toolchains_llvm"):
        http_archive(
            name = "toolchains_llvm",
            canonical_id = "v1.2.0",
            sha256 = "e3fb6dc6b77eaf167cb2b0c410df95d09127cbe20547e5a329c771808a816ab4",
            strip_prefix = "toolchains_llvm-v1.2.0",
            url = "https://github.com/bazel-contrib/toolchains_llvm/releases/download/v1.2.0/toolchains_llvm-v1.2.0.tar.gz",
        )

    if not native.existing_rule("rules_rust"):
        http_archive(
            name = "rules_rust",
            integrity = "sha256-gnStljEH4UDf911b/+nRt7CaV5WPHqNhYhQr0OevUjI=",
            urls = ["https://github.com/bazelbuild/rules_rust/releases/download/0.55.6/rules_rust-0.55.6.tar.gz"],
        )
