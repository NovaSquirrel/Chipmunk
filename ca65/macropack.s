.feature ubiquitous_idents
.feature addrsize

PARAM_NONE   = %00
PARAM_8BIT   = %01
PARAM_16BIT  = %10
PARAM_16BITX = %11

.macro MemoryInstruction opcode, mem, index
  .assert .blank(index) || .xmatch (index, x), error, "bad addressing mode"
  .local @value
  .ifnblank mem
    @value = mem
  .endif

  .ifblank mem
    .byt (opcode << 2) | PARAM_NONE
  .elseif .xmatch (index, x)
    .byt (opcode << 2) | PARAM_16BITX, <mem, >mem
  .elseif .addrsize(@value) = 1
    .byt (opcode << 2) | PARAM_8BIT, mem
  .else
    .byt (opcode << 2) | PARAM_16BIT, <mem, >mem
  .endif
.endmacro

.macro ImmOrMemInstruction opcode, mem, index
  .local @argvalue
  .ifblank mem
    .byt ((opcode+1) << 2) | PARAM_NONE
  .elseif (.match (.left (1, {mem}), #))
    .if(.tcount(mem) = 1)
      .byte (opcode << 2)
    .else
      @argvalue = .right(.tcount(mem)-1, mem)
      .byte (opcode << 2) | PARAM_8BIT, @argvalue
    .endif
  .else
    MemoryInstruction (opcode+1), mem, index
  .endif
.endmacro

.macro lda mem, index
  .local @argvalue, @lpar, @rpar
  @lpar = .match (.left (1, {mem}), {(})
  @rpar = .match (.right (1, {mem}), {)})

  .if(.xmatch (index, y))
    .if @lpar && @rpar
      .byt ($28 << 2) | PARAM_8BIT, mem
    .else
      .byt ($28 << 2) | PARAM_16BIT, <mem, >mem
    .endif
  .else
    ImmOrMemInstruction $00, mem, index
  .endif
.endmacro

.macro ldx mem, index
  ImmOrMemInstruction $02, mem, index
.endmacro

.macro ldy mem, index
  ImmOrMemInstruction $04, mem, index
.endmacro

.macro sta mem, index
  .local @argvalue, @lpar, @rpar
  @lpar = .match (.left (1, {mem}), {(})
  @rpar = .match (.right (1, {mem}), {)})

  .if(.xmatch ({index}, y))
    .if @lpar && @rpar
      .byt ($29 << 2) | PARAM_8BIT, mem
    .else
      .byt ($29 << 2) | PARAM_16BIT, <mem, >mem
    .endif
  .else
    MemoryInstruction $21, mem, index
  .endif
.endmacro

.macro stx mem, index
  MemoryInstruction $23, mem, index
.endmacro

.macro sty mem, index
  MemoryInstruction $25, mem, index
.endmacro

.macro ldap mem
  ; no support for the zero parameter
  .byt ($28 << 2) | PARAM_8BIT, mem
.endmacro

.macro stap mem
  ; no support for the zero parameter
  .byt ($29 << 2) | PARAM_8BIT, mem
.endmacro

.macro clc
  .byt $06 << 2
.endmacro

.macro sec
  .byt $07 << 2
.endmacro

.macro add mem, index
  ImmOrMemInstruction $08, mem, index
.endmacro

.macro sub mem, index
  ImmOrMemInstruction $0A, mem, index
.endmacro

.macro adc mem, index
  ImmOrMemInstruction $0C, mem, index
.endmacro

.macro sbc mem, index
  ImmOrMemInstruction $0E, mem, index
.endmacro

.macro nor mem, index
  ImmOrMemInstruction $10, mem, index
.endmacro

.macro eor mem, index
  ImmOrMemInstruction $12, mem, index
.endmacro

.macro cmp mem, index
  ImmOrMemInstruction $14, mem, index
.endmacro

.macro cpx mem, index
  ImmOrMemInstruction $16, mem, index
.endmacro

.macro cpy value
  .assert (.match (.left (1, {value}), #)), error, "CPY only supports constants"

  .local @argvalue
  .if (.tcount(value) = 1)
    .byt ($1c << 2) | PARAM_NONE
  .else
    @argvalue = .right(.tcount(value)-1, value)
    .byt ($1c << 2) | PARAM_8BIT, @argvalue
  .endif
.endmacro

.macro asl
  .byt $18 << 2
.endmacro

.macro lsr
  .byt $1a << 2
.endmacro

.macro rol mem, index
  MemoryInstruction $19, mem, index
.endmacro

.macro ror mem, index
  MemoryInstruction $1B, mem, index
.endmacro

.macro inc mem, index
  MemoryInstruction $1D, mem, index
.endmacro

.macro dec mem, index
  MemoryInstruction $1F, mem, index
.endmacro

.macro ina
  .byt $2A << 2
.endmacro

.macro dea
  .byt $2B << 2
.endmacro

.macro inx
  .byt $2C << 2
.endmacro

.macro dex
  .byt $2D << 2
.endmacro

.macro iny
  .byt $2E << 2
.endmacro

.macro dey
  .byt $2F << 2
.endmacro

.macro adx value
  .assert (.match (.left (1, {value}), #)), error, "ADY only supports constants"
  .local @argvalue
  @argvalue = .right(.tcount(value)-1, value)
  .byt ($2C << 2) | PARAM_8BIT, @argvalue
.endmacro

.macro sbx value
  .assert (.match (.left (1, {value}), #)), error, "SBX only supports constants"
  .local @argvalue
  @argvalue = .right(.tcount(value)-1, value)
  .byt ($2D << 2) | PARAM_8BIT, @argvalue
.endmacro

.macro ady value
  .assert (.match (.left (1, {value}), #)), error, "ADY only supports constants"
  .local @argvalue
  @argvalue = .right(.tcount(value)-1, value)
  .byt ($2E << 2) | PARAM_8BIT, @argvalue
.endmacro

.macro sby value
  .assert (.match (.left (1, {value}), #)), error, "SBY only supports constants"
  .local @argvalue
  @argvalue = .right(.tcount(value)-1, value)
  .byt ($2F << 2) | PARAM_8BIT, @argvalue
.endmacro

.macro nop
  .byt $20 << 2
.endmacro

.macro tax
  .byt $22 << 2
.endmacro

.macro txa
  .byt $24 << 2
.endmacro

.macro tay
  pha
  ply
.endmacro

.macro tya
  phy
  pla
.endmacro

.macro txy
  phx
  ply
.endmacro

.macro tyx
  phy
  plx
.endmacro

.macro swapax
  .byt $26 << 2
.endmacro

.macro swapay
  pha
  ply
  pla
  ply
.endmacro

.macro swapxy
  phx
  phy
  plx
  ply
.endmacro

.macro rts
  .byt $27 << 2
.endmacro

.macro php
  .byt $30 << 2
.endmacro

.macro pha
  .byt $32 << 2
.endmacro

.macro phx
  .byt $34 << 2
.endmacro

.macro phy
  .byt $36 << 2
.endmacro

.macro plp
  .byt $31 << 2
.endmacro

.macro pla
  .byt $33 << 2
.endmacro

.macro plx
  .byt $35 << 2
.endmacro

.macro ply
  .byt $37 << 2
.endmacro

.macro not
  nor #
.endmacro

.macro neg
  not
  ina
.endmacro

.macro ora mem, index
  nor mem, index
  not
.endmacro

.macro bic mem, index
  not
  nor mem, index
.endmacro

.macro and mem
  .assert (.match (.left (1, {mem}), #)), error, "AND only supports constants"

  .local @argvalue
  @argvalue = .right(.tcount(mem)-1, mem)
  bic #<~@argvalue
.endmacro

.macro BranchInstruction opcode, target
  .local @distance
  @distance = (target) - (* + 2)
  .assert @distance >= -128 && @distance <= 127, error, "branch out of range"
  .byte (opcode<<2) | PARAM_8BIT, <@distance
.endmacro

.macro bra destination
  BranchInstruction $38, destination
.endmacro

.macro bsr destination
  BranchInstruction $39, destination
.endmacro

.macro beq destination
  BranchInstruction $3d, destination
.endmacro

.macro bne destination
  BranchInstruction $3c, destination
.endmacro

.macro bpl destination
  BranchInstruction $3a, destination
.endmacro

.macro bmi destination
  BranchInstruction $3b, destination
.endmacro

.macro bcc destination
  BranchInstruction $3e, destination
.endmacro

.macro bcs destination
  BranchInstruction $3f, destination
.endmacro

.macro jmp destination
  .byt ($38 << 2) | PARAM_16BIT, <destination, >destination
.endmacro

.macro jsr destination
  .byt ($39 << 2) | PARAM_16BIT, <destination, >destination
.endmacro

.macro jpl destination
  .byt ($3A << 2) | PARAM_16BIT, <destination, >destination
.endmacro

.macro jmi destination
  .byt ($3B << 2) | PARAM_16BIT, <destination, >destination
.endmacro

.macro jne destination
  .byt ($3C << 2) | PARAM_16BIT, <destination, >destination
.endmacro

.macro jeq destination
  .byt ($3D << 2) | PARAM_16BIT, <destination, >destination
.endmacro

.macro jcc destination
  .byt ($3E << 2) | PARAM_16BIT, <destination, >destination
.endmacro

.macro jcs destination
  .byt ($3F << 2) | PARAM_16BIT, <destination, >destination
.endmacro

.macro halt
  .byt %10000011
.endmacro
