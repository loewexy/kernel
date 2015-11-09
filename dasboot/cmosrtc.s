
        .section        .text
        .code16
        .type           read_cmos_rtc, @function
        .global         read_cmos_rtc
        .align  8
read_cmos_rtc:
#
# This procedure reads the date/time fields from the CMOS RTC
#
        enter   $0, $0
        pushaw

.Lwait_rtc_uip_set:
        mov     $0x8A, %ax
        out     %al, $0x70
        in      $0x71, %al
        test    $0x80, %al
        jz      .Lwait_rtc_uip_set

.Lwait_rtc_uip_clear:
        mov     $0x0A, %ax
        out     %al, $0x70
        in      $0x71, %al
        test    $0x80, %al
        jnz     .Lwait_rtc_uip_clear

        xor     %si, %si
        mov     4(%bp), %bx
.Lrtc_reg_loop:
        mov     .Lcmos_rtc_idx(%si), %al
        out     %al, $0x70
        in      $0x71, %al
        mov     %al, %ch
        and     $0xf, %ch
        shr     $4, %al
        mov     %al, %cl

        mov     $10, %dl
        mov     %cl, %al
        mul     %dl
        add     %ch, %al
        mov     %al, (%bx,%si,1)        # store decimal time value

        add     $0x3030, %cx
        movzxb  .Lcmos_str_idx(%si), %di
        mov     %cx, 6(%bx,%di,1)       # store string representation
        inc     %si
        cmp     $6, %si
        jb      .Lrtc_reg_loop

        popaw
        leave
        ret     $2


        .section    .data
        .align      4
#------------------------------------------------------------------
#
#  struct tm {
#      int tm_sec;         /* seconds (SS) */
#      int tm_min;         /* minutes (MM) */
#      int tm_hour;        /* hours (HH) */
#      int tm_mday;        /* day of the month (DD) */
#      int tm_mon;         /* month (MM) */
#      int tm_year;        /* year (YY) */
#      int tm_wday;        /* day of the week */
#      int tm_yday;        /* day in the year */
#      int tm_isdst;       /* daylight saving time */
#  };
#
#------------------------------------------------------------------
# CMOS RTC data structures
#
#                         SS    MM    HH    DD    MM    YY
#------------------------------------------------------------------
.Lcmos_rtc_idx: .byte   0x00, 0x02, 0x04, 0x07, 0x08, 0x09
.Lcmos_str_idx: .byte      6,    3,    0,   15,   12,    9

