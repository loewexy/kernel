/*===================================================================
 * DHBW Ravensburg - Campus Friedrichshafen
 *
 * Vorlesung Systemnahe Programmierung (SNP)
 *
 * ramdisk.c - Create a file index table for a RAM Disk
 *
 * Author:  Ralf Reutemann
 * Created: 22-12-2014
 *
 * $Id:$
 *
 *===================================================================*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <inttypes.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <stdbool.h>
#include <libgen.h>


#define MAX_FILE_ENTRIES            16
#define MAX_FILE_NAME               16
#define RAM_DISK_SIZE       (1024*1024)     // 1 MB
#define ADDR_ALIGN                  16
#define READ_BUFFER_SIZE          8192


typedef struct file_entry {
    uint32_t    fe_mtime;
    uint32_t    fe_size;
    uint32_t    fe_addr;
    char        fe_spare[4];
    char        fe_name[MAX_FILE_NAME];
} file_entry_t;


typedef struct file_list {
    char          fl_sig[8];                      // offset  0  0x00
    uint32_t      fl_num;                         //         8  0x08
    uint32_t      fl_size;                        //        12  0x0c
    uint32_t      fl_mtime;                       //        16  0x10
    uint16_t      fl_start_sector;                //        20  0x14
    char          fl_spare[10];                   //        22  0x16
    file_entry_t  fl_files[MAX_FILE_ENTRIES];     //        32  0x20
} file_list_t;




char *
map_file_to_memory(size_t *len, int fd, const char *file)
{
    struct stat sb;
    char *addr;

    /* obtain the size of the file and use it to specify the size
     * of the memory mapping.
     */
    if(fstat(fd, &sb) < 0) {
        perror("fstat");
        return 0;
    } /* end if */
    *len = sb.st_size;

    /* map file specified by file descriptor fd into memory with read/write
     * access.
     */
    addr = mmap(NULL, *len, PROT_WRITE, MAP_SHARED, fd, 0);
    if(addr == MAP_FAILED) {
        perror("mmap");
        return 0;
    } /* end if */

    printf("Mapped %zu (%#zx) bytes starting at address %p of file %s\n",
           *len, *len, addr, file);

    return addr;
} /* end of map_file_to_memory */


void
copy_filename(file_entry_t *fep, char *file)
{
    size_t len;
    char *s = basename(file);

    memset(fep->fe_name, ' ', MAX_FILE_NAME);
    len = strlen(s);
    memcpy(fep->fe_name, s, (len < MAX_FILE_NAME) ? len : MAX_FILE_NAME);
} /* end of copy_filename */


uint32_t
read_file_to_buffer(file_entry_t *fep, char *file, char *addr, uint32_t offset)
{
    struct stat sb;
    int fd;
    char *ptr;
    ssize_t cc;

    if((fd = open(file, O_RDONLY)) < 0) {
        perror("open");
        return 0;
    } /* end if */

    if(fstat(fd, &sb) < 0) {
        perror("fstat");
        close(fd);
        return 0;
    } /* end if */
    fep->fe_size = sb.st_size;
    fep->fe_mtime = sb.st_mtime;
    fep->fe_addr = offset;
    copy_filename(fep, file);

    printf("   0x%06x  %6d (0x%06x)   %10d %s",
           offset, fep->fe_size, fep->fe_size,
           fep->fe_mtime, ctime((time_t *)&fep->fe_mtime));

    ptr = addr + offset;
    do {
        if((cc = read(fd, ptr, READ_BUFFER_SIZE)) < 0) {
            perror("read");
            close(fd);
            return 0;
        } /* end if */
        ptr += cc;
    } while(cc > 0);

    offset = offset + sb.st_size;
    if(offset & (ADDR_ALIGN-1)) {
        offset = (offset & ~(ADDR_ALIGN-1)) + ADDR_ALIGN;
    } /* end if */

    if(close(fd) < 0) {
        perror("close");
        return 0;
    } /* end if */

    return offset;
} /* end of read_file_to_buffer */


int
main(int argc, char *argv[])
{
    char *buf;
    char *img_addr;
    uint32_t addr_offset;
    int fd;
    uint32_t fe_index;
    int status = EXIT_SUCCESS;
    bool file_error;
    file_list_t file_list;

    if((argc > 4) && (argc < (MAX_FILE_ENTRIES+4))) {
        if((fd = open(argv[1], O_RDWR)) < 0) {
            perror("open");
            status = EXIT_FAILURE;
        } else {
            if((buf = malloc(RAM_DISK_SIZE)) == NULL) {
                // TODO: error handling
            } /* end if */
            memset(buf, 0, RAM_DISK_SIZE);

            fe_index = 0;
            file_error = false;
            addr_offset = 0;
            for(int i = 4; i < argc; i++) {
                printf("%2d %s:\n", fe_index, argv[i]);
                addr_offset = read_file_to_buffer(&file_list.fl_files[fe_index],
                                                  argv[i], buf, addr_offset);
                file_error = (addr_offset == 0);
                if(file_error == true) {
                    break;
                } /* end if */
                fe_index++;
            } /* end for */
            printf("total size: %d (0x%x) bytes\n", addr_offset, addr_offset);

            if(!file_error && (addr_offset <= RAM_DISK_SIZE)) {
                size_t img_len;
                if((img_addr = map_file_to_memory(&img_len, fd, argv[1])) != NULL) {
                    printf("%d file entries x %zd bytes, " \
                           "of which %d entries are used\n",
                           MAX_FILE_ENTRIES, sizeof(file_entry_t), fe_index);
                    memcpy(file_list.fl_sig, "RAMDISK ", 8);
                    file_list.fl_num = fe_index;
                    file_list.fl_size = addr_offset;
                    file_list.fl_mtime = (uint32_t)time(NULL);
                    file_list.fl_start_sector = (uint16_t)atoi(argv[3]);

                    int img_toc_offs = atoi(argv[2]) << 9;
                    int img_start_offs = file_list.fl_start_sector << 9;
                    if((img_toc_offs+sizeof(file_list) <= img_len) &&
                       (img_start_offs+addr_offset <= img_len)) {
                        memcpy(img_addr+img_toc_offs, &file_list, sizeof(file_list));
                        memcpy(img_addr+img_start_offs, buf, addr_offset);
                    } else {
                        fprintf(stderr, "ERROR: attempt to write TOC/files outside disk image\n");
                        status = EXIT_FAILURE;
                    } /* end if */
                } /* end if */
            } else {
                // TODO: error handling
            } /* end if */

            if(close(fd) < 0) {
                perror("close");
                status = EXIT_FAILURE;
            } /* end if */

            free(buf);
        } /* end if */
    } else if(argc == 3) {
        if((fd = open(argv[1], O_RDWR)) < 0) {
            perror("open");
            status = EXIT_FAILURE;
        } else {
            size_t img_len;
            if((img_addr = map_file_to_memory(&img_len, fd, argv[1])) != NULL) {
                int img_toc_offs = atoi(argv[2]) << 9;
                file_list_t *flp = (file_list_t *)(img_addr+img_toc_offs);
                char sig_str[9];
                memcpy(sig_str, flp->fl_sig, 8);
                sig_str[8] = '\0';
                printf("signature: '%s'\n", sig_str);
                printf("start sector: %d\n", flp->fl_start_sector);
                if(flp->fl_num <= MAX_FILE_ENTRIES) {
                    file_entry_t *fep;
                    for(int i = 0; i < flp->fl_num; i++) {
                        fep = &flp->fl_files[i];
                        char name[MAX_FILE_NAME+1];
                        memcpy(name, fep->fe_name, MAX_FILE_NAME);
                        name[MAX_FILE_NAME] = '\0';
                        printf("  %s  0x%06x  %6d (0x%06x)   %10d %s",
                               name, fep->fe_addr, fep->fe_size, fep->fe_size,
                               fep->fe_mtime, ctime((time_t *)&fep->fe_mtime));
                    } /* end for */
                } /* end if */
            } /* end if */
        } /* end if */
    } else {
        fprintf(stderr, "Usage: ramdisk diskimage toc pos file1 file2...\n");
        fprintf(stderr, "Note: The maximum number of files is %d\n", MAX_FILE_ENTRIES);
        status = EXIT_FAILURE;
    } /* end if */

    exit(status);
} /* end of main */


