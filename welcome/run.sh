#!/bin/bash

make && qemu-system-x86_64 -fda welcome.flp -curses

