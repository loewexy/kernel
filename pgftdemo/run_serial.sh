#!/bin/bash

make && qemu-system-x86_64 -fda pgftdemo.flp -m 16M -cpu Nehalem -serial stdio -no-reboot

