# Version 5

So the file `merzboy.ams` was more than 700 lines long in the previous version, and it started to become annoying to do all that scrolling. So this version is about splitting the code between files. One way to do that is with the "INCLUDE" syntax. This will process the included file and continue on the next line when done, like pasting source code from another file. [Read the include documentation here](https://rgbds.gbdev.io/docs/v0.9.1/rgbasm.5#Including_other_source_files).

Another way to include code is to [export](https://rgbds.gbdev.io/docs/v0.9.1/rgbasm.5#Exporting_and_importing_symbols) the symbols and then include the file in the Makefile and link them. Check out the new Makefile with the `utils.asm` added in "SOURCES."