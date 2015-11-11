#!/usr/bin/env perl

use 5.010;
use strict;
use warnings;

for(my $i = 0; $i < 1000; $i++)
{
	my $number = int(rand() * 100);
	
	if($number < 40) {
		my $address = 0x08048000;
		$address += int(262144*rand()) * 4;
		
		printf "R %08x\r\n", $address;
		
	} elsif($number < 80) {
		my $address = 0x08048000;
		$address += int(262144*rand()) * 4;
		
		my $value = int(0xFFFFFFFF * rand());
		
		printf "W %08x %08x\r\n", $address, $value;
		
	} elsif($number < 85) {
		print "A\r\n";
	} elsif($number < 90) {
		print "M\r\n";
	} elsif($number < 95) {
		my $address = 0x08048000;
		$address += int(256*rand()) * 4096;
		
		my $words = int(1024*rand());
		
		printf "D %08x %08x\r\n", $address, $words;
		
	} else {
		my $address = 0x08048000;
		$address += int(256*rand()) * 4096;
		
		my $words = int(1024*rand());
		
		printf "X %08x %08x\r\n", $address, $words;
	}	
}

print "Q\r\n";
