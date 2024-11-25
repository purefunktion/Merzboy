INCLUDE "hardware.inc"      ; Include the definitions from this community-maintained classic

SECTION "Header", ROM0[$100]; Mandatory GB stuff
    jp EntryPoint
    ds $150 - @, 0          ; Make room for the header

EntryPoint:
    call WaitVBlank         ; Wait for Vertical Blank function call
    xor a                   ; Turn A into 0
    ld [rLCDC], a           ; Load A(0) into rLCDC, bit 7 = on/off (disable display)
    
    ; Copy the tile data now that the LCD is turned off
	ld de, Tiles            ; See "Tiles" further down, it's a label in code but only a memory location in the machine
	ld hl, $9000            ; Place where the GB tiles usually live in memory 
	ld bc, TilesEnd - Tiles ; TilesEnd is also just a number; hence BC now contains the number of tiles to copy
	call Memcpy             ; See the Memcpy routine down below

    ld b, 160               ; Loop counter
    ld hl, _OAMRAM

ClearOam:
    ld [hli], a             ; Load value of A into memory address of HL and post-increment HL
    dec b                   ; Decrease loop counter
    jp nz, ClearOam         ; If B is not zero, loop again
                            ; If zero flag is set, fall through
    call ClearBg            ; Clear the background
    call WaitVBlank         ; Wait again; clearing the background takes a while
    call SetSwitchDisplay
    ld a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJON
    ld [rLCDC], a
    ; During the first (blank) frame, initialize display registers
    ld a, %11100100
    ld [rBGP], a
    ld a, %11100100
    ld [rOBP0], a

    ; Initialize the sound system
    ; Has to be done in this order, by the way
    ld a, $80
    ldh [rNR52], a      ; Enable sound
    ; As an aside, observe the "ldh" here instead of "ld"
    ; All sound registers are in $FF00-$FFFF RAM range, and "ldh" is faster than "ld"
    ; So when accessing HRAM, use "ldh"
    ; https://rgbds.gbdev.io/docs/v0.8.0/gbz80.7#LDH__n16_,A
    ld a, $77
    ldh [rNR50], a      ; Turn off VIN
    ld a, $FC
    ldh [rNR51], a      ; Enable S01 and S02

    xor a                   ; This will set register A to zero, faster than doing "ld a, $00"
    ld [rNR41], a           ; FF20 noise channel length timer https://gbdev.io/pandocs/Audio_Registers.html#ff20--nr41-channel-4-length-timer-write-only
    ld [rNR42], a           ; FF21 noise channel envelope https://gbdev.io/pandocs/Audio_Registers.html#ff21--nr42-channel-4-volume--envelope
    ld [rNR43], a           ; FF22 frequency and randomness https://gbdev.io/pandocs/Audio_Registers.html#ff22--nr43-channel-4-frequency--randomness
    ld [rNR44], a           ; FF23 noise control (trigger and length enable) https://gbdev.io/pandocs/Audio_Registers.html#ff22--nr43-channel-4-frequency--randomness
    
    ; Keypad state variables in Work RAM. Look at the end of the file for declarations
    ld [wCurKeys], a        ; Current key init
	ld [wNewKeys], a        ; New key init
    ld [wPreviousKeys], a   ; Previous key init

; MAIN
MainLoop:
    call UpdateKeys         ; Update the key states
    call CheckKeysPLayMode  ; Check the play mode
    jp MainLoop             ; Jump back and do the main loop again
; END MAIN

;;;;;; ROUTINES ;;;;;;

; Wait for Vertical Blank
WaitVBlank:
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
Memcpy:
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

; Clear the background
ClearBg:
    xor a               ; Turn a into 0
    ld [rLCDC], a       ; Load a(0) into rLCDC, bit 7 = on/off Disable display
    ld b, $04           ; We will write $0400 (1024) bytes
    ld c, $00
    ld hl, $9800        ; We will be writing to the BG tile map
.bg_reset_loop:
    ld a, $00           ; 0th is the blank tile
    ld [hli], a         ; Store one byte in the destination
    ; The same caveat applies as in memcpy
    dec bc              ; Decrement the counter
    ld a, b
    or c
    jr nz, .bg_reset_loop ; Loop until bc is zero
    ld a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJON
    ld [rLCDC], a
    ret

; Update graphics
SetSwitchDisplay:
    ld hl, $98E7        ; On screen position memory location switch upper part
    ld a, $01           ; Tile number 1, see tiles below
    ld [hl], a
    ld hl, $9907        ; The position under the above on screen, switch lower part
    ld a, $03           ; Tile number 3 
    ld [hl], a
    ret

; Code from the GB ASM Tutorial https://gbdev.io/gb-asm-tutorial/
UpdateKeys:
    ; Poll half the controller
    ld a, P1F_GET_BTN
    call .onenibble
    ld b, a         ; B7-4 = 1; B3-0 = unpressed buttons

    ; Poll the other half
    ld a, P1F_GET_DPAD
    call .onenibble
    swap a          ; A3-0 = unpressed directions; A7-4 = 1
    xor a, b        ; A = pressed buttons + directions
    ld b, a         ; B = pressed buttons + directions

    ; And release the controller
    ld a, P1F_GET_NONE
    ldh [rP1], a

    ; Combine with previous wCurKeys to make wNewKeys
    ld a, [wCurKeys]
    xor a, b        ; A = keys that changed state
    and a, b        ; A = keys that changed to pressed
    ld [wNewKeys], a
    ld a, b
    ld [wCurKeys], a
    ret
.onenibble
    ldh [rP1], a    ; switch the key matrix
    call .knownret  ; burn 10 cycles calling a known ret
                    ; As an aside, the above tripped me up, I thought 10 cycles meant 10 loops
                    ; but that is not the case.
                    ; The above burns CPU cycles. It is a "call", so the "ret" in
                    ; .knownret ends up on the next line. 
    ldh a, [rP1]    ; Ignore value while waiting for the key matrix to settle
    ldh a, [rP1]
    ldh a, [rP1]    ; This read counts
    or a, $F0       ; A7-4 = 1; A3-0 = unpressed keys
                    ; Now fall through to ret which returns from where the "UpdateKeys" is called
.knownret
    ret

; Check the key pad in play mode
CheckKeysPLayMode:
    ld a, [wPreviousKeys]       ; Load previous state of the keys into register a
	and a, PADF_A               ; AND the value in reg a with PADF_A(which is $01, see hardware.inc)
	jp nz, .previousAPressed    ; If no bits in reg a match PADF_A the zero flag is raised.(A button not pressed earlier)
                                ; so if A button was pressed earlier we jump to .previousAPressed...
.previousANotPressed            ; ...or we fall through to here
    ld a, [wCurKeys]            ; Load current keys into reg a
    and a, PADF_A               ; Check as explained above
    ret z                       ; A button was not pressed and was not previously pressed so we return
    ld a, [wCurKeys]            ; Load a with current keys again because a is trashed after AND operation
    ld [wPreviousKeys], a       ; A button pressed for the first time, now save in previous keys "variable"
    call HandlePressA
    ret                          
.previousAPressed               ; Now to check if the A button is released as in previously pressed and now released
    ld a, [wCurKeys]
    and a, PADF_A
    ret nz                      ; Still pressing, return from routine
    call HandleReleaseA         ; A button is released, now call routine for when this happens
    xor a                       ; Turn a into 0
    ld [wPreviousKeys], a       ; Reset previous keys
    ret

; Handle A button press
HandlePressA:
    ld a, $F8       ; Max volume
    ld [rNR42], a   ; This is where we update noise volume https://gbdev.io/pandocs/Audio_Registers.html?search=#ff21--nr42-channel-4-volume--envelope
    ld a, $80       ; Retrigger noise channel
    ld [rNR44], a   
    call WaitVBlank ; Wait for VBlank...
    call SwitchToOn ; ...then update screen graphics
    ret

; Handle release of A button
HandleReleaseA:
    ld a, $08               ; Volume zero
    ld [rNR42], a 
    ld a, $80               ; Retrigger noise channel
    ld [rNR44], a
    call WaitVBlank         ; Wait for VBlank
    call SetSwitchDisplay   ; Update graphics to the "button off look"
    ret

; Handle Graphics
SwitchToOn:
    ld hl, $98E7    ; Location of "top of the button" 
    ld a, $03       ; Tile 3
    ld [hl], a
    ld hl, $9907    ; Location of "bottom of the button"
    ld a, $02       ; Tile 2
    ld [hl], a
    ret

Tiles:
    ; Tile 0
	dw `00000000 ; The blank tile
	dw `00000000 ; Backtick and the one of 0,1,2,3 for graphics. `01012323’ is equivalent to ‘$0F55’.
	dw `00000000 ; https://rgbds.gbdev.io/docs/v0.8.0/rgbasm.5#Numeric_formats
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
    ; Tile 1
    dw `33333333 ; Top tile empty look for the on/off switch
	dw `30000003
	dw `30000003
	dw `30000003
	dw `30000003
	dw `30000003
	dw `30000003
	dw `30000003
    ; Tile 2
    dw `30000003 ; Bottom tile empty look for the on/off switch
	dw `30000003
	dw `30000003
	dw `30000003
	dw `30000003
	dw `30000003
	dw `30000003
	dw `33333333
    ; Tile 3
    dw `33333333 ; Top tile button look for the on/off switch
	dw `32222223
	dw `32222223
	dw `32222223
	dw `32222223
	dw `32222223
	dw `32222223
	dw `32222223
    ; Tile 4
    dw `32222223 ; Bottom tile button look for the on/off switch
	dw `32222223
	dw `32222223
	dw `32222223
	dw `32222223
	dw `32222223
	dw `32222223
	dw `33333333
TilesEnd:

SECTION "merz_vars", wram0      ; This is work RAM
; Button states
wCurKeys: db            ; Current keys pressed
wNewKeys: db            ; Keys changed this frame
wPreviousKeys: db       ; Keys that is already pressed

; Noise channel variables (Placeholder not yet used)
wAmplitude: ds 1        ; Amplitude 
wClockShift: ds 1       ; Clockshift
wLsfrWidth: ds 1        ; LSFR width
wClockDivider: ds 1     ; Clock Divider