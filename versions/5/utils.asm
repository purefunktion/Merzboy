; This is where we will put utility or helper functions used by the whole program
INCLUDE "../../includes/hardware.inc" ; Include the definitions from this community-maintained classic

SECTION "Utils", ROM0;

; OBS the double colons(::) after the labels like WaitVBlank::
; they are now "exported"

; Wait for Vertical Blank
WaitVBlank::
    ld a, [rLY]             ; Fetch the value from [rLY] (LCDC Y-Coordinate) into register A. See hardware.inc file
    cp 144                  ; The value in A (from rLY) is compared (cp) with the value 144. cp means value of A minus 144
    jr c, WaitVBlank        ; If A < 144, the carry flag is set, and a jump is made back to WaitVBlank above
    ret                     ; Return; we are now in VBlank (Values range from 0->153. 144->153 is the VBlank period.)

; Copied from somewhere
; Copies a block of memory somewhere else
; @param DE Pointer to beginning of block to copy
; @param HL Pointer to where to copy (bytes will be written from there onwards)
; @param BC Amount of bytes to copy (0 causes 65536 bytes to be copied)
; @return DE Pointer to byte after last copied one
; @return HL Pointer to byte after last written one
; @return BC 0
; @return A 0
; @return F Z set, C reset
Memcpy::
    ; Increment B if C is non-zero
    dec bc
    inc b
    inc c
.loop
    ld a, [de]
    ld [hli], a
    inc de
    dec c
    jr nz, .loop
    dec b
    jr nz, .loop
    ret

;; Another borrow from GB ASM Tutorial made by Damian Yerrick(aka PinoBatch)
;; From: https://github.com/pinobatch/libbet/blob/master/src/rand.z80#L34-L54
; Generates a pseudorandom 16-bit integer in BC
; using the LCG formula from cc65 rand():
; x[i + 1] = x[i] * 0x01010101 + 0xB3B3B3B3
; @return A=B=state bits 31-24 (which have the best entropy),
; C=state bits 23-16, HL trashed
Rand:: ; OBSERVE the exported symbol double colon (::) read about that here https://rgbds.gbdev.io/docs/master/rgbasm.5#Exporting_and_importing_symbols
  ; Add 0xB3 then multiply by 0x01010101
  ld hl, randstate+0
  ld a, [hl]
  add a, $B3
  ld [hl+], a   ; [hl+] is the same as [hli] https://rgbds.gbdev.io/docs/v0.8.0/gbz80.7#LD__HLI_,A
  adc a, [hl]   ; "Add the byte pointed to by HL plus the carry flag to A." https://rgbds.gbdev.io/docs/v0.8.0/gbz80.7#ADC_A,_HL_
  ld [hl+], a
  adc a, [hl]
  ld [hl+], a
  ld c, a
  adc a, [hl]
  ld [hl], a
  ld b, a
  ret