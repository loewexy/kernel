
        .quad   0x0000000000000000      # null segment-descriptor
        #----------------------------------------------------------
        # Code/Data, 32 bit, 4kB, Priv 0, Type 0x02, 'Read/Write'
        # Base Address: 0x00000000   Limit: 0x000fffff
        .quad   0x00CF92000000FFFF      # code segment-descriptor
        #----------------------------------------------------------
        # Call Gate, 32-bit, Ring 0
        .equ    selPM32, (.-theGDT)+0   # selector for call-gate
        .global selPM32
        .word   pm_enter, privCS, 0x8C00, 0x0000 # gate-descriptor
        #----------------------------------------------------------
        # Call Gate, 16-bit, Ring 0
        .equ    selRM16, (.-theGDT)+0   # selector for call-gate
        .global selRM16
        .word   rm_enter, sel_cs, 0x8400, 0x0000 # gate-descriptor
        #----------------------------------------------------------
        # Call Gate, 32-bit, Ring 3
        .equ    selUsr, (.-theGDT)+3   # selector for call-gate
        .global selUsr
        .word   bail_out, privCS, 0xEC00, 0x0000 # gate-descriptor
        #----------------------------------------------------------
        # Code/Data, 16 bit, Byte, Priv 0, Type 0x0a, 'Execute/Read'
        # Base Address: 0x00010000   Limit: 0x0000FFFF
        .equ    sel_cs, (.-theGDT)+0    # selector for 16bit code
        .global sel_cs
        .quad   0x00009A010000FFFF      # code segment-descriptor
        #----------------------------------------------------------
        # Code/Data, 16 bit, Byte, Priv 0, Type 0x02, 'Read/Write'
        # Base Address: 0x00020000   Limit: 0x0000FFFF
        .equ    sel_ds, (.-theGDT)+0    # selector for 16bit data
        .global sel_ds
        .quad   0x000092020000FFFF      # data segment-descriptor
        #----------------------------------------------------------
        # Code/Data, 16 bit, Byte, Priv 0, Type 0x02, 'Read/Write'
        # Base Address: 0x000b8000   Limit: 0x00007FFF
        # Used to access CGA Display RAM
        .equ    sel_es, (.-theGDT)+0    # selector for video area
        .global sel_es
        .quad   0x0000920B80007fff      # vram segment-descriptor
        #----------------------------------------------------------
        # Code/Data, 16 bit, Byte, Priv 0, Type 0x02, 'Read/Write'
        # Base Address: 0x00000400   Limit: 0x000000FF
        .equ    sel_bs, (.-theGDT)+0    # selector for BIOS data
        .global sel_bs
        .quad   0x00009200040000ff      # data segment-descriptor
        #----------------------------------------------------------
        # Code/Data, 32 bit, Byte, Priv 0, Type 0x0a, 'Execute/Read'
        # Base Address: 0x00010000   Limit: 0x0000FFFF
        .equ    privCS, (.-theGDT)+0    # selector for ring0 code
        .global privCS
        .quad   0x00409A010000FFFF      # code segment-descriptor
        #----------------------------------------------------------
        # Code/Data, 32 bit, Byte, Priv 0, Type 0x02, 'Read/Write'
        # Base Address: 0x00020000   Limit: 0x0007FFFF
        .equ    privDS, (.-theGDT)+0    # selector for ring0 data
        .global privDS
        .quad   0x004792020000FFFF      # data segment-descriptor
        #----------------------------------------------------------
        # Expand-Up Stack Segment Descriptor
        # Code/Data, 32 bit, Byte, Priv 0, Type 0x02, 'Read/Write'
        # Base Address: 0x00020000   Limit: 0x0007FFFF
        .equ    privSS, (.-theGDT)+0    # selector for ring0 data
        .global privSS
        .quad   0x00479200C0003FFF      # stack segment-descriptor
        #----------------------------------------------------------

