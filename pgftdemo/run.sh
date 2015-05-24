#!/bin/bash

make && qemu-system-x86_64 -fda pgftdemo.flp -m 1024M -curses

