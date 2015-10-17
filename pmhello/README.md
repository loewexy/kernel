# pmhello
This program shows the transition from x86 real-mode to protected-mode
and prints a simple welcome message to the screen. Finally, the program
triggers a General Protection Fault (int#14) exception by raising an
unhandled interrupt. The exception handler prints the contents of all
registers, including the address of the faulting instruction.
