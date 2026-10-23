// Test-only compiler failure whose diagnostics exceed an OS pipe's capacity.
#include <stdio.h>

int main(void) {
    for (int index = 0; index < 262144; ++index) {
        fputs("long compiler diagnostic\n", stderr);
    }
    fputs("stderr complete\n", stderr);
    return 17;
}
