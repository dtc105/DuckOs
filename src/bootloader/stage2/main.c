#include "stdint.h"
#include "stdio.h"

void _cdecl cstart_(uint16_t bootDrive) {
    // puts("Hello World (from c)");
    printf("Hello %b", 92719);
    while (1 == 1);
}