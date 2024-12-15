"rllvm-wrapped LLVM"

def rllvm_wrapper_repo_impl(rctx):
    rctx.file(
        "BUILD.bazel",
        content = rctx.read(Label("//toolchain:BUILD.llvm_repo.bazel")),
        executable = False,
    )
