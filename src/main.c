/* main.c — native C driver for the extracted [Hello] module.
 *
 * KaRaMeL extracts the F* module [Hello] to [Hello.c] / [Hello.h] but does
 * not emit a C [main()].  This driver supplies it: it calls the extracted
 * entry point [Hello_main] (the C form of [Hello.main], which exercises the
 * verified operations) and forwards its exit code to the process.
 *
 * No I/O is performed here or in [Hello.fst] — the verified module is pure
 * computation.
 */
#include "Hello.h"

int main(void) {
  return (int)Hello_main();
}
