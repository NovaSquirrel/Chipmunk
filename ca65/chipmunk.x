MEMORY {
  ZP:     start = $10, size = $f0, type = rw;
  # use first $10 zeropage locations as locals
  RAM:    start = $0100, size = $0080, type = rw;
  PRG:    start = $0200, size = $0a00, type = ro, file = %O, fill=no;
}

SEGMENTS {
  ZEROPAGE: load = ZP, type = zp;
  BSS:      load = RAM, type = bss, define = yes, align = $100;
  CODE:     load = PRG, type = ro;
}

FILES {
  %O: format = bin;
}

