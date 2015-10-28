# Introduction

This program demonstrates the x86 paging mechanism by providing a mapping of virtual memory areas to
corresponding physical addresses:
* The kernel code address area itself is mapped 1:1 to physical addresses
* The Linux user space virtual address area beginning at 0x8048000 and the stack area are mapped to physical
  memory starting at address 0x200000

# Boot Loader Signature

The program's signature is stored in a dedicated ELF section and verified by the boot loader
prior to executing the image. The module start.s defines the signature layout as follows
(gas syntax):

```assembly
.section        .signature, "a", @progbits
.ascii  "DHBW"                  # application 'signature'
.long   0
.long   _start                  # store start address
.long   etext
.long   edata
```

# Memory Layout

 Address        |       Description                                   | Segment Name
---------------:|:---------------------------------------------------:|:------------
```0x200000```  |   Memory area used for allocation of pages          |
```0x100000```  |         RAM Disk for ELF Images                     |
 ```0xC0000```  |      Reserved (BIOS)                                |
 ```0xB8000```  |   CGA Text Video Buffer  (4 Pages 25x80)            | sel\_es
 ```0x9FC00```  |   Reserved (Video)                                  |
 ```0x20000```  |    Kernel  .data .bss                               | privDS
 ```0x10000```  |       Kernel .text                                  | privCS
 ```0x0C000```  |    Kernel Stack (Protected Mode)                    | privSS
 ```0x07E00```  |       Unused Memory                                 |
 ```0x07C00```  |        Boot Sector  (512 Bytes)                     |
 ```0x00500```  |     Real Mode Stack                                 |
 ```0x00400```  |       BIOS Data Area (BDA)                          | sel\_bs
 ```0x00000```  |         Real Mode Interrupt Vector Table            |


# Monitor Command Description

All addresses and numbers are interpreted hexadecimal. Leading zeroes can be omitted

 Command			|		Description
 :------------------|:-----------------------------------------------------------------------------------------------------------
 ```H```			|	Print help message
 ```Q```			|	Quit monitor
 ```M```			|	Show non-kernel page table entries
 ```C```			| 	Release allocated pages (except kernel)
 ```D ADDR NUM```	|	Print ```NUM``` of DWORDS beginning from ```ADDR``` 
 ```X ADDR NUM```	|	Calculate CRC32 for ```NUM``` DWORDS beginning from ```ADDR```
 ```P ADDR```		|	Invalidate TLB entry for virtual address ```ADDR```
 ```R ADDR```		|	Read from address ```ADDR```
 ```F ADDR DWORD```	|	Fill page belonging to ```ADDR``` with 32-bit DWORD ```DWORD``` incremented by one for each address step
 ```W ADDR DWORD```	|	Write 32-bit DWORD ```DWORD``` to address ```ADDR```
