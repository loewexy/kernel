# kernel
Very simplistic x86 kernel running from virtual floppy disk in QEMU



==========================================================================
boot/bootload - PC Bootloader for DHBW Kernel
==========================================================================

Here is a 'boot-loader' that you can use for launching our
programming demos and exercises.

This boot-loader first demonstrates use of the ROM-BIOS
'Get Memory Size' service (int 0x12) in order to find out
the upper limit on memory available for use in real-mode.
Then, it loads a chunk of blocks from floppy disk into
memory starting at address 0x07E0:0000.

If a program with signature word 0xABCD is found at location
0x1000:0000, this program is executed with CS:IP = 0x1000:0002.

Otherwise, address 0x1000:0000 is checked for signature string
'DHBW', and if found, the program located there is executed
with CS:IP = 0x1000:addr, where the 16-bit start # address
'addr' is stored at location 0x1000:0008.

This code begins executing with CS:IP = 0x07C0:0000


LIMITATIONS:
This bootloader assumes a virtual floppy disk, e.g. as provided
by QEMU. In order to support real floppy drive hardware, drive
motor control needs to be added.

Based on cs630ipl.s and memsize.s written by Prof. Allan Cruse,
University of San Francisco, Course CS 630, Fall 2008



==========================================================================
tickdemo
==========================================================================

This boot-sector program illustrates basic issues involved
in writing the interrupt-handling procedure for a hardware
device (in this instance the PC's interval timer-counter).
Here we temporarily replace the interrupt-handler provided
by the ROM-BIOS with one of our own design, by overwriting
the appropriate entry in the Interrupt Vector Table.  What
is essential, besides incrementing our 'ticks'variable, is
that (1) an interrupt-handler must issue an EOI command to
the Interrupt Controller, and (2) an interrupt-handler has
to preserve the contents of all the processor's registers.



==========================================================================
timeoday
==========================================================================

The emphasis in this example is on making very clear what
arithmetical steps are needed in order to convert 'ticks'
(i.e., the number of timer-interrupts that occurred since
midnight) into the current time-of-day, written using the
'HH:MM:SS' format on the customary twelve-hour clock, and
to show how steps that require multiplications, divisions
and rounding to the nearest integer, can be done with the
x86 instruction-set in an especially efficient manner.



==========================================================================
welcome
==========================================================================

This boot-sector replacement program uses some ROM-BIOS
services to write a text-string to the console display.

