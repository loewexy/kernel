#!/bin/bash

qemu-system-x86_64 -fda pgftdemo.flp -m 16M -cpu Nehalem -serial stdio -no-reboot -serial mon:telnet::4444,server,nowait -nographic

