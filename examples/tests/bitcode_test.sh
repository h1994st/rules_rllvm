#!/usr/bin/env bash
# Asserts the four invariants of the bitcode design. Run directly, not via
# `bazel test`: it invokes bazel internally, which must not be nested inside a
# Bazel test sandbox.
set -euo pipefail
BAZEL="${BAZEL:-bazelisk}"
LOG=$(mktemp)

# 1. LAZINESS: a normal build must run ZERO bitcode actions.
#
# Two builds, because they catch different regressions. Building the binary
# alone is structurally lazy (the aspect is attached to rllvm_cc_bitcode's
# `target` attribute, so it does not run at all here) -- that check guards
# against the aspect ever being attached more broadly. Building //... is the
# one that can actually fail today: rllvm_cc_bitcode targets are swept into a
# wildcard build unless tagged `manual`, which is the documented foot-gun,
# since a rule cannot inject its own tags.
$BAZEL clean >/dev/null 2>&1
$BAZEL build //:diamond --execution_log_json_file="$LOG" >/dev/null 2>&1
if grep -q '"mnemonic": *"CcBitcode' "$LOG"; then
  echo "FAIL: bitcode actions ran while building //:diamond"; exit 1
fi

$BAZEL build //... --execution_log_json_file="$LOG" >/dev/null 2>&1
if grep -q '"mnemonic": *"CcBitcode' "$LOG"; then
  echo "FAIL: bitcode actions ran during a wildcard build"; exit 1
fi
echo "PASS: laziness"

# 2. CONTENT: the merged module must contain real symbols.
$BAZEL build //:diamond_bc >/dev/null 2>&1
BC=$($BAZEL cquery --output=files //:diamond_bc 2>/dev/null | grep '\.bc$')
NM=$(echo "$($BAZEL info output_base)"/external/*llvm_toolchain_llvm/bin/llvm-nm)
SYMS=$("$NM" "$BC")
for s in rllvm_a_value rllvm_b_value rllvm_c_value main; do
  echo "$SYMS" | grep -q "$s" || { echo "FAIL: missing symbol $s"; exit 1; }
done
echo "PASS: content"

# 3. DIAMOND: lib_c must be defined exactly once.
# Mach-O prefixes symbols with an underscore, ELF does not; accept both.
COUNT=$(echo "$SYMS" | grep -cE ' T _?rllvm_c_value$' || true)
[ "$COUNT" = "1" ] || { echo "FAIL: rllvm_c_value defined $COUNT times, expected 1"; exit 1; }
echo "PASS: diamond dedup"

# 4. SKIP RECORDING, both directions.
# A target that contributes a library but no bitcode IS a gap and must be
# recorded. A header-only library contributes no code, so recording it would
# bury the entries that matter.
MAN=$($BAZEL cquery --output=files //:diamond_bc 2>/dev/null | grep 'manifest.json$')
if grep -q 'header_only' "$MAN"; then
  echo "FAIL: header-only library was recorded as a skip"; exit 1
fi
grep -q '"target":"@@//:asm_only"' "$MAN" || {
  echo "FAIL: sourceless-but-code-contributing target was not recorded"; exit 1
}
grep -q '"reason":"no_sources"' "$MAN" || {
  echo "FAIL: skip record is missing its reason"; exit 1
}
echo "PASS: skip recording"

# 5. WASM: the merged module must carry the wasm triple, not the host's.
#
# Asserting the triple rather than that the build succeeded is the whole point:
# a host-targeted module also builds and also links, so "it worked" would pass
# while extracting the wrong thing. The aspect has no wasm-specific code, so
# the triple is evidence that it took the command line from whichever cc
# toolchain the platform resolved.
WASM_PLATFORM="@toolchains_llvm//platforms:wasip1-wasm32"
$BAZEL build //wasm:wasm_app_bc --platforms="$WASM_PLATFORM" >/dev/null 2>&1
WBC=$($BAZEL cquery --output=files //wasm:wasm_app_bc --platforms="$WASM_PLATFORM" 2>/dev/null | grep '\.bc$')
DIS=$(echo "$($BAZEL info output_base)"/external/*llvm_toolchain_llvm/bin/llvm-dis)
TRIPLE=$("$DIS" -o - "$WBC" | grep -m1 '^target triple')
case "$TRIPLE" in
  *wasm32*) ;;
  *) echo "FAIL: wasm module has triple '$TRIPLE', expected wasm32"; exit 1 ;;
esac

# Both translation units must be there, or the aspect stopped at the top node
# under the platform transition.
WSYMS=$("$NM" "$WBC")
for s in rllvm_wasm_value main; do
  echo "$WSYMS" | grep -q "$s" || { echo "FAIL: wasm module missing symbol $s"; exit 1; }
done
echo "PASS: wasm target triple"
