.include "macropack.s"
.macro PassIfEqual
  clc
  bne :+
  sec
: rol TestPassed
.endmacro

.segment "ZEROPAGE"
  TestPassed: .res 1 ; bit field, each bit represents a passed/failed test
  Pointer:    .res 2
.code

  ; Test to make sure branches work
  bra :+
  halt
:

; TEST ONE: Try adding numbers from an array
  lda #
  sta TestPassed ; Initialize test passed variable
  ldx #
: add Array,x
  inx
  cpx #4
  bne :-

  cmp #10
  PassIfEqual

; TEST TWO: Bit math stuff, and memory inc/dec
  lda #7
  sta      ; load the counter we'll be using
  lda #
  ldx #
: ora BitArray,x
  inx
  dec     ; decrement counter
  bpl :-  ; test BPL too rather than BNE again

  eor #1  ; test exclusive or
  sub #2  ; test subtraction
  cmp #$fc
  PassIfEqual

; TEST THREE: Indirect access
  lda #<Array
  sta Pointer+0
  lda #>Array
  sta Pointer+1

  lda #
  sta   ; counter
  ldy #
: lda (Pointer),y
  add
  sta   ; add number to counter
  iny
  cpy #4
  bne :-

  lda
  cmp #10
  PassIfEqual

; TEST FOUR: Writing to memory
  ldx #1
  ldy #2
  stx
  sty 1
  lda #3
  sta 1,x
  lda #4
  sta 1,y

  lda #4
  sta Pointer+0
  ldy #
  sty Pointer+1
  lda #5
  sta (Pointer),y

  ; Add up all the numbers we wrote to see if it's 15
  lda 0
  add 1
  add 2
  add 3
  add 4
  cmp #15
  PassIfEqual  

; TEST FIVE: Add a 16-bit number

  ; Store $02ff to memory
  lda #$ff
  sta
  lda #2
  sta 1
 
  ; Add 2 to this number and use carry
  lda
  add #2
  sta
  lda 1
  adc #
  sta 1
  cmp #3
  PassIfEqual

; TEST SIX: Negate a 16-bit number
  lda #$12
  sta 1
  lda #$34
  sta 0

  sec             ;Ensure carry is set
  lda #           ;Load constant zero
  sub             ;... subtract the least significant byte
  sta             ;... and store the result
  lda #           ;Load constant zero again
  sbc 1           ;... subtract the most significant byte
  sta 1           ;... and store the result
  cmp #$ed
  PassIfEqual

; TEST SEVEN: ADX and SBX and SWAPAX
  lda #
  ldx #
  adx #10
  sbx #5
  swapax
  cmp #5
  PassIfEqual

; TEST EIGHT: Subroutines
  lda #
  jsr AddFive
  jsr AddFive
  bsr AddFive
  bsr AddFive
  cmp #20
  PassIfEqual

  lda TestPassed
  halt

AddFive:
  add #5
  rts

Array:
  .byt 1, 2, 3, 4, 0

BitArray:
  .byt 1, 2, 4, 8, 16, 32, 64, 128
