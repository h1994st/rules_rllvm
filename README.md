# rules_rllvm

Bazel rules for integrating [rllvm](https://github.com/h1994st/rllvm) into
your build process. Wraps
[toolchains_llvm](https://github.com/bazel-contrib/toolchains_llvm) to
transparently inject rllvm compiler wrappers (`rllvm-cc` / `rllvm-cxx`), so
that whole-program LLVM bitcode is generated alongside normal compilation.

## Setup

### WORKSPACE

```starlark
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "rules_rllvm",
    # See https://github.com/h1994st/rules_rllvm/releases for latest release
    sha256 = "...",
    strip_prefix = "rules_rllvm-<version>",
    url = "https://github.com/h1994st/rules_rllvm/releases/download/<version>/rules_rllvm-<version>.tar.gz",
)

load("@rules_rllvm//toolchain:deps.bzl", "rules_rllvm_dependencies")

rules_rllvm_dependencies()

load("@rules_rllvm//toolchain:rules.bzl", "rllvm_toolchain")

rllvm_toolchain(
    "rllvm_toolchain",
    llvm_version = "19.1.0",
    rllvm_log_level = 5,
    skip_bitcode_generation = False,
)

register_toolchains("@rllvm_toolchain//:all")
```

### Bzlmod

In your `MODULE.bazel`:

```starlark
bazel_dep(name = "rules_rllvm", version = "<version>")

rllvm = use_extension("@rules_rllvm//toolchain:extensions.bzl", "rllvm")
rllvm.toolchain(
    name = "rllvm_toolchain",
    llvm_version = "19.1.0",
    rllvm_log_level = 5,
    skip_bitcode_generation = False,
)

use_repo(rllvm, "rllvm_toolchain")
use_repo(rllvm, "rllvm_toolchain_llvm")

register_toolchains("@rllvm_toolchain//:all")
```

## Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `llvm_version` | `string` | — | LLVM version to download (e.g. `"19.1.0"`) |
| `rllvm_log_level` | `int` | `0` | Log verbosity: 0 = nothing, 1 = error, 2 = warn, 3 = info, 4 = debug, 5 = trace |
| `skip_bitcode_generation` | `bool` | `False` | When `True`, rllvm acts as a pass-through without generating bitcode |

## How It Works

1. `rllvm_toolchain()` downloads pre-built LLVM binaries via `toolchains_llvm`.
2. The rllvm wrapper repository replaces the `clang` / `clang++` symlinks with
   a wrapper script that routes compilation through `rllvm-cc` / `rllvm-cxx`.
3. rllvm transparently calls the real clang while generating whole-program LLVM
   bitcode as a side effect.
4. A configuration file (`rllvm_config.yml`) is generated from the specified log
   level and bitcode-skip options.

## Supported Platforms

- **Linux x86_64** — the only platform with rllvm binary distributions currently available.

## Known Limitations

- **`absolute_paths = True` is forced.** rllvm invokes clang using absolute
  paths, which requires this setting in the underlying toolchain configuration.
- **Depends on `toolchains_llvm` internal APIs** (pinned to v1.5.0). Future
  versions of `toolchains_llvm` may require updates to these rules.
- **Bazel >= 3.7.0** is required.

## License

See [LICENSE](LICENSE) for details.
