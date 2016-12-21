.include "macropack.s"
.code

  lda #
  lda 0
  ina
  ina
  ina

;: eor array,x
;  nop
;  inx
;  cpx #3
;  jne :-

  halt

array:
  .byt 1, 2, 4
