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
