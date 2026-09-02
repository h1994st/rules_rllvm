"""Provider and source classification for the bitcode aspect."""

BitcodeInfo = provider(
    doc = "Bitcode shadow node for one C/C++ target.",
    fields = {
        "tu_bitcode": "depset[File]: per-TU .bc, direct = this target, transitive = deps",
        "module": "File or None: this node's own sources merged by llvm-link",
        "modules": "depset[File]: direct = [module] if any, transitive = deps' modules",
        "manifest": "depset[string]: JSON skip records from this node and below",
    },
)

COMPILABLE_C_EXTS = ["c", "m"]

COMPILABLE_CXX_EXTS = ["cc", "cpp", "cxx", "c++", "C", "mm"]

def is_cxx_source(f):
    """True if this file compiles as C++.

    Args:
        f: a File (or anything exposing `extension`).

    Returns:
        bool
    """
    return f.extension in COMPILABLE_CXX_EXTS

def is_compilable_source(f):
    """True if this file is a translation unit (not a header or data file).

    Args:
        f: a File (or anything exposing `extension`).

    Returns:
        bool
    """
    return f.extension in COMPILABLE_C_EXTS or f.extension in COMPILABLE_CXX_EXTS
