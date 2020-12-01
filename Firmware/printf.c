/* Small, noncompliant, not-full-featured printf implementation
 *
 *
 * Copyright (c) 2010-2020, Ingo Korb
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 *
 * FIXME: Selection of output function should be more flexible
 */

#include <stdio.h>
#include <stdarg.h>
#include <string.h>

void osd_putchar(char c);
#define outfunc(x) osd_putchar(x)

#define FLAG_ZEROPAD   1
#define FLAG_LEFTADJ   2
#define FLAG_BLANK     4
#define FLAG_FORCESIGN 8
#define FLAG_WIDTH     16
#define FLAG_LONG      32
#define FLAG_UNSIGNED  64
#define FLAG_NEGATIVE  128

/* Digits used for conversion */
static const char hexdigits[] = "0123456789abcdef";

/* Temporary buffer used for numbers - just large enough for 32 bit in octal */
static char buffer[12];

/* Output string length */
static unsigned int outlength;

/* Output pointer */
static char *outptr;
static int maxlen;

/* printf */
static void outchar(char x) {
  if (maxlen) {
    maxlen--;
    outfunc(x);
    outlength++;
  }
}

/* sprintf */
static void outstr(char x) {
  if (maxlen) {
    maxlen--;
    *outptr++ = x;
    outlength++;
  }
}

static int internal_nprintf(void (*output_function)(char c), const char *fmt, va_list ap) {
  unsigned int width;
  unsigned int flags;
  unsigned int base = 0;
  char *ptr = NULL;

  outlength = 0;

  while (*fmt) {
    while (1) {
      if (*fmt == 0)
        goto end;

      if (*fmt == '%') {
        fmt++;
        if (*fmt != '%')
          break;
      }

      output_function(*fmt++);
    }

    flags = 0;
    width = 0;

    /* read all flags */
    do {
      if (flags < FLAG_WIDTH) {
        switch (*fmt) {
        case '0':
          flags |= FLAG_ZEROPAD;
          continue;

        case '-':
          flags |= FLAG_LEFTADJ;
          continue;

        case ' ':
          flags |= FLAG_BLANK;
          continue;

        case '+':
          flags |= FLAG_FORCESIGN;
          continue;
        }
      }

      if (flags < FLAG_LONG) {
        if (*fmt >= '0' && *fmt <= '9') {
          unsigned char tmp = *fmt - '0';
          width = 10*width + tmp;
          flags |= FLAG_WIDTH;
          continue;
        }

        if (*fmt == 'h')
          continue;

        if (*fmt == 'l') {
          flags |= FLAG_LONG;
          continue;
        }
      }

      break;
    } while (*fmt++);

    /* Strings */
    if (*fmt == 'c' || *fmt == 's') {
      switch (*fmt) {
      case 'c':
        buffer[0] = va_arg(ap, int);
        ptr = buffer;
        break;

      case 's':
        ptr = va_arg(ap, char *);
        break;
      }

      goto output;
    }

    /* Numbers */
    switch (*fmt) {
    case 'u':
      flags |= FLAG_UNSIGNED;
    case 'd':
      base = 10;
      break;

    case 'o':
      base = 8;
      flags |= FLAG_UNSIGNED;
      break;

    case 'p': // pointer
      output_function('0');
      output_function('x');
      width -= 2;
    case 'x':
      base = 16;
      flags |= FLAG_UNSIGNED;
      break;
    }

    unsigned int num;

    if (!(flags & FLAG_UNSIGNED)) {
      int tmp = va_arg(ap, int);
      if (tmp < 0) {
        num = -tmp;
        flags |= FLAG_NEGATIVE;
      } else
        num = tmp;
    } else {
      num = va_arg(ap, unsigned int);
    }

    /* Convert number into buffer */
    ptr = buffer + sizeof(buffer);
    *--ptr = 0;
    do {
      *--ptr = hexdigits[num % base];
      num /= base;
    } while (num != 0);

    /* Sign */
    if (flags & FLAG_NEGATIVE) {
      output_function('-');
      width--;
    } else if (flags & FLAG_FORCESIGN) {
      output_function('+');
      width--;
    } else if (flags & FLAG_BLANK) {
      output_function(' ');
      width--;
    }

  output:
    /* left padding */
    if ((flags & FLAG_WIDTH) && !(flags & FLAG_LEFTADJ)) {
      while (strlen(ptr) < width) {
        if (flags & FLAG_ZEROPAD)
          output_function('0');
        else
          output_function(' ');
        width--;
      }
    }

    /* data */
    while (*ptr) {
      output_function(*ptr++);
      if (width)
        width--;
    }

    /* right padding */
    if (flags & FLAG_WIDTH) {
      while (width) {
        output_function(' ');
        width--;
      }
    }

    fmt++;
  }

 end:
  return outlength;
}

int printf(const char *format, ...) {
  va_list ap;
  int res;

  maxlen = -1;
  va_start(ap, format);
  res = internal_nprintf(outchar, format, ap);
  va_end(ap);
  return res;
}

int snprintf(char *str, size_t size, const char *format, ...) {
  va_list ap;
  int res;

  maxlen = size;
  outptr = str;
  va_start(ap, format);
  res = internal_nprintf(outstr, format, ap);
  va_end(ap);
  if (res < size)
    str[res] = 0;
  return res;
}

/* Required for gcc compatibility */
int puts(const char *str) {
  while (*str)
    outfunc(*str++);
  outfunc('\n');
  return 0;
}

#undef putchar
int putchar(int c) {
  outfunc(c);
  return 0;
}
