#!/bin/bash

make && qemu-system-x86_64 -fda pgftdemo.flp -m 16M -cpu Nehalem -curses -no-reboot -serial telnet::4444,server

