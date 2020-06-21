#include <gillian-c/gillian-c.h>
#include <stdlib.h>

void success(void) {
  ASSERT(1);
}

void may_fail(int x) {
  int y = 2 * x;
  ASSERT(y < 30);
}

int main() {
  int x = __builtin_annot_intval("symb_int", x);

  if (x < 10) {
    success();
  } else {
    may_fail(x);
  }

  return 0;
}