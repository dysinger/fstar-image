/* main.c — native C driver for the extracted [Hello] module.
 *
 * KaRaMeL extracts the F* module [Hello] to [Hello.c] / [Hello.h] but does
 * not emit a C [main()].  This driver supplies it:
 *
 *   - it calls the verified [Hello_add] (the C form of [Hello.add], proven
 *     commutative in F*) on 10 + 20 and prints the result;
 *   - it then calls the extracted entry point [Hello_main] (the C form of
 *     [Hello.main]) and forwards its exit code to the process.
 */
#include "Hello.h"

#include <stdio.h>

int main(void) {
  uint8_t x = 0x0Au; /* 10 */
  uint8_t y = 0x14u; /* 20 */
  uint8_t z = Hello_add(x, y); /* 30 mod 256, proven commutative */

  printf("Hello, F*! %u + %u = %u\n",
         (unsigned)x, (unsigned)y, (unsigned)z);

  return (int)Hello_main();
}
