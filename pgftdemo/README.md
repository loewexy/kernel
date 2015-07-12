
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

