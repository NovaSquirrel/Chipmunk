#include <stdio.h>

int main(int argc, char *argv[]) {
  if(argc < 3) {
    puts("needs two arguments");
    return -1;
  }

  FILE *In = fopen(argv[1], "rb");
  if(!In) {
    puts("Couldn't open input");
    return -1;
  }
  FILE *Out = fopen(argv[2], "wb");
  if(!Out) {
    puts("Couldn't open output");
    return -1;
  }

  while(1) {
    int byte = fgetc(In);
    if(byte == EOF)
      break;
    fprintf(Out, "%.2x\r\n", byte);
  }
  fclose(In);
  fclose(Out);
  return 0;
}
