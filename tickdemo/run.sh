#!/bin/bash

make && qemu-system-x86_64 -fda tickdemo.flp -curses

