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
