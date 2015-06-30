#!/bin/bash

make && qemu-system-x86_64 -fda elfexec.flp -m 1024M -curses

