#include <stdio.h>
#include "uring.h"

int main() {

  printf("Sizeof(event) %zu\n", sizeof(struct event));

  return 0;

}
