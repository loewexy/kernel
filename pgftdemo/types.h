
#ifndef TYPES_H
#define TYPES_H        1

/*
 * Defines a subset of integer types according to
 * ISO C99: 7.18 Integer types <stdint.h>
 */

#define NULL                    0

#define PACKED __attribute__((packed))

/* Exact integral types.  */

/* Signed.  */

#ifndef __int8_t_defined
# define __int8_t_defined
typedef signed char             int8_t;
typedef short int               int16_t;
typedef int                     int32_t;
# if __WORDSIZE == 64
typedef long int                int64_t;
# else
__extension__
typedef long long int           int64_t;
# endif
#endif

/* Unsigned.  */
typedef unsigned char           uint8_t;
typedef unsigned short int      uint16_t;
#ifndef __uint32_t_defined
typedef unsigned int            uint32_t;
# define __uint32_t_defined
#endif
#if __WORDSIZE == 64
typedef unsigned long int       uint64_t;
#else
__extension__
typedef unsigned long long int  uint64_t;
#endif

#endif  /* types.h */

