INCLUDE "../../includes/hardware.inc"      ; Include the definitions from this community maintained classic

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

    xor a                   ; zero out a register again
    ld b, 160               ; Loop counter $A0 from FE00 -> FEA0
    ld hl, _OAMRAM          ; Object Attribute Memory https://gbdev.io/pandocs/OAM.html#object-attribute-memory-oam
ClearOam:
    ld [hli], a             ; Load value of A into memory address of HL and post-increment HL https://rgbds.gbdev.io/docs/v0.8.0/gbz80.7#LD__HLI_,A
    dec b                   ; Decrease loop counter
    jp nz, ClearOam         ; If B is not zero, loop again
                            ; If zero flag is set, fall through
    call CopySprites        ; Copy sprites to where OAM objects live in memory

    ; Let's load a sprite on to the screen
    ld hl, _OAMRAM
    ld a, 124 + 16          ; the "+16" here is because the vertical position on screen starts at 16
                            ; Read more here https://gbdev.io/pandocs/OAM.html
    ld [hli], a
    ld a, 32 + 8            ; Same as above but here it is "+8" for the x, horizontal position on screen
    ld [hli], a
    ld a, 0
    ld [hli], a
    ld [hli], a

    call CopyTilemapTo      ; copy the tiles from the tilemap to the background
    xor a                   ; Make a = 0
    ; The state of the "sound" of the noise channel
    ; Set here beacuase ShowNoiseRandomnessSettings is dependent of the values
    ld [wClockShift], a     ; Clockshift state kept here
    ld [wLsfrWidth], a      ; LSFR width state kept here
    ld [wClockDivider], a   ; Clock Divider state kept here
    ld [wRandomByte], a     ; This one is used to keep track of byte in rNR43

    call ShowNoiseRandomnessSettings ; Show the settings in the FF22 registry
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
    ldh [rNR50], a          ; Turn off VIN
    ld a, $FC
    ldh [rNR51], a          ; Enable S01 and S02

    xor a                   ; This will set register A to zero, faster than doing "ld a, $00"
    ld [rNR41], a           ; FF20 noise channel length timer https://gbdev.io/pandocs/Audio_Registers.html#ff20--nr41-channel-4-length-timer-write-only
    ld [rNR42], a           ; FF21 noise channel envelope https://gbdev.io/pandocs/Audio_Registers.html#ff21--nr42-channel-4-volume--envelope
    ld [rNR43], a           ; FF22 frequency and randomness https://gbdev.io/pandocs/Audio_Registers.html#ff22--nr43-channel-4-frequency--randomness
    ld [rNR44], a           ; FF23 noise control (trigger and length enable) https://gbdev.io/pandocs/Audio_Registers.html#ff22--nr43-channel-4-frequency--randomness

    ; Keypad state variables in Work RAM. Look at the end of the file for declarations
    ld [wCurKeys], a        ; Current key init
    ld [wNewKeys], a        ; New key init
    ld [wPreviousKeys], a   ; Previous key init

    ; State of the "play mode" as I call it. For now either "random" or "manual"
    ld [wPlayMode], a   ; manual = 0, random = 1
    ; Switch mode between Kill Switch or On/Off mode
    ld [wSwitchMode], a ; on/off = 0, kill switch = 1
    ; What setting in the noise channel are we pointing at with the arrow sprite
    ld [wArrowNoiseSetting], a ; Start with ClockShift
    ; Place on screen to put the arrow
    ld a, 32
    ld [wArrowXValue], a        ; Place under clock shift values
    ld a, 80
    ld [wArrowXValue + 1], a    ; Place under lsfr width value
    ld a, 120
    ld [wArrowXValue + 2], a    ; Place under clock divider values
    ld a, 128
    ld [wArrowYValue], a        ; All on the same line vertically

; MAIN
MainLoop:
    call WaitVBlank         ; Wait one Vblank so we don't double fire
    call CheckKeysPLayMode  ; Check the play mode
    call UpdateKeys         ; Update the key states
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

; Copy to OAM
CopySprites:
; Copy the paddle tile
    ld de, Sprites
    ld hl, $8000                    ; This is the address of VRAM(Video RAM)
    ld bc, SpritesEnd - Sprites
copySprites:
    ld a, [de]
    ld [hli], a
    inc de
    dec bc
    ld a, b
    or a, c
    jp nz, copySprites
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
    ld a, PADF_A                ; Load a with current keys again because a is trashed after AND operation
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
    jp z, .checkSelect
    ld a, PADF_B
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

; SELECT button
.checkSelect
    ld a, [wPreviousKeys]
    and a, PADF_SELECT
    jp nz, .previousSelectPressed
    ld a, [wCurKeys]
    and a, PADF_SELECT
    jp z, .checkRight
    ld a, PADF_SELECT
    ld [wPreviousKeys], a
    ret
.previousSelectPressed
    ld a, [wCurKeys]
    and a, PADF_SELECT
    ret nz
    call HandlePressSelect
    xor a
    ld [wPreviousKeys], a
    ret

; RIGHT on pad
.checkRight
    ld a, [wPreviousKeys]
    and a, PADF_RIGHT
    jp nz, .previousRightPressed
    ld a, [wCurKeys]
    and a, PADF_RIGHT
    jp z, .checkLeft
    ld a, PADF_RIGHT
    ld [wPreviousKeys], a
    ret
.previousRightPressed
    ld a, [wCurKeys]
    and a, PADF_RIGHT
    ret nz
    call HandlePressRight
    xor a
    ld [wPreviousKeys], a
    ret

; LEFT on pad
.checkLeft
    ld a, [wPreviousKeys]
    and a, PADF_LEFT
    jp nz, .previousLeftPressed
    ld a, [wCurKeys]
    and a, PADF_LEFT
    jp z, .checkUp
    ld a, PADF_LEFT
    ld [wPreviousKeys], a
    ret
.previousLeftPressed
    ld a, [wCurKeys]
    and a, PADF_LEFT
    ret nz
    call HandlePressLeft
    xor a
    ld [wPreviousKeys], a
    ret

; UP on pad
.checkUp
    ld a, [wCurKeys]
    and a, PADF_UP
    jr nz, .curKeyUpPressed
    ld a, [wPreviousKeys]   ; Not currently pressing
    and a, PADF_UP
    jr nz, .releasedUp
    jp .checkDown           ; Not released, not currently pressing go check down btn
.curKeyUpPressed
    ld a, [wPreviousKeys]
    and a, PADF_UP
    ret nz                  ; Still pressing
    ld a, [wPreviousKeys]
    set PADB_UP, a
    ld [wPreviousKeys], a
    ret
.releasedUp
    call HandlePressUp
    ld a, [wPreviousKeys]
    res PADB_UP, a
    ld [wPreviousKeys], a
    ret

; DOWN on pad
.checkDown
    ld a, [wCurKeys]
    and a, PADF_DOWN
    jr nz, .curKeyDownPressed
    ld a, [wPreviousKeys]       ; Not currently pressing
    and a, PADF_DOWN
    jr nz, .releasedDown
    ret                         ; Not released, not currently pressing return
.curKeyDownPressed
    ld a, [wPreviousKeys]
    and a, PADF_DOWN
    ret nz                      ; Still pressing
    ld a, [wPreviousKeys]
    set PADB_DOWN, a
    ld [wPreviousKeys], a
    ret
.releasedDown
    call HandlePressDown
    ld a, [wPreviousKeys]
    res PADB_DOWN, a
    ld [wPreviousKeys], a
    ret


; Handle A button press in On/Off mode
HandlePressAOnOffMode:
    ; For simplicity we only use one of the noise channels variables(as they are randomized on the release of the A button)
    ; We will use the others later
    ld a, [wPlayMode]       ; Load playmode
    cp a, 0                 ; ComPare value in register a to 0 https://rgbds.gbdev.io/docs/v0.8.0/gbz80.7#CP_A,n8
    jr z, .skipRandom       ; If a == 0 skip the random part
    call Rand               ; Let's generate a pseudo random number
    call StoreRandValues    ; Store random values
    ld a, [wRandomByte]     ; Load the random value in wRandomByte into a
    ld [rNR43], a           ; And pass that to the noise "frequency & randomness" register
.skipRandom
    ld a, $F8               ; Max volume
    ld [rNR42], a           ; This is where we update noise volume https://gbdev.io/pandocs/Audio_Registers.html?search=#ff21--nr42-channel-4-volume--envelope
    ld a, $80               ; Retrigger noise channel
    ld [rNR44], a   
    call WaitVBlank         ; Wait for VBlank...
    call SwitchToOn         ; ...then update screen graphics
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
    ret

; Handle A button press in Kill Switch(KS) mode
HandlePressAKSMode:
    ld a, [wPlayMode]       ; Load playmode
    cp a, 0                 ; ComPare value in register a to 0 https://rgbds.gbdev.io/docs/v0.8.0/gbz80.7#CP_A,n8
    jr z, .skipRandom       ; If a == 0 skip the random part
    call Rand               ; Let's generate a pseudo random number
    call StoreRandValues    ; Store random values
    ld a, [wRandomByte]     ; Load the random value in wRandomByte into a
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
    ret

; Store the random values in right format at right places
; b = random value from rand
StoreRandValues:
    ld a, b                 ; Use a here to get stuff into RAM
    ld [wRandomByte], a     ; Store random byte in wRandomByte
    swap a                  ; Swap high and low nibble in reg a
    and $0F                 ; Mask the high nibble, leaving the former high nibble as a number in a
    ld [wClockShift], a     ; And place value in wClockShift
    ld a, [wRandomByte]     ; Load random value to a again
    and $0F                 ; Get rid of high nibble
    srl a                   ; Shift right to get only 4th bit
    srl a
    srl a
    ld [wLsfrWidth], a      ; Store the value in wLsfrWidth
    ld a, [wRandomByte]     ; Load random value to a again
    and $0F                 ; Get rid of high nibble
    res 3, a                ; RES u3,r8 Set bit u3 in register r8 to 0. Only the three right most bits control the clock divider
    ld [wClockDivider], a   ; Store the value in wClockDivider
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

; Handle pressing SELECT button 
HandlePressSelect:
    ld a, [wSwitchMode]     ; Are we in on/off(0) or KS(1) mode?
    cp 0
    jr z, .changeToKillSwitchMode
    xor a                   ; Change to on/off mode
    ld [wSwitchMode], a
    call WaitVBlank
    call SetOnOffKSDisplay
    ret
.changeToKillSwitchMode
    ld a, 1
    ld [wSwitchMode], a     ; Change to kill switch mode
    call WaitVBlank
    call SetToKSDisplay
    ret

; Handle right press
HandlePressRight:
    ld a, [wArrowNoiseSetting]  ; Which setting in NR43 should we go to
    cp 1
    jr z, .goToTwo              ; Equal means we are on 1, goto 2
    jr c, .goToOne              ; Carry means we are on 0, goto 1
.goToZero                       ; Otherwise we are on 2, go around to 0
    xor a
    ld [wArrowNoiseSetting], a
    call DrawArrow
    ret
.goToTwo
    ld a, 2
    ld [wArrowNoiseSetting], a
    call DrawArrow
    ret
.goToOne
    ld a, 1
    ld [wArrowNoiseSetting], a
    call DrawArrow
    ret

; Handle left press
HandlePressLeft:
    ld a, [wArrowNoiseSetting]  ; Which setting in NR43 should we go to
    cp 1
    jr z, .goToZero             ; Equal means we are on 1, goto 0
    jr c, .goToTwo              ; Carry means we are on 0, go around to 2
.goToOne                        ; Otherwise we a are on 2, go to 1
    ld a, 1
    ld [wArrowNoiseSetting], a
    call DrawArrow
    ret
.goToZero
    xor a
    ld [wArrowNoiseSetting], a
    call DrawArrow
    ret
.goToTwo
    ld a, 2
    ld [wArrowNoiseSetting], a
    call DrawArrow
    ret

; Presing up will increase the value currently being selected
HandlePressUp:
    ld a, [wArrowNoiseSetting]  ; Which setting in NR43 should we increase
    cp 1
    jr z, .goToOne
    jr c, .goToZero
.goToTwo
    call IncClockDiv
    jr .done
.goToOne
    call IncLFSRWidth
    jr .done
.goToZero
    call IncClockShift
.done
    ld a, [wSwitchMode]     ; Check the "switch mode"
    cp 0
    jr z, .goKSMode         ; Kill Switch mode if wSwitchMode = 1
.goOnOffMode
    ; no sound
    call ShowNoiseRandomnessSettings
    ret
.goKSMode
    ld a, $80               ; Retrigger noise channel
    ldh [rNR44], a
    call ShowNoiseRandomnessSettings
    ret

; Presing up will decrease the value currently being selected
HandlePressDown:
    ld a, [wArrowNoiseSetting]  ; Which setting in NR43 should we increase
    cp 1
    jr z, .goToOne
    jr c, .goToZero
.goToTwo
    call DecClockDiv
    jr .done
.goToOne
    call DecLFSRWidth
    jr .done
.goToZero
    call DecClockShift
.done
    ld a, [wSwitchMode]         ; Check the "switch mode"
    cp 0
    jr z, .goKSMode           ; Kill Switch mode if wSwitchMode = 1
.goOnOffMode
    ; no sound
    call ShowNoiseRandomnessSettings
    ret
.goKSMode                   ; KS mode, sound is being playes so ...
    ld a, $80               ; ... retrigger noise channel
    ldh [rNR44], a
    call ShowNoiseRandomnessSettings
    ret

; Increase clock divider
IncClockDiv:
    ld a, [wClockDivider]   ; Load clock divider value into a
    cp 7                    ; Max value is 7
    jr z, .doNothing        ; If we are there return
    inc a                   ; Increase by one
    ld [wClockDivider], a   ; Store back into clock divder address
    ld b, a                 ; Save clock divider value in b for now
    ld a, [wRandomByte]     ; Get the random byte used to change the value in rNR43
    and $F8                 ; 0b11111000 mask out everything but the first 3 bits
    or a, b                 ; Combine b with a to save new clock div value
    ld [wRandomByte], a     ; Save back new value in wRandomByte
    ldh [rNR43], a          ; Update the sound in noise reg
.doNothing
    ret

; Increase LSFR width
IncLFSRWidth:
    ld a, [wLsfrWidth]      ; Load lfsr width value into a
    cp 1                    ; Maximum is 1
    jr z, .doNothing        ; If we are there return
    ld a, 1                 ; Load max value of 1
    ld [wLsfrWidth], a      ; Store new value
    ld a, [wRandomByte]     ; Get the random byte used to change the value in rNR43
    set 3, a                ; We know we are going to set here
    ld [wRandomByte], a     ; Save back new value in wRandomByte
    ldh [rNR43], a          ; Update the sound in noise reg
.doNothing
    ret

; Increse the clock shift
IncClockShift:
    ld a, [wClockShift]     ; load clock shift value into a
    cp 15                   ; Maximum is 15
    jr nc, .doNothing       ; if we are there return
    inc a                   ; otherwise increase by one
    ld [wClockShift], a     ; store it back
    swap a                  ; swap high and low nibble
    and a, $F0              ; mask high nibble(former low)
    ld b, a                 ; save in b
    ld a, [wRandomByte]     ; get the random byte used to change the value in rNR43
    and a, $0F              ; mask low nibble
    or a, b                 ; combine high and low nibble
    ld [wRandomByte], a     ; save back new value in wRandomByte
    ldh [rNR43], a          ; and update the sound in noise reg
.doNothing
    ret

; Decrese the clock shift
DecClockShift:
    ld a, [wClockShift]     ; load clock shift value into a
    cp 0                    ; Minimum is 0
    jr z, .doNothing        ; jump if equal here
    dec a                   ; otherwise decrease by one
    ld [wClockShift], a     ; store it back
    swap a                  ; swap high and low nibble
    and a, $F0              ; mask high nibble(former low)
    ld b, a                 ; save in b
    ld a, [wRandomByte]     ; get the random byte used to change the value in rNR43
    and a, $0F              ; mask low nibble
    or a, b                 ; combine high and low nibble
    ld [wRandomByte], a     ; save back new value in wRandomByte
    ldh [rNR43], a          ; Update the sound in noise reg
.doNothing
    ret

; Decrease clock divider
DecClockDiv:
    ld a, [wClockDivider]   ; Load clock divider value into a
    cp 0                    ; Min value is 0
    jr z, .doNothing        ; If we are there return
    dec a                   ; Decrease by one
    ld [wClockDivider], a   ; Store back into clock divder address
    ld b, a                 ; Save clock divider value in b for now
    ld a, [wRandomByte]     ; Get the random byte used to change the value in rNR43
    and $F8                 ; 0b11111000 mask out everything but the first 3 bits
    or a, b                 ; Combine b with a to save new clock div value
    ld [wRandomByte], a     ; Save back new value in wRandomByte
    ldh [rNR43], a          ; Update the sound in noise reg
.doNothing
    ret

; Decrease LSFR width
DecLFSRWidth:
    ld a, [wLsfrWidth]      ; Load lfsr width value into a
    cp 0                    ; Maximum is 1
    jr z, .doNothing        ; If we are there return
    ld a, 0                 ; Load min value of 0
    ld [wLsfrWidth], a      ; Store new value
    ld a, [wRandomByte]     ; Get the random byte used to change the value in rNR43
    res 3, a                ; We know we are going to res here
    ld [wRandomByte], a     ; Save back new value in wRandomByte
    ld [rNR43], a           ; Update the sound in noise reg
.doNothing
    ret

; Draw the position of the arrow to the screen
DrawArrow:
    call WaitVBlank
    ld a, [wArrowNoiseSetting]
    ld hl, wArrowXValue
    add a, l
    ld l, a
    ld a, [hl]
    add a, 8
    ld [_OAMRAM + 1], a
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
; There are three calls here and this is not optimal as each "call" costs 6 cycles.
; But this is more clear to read I think
ShowNoiseRandomnessSettings:
    call ShowClockShift    ; we will begin with the "Clock shift" part of rNR43
    call ShowLFSRwidth
    call ShowClockdivider
    ret

; Display the clock shift number in noise reg FF22 — NR43: Channel 4 frequency & randomness
ShowClockShift:
    ld a, [wClockShift]
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
    ld a, [wLsfrWidth]      ; Get LsfrWidth value
    add a, $18              ; 18 is the 0 digit, add to get to the right digit
    ld hl, LSFRWIDTHPLACE   ; Put in place
    ld [hl], a
    ret

; Display the clock~} divider
ShowClockdivider:
    ld a, [wClockDivider]
    add a, $18          ; 18 is the 0 digit, add to get to the right digit
    ld hl, CLDIVPLACE
    ld [hl], a
    ret

SECTION "merz_vars", wram0      ; This is work RAM
; Button states
wCurKeys: db            ; Current keys pressed
wNewKeys: db            ; Keys changed this frame
wPreviousKeys: db       ; Keys that is already pressed

; Noise channel variables (Placeholder not yet used)
wRandomByte: ds 1       ; Store byte from rand sub routine
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

wArrowNoiseSetting: ds 1    ; What setting in the noise channel are we pointing at
                            ; 0=ClkShift 1=LFSR 2=ClkDiv
wArrowXValue: ds 3          ; The values of X(horizontal) where to place arrow on screen
wArrowYValue: ds 1          ; The value of Y(vertical) where to place arrow on screen