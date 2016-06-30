#ifndef __CS_LES_FILTER_H__
#define __CS_LES_FILTER_H__

/*============================================================================
 * Filters for dynamic models.
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
 *  Local headers
 *----------------------------------------------------------------------------*/

#include "cs_base.h"

/*----------------------------------------------------------------------------*/

BEGIN_C_DECLS

/*=============================================================================
 * Local Macro definitions
 *============================================================================*/

/*============================================================================
 * Type definition
 *============================================================================*/

/*============================================================================
 * Public function prototypes for Fortran API
 *============================================================================*/

/*----------------------------------------------------------------------------
 * Compute filters for dynamic models. This function deals with the standard
 * or extended neighborhood.
 *
 * Fortran Interface :
 *
 * subroutine cfiltr (var, f_var, wbuf1, wbuf2)
 * *****************
 *
 * double precision(*) var[]   <-- array of variables to filter
 * double precision(*) f_var[] --> filtered variable array
 * double precision(*) wbuf1[] --- working buffer
 * double precision(*) wbuf2[] --- working buffer
 *----------------------------------------------------------------------------*/

void
CS_PROCF (cfiltr, CFILTR)(cs_real_t  var[],
                          cs_real_t  f_var[],
                          cs_real_t  wbuf1[],
                          cs_real_t  wbuf2[]);

/*=============================================================================
 * Public function prototypes
 *============================================================================*/

/*----------------------------------------------------------------------------
 * Compute filters for dynamic models.
 *
 * This function deals with the standard or extended neighborhood.
 *
 * parameters:
 *   stride  <--  stride of array to filter
 *   val     <->  array of values to filter
 *   f_val   -->  array of filtered values
 *----------------------------------------------------------------------------*/

void
cs_les_filter(int        stride,
              cs_real_t  val[],
              cs_real_t  f_val[]);

/*----------------------------------------------------------------------------*/

END_C_DECLS

#endif /* __CS_LES_FILTER_H__ */
