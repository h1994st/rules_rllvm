"""WASI sysroot and compiler-rt builtins for the wasm32-wasip1 example.

Only `wasm32-wasip1` is unpacked. The upstream release ships five ABIs, and
carrying the rest would triple the download for targets nothing here builds.
"""

_ABI = "wasm32-wasip1"

_SYSROOT_BUILD = """\
filegroup(
    name = "{abi}",
    srcs = glob(["include/**", "lib/**", "share/**"], allow_empty = True),
    visibility = ["//visibility:public"],
)
"""

def _wasi_sdk_sysroot_impl(rctx):
    rctx.download_and_extract(
        integrity = "sha256-NRcvfSeZSFsVpGsdh/UKWF2RXsZiCA8AXZkVOlCIjwg=",
        stripPrefix = "wasi-sysroot-24.0",
        url = ["https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-24/wasi-sysroot-24.0.tar.gz"],
    )

    rctx.file("%s/BUILD.bazel" % _ABI, _SYSROOT_BUILD.format(abi = _ABI))

    # The sysroot is the package directory, so clang looks for `<pkg>/include`
    # and `<pkg>/lib/wasm32-wasip1`. The archive nests one level differently.
    rctx.execute(["mv", "include/" + _ABI, "%s/include" % _ABI])
    rctx.execute(["mv", "share/" + _ABI, "%s/share" % _ABI])
    rctx.execute(["mkdir", "-p", "%s/lib" % _ABI])
    rctx.execute(["mv", "lib/" + _ABI, "%s/lib/%s" % (_ABI, _ABI)])

wasi_sdk_sysroot = repository_rule(_wasi_sdk_sysroot_impl)

def _libclang_rt_wasm32_impl(rctx):
    rctx.file("BUILD.bazel", 'exports_files(glob(["*.a"]))\n')
    rctx.download_and_extract(
        integrity = "sha256-fjPA33WLkEabHePKFY4tCn9xk01YhFJbpqNy3gs7Dsc=",
        stripPrefix = "libclang_rt.builtins-wasm32-wasi-24.0",
        url = ["https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-24/libclang_rt.builtins-wasm32-wasi-24.0.tar.gz"],
    )

libclang_rt_wasm32 = repository_rule(_libclang_rt_wasm32_impl)
