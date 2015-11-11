#!/bin/bash

WD=$(pwd)

FAIL=0

echo "Running regression Test"

echo "Inserting test script to kernel, this could take a long time."
cd ..
./run_serial.sh < $WD/regression.txt > $WD/output.txt
cd $WD

echo "Reading correct read and write addresses from .elf"
RADDR=$(objdump -x ../pgftdemo.elf | grep mon_inst_rd_addr | cut -d" " -f 1 | tr [:lower:] [:upper:])
WADDR=$(objdump -x ../pgftdemo.elf | grep mon_inst_wr_addr | cut -d" " -f 1 | tr [:lower:] [:upper:])

echo "Comparing EIP addresses"
while read line
do
	echo $line | grep "Page fault" > /dev/null
	
	if [ $? -eq 0 ]
	then
		EIP=$(echo $line | grep -E -o '\(.+\)' | sed 's/(EIP 0x\(.\{8\}\))/\1/g')
		
		LASTCMD=$(echo $LASTLINE | cut -c 1)
		
		if [ $LASTCMD == "R" -a $EIP != $RADDR ]
		then
			echo "Read Error: EIP does not match, was 0x$EIP, expected 0x$RADDR"
			FAIL=1
		fi
		
		if [ $LASTCMD == "W" -a $EIP != $WADDR ]
		then
			echo "Write Error: EIP does not match, was 0x$EIP, expected 0x$WADDR"
			FAIL=1
		fi
	fi
	
	LASTLINE=$line
done < output.txt

echo "Removing EIP addresses from output"
cat output.txt | sed "s/(EIP.\+)/()/g" > tmp.txt
mv tmp.txt output.txt
todos output.txt

echo "Calling diff"
diff regression-reference.txt output.txt
if [ $? -ne 0 ]
then
	FAIL=1
fi

rm output.txt

if [ $FAIL -eq 1 ]
then
	echo "Regression test failed!"
else
	echo "Test successful!"
fi


exit $FAIL
