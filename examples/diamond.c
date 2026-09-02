#include "lib_a.h"
#include "lib_b.h"
#include "header_only.h"
int main(void) {
  return rllvm_a_value() + rllvm_b_value() + rllvm_header_only();
}
