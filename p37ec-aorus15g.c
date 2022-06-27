
/**
Copyright (c) 2016 Jason Ertel, Codesim LLC

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

Modifed to work with Gigabyte AORUS 15G KB
Raymundo Cassani, Jun 2022

*/
#include <endian.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>


unsigned short read16(FILE* f, unsigned char offset) {
  fseek(f, offset, SEEK_SET);
  unsigned short s = 0;
  fread(&s, sizeof(unsigned short), 1, f);
  return htobe16(s);
}

unsigned char read8(FILE* f, unsigned char offset) {
  fseek(f, offset, SEEK_SET);
  unsigned char c = 0;
  fread(&c, sizeof(unsigned char), 1, f);
  return c;
}

unsigned char read1(FILE* f, unsigned char offset, unsigned char bit) {
  fseek(f, offset, SEEK_SET);
  unsigned char c = 0;
  fread(&c, sizeof(unsigned char), 1, f);
  return (c & (1 << bit)) > 0 ? 1 : 0;
}

void write8(FILE* f, unsigned char offset, const unsigned char value) {
  fseek(f, offset, SEEK_SET);
  unsigned char c = 0;
  fwrite(&value, sizeof(unsigned char), 1, f);
}

void write1(FILE* f, unsigned char offset, unsigned char bit, const unsigned char value) {
  unsigned char c = read8(f, offset);
  fseek(f, offset, SEEK_SET);
  if (value > 0) {
    c |= (1 << bit);
  } else {
    c &= ~(1 << bit);
  }
  fwrite(&c, sizeof(unsigned char), 1, f);
}

FILE* initEc() {
  system("modprobe ec_sys write_support=1");
  return fopen("/sys/kernel/debug/ec/ec0/io", "r+");
}

void closeEc(FILE* ec) {
  fclose(ec);
}

void fail(const char* msg) {
  printf("ERROR: %s\n", msg);
  exit(1);
}

int main(int argc, char** args) {
  FILE* ec = initEc();
  if (!ec) fail("Unable to initialize embedded controller; did you forget to use sudo?");

  if (argc == 3) {
    char* dotIdx = strchr(args[1], '.');
    if (dotIdx != NULL) {
      *dotIdx = '\0';
      dotIdx++;
      unsigned char offset = (unsigned char)strtol(args[1], NULL, 0);
      unsigned char bit = (unsigned char)atoi(dotIdx);
      unsigned char value = (unsigned char)strtol(args[2], NULL, 0);
      write1(ec, offset, bit, value);
    } else {
      unsigned char offset = (unsigned char)strtol(args[1], NULL, 0);
      unsigned char value = (unsigned char)strtol(args[2], NULL, 0);
      write8(ec, offset, value);
    }
  } else {
    // Setting the following bits causing the EC to activate (or at least activate fan controls)
    write8(ec, 0x01, 0xA3);
    unsigned char bit08_6 = read1(ec, 0x08, 6);
    unsigned char bit06_4 = read1(ec, 0x06, 4);
    unsigned char bit0D_0 = read1(ec, 0x0D, 0);
    unsigned char bit0D_7 = read1(ec, 0x0D, 7);
    unsigned char bit0C_4 = read1(ec, 0x0C, 4);
    unsigned char fan_status = (bit08_6 * 16) + (bit06_4 *  8) + (bit0D_0 *  4) +
                               (bit0D_7 *  2) + (bit0C_4 *  1);
    char fan_mode[20] = "Normal";
    if (bit08_6 == 1) {
        strcpy(fan_mode, "Quiet");
    } else if (bit06_4 == 1) {
        strcpy(fan_mode, "Fix");
    } else if (bit0D_0 == 1) {
        strcpy(fan_mode, "AutoMax");
    } else if (bit0D_7 == 1) {
        strcpy(fan_mode, "Deep control");
    } else if (bit0C_4 == 1) {
        strcpy(fan_mode, "Gaming");
    }
    strcat(fan_mode, " mode");

    printf("Usage: sudo %s [<hex-offset[.bit]> <hex-value>|<bit-value>]\n", args[0]);
    printf("   Ex: sudo %s 0xB0 0xE5\n", args[0]);
    printf("   Ex: sudo %s 0x08.6 1\n\n", args[0]);
    printf("-----------------------------------\n");
    printf("Current Embedded Controller Values:\n");
    printf("  Touchpad and screen\n");
    printf("    Touchpad (1 = Enabled)    [0x03.5]: %d\n", read1(ec, 0x03, 5));
    printf("    Screen   (0 = Enabled)    [0x09.3]: %d\n", read1(ec, 0x09, 3));
    printf("  Fan status\n");
    printf("    Fan current mode:                   %s\n", fan_mode);
    printf("    Fan0 speed (\%)            [0xB3]:   %d%%\n", (int)round(read8(ec, 0xB3) / 2.29));
    printf("    Fan1 speed (\%)            [0xB4]:   %d%%\n", (int)round(read8(ec, 0xB4) / 2.29));
    printf("    Fan0 speed (RPM)          [0xFC]:   %d RPM\n", read16(ec, 0xFC));
    printf("    Fan1 speed (RPM)          [0xFE]:   %d RPM\n", read16(ec, 0xFE));
    printf("  Fan control\n");
    printf("    Fan Quiet mode bit        [0x08.6]: %d\n", bit08_6);
    printf("    Fan Gaming mode bit       [0x0C.4]: %d\n", bit0C_4);
    printf("    Fan Deep control mode bit [0x0D.7]: %d\n", bit0D_7);
    printf("    Fan Auto Max bit          [0x0D.0]: %d\n", bit0D_0);
    printf("    Fan Fix mode bit          [0x06.4]: %d\n", bit06_4);
    printf("    Fan0 target speed (\%)     [0xB0]:   %d%%\n", (int)round(read8(ec, 0xB0) / 2.29));
    printf("    Fan1 target speed (\%)     [0xB1]:   %d%%\n", (int)round(read8(ec, 0xB1) / 2.29));
    printf("-----------------------------------\n");
  }
  closeEc(ec);
  exit(0);
}
