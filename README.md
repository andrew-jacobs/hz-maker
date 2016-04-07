# HZ-Maker
This project contains the source code needed to configure a PIC16F18313 as source of timing
for a simple microprocessor (like the 6502 or 65C02) and a serial chip (like the 6551/65C51
ACIA). It also emulates the funtion of the DS1813 'EconoReset' by providing a clean reset
control signal to the target CPU and peripheral chips.

Using a PIC means that several discrete components can be replaced by a single 8 pin
microcontroller which is cheaper and requires less board space.

In the simplest configuration all you need is a 16F18313, and a 100nF decompling capacitor.
In this mode the PIC internal high speed RC oscillator is used to generate the output clock
signals with a a +/-1% accuracy.

If you add a 8Mhz external timing crystal with suitable load capacitors (typically 22pF) then
the accuracy of the output signals will be much higher.

If you want to add a manual reset button then a normally open tact type switch can be added
to reset the PIC.

An example schematic for circuit showing the pins used for each of the signals is included
the in 'schematic' folder.

## Current Status
I've written all the code and tested it as much as I can in the simulator. I'm waiting for
some real chips to arrive so I can build a proper test board and use my oscilloscope to 
check the signals. 
