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
# main
.org [$0200]
.var tempBuf 64

.var stock 0
.var deck 52
.var waste 52
.var foundations 52*4
.var tableu 52*7


.org [$8000]
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
    
_FIM
    # We are done, now loop forever
    jmp [FIM]

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
  lda <2>; bmi (DrawCardFlipped)
  # -- Input
  # $00-01 → Top-Left Corner
  # $02    → Card ID
  
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
  lda <1>; pha; clc; adc $04; sta <1>
  ldy 1
  ldx $8F; lda <2>; and %0010_0000; bne (red)
  __black
  ldx $0F
  __red
  txa; sta [<0>+Y]; inc Y; sta [<0>+Y]
  pla; sta <1>
  
  # -- Card Body
  
  ldy $20
  
  __body
    lda $0F; sta [<0>+Y]
    inc Y  ; sta [<0>+Y]
    inc Y  ; sta [<0>+Y]
    inc Y  ; sta [<0>+Y]
  
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
  
  ldy $00
  lda $14; sta [<0>+Y]; inc Y
  lda $F1; sta [<0>+Y]; inc Y
           sta [<0>+Y]; inc Y
  lda $14; sta [<0>+Y]
  
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