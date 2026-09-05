#include "wasm/wasm_lib.h"

int main(void) { return rllvm_wasm_value() == 42 ? 0 : 1; }
