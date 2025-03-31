INCLUDE "../../includes/hardware.inc" ; Include the definitions from this community-maintained classic

SECTION "Header", ROM0[$100]; Mandatory GB stuff
    jp EntryPoint
    ds $150 - @, 0          ; Make room for the header

EntryPoint:                 ; Global label https://rgbds.gbdev.io/docs/master/rgbasm.5#Labels
    call WaitVBlank         ; Wait for Vertical Blank call
    xor a                   ; Turns register a into 0, same as doing "ld a, 0" but faster
    ld [rLCDC], a           ; Load a(now 0) into rLCDC, bit 7 = on/off (disable display)
    
    ; Copy the tile data now that the LCD is turned off
    ld de, Tiles            ; See "Tiles" further down, it's a label in code but only a memory location in the machine
    ld hl, $9000            ; Place where the GB tiles usually live in memory
    ld bc, TilesEnd - Tiles ; TilesEnd is also just a number; hence BC now contains the number of tiles to copy
    call Memcpy             ; See the Memcpy routine down below

    ld b, 160               ; Loop counter
    ld hl, _OAMRAM

ClearOam:
    ld [hli], a             ; Load value of A into memory address of HL and post-increment HL https://rgbds.gbdev.io/docs/v0.8.0/gbz80.7#LD__HLI_,A
    dec b                   ; Decrease loop counter
    jp nz, ClearOam         ; If B is not zero, loop again
                            ; If zero flag is set, fall through
    call ClearBg            ; Clear the background
    call WaitVBlank         ; ClearBg puts LCD on again so we wait for VBlank here
    ; During the first (blank) frame, initialize display registers
    ld a, %11100100
    ld [rBGP], a
    ld a, %11100100
    ld [rOBP0], a

    call SetSwitchDisplay   ; Show the on/off switch
    call SetRandManualSwitchDisplay ; Show the random or manual setting button
    call MainTileSetup      ; Main page tile setup(atm the only page)

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

    ; The state of the "sound" of the noise channel
    ld [wClockShift], a     ; Clockshift state kept here
    ld [wLsfrWidth], a      ; LSFR width state kept here
    ld [wClockDivider], a   ; Clock Divider state kept here

    ; Keypad state variables in Work RAM. Look at the end of the file for declarations
    ld [wCurKeys], a        ; Current key init
    ld [wNewKeys], a        ; New key init
    ld [wPreviousKeys], a   ; Previous key init

    ; State of the "play mode" as I call it. For now either "random" or "manual"
    ld [wPlayMode], a   ; manual = 0, random = 1
    ; Switch mode between Kill Switch or On/Off mode
    ld [wSwitchMode], a ; on/off = 0, kill switch = 1

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
.bg_reset_loop:         ; Local label https://rgbds.gbdev.io/docs/master/rgbasm.5#Labels
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

; Main page tile setup
MainTileSetup:
    ; How to find the map address to put tiles in?
    ; I use bgb emulator, right click->other->VRAM viewer->BG Map tab
    ; Hover over the tile you are interested in and see the "Map address" on the right
    ld hl, $98C6        ; On screen position map address for RA tile in RAND sign
    ld a, $05           ; Tile number 5
    ld [hli], a         ; Just inc HL here for next map address
    ld a, $06           ; Tile number 6
    ld [hli], a
    ld a, $07
    ld [hl], a
    ld hl, $9926        ; Manual starts here
    ld a, $08
    ld [hli], a
    inc a               ; Increase a for next tile
    ld [hli], a
    inc a
    ld [hli], a
    inc a
    ld [hl], a
    ld hl, $98CD        ; ON starts here
    ld a, $0C           ; Tile 12
    ld [hli], a
    inc a
    ld [hl], a
    ld hl, $992D        ; OFF starts here
    ld a, $0E           ; Tile 14
    ld [hli], a
    inc a
    ld [hl], a
    ld hl, $9885        ; Kill Switch "switch" starts here
    ld a, $10           ; Tile 16
    ld [hli], a
    inc a
    ld [hli], a
    ld a, $14           ; Tile 20 On/Off sign
    ld [hli], a
    inc a
    ld [hl], a
    ld hl, $9883        ; KS sign starts here
    ld a, $16           ; Tile 22 KS sign
    ld [hli], a
    inc a
    ld [hl], a
    ret

; Update graphics when pressing A button
SetSwitchDisplay:
    ld hl, $98ED        ; On screen position memory location switch upper part
    ld a, $01           ; Tile number 1, see tiles below
    ld [hl], a
    ld hl, $990D        ; The position under the above on screen, switch lower part
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
.previousANotPressed            ; ...or we fall through to here, the label is pointless here, just for clarity
    ld a, [wCurKeys]            ; Load current keys into reg a
    and a, PADF_A               ; Check as explained above
    jp z, .checkB               ; A button was not pressed and was not previously pressed so continue
    ld a, [wCurKeys]            ; Load a with current keys again because a is trashed after AND operation
    ld [wPreviousKeys], a       ; A button pressed for the first time, now save in previous keys "variable"
    ld a, [wSwitchMode]         ; Check the "switch mode"
    cp 0
    jr nz, .goAKSMode           ; Kill Switch mode if wSwitchMode = 1
    call HandlePressAOnOffMode
    ret
.goAKSMode
    call HandlePressAKSMode     ; Goto KS mode
    ret
.previousAPressed               ; Now to check if the A button is released as in previously pressed and now released
    ld a, [wCurKeys]
    and a, PADF_A
    ret nz                      ; Still pressing, return from routine (nz means zero flag not raised)
    ld a, [wSwitchMode]         ; Check the "switch mode"
    cp 0
    jr nz, .goAKSModeRelease
    call HandleReleaseAOnOffMode; A button is released, now call routine for when this happens
    xor a                       ; Turn a into 0
    ld [wPreviousKeys], a       ; Reset previous keys
    ret
.goAKSModeRelease
    call HandleReleaseAKSMode
    xor a                       ; Turn a into 0
    ld [wPreviousKeys], a       ; Reset previous keys
    ret
; B button
.checkB                         ; Now we do the same dance as above but for B button
    ld a, [wPreviousKeys]
    and a, PADF_B
    jp nz, .previousBPressed
    ld a, [wCurKeys]
    and a, PADF_B
    jp z, .checkRight
    ld a, [wCurKeys]
    ld [wPreviousKeys], a
    ret
.previousBPressed
    ld a, [wCurKeys]
    and a, PADF_B
    ret nz
    call HandlePressB
    xor a
    ld [wPreviousKeys], a
    ret
; RIGHT on pad
.checkRight                 ; The Right and Left buttons are easier as the only update
    ld a, [wCurKeys]        ; on the down press. No release check is necessary.
    and a, PADF_RIGHT
    jp z, .checkLeft
    call HandlePressRight
    ld a, [wCurKeys]
    ld [wPreviousKeys], a
    ret
; LEFT on pad
.checkLeft
    ld a, [wCurKeys]
    and a, PADF_LEFT
    ret z                   ; done go home
    call HandlePressLeft
    ld a, [wCurKeys]
    ld [wPreviousKeys], a
    ret

; Handle A button press in On/Off mode
HandlePressAOnOffMode:
    ; For simplicity we only use one of the noise channels variables(as they are randomized on the release of the A button)
    ; We will use the others later
    ld a, [wPlayMode]   ; Load playmode
    cp a, 0             ; ComPare value in register a to 0 https://rgbds.gbdev.io/docs/v0.8.0/gbz80.7#CP_A,n8
    jr z, .skipRandom   ; If a == 0 skip the random part
    ld a, [wClockShift] ; Load the random value in wClockShift into a 
    ld [rNR43], a       ; And pass that to the noise "frequency & randomness" register 
.skipRandom
    ld a, $F8           ; Max volume
    ld [rNR42], a       ; This is where we update noise volume https://gbdev.io/pandocs/Audio_Registers.html?search=#ff21--nr42-channel-4-volume--envelope
    ld a, $80           ; Retrigger noise channel
    ld [rNR44], a   
    call WaitVBlank     ; Wait for VBlank...
    call SwitchToOn     ; ...then update screen graphics
    ret

; Handle release of A button in On/Off mode
HandleReleaseAOnOffMode:
    ld a, $08               ; Volume zero
    ld [rNR42], a 
    ld a, $80               ; Retrigger noise channel
    ld [rNR44], a
    call WaitVBlank         ; Wait for VBlank
    call SetSwitchDisplay   ; Update graphics to the "button off look"
    call Rand               ; Let's generate a pseudo random number
    ld a, b                 ; Use a here to get stuff into RAM
    ld [wClockShift], a     ; Load random byte into clock shift state
    ld [wLsfrWidth], a      ; Load random byte into LSFR width state
    ld a, c                 ; Use the other random byte in c to showcase that it is also random now
    ld [wClockDivider], a   ; Load random byte in b to where we keep clock divider state
    ; You can't load directly from b or c into a memory location like "ld [wClockShift], b" unfortunatly
    ret

; Handle A button press in Kill Switch(KS) mode
HandlePressAKSMode:
    ld a, [wPlayMode]       ; Load playmode
    cp a, 0                 ; ComPare value in register a to 0 https://rgbds.gbdev.io/docs/v0.8.0/gbz80.7#CP_A,n8
    jr z, .skipRandom       ; If a == 0 skip the random part
    ld a, [wClockShift]     ; Load the random value in wClockShift into a
    ld [rNR43], a           ; And pass that to the noise "frequency & randomness" register
.skipRandom
    ld a, $08               ; Turn off volume when in KS mode
    ld [rNR42], a           ; This is where we update noise volume https://gbdev.io/pandocs/Audio_Registers.html?search=#ff21--nr42-channel-4-volume--envelope
    ld a, $80               ; Retrigger noise channel
    ld [rNR44], a
    call WaitVBlank         ; Wait for VBlank...
    call SetSwitchDisplay   ; ...then update screen graphics to on mode as we are in KS mode
    ret

; Handle release of A button in Kill Switch(KS) mode
HandleReleaseAKSMode:
    ld a, $F8               ; Max volume in KS mode
    ld [rNR42], a
    ld a, $80               ; Retrigger noise channel
    ld [rNR44], a
    call WaitVBlank         ; Wait for VBlank
    call SwitchToOn         ; Update graphics to the "button off look"
    call Rand               ; Let's generate a pseudo random number
    ld a, b                 ; Use a here to get stuff into RAM
    ld [wClockShift], a     ; Load random byte into clock shift state
    ld [wLsfrWidth], a      ; Load random byte into LSFR width state
    ld a, c                 ; Use the other random byte in c to showcase that it is also random now
    ld [wClockDivider], a   ; Load random byte in b to where we keep clock divider state
    ; You can't load directly from b or c into a memory location like "ld [wClockShift], b" unfortunatly
    ret

; Press B handle routine
; This determines if a A button press will be picked randomly
; or if it will be the same as the last setting in the noise channel.
HandlePressB:
    ld a, [wPlayMode]                   ; Are we in manual or random mode
    cp 0
    jp z, .changeToOne
    xor a                               ; Change to manual mode
    ld [wPlayMode], a
    call WaitVBlank
    call SetRandManualSwitchDisplay     
    ret
.changeToOne
    ld a, 1
    ld [wPlayMode], a                   ; Set to random
    call WaitVBlank
    call SwitchToRandom
    ret

HandlePressRight:
    ld a, [wSwitchMode]     ; Are we in on/off or KS mode?
    cp 0
    ret z                   ; Already in on/off mode farewell
    xor a                   ; Change to on/off mode
    ld [wSwitchMode], a
    call WaitVBlank
    call SetOnOffKSDisplay
    ret

HandlePressLeft:
    ld a, [wSwitchMode]      ; Are we in on/off or KS mode?
    cp 0
    ret nz                   ; Already in on/off mode good buy
    ld a, 1                  ; Change to on/off mode
    ld [wSwitchMode], a
    call WaitVBlank
    call SetToKSDisplay
    ret

; Handle graphics when pressing A button
SwitchToOn:
    ld hl, $98ED    ; Location of "top of the button"
    ld a, $03       ; Tile 3
    ld [hl], a
    ld hl, $990D    ; Location of "bottom of the button"
    ld a, $02       ; Tile 2
    ld [hl], a
    ret

; Update graphics when pressing B button
SetRandManualSwitchDisplay:  ; Javaesque naming here sry bout that
    ld hl, $98E6        ; On screen position memory location switch upper part
    ld a, $01           ; Tile number 1, see tiles below
    ld [hl], a
    ld hl, $9906        ; The position under the above on screen, switch lower part
    ld a, $03           ; Tile number 3
    ld [hl], a
    ret

; Handle graphics when pressing B button
SwitchToRandom:
    ld hl, $98E6    ; Location of "top of the button"
    ld a, $03       ; Tile 3
    ld [hl], a
    ld hl, $9906    ; Location of "bottom of the button"
    ld a, $02       ; Tile 2
    ld [hl], a
    ret

; Set the switch to the right side on the OO/KS switch when i on/off mode
SetOnOffKSDisplay:
    ld hl, $9885        ; Kill Switch "switch" starts here
    ld a, $10           ; Tile 16
    ld [hli], a
    inc a
    ld [hl], a
    ret

; Set the switch to the left side on the OO/KS switch when i KS mode
SetToKSDisplay:
    ld hl, $9885        ; Kill Switch "switch" starts here
    ld a, $12           ; Tile 18
    ld [hli], a
    inc a
    ld [hl], a
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
    ; Tile 5     ; Here are the tiles for the signs
    dw `33300333 ; RA
    dw `30300300
    dw `33300333
    dw `30030300
    dw `00000000
    dw `00000000
    dw `00000000
    dw `00000000
    ; Tile 6
    dw `30300303 ; AND
    dw `30330303
    dw `30303303
    dw `30300303
    dw `00000000
    dw `00000000
    dw `00000000
    dw `00000000
    ; Tile 7
    dw `33000000 ; D
    dw `00300000
    dw `00300000
    dw `33300000
    dw `00000000
    dw `00000000
    dw `00000000
    dw `00000000
    ; Tile 8
    dw `00000000 ; MA
    dw `00000000
    dw `00000000
    dw `00000000
    dw `32230333
    dw `33330300
    dw `30030333
    dw `30030300
    ; Tile 9
    dw `00000000 ; ANU
    dw `00000000
    dw `00000000
    dw `00000000
    dw `30300303
    dw `30330303
    dw `30303303
    dw `30300303
    ; Tile 10
    dw `00000000 ; UA
    dw `00000000
    dw `00000000
    dw `00000000
    dw `00303333
    dw `00303003
    dw `00303333
    dw `33303003
    ; Tile 11
    dw `00000000 ; L
    dw `00000000
    dw `00000000
    dw `00000000
    dw `03000000
    dw `03000000
    dw `03000000
    dw `03333000
    ; Tile 12
    dw `03300300 ; ON
    dw `30030330
    dw `30030303
    dw `03300300
    dw `00000000
    dw `00000000
    dw `00000000
    dw `00000000
    ; Tile 13
    dw `30000000 ; N
    dw `30000000
    dw `30000000
    dw `30000000
    dw `00000000
    dw `00000000
    dw `00000000
    dw `00000000
    ; Tile 14
    dw `00000000 ;OF
    dw `00000000
    dw `00000000
    dw `00000000
    dw `03300333
    dw `30030300
    dw `30030330
    dw `03300300
    ; Tile 15
    dw `00000000 ; FF
    dw `00000000
    dw `00000000
    dw `00000000
    dw `30333300
    dw `00300000
    dw `00330000
    dw `00300000
    ; Tile 16
    dw `00000000 ; Toggle Kill Switch left empty
    dw `00333333
    dw `03000000
    dw `30000000
    dw `30000000
    dw `03000000
    dw `00333333
    dw `00000000
    ; Tile 17
    dw `00000000 ; Toggle Kill Switch left full
    dw `33333300
    dw `13222230
    dw `22221223
    dw `22222223
    dw `12222230
    dw `33333300
    dw `00000000
    ; Tile 18
    dw `00000000 ; Toggle Kill Switch left full
    dw `00333333
    dw `03222221
    dw `32212222
    dw `32222222
    dw `03222221
    dw `00333333
    dw `00000000
    ; Tile 19
    dw `00000000 ; Toggle Kill Switch right empty
    dw `33333300
    dw `00000030
    dw `00000003
    dw `00000003
    dw `00000030
    dw `33333300
    dw `00000000
    ; Tile 20
    dw `00330030 ; KS toggle sign on/off
    dw `03003033
    dw `03003030
    dw `00330030
    dw `00330033
    dw `03003030
    dw `03003033
    dw `00330030
    ; Tile 21
    dw `03000000 ; End of on/off sign
    dw `03000000
    dw `33000000
    dw `03000000
    dw `33033330
    dw `00030000
    dw `00033000
    dw `00030000
    ; Tile 22
    dw `00000000 ; KS Sign
    dw `00000000
    dw `00000030
    dw `00000033
    dw `00000030
    dw `00000030
    dw `00000000
    dw `00000000
    ; Tile 23
    dw `00000000 ; KS sign end
    dw `00000000
    dw `30003330
    dw `00033300
    dw `30003330
    dw `03033300
    dw `00000000
    dw `00000000
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

; Play mode state
wPlayMode: ds 1         ; 0 = manual, 1 = random
wSwitchMode: ds 1       ; 0 = on/off, 1 = kill switch

; Pseudo rand state see routine above
randstate:: ds 4 ; Also observe the exported symbol double colon :: read about them here https://rgbds.gbdev.io/docs/master/rgbasm.5#Exporting_and_importing_symbols
; Not necessary to export here because everything is in one file, but will be useful when
; you split code over multiple files.