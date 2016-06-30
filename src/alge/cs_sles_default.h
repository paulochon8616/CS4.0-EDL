#ifndef __CS_SLES_DEFAULT_H__
#define __CS_SLES_DEFAULT_H__

/*============================================================================
 * Sparse Linear Equation Solvers
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
#include "cs_halo_perio.h"
#include "cs_matrix.h"
#include "cs_sles.h"

/*----------------------------------------------------------------------------*/

BEGIN_C_DECLS

/*============================================================================
 * Macro definitions
 *============================================================================*/

/*============================================================================
 * Type definitions
 *============================================================================*/

/*============================================================================
 *  Global variables
 *============================================================================*/

/*=============================================================================
 * Public function prototypes
 *============================================================================*/

/*----------------------------------------------------------------------------
 * Default initializations for sparse linear equation solver API.
 *----------------------------------------------------------------------------*/

void
cs_sles_default_log_setup(void);

/*----------------------------------------------------------------------------
 * Default definition of a sparse linear equation solver
 *
 * parameters:
 *   f_id <-- associated field id, or < 0
 *   name <-- associated name if f_id < 0, or NULL
 *   a    <-- matrix
 *----------------------------------------------------------------------------*/

void
cs_sles_default(int                 f_id,
                const char         *name,
                const cs_matrix_t  *a);

/*----------------------------------------------------------------------------
 * Default setup setup for sparse linear equation solver API.
 *
 * This includes setup logging.
 *----------------------------------------------------------------------------*/

void
cs_sles_default_setup(void);

/*----------------------------------------------------------------------------
 * Return default verbosity associated to a field id, name couple.
 *
 * parameters:
 *   f_id <-- associated field id, or < 0
 *   name <-- associated name if f_id < 0, or NULL
 *
 * returns:
 *   verbosity associated with field or name
 *----------------------------------------------------------------------------*/

int
cs_sles_default_get_verbosity(int          f_id,
                              const char  *name);

/*----------------------------------------------------------------------------
 * Default finalization for sparse linear equation solver API.
 *
 * This includes performance data logging output.
 *----------------------------------------------------------------------------*/

void
cs_sles_default_finalize(void);

/*----------------------------------------------------------------------------
 * Call sparse linear equation solver using native matrix arrays.
 *
 * parameters:
 *   f_id                   <-- associated field id, or < 0
 *   name                   <-- associated name if f_id < 0, or NULL
 *   symmetric              <-- indicates if matrix coefficients are symmetric
 *   diag_block_size        <-- block sizes for diagonal, or NULL
 *   extra_diag_block_size  <-- block sizes for extra diagonal, or NULL
 *   da                     <-- diagonal values (NULL if zero)
 *   xa                     <-- extradiagonal values (NULL if zero)
 *   rotation_mode          <-- halo update option for rotational periodicity
 *   r_epsilon              <-- precision
 *   r_norm                 <-- residue normalization
 *   n_iter                 --> number of iterations
 *   residue                --> residue
 *   rhs                    <-- right hand side
 *   vx                     <-> system solution
 *
 * returns:
 *   convergence state
 *----------------------------------------------------------------------------*/

cs_sles_convergence_state_t
cs_sles_solve_native(int                  f_id,
                     const char          *name,
                     bool                 symmetric,
                     const int           *diag_block_size,
                     const int           *extra_diag_block_size,
                     const cs_real_t     *da,
                     const cs_real_t     *xa,
                     cs_halo_rotation_t   rotation_mode,
                     double               precision,
                     double               r_norm,
                     int                 *n_iter,
                     double              *residue,
                     const cs_real_t     *rhs,
                     cs_real_t           *vx);

/*----------------------------------------------------------------------------
 * Free sparse linear equation solver setup using native matrix arrays.
 *
 * parameters:
 *   f_id                   <-- associated field id, or < 0
 *   name                   <-- associated name if f_id < 0, or NULL
 *----------------------------------------------------------------------------*/

void
cs_sles_free_native(int          f_id,
                    const char  *name);

/*----------------------------------------------------------------------------*/

END_C_DECLS

#endif /* __CS_SLES_DEFAULT_H__ */