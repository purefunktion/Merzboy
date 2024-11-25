ASM = rgbasm
LINK = rgblink
FIX = rgbfix

# Change the following lines
ROM_NAME = merzboy
SOURCES = merzboy.asm
FIX_FLAGS = -v -p 0

INCDIR = inc
OBJECTS = $(SOURCES:%.asm=%.o)

all: $(ROM_NAME)

$(ROM_NAME): $(OBJECTS)
		$(LINK) -o $@.gb -n $@.sym $(OBJECTS)
		$(FIX) $(FIX_FLAGS) $@.gb

%.o: %.asm
		$(ASM) -I$(INCDIR)/ -o $@ $<

clean:
		rm $(ROM_NAME).gb $(ROM_NAME).sym $(OBJECTS)ii m