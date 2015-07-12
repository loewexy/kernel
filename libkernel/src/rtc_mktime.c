
#define YEAR_EPOCH                 1900   /* Epoch year for struct tm */

#define SECS_PER_MIN               60UL
#define SECS_PER_HOUR            3600UL
#define SECS_PER_DAY            86400UL


/* Nonzero if YEAR is a leap year (every 4 years,
   except every 100th isn't, and every 400th is).
   However, for the given range of years it is
   sufficient to just check for modulo 4. */
#define ISLEAP(year)    (!((year) & 0x3))

struct cmos_rtc {
      unsigned char rtc_sec;         /* seconds */
      unsigned char rtc_min;         /* minutes */
      unsigned char rtc_hour;        /* hours */
      unsigned char rtc_mday;        /* day of the month */
      unsigned char rtc_mon;         /* month */
      unsigned char rtc_year;        /* year */
};

short month_days[2][16] = {
    /*   Jan  Feb  Mar  Apr  May  Jun  Jul  Aug  Sep  Oct  Nov  Dec
     *    31,  28,  31,  30,  31,  30,  31,  31,  30,  31,  30,  31 */
    { -1,  0,  31,  59,  90, 120, 151, 181, 212, 243, 273, 304, 334, -1, -1, -1 },
    { -1,  0,  31,  60,  91, 121, 152, 182, 213, 244, 274, 305, 335, -1, -1, -1 }
};


short year_days[] = {
    10957, 11323, 11688, 12053, 12418, 12784, 13149, 13514, 13879, 14245, /* idx =  0..9,  year = 2000..09 */
    14610, 14975, 15340, 15706, 16071, 16436, 16801, 17167, 17532, 17897, /* idx = 10..19, year = 2010..19 */
    18262, 18628, 18993, 19358, 19723, 20089, 20454, 20819, 21184, 21550, /* idx = 20..29, year = 2020..29 */
    21915, 22280, 22645, 23011, 23376, 23741, 24106, 24472,    -1,    -1, /* idx = 30..39, year = 2030..39 */
       -1,    -1,    -1,    -1,    -1,    -1,    -1,    -1,    -1,    -1, /* idx = 40..49, year = -        */
       -1,    -1,    -1,    -1,    -1,    -1,    -1,    -1,    -1,    -1, /* idx = 50..59, year = -        */
       -1,    -1,    -1,    -1,    -1,    -1,    -1,    -1,    -1,    -1, /* idx = 60..69, year = -        */
        0,   365,   730,  1096,  1461,  1826,  2191,  2557,  2922,  3287, /* idx = 70..79, year = 1970..79 */
     3652,  4018,  4383,  4748,  5113,  5479,  5844,  6209,  6574,  6940, /* idx = 80..89, year = 1980..89 */
     7305,  7670,  8035,  8401,  8766,  9131,  9496,  9862, 10227, 10592  /* idx = 90..99, year = 1990..99 */
};



/**
 * Return the `time_t' representation of TP and normalize TP
 */
unsigned long
rtc_mktime(struct cmos_rtc *rtc)
{
    unsigned long timestamp;
    unsigned short days = rtc->rtc_mday-1;
    unsigned short year = rtc->rtc_year + ((rtc->rtc_year >= 70) ? 1900 : 2000);

    days += month_days[ISLEAP(year)][rtc->rtc_mon];
    days += year_days[rtc->rtc_year];

    timestamp = rtc->rtc_sec +
                rtc->rtc_min * SECS_PER_MIN +
                rtc->rtc_hour * SECS_PER_HOUR +
                days * SECS_PER_DAY;

    return timestamp;
}

