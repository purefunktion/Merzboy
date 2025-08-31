# Version 7

First of all the INCLUDE of tilemaps is moved to the Makefile. One problem with includes is that if you change the file that is included make does not pick that up. So it is more convinient to assemble an object file and link it.

Next up was changing how to handle changing between "on/off" and "kill switch" mode. We need the d-pads for the manual setting of noise channels values. See the new HandlePressSelect, works just like the other buttons.  

Also in this version we will use our first sprite(or object as it is called in the PAN docs). It is a pointer or arrow to indicate which value of the noise channels settings we are currently adjusting.
This is why we needed the d-pad to manually switch between settings in the noise channel.

There was one hurdle that took a bit of head scratching to get right in this version. There is a wait for vblank call in the main loop now. This is because when choosing a number for Clock shift/LFSR width/Clock divider the application does this one digit at the time. If you don't wait for a vblank the code for the d-pad can fire multiple times and act wierd, skipping numbers etc. Try commenting out that line and build the project and see for yourself. 