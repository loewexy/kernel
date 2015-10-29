# kernel
Very simplistic x86 kernel running from virtual floppy disk in QEMU

# boot/bootload - PC Bootloader for DHBW Kernel
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

# pgftdemo
This program demonstrates the x86 paging mechanism by providing
a mapping of virtual memory areas to corresponding physical addresses:
* The kernel code address area itself is mapped 1:1 to physical addresses
* The Linux user space virtual address area beginning at 0x8048000
  and the stack area are mapped to physical memory starting at
  address 0x200000


# pmhello
This program shows the transition from x86 real-mode to protected-mode
and prints a simple welcome message to the screen. Finally, the program
triggers a General Protection Fault (int#14) exception by raising an
unhandled interrupt. The exception handler prints the contents of all
registers, including the address of the faulting instruction.
