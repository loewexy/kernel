#!/bin/bash

make && qemu-system-x86_64 -fda pmhello.flp -m 1024M -curses

