# Version 1
This is the first simple version of Merzboy.

## Prerequisites
If you are here to learn more RGBDS assembly, I salute you! Assembly programming is a lot of fun. This project is not intended for the complete newbie. Rather, it fits somewhere between GB ASM Tutorial part 1 and 2. Go through [Part 1](https://gbdev.io/gb-asm-tutorial/part1/setup.html) before you start here. I would also recommend that if you, like me, come from a traditional web/software developer background and have spent your time in the higher abstraction layers, you should go and look at Ben Eater's YouTube video tutorial about how a CPU is made from scratch. It is the best and most accessible introduction to how computers work, in my opinion. I also highly recommend GBDK-2020 which uses C and is a lot easier to get started with Game Boy development if you find assembly to be to hard to grasp in the beginning. Then you can back to asm later. I started that way.

## Merzboy
Merzboy is an application intended for experimental noise music. It only uses the noise channel of the Game Boy to make noise. This project also doubles as a tutorial on RGBDS assembly language. The application is really simplistic and "raw" and I hope it will be of some help for people starting out with assembly programming, which is very hard in the beginning.

## About this version
This little program displays a button, which you control by pressing the A button on a Game Boy (or in an emulator). When doing so, the noise channel's volume is set to full and emits a manually set noise sound. That's it.

## Notes
I try to comment each line or at least every new concept. When a concept appears, like xor a (the same as doing ld a, 0), I try to give a brief explanation. When I started learning assembly language, I got caught up on a lot of small issues, and hopefully, I have written them down here so maybe someone who also gets stuck can get unstuck a bit faster.