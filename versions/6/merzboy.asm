INCLUDE "../../includes/hardware.inc" ; Include the definitions from this community-maintained classic

SECTION "Header", ROM0[$100]; Mandatory GB stuff
    jp EntryPoint
    ds $150 - @, 0          ; Make room for the header

; definitions
; https://rgbds.gbdev.io/docs/v0.7.0/rgbasm.5#Numeric_constants
def CS10PLACE equ $99C3     ; memory address for the clock shift tens numbers tile on background
def CS1PLACE equ $99C4      ; same as above but for ones
def LSFRWIDTHPLACE equ $99CA; LSFR width tile memory address
def CLDIVPLACE equ $99CF    ; and clock divider tile place

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

    call CopyTilemapTo      ; copy the tiles from the tilemap to the background
    call ShowNoiseRandomnessSettings ; show the settings in the FF22 registry
    ld a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJON   ; turn on screen
    ld [rLCDC], a
    call WaitVBlank         ; ClearBg puts LCD on again so we wait for VBlank here
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

; Copy the tile map to the background
; see tiles.asm file
CopyTilemapTo:
   ; Copy the tilemap
    ld de, Tilemap                  ; see the tiles.asm file
    ld hl, $9800                    ; We will be writing to the BG tile map
    ld bc, TilemapEnd - Tilemap     ; this is how many iterations
copyTilemap:                        ; Local label https://rgbds.gbdev.io/docs/master/rgbasm.5#Labels
    ld a, [de]                      ; start at first tilemap memory location
    ld [hli], a                     ; put in bg screen memory and increment hl
    inc de                          ; increment de for next tile map address
    dec bc                          ; count down number of iterations
    ld a, b                         ; check if we reached the end
    or a, c
    jp nz, copyTilemap              ; if not zero in both b and c goto copyTilemap label
    ret                             ; done return to base!

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
    call ShowNoiseRandomnessSettings
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
    call SetSwitchDisplay   ; ...then update screen graphics to On/Off mode as we are in KS mode
    call ShowNoiseRandomnessSettings
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
    ret nz                   ; Already in on/off mode good bye
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

; Update graphics when pressing A button
SetSwitchDisplay:
    ld hl, $98ED        ; On screen position memory location switch upper part
    ld a, $01           ; Tile number 1, see tiles below
    ld [hl], a
    ld hl, $990D        ; The position under the above on screen, switch lower part
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

; This will display what value the noise registry FF22 currently holds
; Displayed as normal decimal numbers.
; There are three calls here and this is not optimal as each call costs 6 cycles.
; But this is more clear to read I think
ShowNoiseRandomnessSettings:
    call ShowClockShift    ; we will begin with the "Clock shift" part of rNR43
    call ShowLFSRwidth
    call ShowClockdivider
    ret

; Display the clock shift number in noise reg FF22 — NR43: Channel 4 frequency & randomness
ShowClockShift:
    ld a, [rNR43]       ; get values from noise regestry controlling randomness
    srl a               ; Shift Right Logically register a.
    srl a
    srl a
    srl a               ; the second nibble as a number
    ld b, a
    cp a, 10
    jr nc, .tenAndAbove ; will carry if a < 10, down in negative land
    jr z, .tenAndAbove  ; if 10 we need to jump as well
    ld a, b             ; restore a to the digit
    add a, $18          ; 18 is the 0 digit, add to get to the right digit
    ld hl, CS1PLACE     ; address where we show the "Clock shift" number.
                        ; CS1PLACE is definied in the beginning of the file
    ld [hl], a
    ld a, $00           ; Clear the 10ers
    ld hl, CS10PLACE
    ld [hl], a
    ret
.tenAndAbove
    ld a, b
    sub a, 10           ; get the digit lower than ten in like 14(get the 4)
    add a, $18          ; 18 is the 0 digit
    ld hl, CS1PLACE
    ld [hl], a
    ld a, $19           ; 19 is the 1 digit
    ld hl, CS10PLACE
    ld [hl], a
    ret

; Display the LSFR width 
ShowLFSRwidth:
    ld a, [rNR43]       ; get values from noise registry controlling randomness
    bit 3, a            ; BIT u3,r8 Test bit u3(0-7) in register r8, set the zero flag if bit not set.
    jr nz, .shortMode
    ld a, $18           ; 0 digit
    ld hl, LSFRWIDTHPLACE
    ld [hl], a
    ret
.shortMode              ; it is called "short mode" in GB pandocs
    ld a, $19           ; 1 digit
    ld hl, LSFRWIDTHPLACE
    ld [hl], a
    ret

; Display the clock~} divider
ShowClockdivider:
    ld a, [rNR43]
    and a, $0F          ; Mask out the higher (left) nibble, i.e., set the left nibble to all zeros
    res 3, a            ; RES u3,r8 Set bit u3 in register r8 to 0. Only the three right most bits control the clock divider
    add a, $18          ; 18 is the 0 digit, add to get to the right digit
    ld hl, CLDIVPLACE
    ld [hl], a
    ret

INCLUDE "tiles.asm"     ; Include the tiles here from the tiles.asm file

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
; you split code over multiple files(see utils.asm).