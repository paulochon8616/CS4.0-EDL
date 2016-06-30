#ifndef __CS_BASE_H__
#define __CS_BASE_H__

/*============================================================================
 * Definitions, global variables, and base functions
 *============================================================================*/

/*
  This file is part of Code_Saturne, a general-purpose CFD tool.

  Copyright (C) 1998-2016 EDF S.A.

  This program is free software; you can redistribute it and/or modify it under
  the terms of the GNU General Public License as published by the Free Software
  Foundation; either version 2 of the License, or (at your option) any later
  version.

  This program is distributed in the hope that it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
  details.

  You should have received a copy of the GNU General Public License along with
  this program; if not, write to the Free Software Foundation, Inc., 51 Franklin
  Street, Fifth Floor, Boston, MA 02110-1301, USA.
*/

/*----------------------------------------------------------------------------*/

/*----------------------------------------------------------------------------
 * Standard C library headers
 *----------------------------------------------------------------------------*/

/*=============================================================================
 * Macro definitions
 *============================================================================*/

/* Application type name */

#define CS_APP_NAME     "Code_Saturne"
#define CS_APP_VERSION  PACKAGE_VERSION  /* PACKAGE_VERSION from autoconf */

/* System type name */

#if defined(__blrts__) || defined(__bg__)
#define _CS_ARCH_Blue_Gene

#elif defined(__linux__) || defined(__linux) || defined(linux)
#define _CS_ARCH_Linux

#elif defined(__sun__) || defined(__sun) || defined(sun)
#define _CS_ARCH_SunOS

#endif

/* On certain architectures such as IBM Blue Gene, some operations may
 * be better optimized on memory-aligned data (if 0 here, no alignment
 * is leveraged). This alignment is not exploited yet in Code_Saturne. */

#if defined(__blrts__) || defined(__bgp__)
#define CS_MEM_ALIGN 16
#elif defined(__bgq__)
#define CS_MEM_ALIGN 32
#else
#define CS_MEM_ALIGN 0
#endif

/*----------------------------------------------------------------------------*/

BEGIN_C_DECLS

/*============================================================================
 * Type definitions
 *============================================================================*/

/* Function pointers for extra cleanup operations to be called when
   entering cs_exit() or bft_error() */

typedef void (cs_base_atexit_t) (void);

/*=============================================================================
 * Global variable definitions
 *============================================================================*/

/*=============================================================================
 * Public function prototypes
 *============================================================================*/

/*----------------------------------------------------------------------------
 * First analysis of the command line to determine an application name.
 *
 * If no name is defined by the command line, a name is determined based
 * on the working directory.
 *
 * The caller is responsible for freeing the returned string.
 *
 * parameters:
 *   argc  <-- number of command line arguments
 *   argv  <-- array of command line arguments
 *
 * returns:
 *   pointer to character string with application name
 *----------------------------------------------------------------------------*/

char *
cs_base_get_app_name(int          argc,
                     const char  *argv[]);

/*----------------------------------------------------------------------------
 * Print logfile header
 *
 * parameters:
 *   argc  <-- number of command line arguments
 *   argv  <-- array of command line arguments
 *----------------------------------------------------------------------------*/

void
cs_base_logfile_head(int    argc,
                     char  *argv[]);

#if defined(HAVE_MPI)

/*----------------------------------------------------------------------------
 * First analysis of the command line and environment variables to determine
 * if we require MPI, and initialization if necessary.
 *
 * parameters:
 *   argc  <-> number of command line arguments
 *   argv  <-> array of command line arguments
 *
 * Global variables `cs_glob_n_ranks' (number of Code_Saturne processes)
 * and `cs_glob_rank_id' (rank of local process) are set by this function.
 *----------------------------------------------------------------------------*/

void
cs_base_mpi_init(int    *argc,
                 char  **argv[]);

#endif /* defined(HAVE_MPI) */

/*----------------------------------------------------------------------------
 * Exit, with handling for both normal and error cases.
 *
 * Finalize MPI if necessary.
 *
 * parameters:
 *   status <-- value to be returned to the parent:
 *              EXIT_SUCCESS / 0 for the normal case,
 *              EXIT_FAILURE or other nonzero code for error cases.
 *----------------------------------------------------------------------------*/

void
cs_exit(int  status);

/*----------------------------------------------------------------------------
 * Initialize error and signal handlers.
 *----------------------------------------------------------------------------*/

void
cs_base_error_init(void);

/*----------------------------------------------------------------------------
 * Initialize management of memory allocated through BFT.
 *----------------------------------------------------------------------------*/

void
cs_base_mem_init(void);

/*----------------------------------------------------------------------------
 * Finalize management of memory allocated through BFT.
 *
 * A summary of the consumed memory is given.
 *----------------------------------------------------------------------------*/

void
cs_base_mem_finalize(void);

/*----------------------------------------------------------------------------
 * Print summary of running time, including CPU and elapsed times.
 *----------------------------------------------------------------------------*/

void
cs_base_time_summary(void);

/*----------------------------------------------------------------------------
 * Set output file name and suppression flag for bft_printf().
 *
 * This allows redirecting or suppressing logging for different ranks.
 *
 * parameters:
 *   log_name    <-- base file name for log, or NULL for stdout
 *   r0_log_flag <-- redirection for rank 0 log;
 *                   0: not redirected; 1: redirected to <log_name> file
 *   rn_log_flag <-- redirection for ranks > 0 log:
 *                   0: not redirected; 1: redirected to <log_name>_n*" file;
 *                   2: redirected to "/dev/null" (suppressed)
 *----------------------------------------------------------------------------*/

void
cs_base_bft_printf_init(const char  *log_name,
                        int          r0_log_flag,
                        int          rn_log_flag);

/*----------------------------------------------------------------------------
 * Replace default bft_printf() mechanism with internal mechanism.
 *
 * This allows redirecting or suppressing logging for different ranks.
 *
 * parameters:
 *   log_name    <-- base file name for log
 *   r0_log_flag <-- redirection for rank 0 log;
 *                   0: not redirected; 1: redirected to "listing" file
 *   rn_log_flag <-- redirection for ranks > 0 log:
 *                   0: not redirected; 1: redirected to "listing_n*" file;
 *                   2: redirected to "/dev/null" (suppressed)
 *----------------------------------------------------------------------------*/

void
cs_base_bft_printf_set(const char  *log_name,
                       int          r0_log_flag,
                       int          rn_log_flag);

/*----------------------------------------------------------------------------
 * Return name of default log file.
 *
 * cs_base_bft_printf_set or cs_base_c_bft_printf_set() must have
 * been called before this.
 *
 * returns:
 *   name of default log file
 *----------------------------------------------------------------------------*/

const char *
cs_base_bft_printf_name(void);

/*----------------------------------------------------------------------------
 * Return flag indicating if the default log file output is suppressed.
 *
 * cs_base_bft_printf_set or cs_base_c_bft_printf_set() must have
 * been called before this.
 *
 * returns:
 *   output suppression flag
 *----------------------------------------------------------------------------*/

bool
cs_base_bft_printf_suppressed(void);

/*----------------------------------------------------------------------------
 * Print a warning message header.
 *
 * parameters:
 *   file_name <-- name of source file
 *   line_nume <-- line number in source file
 *----------------------------------------------------------------------------*/

void
cs_base_warn(const char  *file_name,
             int          line_num);

/*----------------------------------------------------------------------------
 * Define a function to be called when entering cs_exit() or bft_error().
 *
 * Compared to the C atexit(), only one function may be called (latest
 * setting wins), but the function is called slighty before exit,
 * so it is well adapted to cleanup such as flushing of non-C API logging.
 *
 * parameters:
 *   fct <-- pointer tu function to be called
 *----------------------------------------------------------------------------*/

void
cs_base_atexit_set(cs_base_atexit_t  *const fct);

/*----------------------------------------------------------------------------
 * Convert a character string from the Fortran API to the C API.
 *
 * Eventual leading and trailing blanks are removed.
 *
 * parameters:
 *   f_str <-- Fortran string
 *   f_len <-- Fortran string length
 *
 * returns:
 *   pointer to C string
 *----------------------------------------------------------------------------*/

char *
cs_base_string_f_to_c_create(const char  *f_str,
                             int          f_len);

/*----------------------------------------------------------------------------
 * Free a string converted from the Fortran API to the C API.
 *
 * parameters:
 *   str <-> pointer to C string
 *----------------------------------------------------------------------------*/

void
cs_base_string_f_to_c_free(char  **c_str);

/*----------------------------------------------------------------------------
 * Clean a string representing options.
 *
 * Characters are converted to lowercase, leading and trailing whitespace
 * is removed, and multiple whitespaces or tabs are replaced by single
 * spaces.
 *
 * parameters:
 *   s <-> string to be cleaned
 *----------------------------------------------------------------------------*/

void
cs_base_option_string_clean(char  *s);

/*----------------------------------------------------------------------------
 * Return a string providing locale path information.
 *
 * This is normally the path determined upon configuration, but may be
 * adapted for movable installs using the CS_ROOT_DIR environment variable.
 *
 * returns:
 *   locale path
 *----------------------------------------------------------------------------*/

const char *
cs_base_get_localedir(void);

/*----------------------------------------------------------------------------
 * Return a string providing package data path information.
 *
 * This is normally the path determined upon configuration, but may be
 * adapted for movable installs using the CS_ROOT_DIR environment variable.
 *
 * returns:
 *   package data path
 *----------------------------------------------------------------------------*/

const char *
cs_base_get_pkgdatadir(void);

/*----------------------------------------------------------------------------
 * Return a string providing loadable library path information.
 *
 * This is normally the path determined upon configuration, but may be
 * adapted for movable installs using the CS_ROOT_DIR environment variable.
 *
 * returns:
 *   package loadable library (plugin) path
 *----------------------------------------------------------------------------*/

const char *
cs_base_get_pkglibdir(void);

/*----------------------------------------------------------------------------
 * Ensure bool argument has value 0 or 1.
 *
 * This allows working around issues with Intel compiler C bindings,
 * which seem to pass incorrect values in some cases.
 *
 * parameters:
 *   b <-> pointer to bool
 *----------------------------------------------------------------------------*/

void
cs_base_check_bool(bool *b);

/*----------------------------------------------------------------------------*/

END_C_DECLS

#endif /* __CS_BASE_H__ */
