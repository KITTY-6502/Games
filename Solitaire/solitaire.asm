.cpu 65c02

# ==== Solitaire For the Kitty!! ===
# Info:
# Card IDs are a 6-bit value:
#  - lower 4 bits are the Rank (0-12), 'A23456789TJQK'
#  - upper 2 bits are the Suit, ♦♣♦♥
# -- Variables
# zp
.zorg <$10>
.zp random 2
.zp card_ptr 2
.zp cursor
.zp key_0
# main
.org [$0200]
.var tempBuf 64

.var deck 52
.val stock deck
.var waste 52
.var foundation_0 52
.var foundation_1 52
.var foundation_2 52
.var foundation_3 52
.var tableu_0 52
.var tableu_1 52
.var tableu_2 52
.var tableu_3 52
.var tableu_4 52
.var tableu_5 52
.var tableu_6 52

.val stockID 0
.val wasteID 1
.val foundation_0ID 3
.val foundation_1ID 4
.val foundation_2ID 5
.val foundation_3ID 6

.val tableu_0ID 8
.val tableu_1ID 9
.val tableu_2ID 10
.val tableu_3ID 11
.val tableu_4ID 12
.val tableu_5ID 13
.val tableu_6ID 14


.org [$8000]

# Tables and Data
_StackTableLo
.byte stock.lo, waste.lo, 0, foundation_0.lo, foundation_1.lo, foundation_2.lo, foundation_3.lo,0
.byte tableu_0.lo, tableu_1.lo, tableu_2.lo, tableu_3.lo, tableu_4.lo, tableu_5.lo, tableu_6.lo,0
_StackTableHi
.byte stock.hi, waste.hi, 0, foundation_0.hi, foundation_1.hi, foundation_2.hi, foundation_3.hi,0
.byte tableu_0.hi, tableu_1.hi, tableu_2.hi, tableu_3.hi, tableu_4.hi, tableu_5.hi, tableu_6.hi,0

_NMI
_IRQ
_RESET
    # Disable IRQ and Decimal Mode
    sei; cld
    
    # Set stack pointer
    ldx $FF; txs
    
    # Mute Audio Channels
    stz [$70F0]; stz [$70F1]; stz [$70F2]; stz [$70F3]
    
    # Reset Screen
    ldx $00
    __clearloop
        # Space Character
        lda ' '
        sta [$6800+X]; sta [$6900+X]; sta [$6A00+X]; sta [$6B00+X]
        # White Foreground, Green Background
        lda $F4
        sta [$6C00+X]; sta [$6D00+X]; sta [$6E00+X]; sta [$6F00+X]
    inc X; bne (clearloop)
    
    lda 1; sta <random>
    
    jsr [ShuffleDeck]
    jsr [Serve]
    
    ldx tableu_0ID
    __drawStacks
    phx; jsr [DrawStack]; plx
    inc X; cpx tableu_6ID+1; bne (drawStacks)
    
    
    
    lda $02; sta <0>
    lda $68; sta <1>
    jsr [DrawCardShadow]
    
    ldx stockID
    jsr [DrawStackTop]
    
    lda $06; sta <0>
    lda $68; sta <1>
    jsr [DrawCardShadow]
    
    lda $0E; sta <0>
    lda $68; sta <1>
    jsr [DrawCardShadow]
    lda $12; sta <0>
    lda $68; sta <1>
    jsr [DrawCardShadow]
    lda $16; sta <0>
    lda $68; sta <1>
    jsr [DrawCardShadow]
    lda $1A; sta <0>
    lda $68; sta <1>
    jsr [DrawCardShadow]
  lda 0
    sta <cursor>
    sta <key_0>
_FIM
  wai
  ldx <cursor>
  jsr [StackIDToCursor]
  
  ldy $C1
  lda ' ';      sta [<0>+Y]
  inc Y; sta [<0>+Y]
  
  lda <1>; clc; adc 4; sta <1>
  lda $F4; sta [<0>+Y]
  dec Y;   sta [<0>+Y]
  
  lda [$7000]; pha; cmp <key_0>; beq (noInput)
    
    bit %0000_0001; bne (right)
    bit %0000_0010; bne (down)
    bit %0000_0100; bne (left)
    bit %0000_1000; bne (up)
    bra (noInput)
    __left
    lda <cursor>; and %0000_0111; beq (noInput)
      dec <cursor>
    bra (noInput)
    __down
    lda <cursor>; ora %0000_1000; sta <cursor>
    bra (noInput)
    __right
    lda <cursor>; and %0000_0111; cmp 6; beq (noInput)
      inc <cursor>
    bra (noInput)
    __up
    lda <cursor>; and %0000_0111; sta <cursor>
  __noInput
  pla; sta <key_0>
  
  ldx <cursor>
  jsr [StackIDToCursor]
  
  ldy $C1
  lda $A8;      sta [<0>+Y]
  inc A; inc Y; sta [<0>+Y]
  
  lda <1>; clc; adc 4; sta <1>
  lda $F4; sta [<0>+Y]
  dec Y;   sta [<0>+Y]
jmp [FIM]

_StackIDToCursor
  # Pos Lo
  txa; and %0000_0111
  asl A; asl A
  inc A; inc A
  #clc; adc $E0
  sta <0>
  
  # Pos Hi
  txa; lsr A; lsr A; lsr A; clc
  adc $68; sta <1>
  
  lda <cursor>; bit %0000_1000; bne (lowRow)
rts
__lowRow
  lda [StackTableLo+X]; sta <card_ptr+0>
  lda [StackTableHi+X]; sta <card_ptr+1>
  
  ldy 0
  ___loop
  lda [<card_ptr>+Y]
  cmp $FF; beq (break); inc Y; bra (loop)
  ___break
  cpy 2; bcc (done)
  lda 0; sta <card_ptr+0>
  dec Y; tya
  asl A; rol <card_ptr>
  asl A; rol <card_ptr>
  asl A; rol <card_ptr>
  asl A; rol <card_ptr>
  asl A; rol <card_ptr>
  clc
  adc <0>; sta <0>
  lda <1>; adc <card_ptr>; sta <1>
___done
rts

_DEBUGFullDeckPrint
  # Draw the Full Deck
  ldy 0
  lda $00; sta <0>
  lda $68; sta <1>
  
  __deckPrint
    lda [deck+Y]; sta <2>
    phy; jsr [DrawCard]; ply
    clc
    lda <0>; adc 4; sta <0>
    lda <1>; adc 0; sta <1>
  inc Y; cpy 52; bne (deckPrint)
  
  lda $80; sta <2>; jsr [DrawCard]
rts

_Serve
  # Clear the stacks
  ldx 51
  
  __clrStacks
    lda $FF
    
    sta [waste+X]
    
    sta [foundation_0+X]
    sta [foundation_1+X]
    sta [foundation_2+X]
    sta [foundation_3+X]
    
    sta [tableu_0+X]
    sta [tableu_1+X]
    sta [tableu_2+X]
    sta [tableu_3+X]
    sta [tableu_4+X]
    sta [tableu_5+X]
    sta [tableu_6+X]
    
    lda [stock+X]
    ora $80
    sta [stock+X]
    
  dec X; bpl (clrStacks)
  
  # Evil Unrolled Loops to fill the tableus
  ldy 51
  lda [stock+Y]; and %0111_1111; sta [tableu_0+0]; dec Y
  
  lda [stock+Y]; sta [tableu_1+0]; dec Y
  lda [stock+Y]; and %0111_1111; sta [tableu_1+1]; dec Y
  
  lda [stock+Y]; sta [tableu_2+0]; dec Y
  lda [stock+Y]; sta [tableu_2+1]; dec Y
  lda [stock+Y]; and %0111_1111; sta [tableu_2+2]; dec Y
  
  lda [stock+Y]; sta [tableu_3+0]; dec Y
  lda [stock+Y]; sta [tableu_3+1]; dec Y
  lda [stock+Y]; sta [tableu_3+2]; dec Y
  lda [stock+Y]; and %0111_1111; sta [tableu_3+3]; dec Y
  
  lda [stock+Y]; sta [tableu_4+0]; dec Y
  lda [stock+Y]; sta [tableu_4+1]; dec Y
  lda [stock+Y]; sta [tableu_4+2]; dec Y
  lda [stock+Y]; sta [tableu_4+3]; dec Y
  lda [stock+Y]; and %0111_1111; sta [tableu_4+4]; dec Y
  
  lda [stock+Y]; sta [tableu_5+0]; dec Y
  lda [stock+Y]; sta [tableu_5+1]; dec Y
  lda [stock+Y]; sta [tableu_5+2]; dec Y
  lda [stock+Y]; sta [tableu_5+3]; dec Y
  lda [stock+Y]; sta [tableu_5+4]; dec Y
  lda [stock+Y]; and %0111_1111; sta [tableu_5+5]; dec Y
  
  lda [stock+Y]; sta [tableu_6+0]; dec Y
  lda [stock+Y]; sta [tableu_6+1]; dec Y
  lda [stock+Y]; sta [tableu_6+2]; dec Y
  lda [stock+Y]; sta [tableu_6+3]; dec Y
  lda [stock+Y]; sta [tableu_6+4]; dec Y
  lda [stock+Y]; sta [tableu_6+5]; dec Y
  lda [stock+Y]; and %0111_1111; sta [tableu_6+6]
  
  # Non-Evil Loop to clear the stock
  lda $FF
  _clrStock
    sta [stock+Y]
  inc Y; cpy 52; bne (clrStock)
  
  # We did it :)
rts

_ShuffleDeck
  # -- Shuffle Deck
  # Simple Dumb Shuffling Algorithm:
  # 1 - "tempDeck" 64-entry List Keeps track of which cards have been selected
  #   * 0 = taken, 1 = avaliable
  #   * this list is populated according to which card values are legal
  # 2 - We generate random card values (0-63) and check if they are avaliable, then add to "deck"
  # 3 - Once 52 cards have been selected, we are done
  # Fill temp deck
  ldx 63
  __tempDeckFill
    ldy 1
    txa; and $0F; cmp 13; bcc (valid)
      ldy 0
    ___valid
    tya; sta [tempBuf+X]
  dex; bpl (tempDeckFill)
  
  # Fill Actual Deck
  ldy 51
  __deckFill
    jsr [Random]
    and %0011_1111; tax
    lda [tempBuf+X]; beq (deckFill)
    txa; sta [deck+Y]
    lda 0; sta [tempBuf+X]
  dec Y; bpl (deckFill)
rts
# Draw Card
_DrawCard
  lda <2>; bpl (c)
   jmp [DrawCardFlipped]
  __c
  # -- Input
  # $00-01 → Top-Left Corner
  # $02    → Card ID
  # $03    → Card Above
  
  lda <0>; sta <4>
  lda <1>; clc; adc 4; sta <5>
  
  # -- Header
  # - Tiles
  ldy 0
  lda $AA; sta [<0>+Y]
  
  inc Y
  lda <2>; and %0000_1111; tax
  lda [Rank+X]; sta [<0>+Y]
  
  inc Y
  lda <2>; lsr A; lsr A; lsr A; lsr A; tax
  lda [Suits+X]; sta [<0>+Y]
  
  inc Y
  lda $AB; sta [<0>+Y]
  
  # - Colors
  #lda <1>; pha; clc; adc $04; sta <1>; sta <5>
  ldy 1
  ldx $8F; lda <2>; and %0010_0000; bne (red)
  __black
  ldx $0F
  __red
  txa; sta [<4>+Y]; inc Y; sta [<4>+Y]
  
  # Card Under
  __under
  ldx $F4
  lda <3>
    cmp $FF; beq (none)
    bmi (down)
  ___up
  ldx $FF; bra (none)
  ___down
  ldx $F1
  ___none
  txa
  ldy 0; sta [<4>+Y]
  ldy 3; sta [<4>+Y]
  #pla; sta <1>
  
  # -- Card Body
  
  
  ldy $20
  
  __body
    lda $0F; sta [<0>+Y]
    lda $FF; sta [<4>+Y]
    
    inc Y
    lda $0F; sta [<0>+Y]
    lda $FF; sta [<4>+Y]
    
    inc Y
    lda $0F; sta [<0>+Y]
    lda $FF; sta [<4>+Y]
    
    inc Y
    lda $0F; sta [<0>+Y]
    lda $FF; sta [<4>+Y]
  tya; clc; adc 29; tay; cmp 160; bne (body)
  
  lda $BA; sta [<0>+Y]; inc Y
  lda $0F; sta [<0>+Y]; inc Y
           sta [<0>+Y]; inc Y
  lda $BB; sta [<0>+Y]
  
rts
__Rank
.byte 'A23456789TJQK'
__Suits
# Spades, Clubs, Tiles, Hearts
.byte $F8,$FA,$FC,$FE
  
_DrawCardFlipped
  cmp $FF; bne (c)
    rts
  __c
  # Card Body
  ldy 0
  lda $AA; sta [<0>+Y]; inc Y
  lda $DC; sta [<0>+Y]; inc Y
           sta [<0>+Y]; inc Y
  lda $AB; sta [<0>+Y]; inc Y
  
  ldy $20
  
  __body
    lda $0F; sta [<0>+Y]
    inc Y  ; sta [<0>+Y]
    inc Y  ; sta [<0>+Y]
    inc Y  ; sta [<0>+Y]
  
  tya; clc; adc 29; tay; cmp 160; bne (body)
  
  lda $BA; sta [<0>+Y]; inc Y
  lda $DC; sta [<0>+Y]; inc Y
           sta [<0>+Y]; inc Y
  lda $BB; sta [<0>+Y]

  # Card Color
  lda <1>; pha; clc; adc 4; sta <1>
  
  ldy $01
  lda $F1; sta [<0>+Y]; inc Y
           sta [<0>+Y]; inc Y
  
  __under
  ldx $14
  lda <3>
    cmp $FF; beq (none)
    bmi (down)
  ___up
  # THIS SHOULD NORMALLY NEVER HAPPEN
  ldx $1F
  bra (none)
  ___down
  ldx $11
  ___none
  txa
  ldy 0; sta [<0>+Y]
  ldy 3; sta [<0>+Y]
  
  ldy $20
  
  __color
    lda $1F; sta [<0>+Y]
    inc Y  ; sta [<0>+Y]
    inc Y  ; sta [<0>+Y]
    inc Y  ; sta [<0>+Y]
  
  tya; clc; adc 29; tay; cmp 160; bne (color)
  
  lda $14; sta [<0>+Y]; inc Y
  lda $F1; sta [<0>+Y]; inc Y
           sta [<0>+Y]; inc Y
  lda $14; sta [<0>+Y]
  
  pla; sta <1>
rts

_DrawCardShadow

  ldy 0
  lda $AD; sta [<0>+Y]
  inc Y  ; lda $AC; sta [<0>+Y]
  inc Y  ; sta [<0>+Y]
  inc Y  ; lda $AE; sta [<0>+Y]
  
  ldy 160
  lda $BD; sta [<0>+Y]
  inc Y  ; lda $AC; sta [<0>+Y]
  inc Y  ; sta [<0>+Y]
  inc Y  ; lda $BE; sta [<0>+Y]
  
  lda <1>; pha; clc; adc 4; sta <1>
  
  ldy 0
  __color
    lda $F4; sta [<0>+Y]
    inc Y  ; sta [<0>+Y]
    inc Y  ; sta [<0>+Y]
    inc Y  ; sta [<0>+Y]
  
  tya; clc; adc 29; tay; cmp 192; bne (color)
  
  pla; sta <1>
rts

_DrawStack
  # Print!
  lda [StackTableLo+X]; sta <card_ptr+0>
  lda [StackTableHi+X]; sta <card_ptr+1>
  
  # Pos Lo
  txa; and %0000_0111
  asl A; asl A
  inc A; inc A
  #clc; adc $E0
  sta <0>
  
  # Pos Hi
  lda $69; sta <1>
  # Previous Card
  lda $FF; sta <3>
  
  ldy 0
  __tabPrint
    lda [<card_ptr>+Y]
    cmp $FF; beq (break)
    
      sta <2>
      phy
      jsr [DrawCard]
      ply
      
      clc
      lda <0>; adc $20; sta <0>
      lda <1>; adc $00; sta <1>
      lda <2>; sta <3>
  inc Y; bra (tabPrint)
  ___break
rts

_DrawStackTop
  # Print!
  lda [StackTableLo+X]; sta <card_ptr+0>
  lda [StackTableHi+X]; sta <card_ptr+1>
  
  # Pos Lo
  txa; and %0000_0111
  asl A; asl A
  inc A; inc A
  #clc; adc $E0
  sta <0>
  
  # Pos Hi
  txa; lsr A; lsr A; lsr A; clc
  adc $68; sta <1>
  # TopMostCard
  lda $FF; sta <2>; sta <3>
  
  ldy 0
  __topFind
    lda [<card_ptr>+Y]
    cmp $FF; beq (break)
      sta <2>
  inc Y; bra (topFind)
  ___break
  
  jsr [DrawCard]
rts

.macro xorShift789
  # https://github.com/impomatic/xorshift798/blob/main/6502.asm
  #; 16-bit xorshift 6502 pseudorandom number generator by John Metcalf

  #; generates 16-bit pseudorandom numbers with a period of 65535
  #; using the xorshift method

  #; XSHFT ^= XSHFT << 7
  #; XSHFT ^= XSHFT >> 9
  #; XSHFT ^= XSHFT << 8
  
  # XSHFT.hi ^= XSHFT << 7
  lda <random+1>; ror A
  lda <random+0>; ror A
  xor <random+1>; sta <random+1>
  # -- XSFHT.lo ^= XSHFT >> 9
  #lda <random+1>
  ror A; xor <random+0>; sta <random+0>
  # -- XSHFT.hi ^= XSHFT << 8
  #lda <random+0>
  xor <random+1>; sta <random+1>
rts
.endmacro

_Random
xorShift789

# Interrupt Vectors
.pad [VECTORS]
.word NMI
.word RESET
.word IRQ