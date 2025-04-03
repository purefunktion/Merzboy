Version 6
The background was not handled as it usually is in this project. I had somewhat of a hard time grasping the concept of tiles and tilemaps when I started out, and in the beginning of this project, there were only 5 tiles. Now the project follows the conventional approach of providing a tilemap that is copied into the background layer. This takes up more space but is a more straightforward and convenient way of working with backgrounds. Check out the new tilemap in the `tiles.asm` file and the new subroutine `CopyTilemapTo` in the `merzboy.asm` file. Look in version 5 and compare to the old `ClearBg` and `MainTileSetup`

There are some fun bit-twiddling operations in the `ShowNoiseRandomnessSettings` section of the code now. Bit shifting, masking, checking, and setting specific bits in a byte.

Also introduced the def equ directives now to have definitions in one place so it is easier to change in just one place.