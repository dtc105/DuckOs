#include "stdio.h"
#include "x86.h"

void putc(char c){
    x86_Video_WriteCharTeletype(c, 0);
}

void puts(const char* str) {
    while (*str) {
        putc(*str);
        str++;
    }
}

#define PRINTF_STATE_NORMAL         0
#define PRINTF_STATE_LENGTH         1
#define PRINTF_STATE_LENGTH_SHORT   2
#define PRINTF_STATE_LENGTH_LONG    3
#define PRINTF_STATE_SPEC           4

#define PRINTF_LENGTH_DEFAULT       0
#define PRINTF_LENGTH_SHORT_SHORT   1
#define PRINTF_LENGTH_SHORT         2
#define PRINTF_LENGTH_LONG          3
#define PRINTF_LENGTH_LONG_LONG     4

const char g_HexChars[] = "0123456789abcdef";
int* printf_number(int* argp, int length, bool sign, int radix);

void _cdecl printf(const char* fmt, ...) {
    int state = PRINTF_STATE_NORMAL;
    int* argp = (int*)&fmt;
    int length = PRINTF_LENGTH_DEFAULT;
    int radix = 10;
    bool sign = false;

    argp++;
    while (*fmt) {
        switch (state) {
            case PRINTF_STATE_NORMAL:
                switch(*fmt) {
                    case '%':
                        state = PRINTF_STATE_LENGTH;
                        break;
                    default:
                        putc(*fmt);
                        break;
                }
                break;
            case PRINTF_STATE_LENGTH:
                switch(length) {
                    case 'h':
                        length = PRINTF_LENGTH_SHORT;
                        state = PRINTF_STATE_LENGTH_SHORT;
                        break;
                    case 'l':
                        length = PRINTF_LENGTH_LONG;
                        state = PRINTF_STATE_LENGTH_LONG;
                        break;
                    default:
                        goto PRINTF_STATE_SPEC_;
                }
                break;
            case PRINTF_STATE_LENGTH_SHORT:
                if (*fmt == 'h') {
                    length = PRINTF_LENGTH_SHORT_SHORT;
                    state = PRINTF_STATE_SPEC;
                } else {
                    goto PRINTF_STATE_SPEC_;
                }
                break;
            case PRINTF_STATE_LENGTH_LONG:
                if (*fmt == 'l') {
                    length = PRINTF_LENGTH_LONG_LONG;
                    state = PRINTF_STATE_SPEC;
                } else {
                    goto PRINTF_STATE_SPEC_;
                }
                break;
            case PRINTF_STATE_SPEC:
            PRINTF_STATE_SPEC_:
                switch (*fmt) {
                    case 'c':
                        putc((char)*argp);
                        argp++;
                        break;
                    case 's':
                        puts(*(char**)argp);
                        argp++;
                        break;
                    case 'd':
                    case 'i':
                        radix = 10;
                        sign = true;
                        argp = printf_number(argp, length, sign, radix);
                        break;
                    case 'u':
                        radix = 10;
                        sign = false;
                        argp = printf_number(argp, length, sign, radix);
                        break;
                    case 'X':
                    case 'x':
                    case 'p':
                        radix = 16;
                        sign = false;
                        argp = printf_number(argp, length, sign, radix);
                        break;
                    case 'o':
                        radix = 8;
                        sign = false;
                        argp = printf_number(argp, length, sign, radix);
                        break;
                    case 'B':
                    case 'b':
                        radix = 2;
                        sign = false;
                        argp = printf_number(argp, length, sign, radix);
                        break;
                    case '%':
                        putc('%');
                        break;
                    default:
                        break;
                }

                state = PRINTF_STATE_NORMAL;
                length = PRINTF_LENGTH_DEFAULT;
                radix = 10;
                sign = true;
                break;
        }
        
        fmt++;
    }
}

int* printf_number(int* argp, int length, bool sign, int radix) {
    char buffer[32];
    uint64_t number;
    int number_sign = 1;
    int pos = 0;

    switch (length) {
        case PRINTF_LENGTH_SHORT_SHORT:
        case PRINTF_LENGTH_SHORT:
        case PRINTF_LENGTH_DEFAULT:
            if (sign) {
                int num = *argp;
                if (num < 0) {
                    num = -num;
                    number_sign = -1;
                }
                number = (uint64_t)num;
            } else {
                number = *(unsigned int*)argp;
            }
            argp++;
            break;
        case PRINTF_LENGTH_LONG:
            if (sign) {
                int32_t num = *(int32_t*)argp;
                if (num < 0) {
                    num = -num;
                    number_sign = -1;
                }
                number = (uint64_t)num;
            } else {
                number = *(uint32_t*)argp;
            }
            argp += 2;
            break;
        case PRINTF_LENGTH_LONG_LONG:
            if (sign) {
                int64_t num = *(int64_t*)argp;
                if (num < 0) {
                    num = -num;
                    number_sign = -1;
                }
                number = (uint64_t)num;
            } else {
                number = *(uint64_t*)argp;
            }
            argp += 4;
            break;
    }

    // convert to ascii
    do {
        uint32_t remainder;
        x86_div64_32(number, radix, &number, &remainder);
        buffer[pos++] = g_HexChars[remainder];
    } while (number > 0);

    // add '-'
    if (sign && number_sign < 0) {
        buffer[pos++] = '-';
    }

    // print in reverse
    while (--pos >= 0) {
        putc(buffer[pos]);
    }
    return argp;
}