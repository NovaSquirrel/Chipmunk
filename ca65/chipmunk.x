MEMORY {
  LOCALS: start = $0, size = $10, type = rw, file = %O, fill=yes;
  ZP:     start = $10, size = $f0, type = rw, file = %O, fill=yes;
  # use first $10 zeropage locations as locals
  RAM:    start = $0100, size = $00c0, type = rw, file = %O, fill=yes;
  STACK:  start = $01c0, size = $0040, type = rw, file = %O, fill=yes;
  PRG:    start = $0200, size = $0a00, type = ro, file = %O, fill=yes, fillval=$83;
}

SEGMENTS {
  ZEROPAGE: load = ZP, type = zp;
  BSS:      load = RAM, type = bss, define = yes, align = $100;
  CODE:     load = PRG, type = ro;
}

FILES {
  %O: format = bin;
}

