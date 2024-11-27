# Version 1
This is the MVP if you want to be all tech-bro-y about it.

## Prerequisites
If you are here to learn more RGBDS assembly, I salute you! It is a lot of fun. This project is not intended for the complete newbie. Rather, it fits somewhere between GB ASM Tutorial part 1 and 2. Go through that one before you look here. I would also recommend that if, like me, come from a traditional web programmer background and have spent your time in the higher abstraction layers, you should go and look at Ben Eater's YouTube video tutorial about how a CPU is made from scratch. It is the best and most accessible introduction to how computers work, in my opinion.

## About this version
This little program displays a button, which you control by pressing the A button on a Game Boy (or in an emulator). When doing so, the noise channel's volume is set to full and emits a manually set noise sound. That's it. I leave it to you to copy the hardware.inc and Makefile here if you want to build it.

## Notes
I try to comment each line or at least every new concept. When a concept appears, like xor a (the same as doing ld a, 0), I try to give a brief explanation. When I started learning assembly language, I got caught up on a lot of small issues, and hopefully, I have written them down here so maybe someone who also gets stuck can get the answer a bit faster.