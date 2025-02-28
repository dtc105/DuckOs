#include "stdio.h"
#include "x86.h"

void printChar(char c){
    x86_Video_WriteCharTeletype(c, 0);
}

void printString(const char* str) {
    while (*str) {
        printChar(*str);
        str++;
    }
}