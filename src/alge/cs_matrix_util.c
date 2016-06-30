/*============================================================================
 * Utilitary functions for sparse matrixes.
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

#include "cs_defs.h"

/*----------------------------------------------------------------------------
 * Standard C library headers
 *----------------------------------------------------------------------------*/

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <math.h>

#if defined(HAVE_MPI)
#include <mpi.h>
#endif

/*----------------------------------------------------------------------------
 * Local headers
 *----------------------------------------------------------------------------*/

#include "bft_mem.h"
#include "bft_error.h"
#include "bft_printf.h"

#include "fvm_io_num.h"

#include "cs_base.h"
#include "cs_blas.h"
#include "cs_file.h"
#include "cs_halo.h"
#include "cs_log.h"
#include "cs_numbering.h"
#include "cs_order.h"
#include "cs_part_to_block.h"
#include "cs_prototypes.h"
#include "cs_timer.h"

/*----------------------------------------------------------------------------
 *  Header for the current file
 *----------------------------------------------------------------------------*/

#include "cs_matrix_util.h"

#include "cs_matrix_priv.h"

/*----------------------------------------------------------------------------*/

BEGIN_C_DECLS

/*! \cond DOXYGEN_SHOULD_SKIP_THIS */

/*=============================================================================
 * Local Macro Definitions
 *============================================================================*/

/*=============================================================================
 * Local Type Definitions
 *============================================================================*/

/*============================================================================
 *  Global variables
 *============================================================================*/

/*============================================================================
 * Private function definitions
 *============================================================================*/

/*----------------------------------------------------------------------------
 * y[i] = abs(da[i]), with da possibly NULL.
 *
 * parameters:
 *   da          <-- Pointer to coefficients array (usually matrix diagonal)
 *   dd          --> Resulting vector
 *   n_cells     <-- Number of cells
 *   n_cells_ext <-- Number of cells + ghost cells
*----------------------------------------------------------------------------*/

static void
_diag_dom_diag_contrib(const cs_real_t  *restrict da,
                       cs_real_t        *restrict dd,
                       cs_lnum_t         n_cells,
                       cs_lnum_t         n_cells_ext)
{
  cs_lnum_t  ii;

  if (da != NULL) {
#   pragma omp parallel for
    for (ii = 0; ii < n_cells; ii++)
      dd[ii] = fabs(da[ii]);
    for (ii = n_cells; ii < n_cells_ext; ii++)
      dd[ii] = 0.0;
  }
  else {
#   pragma omp parallel for
    for (ii = 0; ii < n_cells_ext; ii++)
      dd[ii] = 0.0;
  }

}

/*----------------------------------------------------------------------------
 * Block diagonal contribution to diagonal dominance, with da possibly NULL.
 *
 * parameters:
 *   da          <-- Pointer to coefficients array (usually matrix diagonal)
 *   dd          --> Resulting vector
 *   n_cells     <-- Number of cells
 *   n_cells_ext <-- Number of cells + ghost cells
 *   b_size      <-- block size, including padding:
 *                   b_size[0]: useful block size
 *                   b_size[1]: vector block extents
 *                   b_size[2]: matrix line extents
 *                   b_size[3]: matrix line*column (block) extents
 *----------------------------------------------------------------------------*/

static void
_b_diag_dom_diag_contrib(const cs_real_t  *restrict da,
                         cs_real_t        *restrict dd,
                         cs_lnum_t         n_cells,
                         cs_lnum_t         n_cells_ext,
                         const int         b_size[4])
{
  cs_lnum_t  ii, jj, kk;
  double  sign;
  const cs_lnum_t  dd_size = n_cells_ext*b_size[1];

# pragma omp parallel for
  for (ii = 0; ii < dd_size; ii++)
    dd[ii] = 0.0;

  if (da != NULL) {
#   pragma omp parallel for private(jj, kk, sign)
    for (ii = 0; ii < n_cells; ii++) {
      for (jj = 0; jj < b_size[1]; jj++)
        dd[ii*b_size[1] + jj] = 0.0;
      for (jj = 0; jj < b_size[0]; jj++) {
        for (kk = 0; kk < b_size[0]; kk++) {
          sign = (jj == kk) ? 1. : -1.;
          dd[ii*b_size[1] + kk]
            += sign*fabs(da[ii*b_size[3] + jj*b_size[2] + kk]);
        }
      }
    }
  }
}

/*----------------------------------------------------------------------------
 * Normalize diagonal dominance, with da possibly NULL.
 *
 * parameters:
 *   da          <-- Pointer to coefficients array (usually matrix diagonal)
 *   dd          --> Resulting vector
 *   n_cells     <-- Number of cells
*----------------------------------------------------------------------------*/

static void
_diag_dom_diag_normalize(const cs_real_t  *restrict da,
                         cs_real_t        *restrict dd,
                         cs_lnum_t         n_cells)
{
  cs_lnum_t  ii;

  if (da != NULL) {
#   pragma omp parallel for
    for (ii = 0; ii < n_cells; ii++) {
      if (fabs(da[ii]) > 1.e-18)
        dd[ii] /= fabs(da[ii]);
      else if (dd[ii] > -1.e-18)
        dd[ii] = -1.e18;
      else
        dd[ii] = 0;
    }
  }
  else {
#   pragma omp parallel for
    for (ii = 0; ii < n_cells; ii++) {
      if (dd[ii] > -1.e-18)
        dd[ii] = -1.e18;
      else
        dd[ii] = 0;
    }
  }
}

/*----------------------------------------------------------------------------
 * Normalize block diagonal dominance, with da possibly NULL.
 *
 * parameters:
 *   da      <-- Pointer to coefficients array (usually matrix diagonal)
 *   dd      --> Resulting vector
 *   n_cells <-- Number of cells
 *   b_size  <-- block size, including padding:
 *               b_size[0]: useful block size
 *               b_size[1]: vector block extents
 *               b_size[2]: matrix line extents
 *               b_size[3]: matrix line*column (block) extents
 *----------------------------------------------------------------------------*/

static void
_b_diag_dom_diag_normalize(const cs_real_t  *restrict da,
                           cs_real_t        *restrict dd,
                           cs_lnum_t         n_cells,
                           const int         b_size[4])
{
  cs_lnum_t  ii, jj;
  double  d_val;

  if (da != NULL) {
#   pragma omp parallel for private(jj, d_val)
    for (ii = 0; ii < n_cells; ii++) {
      for (jj = 0; jj < b_size[0]; jj++) {
        d_val = fabs(da[ii*b_size[3] + jj*b_size[2] + jj]);
        if (d_val > 1.e-18)
          dd[ii*b_size[1] + jj] /= d_val;
        else if (dd[ii*b_size[1] + jj] > -1.e-18)
          dd[ii*b_size[1] + jj] = -1.e18;
        else
          dd[ii*b_size[1] + jj] = 0;
      }
    }
  }
}

/*----------------------------------------------------------------------------
 * Measure Diagonal dominance of native matrix.
 *
 * parameters:
 *   matrix <-- Pointer to matrix structure
 *   dd     --> Resulting vector
 *----------------------------------------------------------------------------*/

static void
_diag_dom_native(const cs_matrix_t  *matrix,
                 cs_real_t          *restrict dd)
{
  cs_lnum_t  ii, jj, face_id;

  const cs_matrix_struct_native_t  *ms = matrix->structure;
  const cs_matrix_coeff_native_t  *mc = matrix->coeffs;

  const cs_real_t  *restrict xa = mc->xa;

  /* diagonal contribution */

  _diag_dom_diag_contrib(mc->da, dd, ms->n_cells, ms->n_cells_ext);

  /* non-diagonal terms */

  if (mc->xa != NULL) {

    const cs_lnum_2_t *restrict face_cel_p = ms->face_cell;

    if (mc->symmetric) {

      for (face_id = 0; face_id < ms->n_faces; face_id++) {
        ii = face_cel_p[face_id][0];
        jj = face_cel_p[face_id][1];
        dd[ii] -= fabs(xa[face_id]);
        dd[jj] -= fabs(xa[face_id]);
      }

    }
    else {

      for (face_id = 0; face_id < ms->n_faces; face_id++) {
        ii = face_cel_p[face_id][0];
        jj = face_cel_p[face_id][1];
        dd[ii] -= fabs(xa[2*face_id]);
        dd[jj] -= fabs(xa[2*face_id + 1]);
      }

    }

  }

  _diag_dom_diag_normalize(mc->da, dd, ms->n_cells);
}

/*----------------------------------------------------------------------------
 * Measure Diagonal dominance of native matrix with block diagonal.
 *
 * parameters:
 *   matrix <-- Pointer to matrix structure
 *   dd     --> Resulting vector
 *----------------------------------------------------------------------------*/

static void
_b_diag_dom_native(const cs_matrix_t  *matrix,
                   cs_real_t          *restrict dd)
{
  cs_lnum_t  ii, jj, kk, face_id;

  const cs_matrix_struct_native_t  *ms = matrix->structure;
  const cs_matrix_coeff_native_t  *mc = matrix->coeffs;

  const cs_real_t  *restrict xa = mc->xa;
  const int *db_size = matrix->db_size;

  /* block diagonal contribution */

  _b_diag_dom_diag_contrib(mc->da, dd, ms->n_cells, ms->n_cells_ext, db_size);

  /* non-diagonal terms */

  if (mc->xa != NULL) {

    const cs_lnum_2_t *restrict face_cel_p = ms->face_cell;

    if (mc->symmetric) {

      for (face_id = 0; face_id < ms->n_faces; face_id++) {
        ii = face_cel_p[face_id][0];
        jj = face_cel_p[face_id][1];
        for (kk = 0; kk < db_size[0]; kk++) {
          dd[ii*db_size[1] + kk] -= fabs(xa[face_id]);
          dd[jj*db_size[1] + kk] -= fabs(xa[face_id]);
        }
      }
    }
    else {

      for (face_id = 0; face_id < ms->n_faces; face_id++) {
        ii = face_cel_p[face_id][0];
        jj = face_cel_p[face_id][1];
        for (kk = 0; kk < db_size[0]; kk++) {
          dd[ii*db_size[1] + kk] -= fabs(xa[2*face_id]);
          dd[jj*db_size[1] + kk] -= fabs(xa[2*face_id + 1]);
        }
      }

    }

  }

  _b_diag_dom_diag_normalize(mc->da, dd, ms->n_cells, db_size);
}

/*----------------------------------------------------------------------------
 * Measure Diagonal dominance of CSR matrix.
 *
 * parameters:
 *   matrix <-- Pointer to matrix structure
 *   dd     --> Resulting vector
 *----------------------------------------------------------------------------*/

static void
_diag_dom_csr(const cs_matrix_t  *matrix,
              cs_real_t          *restrict dd)
{
  cs_lnum_t  ii, jj, n_cols;
  double  sii, sign, d_val;
  cs_lnum_t  *restrict col_id;
  cs_real_t  *restrict m_row;

  const cs_matrix_struct_csr_t  *ms = matrix->structure;
  const cs_matrix_coeff_csr_t  *mc = matrix->coeffs;
  cs_lnum_t  n_rows = ms->n_rows;

  /* Standard case */

# pragma omp parallel for private(jj, col_id, m_row, n_cols, sii, sign, d_val)
  for (ii = 0; ii < n_rows; ii++) {
    col_id = ms->col_id + ms->row_index[ii];
    m_row = mc->val + ms->row_index[ii];
    n_cols = ms->row_index[ii+1] - ms->row_index[ii];
    sii = 0.0;
    d_val = 0.0;
    for (jj = 0; jj < n_cols; jj++) {
      if (col_id[jj] == ii) {
        sign = 1.;
        d_val = fabs(m_row[jj]);
      }
      else
        sign = -1.;
      sii += sign * fabs(m_row[jj]);
    }
    if (d_val > 1.e-18)
      sii /= d_val;
    else if (sii > -1.e-18)
      sii = -1.e18;
    else
      sii = 0;
    dd[ii] = sii;
  }
}

/*----------------------------------------------------------------------------
 * Measure Diagonal dominance of symmetric CSR matrix.
 *
 * parameters:
 *   matrix <-- Pointer to matrix structure
 *   dd     --> Resulting vector
 *----------------------------------------------------------------------------*/

static void
_diag_dom_csr_sym(const cs_matrix_t  *matrix,
                  cs_real_t          *restrict dd)
{
  cs_lnum_t  ii, jj, n_cols;
  cs_lnum_t  *restrict col_id;
  cs_real_t  *restrict m_row;

  const cs_matrix_struct_csr_sym_t  *ms = matrix->structure;
  const cs_matrix_coeff_csr_sym_t  *mc = matrix->coeffs;
  cs_lnum_t  n_rows = ms->n_rows;

  cs_lnum_t sym_jj_start = 0;

  /* By construction, the matrix has either a full or an empty
     diagonal structure, so testing this on the first row is enough */

  if (ms->col_id[ms->row_index[0]] == 0)
    sym_jj_start = 1;

  /* Initialize dd */

  for (ii = 0; ii < ms->n_cols; ii++)
    dd[ii] = 0.0;

  /* Upper triangular + diagonal part in case of symmetric structure */

  for (ii = 0; ii < n_rows; ii++) {
    cs_real_t  sii = 0.0;
    col_id = ms->col_id + ms->row_index[ii];
    m_row = mc->val + ms->row_index[ii];
    n_cols = ms->row_index[ii+1] - ms->row_index[ii];
    for (jj = 0; jj < n_cols; jj++) {
      double sign = (col_id[jj] == ii) ? 1. : -1.;
      sii += sign * fabs(m_row[jj]);
    }
    dd[ii] += sii;
    for (jj = sym_jj_start; jj < n_cols; jj++)
      dd[col_id[jj]] -= fabs(m_row[jj]);
  }

  /* normalize */

  for (ii = 0; ii < n_rows; ii++) {
    cs_real_t sii = 0.0, d_val = 0.0;
    col_id = ms->col_id + ms->row_index[ii];
    m_row = mc->val + ms->row_index[ii];
    n_cols = ms->row_index[ii+1] - ms->row_index[ii];
    for (jj = 0; jj < n_cols; jj++) {
      if (col_id[jj] == ii)
        d_val = fabs(m_row[jj]);
    }
    if (d_val > 1.e-18)
      sii /= d_val;
    else if (sii > -1.e-18)
      sii = -1.e18;
    else
      sii = 0;
    dd[ii] = sii;
  }
}

/*----------------------------------------------------------------------------
 * Measure Diagonal dominance of MSR matrix.
 *
 * parameters:
 *   matrix <-- Pointer to matrix structure
 *   dd     --> Resulting vector
 *----------------------------------------------------------------------------*/

static void
_diag_dom_msr(const cs_matrix_t  *matrix,
              cs_real_t          *restrict dd)
{
  cs_lnum_t  ii, jj, n_cols;
  cs_real_t  sii;
  cs_real_t  *restrict m_row;

  const cs_matrix_struct_csr_t  *ms = matrix->structure;
  const cs_matrix_coeff_msr_t  *mc = matrix->coeffs;
  cs_lnum_t  n_rows = ms->n_rows;

  /* diagonal contribution */

  _diag_dom_diag_contrib(mc->d_val, dd, ms->n_rows, ms->n_cols);

  /* extra-diagonal contribution */

  if (mc->x_val != NULL) {

#   pragma omp parallel for private(jj, m_row, n_cols, sii)
    for (ii = 0; ii < n_rows; ii++) {
      m_row = mc->x_val + ms->row_index[ii];
      n_cols = ms->row_index[ii+1] - ms->row_index[ii];
      sii = 0.0;
      for (jj = 0; jj < n_cols; jj++)
        sii -= fabs(m_row[jj]);
      dd[ii] += sii;
    }

  }

  _diag_dom_diag_normalize(mc->d_val, dd, n_rows);
}

/*----------------------------------------------------------------------------
 * Measure Diagonal dominance of MSR matrix, blocked version.
 *
 * parameters:
 *   matrix <-- Pointer to matrix structure
 *   dd     --> Resulting vector
 *----------------------------------------------------------------------------*/

static void
_b_diag_dom_msr(const cs_matrix_t  *matrix,
                cs_real_t          *restrict dd)
{
  cs_lnum_t  ii, jj, kk, n_cols;
  cs_real_t  *restrict m_row;

  const cs_matrix_struct_csr_t  *ms = matrix->structure;
  const cs_matrix_coeff_msr_t  *mc = matrix->coeffs;
  const int *db_size = matrix->db_size;
  const cs_lnum_t  n_rows = ms->n_rows;

  /* diagonal contribution */

  _b_diag_dom_diag_contrib(mc->d_val, dd, ms->n_rows, ms->n_cols, db_size);

  /* extra-diagonal contribution */

  if (mc->x_val != NULL) {

#   pragma omp parallel for private(jj, kk, m_row, n_cols)
    for (ii = 0; ii < n_rows; ii++) {
      m_row = mc->x_val + ms->row_index[ii];
      n_cols = ms->row_index[ii+1] - ms->row_index[ii];
      for (jj = 0; jj < n_cols; jj++) {
        for (kk = 0; kk < db_size[0]; kk++)
          dd[ii*db_size[1] + kk] -= fabs(m_row[jj]);
      }
    }

  }

  _b_diag_dom_diag_normalize(mc->d_val, dd, ms->n_rows, db_size);
}

/*----------------------------------------------------------------------------
 * Diagonal contribution to matrix dump.
 *
 * parameters:
 *   da          <-- Pointer to coefficients array (usually matrix diagonal)
 *   m_coo       <-- Matrix coefficient coordinates array
 *   m_val       <-- Matrix coefficient values array
 *   g_coo_num   <-- Global coordinate numbers
 *   n_cells     <-- Number of cells
*----------------------------------------------------------------------------*/

static void
_pre_dump_diag_contrib(const cs_real_t  *restrict da,
                       cs_gnum_t        *restrict m_coo,
                       cs_real_t        *restrict m_val,
                       cs_gnum_t        *restrict g_coo_num,
                       cs_lnum_t         n_cells)
{
  cs_lnum_t  ii;

  if (da != NULL) {
#   pragma omp parallel for
    for (ii = 0; ii < n_cells; ii++) {
      m_coo[ii*2] = g_coo_num[ii];
      m_coo[ii*2 + 1] = g_coo_num[ii];
      m_val[ii] = da[ii];
    }
  }
  else {
#   pragma omp parallel for
    for (ii = 0; ii < n_cells; ii++) {
      m_coo[ii*2] = g_coo_num[ii];
      m_coo[ii*2 + 1] = g_coo_num[ii];
      m_val[ii] = 0.0;
    }
  }
}

/*----------------------------------------------------------------------------
 * Block diagonal contribution to matrix dump.
 *
 * parameters:
 *   da        <-- Pointer to coefficients array (usually matrix diagonal)
 *   m_coo     <-- Matrix coefficient coordinates array
 *   m_val     <-- Matrix coefficient values array
 *   g_coo_num <-- Global coordinate numbers
 *   n_cells   <-- Number of cells
 *   b_size    <-- block size, including padding:
 *                 b_size[0]: useful block size
 *                 b_size[1]: vector block extents
 *                 b_size[2]: matrix line extents
 *                 b_size[3]: matrix line*column (block) extents
 *----------------------------------------------------------------------------*/

static void
_b_pre_dump_diag_contrib(const cs_real_t  *restrict da,
                         cs_gnum_t        *restrict m_coo,
                         cs_real_t        *restrict m_val,
                         cs_gnum_t        *restrict g_coo_num,
                         cs_lnum_t         n_cells,
                         const int         b_size[4])
{
  cs_lnum_t  ii, jj, kk;
  cs_lnum_t  db_size[2] = {b_size[0], b_size[0]*b_size[0]};

  if (da != NULL) {
#   pragma omp parallel for private(jj, kk)
    for (ii = 0; ii < n_cells; ii++) {
      for (jj = 0; jj < b_size[0]; jj++) {
        for (kk = 0; kk < b_size[0]; kk++) {
          m_coo[(ii*db_size[1] + jj*db_size[0] + kk)*2]
            = g_coo_num[ii]*b_size[0] + jj;
          m_coo[(ii*db_size[1] + jj*db_size[0] + kk)*2 + 1]
            = g_coo_num[ii]*b_size[0] + kk;
          m_val[ii*db_size[1] + jj*db_size[0] + kk]
            = da[ii*b_size[3] + jj*b_size[2] + kk];
        }
      }
    }
  }
  else {
#   pragma omp parallel for private(jj, kk)
    for (ii = 0; ii < n_cells; ii++) {
      for (jj = 0; jj < b_size[0]; jj++) {
        for (kk = 0; kk < b_size[0]; kk++) {
          m_coo[(ii*db_size[1] + jj*db_size[0] + kk)*2]
            = g_coo_num[ii]*b_size[0] + jj;
          m_coo[(ii*db_size[1] + jj*db_size[0] + kk)*2 + 1]
            = g_coo_num[ii]*b_size[0] + kk;
          m_val[ii*db_size[1] + jj*db_size[0] + kk] = 0.0;
        }
      }
    }
  }
}

/*----------------------------------------------------------------------------
 * Prepare dump of native matrix.
 *
 * parameters:
 *   matrix    <-- Pointer to matrix structure
 *   m_coo     <-- Matrix coefficient coordinates array
 *   m_val     <-- Matrix coefficient values array
 *   g_coo_num <-- Global coordinate numbers
 *
 * returns:
 *   number of matrix entries
 *----------------------------------------------------------------------------*/

static cs_lnum_t
_pre_dump_native(const cs_matrix_t  *matrix,
                 cs_gnum_t          *restrict m_coo,
                 cs_real_t          *restrict m_val,
                 cs_gnum_t          *restrict g_coo_num)
{
  cs_lnum_t  ii, jj, face_id, dump_id;

  const cs_matrix_struct_native_t  *ms = matrix->structure;
  const cs_matrix_coeff_native_t  *mc = matrix->coeffs;

  const cs_real_t  *restrict xa = mc->xa;

  /* diagonal contribution */

  _pre_dump_diag_contrib(mc->da, m_coo, m_val, g_coo_num, ms->n_cells);

  /* non-diagonal terms */

  dump_id = ms->n_cells;

  if (mc->xa != NULL) {

    const cs_lnum_2_t *restrict face_cel_p
      = (const cs_lnum_2_t *restrict)(ms->face_cell);

    if (mc->symmetric) {

      for (face_id = 0; face_id < ms->n_faces; face_id++) {
        ii = face_cel_p[face_id][0];
        jj = face_cel_p[face_id][1];
        m_coo[dump_id*2] = g_coo_num[ii];
        m_coo[dump_id*2 + 1] = g_coo_num[jj];
        m_val[dump_id] = xa[face_id];
        m_coo[dump_id*2 + 2] = g_coo_num[jj];
        m_coo[dump_id*2 + 3] = g_coo_num[ii];
        m_val[dump_id + 1] = xa[face_id];
        dump_id += 2;
      }

    }
    else {

      for (face_id = 0; face_id < ms->n_faces; face_id++) {
        ii = face_cel_p[face_id][0];
        jj = face_cel_p[face_id][1];
        m_coo[dump_id*2] = g_coo_num[ii];
        m_coo[dump_id*2 + 1] = g_coo_num[jj];
        m_val[dump_id] = xa[2*face_id];
        m_coo[dump_id*2 + 2] = g_coo_num[jj];
        m_coo[dump_id*2 + 3] = g_coo_num[ii];
        m_val[dump_id + 1] = xa[2*face_id + 1];
        dump_id += 2;
      }

    }

  }

  return (ms->n_cells + ms->n_faces*2);
}

/*----------------------------------------------------------------------------
 * Prepare dump of native matrix with block diagonal.
 *
 * parameters:
 *   matrix    <-- Pointer to matrix structure
 *   m_coo     <-- Matrix coefficient coordinates array
 *   m_val     <-- Matrix coefficient values array
 *   g_coo_num <-- Global coordinate numbers
 *
 * returns:
 *   number of matrix entries
 *----------------------------------------------------------------------------*/

static cs_lnum_t
_b_pre_dump_native(const cs_matrix_t  *matrix,
                   cs_gnum_t          *restrict m_coo,
                   cs_real_t          *restrict m_val,
                   cs_gnum_t          *restrict g_coo_num)
{
  cs_lnum_t  ii, jj, kk, face_id, dump_id;

  const cs_matrix_struct_native_t  *ms = matrix->structure;
  const cs_matrix_coeff_native_t  *mc = matrix->coeffs;

  const cs_real_t  *restrict xa = mc->xa;
  const int *db_size = matrix->db_size;

  /* block diagonal contribution */

  _b_pre_dump_diag_contrib(mc->da, m_coo, m_val,
                           g_coo_num, ms->n_cells, db_size);

  /* non-diagonal terms */

  dump_id = ms->n_cells*db_size[0]*db_size[0];

  if (mc->xa != NULL) {

    const cs_lnum_2_t *restrict face_cel_p
      = (const cs_lnum_2_t *restrict)(ms->face_cell);

    if (mc->symmetric) {

      for (face_id = 0; face_id < ms->n_faces; face_id++) {
        ii = face_cel_p[face_id][0];
        jj = face_cel_p[face_id][1];
        for (kk = 0; kk < db_size[0]; kk++) {
          m_coo[dump_id*2] = g_coo_num[ii]*db_size[0] + kk;
          m_coo[dump_id*2 + 1] = g_coo_num[jj]*db_size[0] + kk;
          m_val[dump_id] = xa[face_id];
          m_coo[dump_id*2 + 2] = g_coo_num[jj]*db_size[0] + kk;
          m_coo[dump_id*2 + 3] = g_coo_num[ii]*db_size[0] + kk;
          m_val[dump_id + 1] = xa[face_id];
          dump_id += 2;
        }
      }
    }
    else {

      for (face_id = 0; face_id < ms->n_faces; face_id++) {
        ii = face_cel_p[face_id][0];
        jj = face_cel_p[face_id][1];
        for (kk = 0; kk < db_size[0]; kk++) {
          m_coo[dump_id*2] = g_coo_num[ii]*db_size[0] + kk;
          m_coo[dump_id*2 + 1] = g_coo_num[jj]*db_size[0] + kk;
          m_val[dump_id] = xa[face_id*2];
          m_coo[dump_id*2 + 2] = g_coo_num[jj]*db_size[0] + kk;
          m_coo[dump_id*2 + 3] = g_coo_num[ii]*db_size[0] + kk;
          m_val[dump_id + 1] = xa[face_id*2 + 1];
          dump_id += 2;
        }
      }

    }

  }

  return ((ms->n_cells*db_size[0] + ms->n_faces*2) * db_size[0]);
}

/*----------------------------------------------------------------------------
 * Prepare dump of CSR matrix.
 *
 * parameters:
 *   matrix    <-- Pointer to matrix structure
 *   m_coo     <-- Matrix coefficient coordinates array
 *   m_val     <-- Matrix coefficient values array
 *   g_coo_num <-- Global coordinate numbers
 *
 * returns:
 *   number of matrix entries
 *----------------------------------------------------------------------------*/

static cs_lnum_t
_pre_dump_csr(const cs_matrix_t  *matrix,
              cs_gnum_t          *restrict m_coo,
              cs_real_t          *restrict m_val,
              cs_gnum_t          *restrict g_coo_num)
{
  cs_lnum_t  ii, jj, n_cols, dump_id;
  cs_lnum_t  *restrict col_id;
  cs_real_t  *restrict m_row;

  const cs_matrix_struct_csr_t  *ms = matrix->structure;
  const cs_matrix_coeff_csr_t  *mc = matrix->coeffs;
  cs_lnum_t  dump_id_shift = 0;
  cs_lnum_t  n_rows = ms->n_rows;

  if (ms->have_diag == false) {
    assert(0);
#   pragma omp parallel for
    for (ii = 0; ii < n_rows; ii++) {
      m_coo[ii*2] = g_coo_num[ii];
      m_coo[ii*2+1] = g_coo_num[ii];
      m_val[ii] = 0.0;
    }
    dump_id_shift = n_rows;
  }

# pragma omp parallel for private(jj, dump_id, col_id, m_row, n_cols)
  for (ii = 0; ii < n_rows; ii++) {
    col_id = ms->col_id + ms->row_index[ii];
    m_row = mc->val + ms->row_index[ii];
    n_cols = ms->row_index[ii+1] - ms->row_index[ii];
    for (jj = 0; jj < n_cols; jj++) {
      dump_id = ms->row_index[ii] + jj + dump_id_shift;
      m_coo[dump_id*2] = g_coo_num[ii];
      m_coo[dump_id*2+1] = g_coo_num[col_id[jj]];
      m_val[dump_id] = m_row[jj];
    }
  }

  return (ms->row_index[n_rows] + dump_id_shift);
}

/*----------------------------------------------------------------------------
 * Prepare dump of symmetric CSR matrix.
 *
 * parameters:
 *   matrix    <-- Pointer to matrix structure
 *   m_coo     <-- Matrix coefficient coordinates array
 *   m_val     <-- Matrix coefficient values array
 *   g_coo_num <-- Global coordinate numbers
 *
 * returns:
 *   number of matrix entries
 *----------------------------------------------------------------------------*/

static cs_lnum_t
_pre_dump_csr_sym(const cs_matrix_t  *matrix,
                  cs_gnum_t          *restrict m_coo,
                  cs_real_t          *restrict m_val,
                  cs_gnum_t          *restrict g_coo_num)
{
  cs_lnum_t  ii, jj, n_cols;
  cs_lnum_t  *restrict col_id;
  cs_real_t  *restrict m_row;

  const cs_matrix_struct_csr_sym_t  *ms = matrix->structure;
  const cs_matrix_coeff_csr_sym_t  *mc = matrix->coeffs;
  cs_lnum_t  dump_id = 0;
  cs_lnum_t  n_rows = ms->n_rows;
  cs_lnum_t sym_jj_start = 1;

  /* By construction, the matrix has either a full or an empty
     diagonal structure, so testing this on the first row is enough */

  if (ms->col_id[ms->row_index[0]] != 0) {
    sym_jj_start = 0;
#   pragma omp parallel for
    for (ii = 0; ii < n_rows; ii++) {
      m_coo[ii*2] = g_coo_num[ii];
      m_coo[ii*2+1] = g_coo_num[ii];
      m_val[ii] = 0.0;
    }
    dump_id = n_rows;
  }

  for (ii = 0; ii < n_rows; ii++) {
    col_id = ms->col_id + ms->row_index[ii];
    m_row = mc->val + ms->row_index[ii];
    n_cols = ms->row_index[ii+1] - ms->row_index[ii];
    /* Upper triangular + diagonal part */
    for (jj = 0; jj < n_cols; jj++) {
      m_coo[dump_id*2] = g_coo_num[ii];
      m_coo[dump_id*2+1] = g_coo_num[col_id[jj]];
      m_val[dump_id] = m_row[jj];
      dump_id += 1;
    }
    /* Lower triangular part */
    for (jj = sym_jj_start; jj < n_cols; jj++) {
      m_coo[dump_id*2] = g_coo_num[col_id[jj]];
      m_coo[dump_id*2+1] = g_coo_num[ii];
      m_val[dump_id] = m_row[jj];
      dump_id += 1;
    }
  }

  return (dump_id);
}

/*----------------------------------------------------------------------------
 * Prepare dump of MSR matrix.
 *
 * parameters:
 *   matrix    <-- Pointer to matrix structure
 *   m_coo     <-- Matrix coefficient coordinates array
 *   m_val     <-- Matrix coefficient values array
 *   g_coo_num <-- Global coordinate numbers
 *
 * returns:
 *   number of matrix entries
 *----------------------------------------------------------------------------*/

static cs_lnum_t
_pre_dump_msr(const cs_matrix_t  *matrix,
              cs_gnum_t          *restrict m_coo,
              cs_real_t          *restrict m_val,
              cs_gnum_t          *restrict g_coo_num)
{
  cs_lnum_t  ii, jj, n_cols, dump_id;
  cs_lnum_t  *restrict col_id;
  cs_real_t  *restrict m_row;

  const cs_matrix_struct_csr_t  *ms = matrix->structure;
  const cs_matrix_coeff_msr_t  *mc = matrix->coeffs;
  const cs_lnum_t  n_rows = ms->n_rows;

  /* diagonal contribution */

  _pre_dump_diag_contrib(mc->d_val, m_coo, m_val, g_coo_num, ms->n_rows);

  /* extra-diagonal contribution */

  if (mc->x_val != NULL) {
#   pragma omp parallel for private(jj, dump_id, col_id, m_row, n_cols)
    for (ii = 0; ii < n_rows; ii++) {
      col_id = ms->col_id + ms->row_index[ii];
      m_row = mc->x_val + ms->row_index[ii];
      n_cols = ms->row_index[ii+1] - ms->row_index[ii];
      for (jj = 0; jj < n_cols; jj++) {
        dump_id = ms->row_index[ii] + jj + ms->n_rows;
        m_coo[dump_id*2] = g_coo_num[ii];
        m_coo[dump_id*2+1] = g_coo_num[col_id[jj]];
        m_val[dump_id] = m_row[jj];
      }
    }
  }
  else {
#   pragma omp parallel for private(jj, dump_id, col_id, n_cols)
    for (ii = 0; ii < n_rows; ii++) {
      col_id = ms->col_id + ms->row_index[ii];
      n_cols = ms->row_index[ii+1] - ms->row_index[ii];
      for (jj = 0; jj < n_cols; jj++) {
        dump_id = ms->row_index[ii] + jj + ms->n_rows;
        m_coo[dump_id*2] = g_coo_num[ii];
        m_coo[dump_id*2+1] = g_coo_num[col_id[jj]];
        m_val[dump_id] = 0.0;
      }
    }
  }

  return (ms->row_index[n_rows] + ms->n_rows);
}

/*----------------------------------------------------------------------------
 * Prepare dump of MSR matrix, blocked version.
 *
 * parameters:
 *   matrix    <-- Pointer to matrix structure
 *   m_coo     <-- Matrix coefficient coordinates array
 *   m_val     <-- Matrix coefficient values array
 *   g_coo_num <-- Global coordinate numbers
 *
 * returns:
 *   number of matrix entries
 *----------------------------------------------------------------------------*/

static cs_lnum_t
_b_pre_dump_msr(const cs_matrix_t  *matrix,
                cs_gnum_t          *restrict m_coo,
                cs_real_t          *restrict m_val,
                cs_gnum_t          *restrict g_coo_num)
{
  cs_lnum_t  ii, jj, kk, n_cols, dump_id;
  cs_lnum_t  *restrict col_id;
  cs_real_t  *restrict m_row;

  const cs_matrix_struct_csr_t  *ms = matrix->structure;
  const cs_matrix_coeff_msr_t  *mc = matrix->coeffs;
  const int  *db_size = matrix->db_size;
  const cs_lnum_t  n_rows = ms->n_rows;
  const cs_lnum_t  dump_id_shift = ms->n_rows*db_size[0]*db_size[0];

  /* diagonal contribution */

  _b_pre_dump_diag_contrib(mc->d_val, m_coo, m_val,
                           g_coo_num, ms->n_rows, db_size);


  /* extra-diagonal contribution */

  if (mc->x_val != NULL) {
#   pragma omp parallel for private(jj, kk, dump_id, col_id, m_row, n_cols)
    for (ii = 0; ii < n_rows; ii++) {
      col_id = ms->col_id + ms->row_index[ii];
      m_row = mc->x_val + ms->row_index[ii];
      n_cols = ms->row_index[ii+1] - ms->row_index[ii];
      for (jj = 0; jj < n_cols; jj++) {
        for (kk = 0; kk < db_size[0]; kk++) {
          dump_id = (ms->row_index[ii] + jj)*db_size[0] + kk + dump_id_shift;
          m_coo[dump_id*2] = g_coo_num[ii]*db_size[0] + kk;
          m_coo[dump_id*2+1] = g_coo_num[col_id[jj]]*db_size[0] + kk;
          m_val[dump_id] = m_row[jj];
        }
      }
    }
  }
  else {
#   pragma omp parallel for private(jj, kk, dump_id, col_id, n_cols)
    for (ii = 0; ii < n_rows; ii++) {
      col_id = ms->col_id + ms->row_index[ii];
      n_cols = ms->row_index[ii+1] - ms->row_index[ii];
      for (jj = 0; jj < n_cols; jj++) {
        for (kk = 0; kk < db_size[0]; kk++) {
          dump_id = (ms->row_index[ii] + jj)*db_size[0] + kk + dump_id_shift;
          m_coo[dump_id*2] = g_coo_num[ii]*db_size[0] + kk;
          m_coo[dump_id*2+1] = g_coo_num[col_id[jj]]*db_size[0] + kk;
          m_val[dump_id] = 0.0;
        }
      }
    }
  }

  return ((ms->row_index[n_rows])*db_size[0] + dump_id_shift);
}

/*----------------------------------------------------------------------------
 * Write header for dump of matrix to native file.
 *
 * 3 characters are used to define (in order):
 * - the size of cs_gnum_t (int, long, or long long)
 * - the size of floating point values (double, should be size _)
 * - 'l' for little-endian files, 'b' for big-endian files.
 *
 * parameters:
 *   f <-- Pointer to file structure
 *----------------------------------------------------------------------------*/

static void
_write_header_simple(cs_file_t  *f)
{
  unsigned char flags[3] = {(unsigned char) sizeof(cs_gnum_t),
                            (unsigned char) sizeof(double),
                            'b'};

  /* Check if system is "big-endian" or "little-endian" */
  {
    unsigned  int_endian = 0;
    *((char *)(&int_endian)) = '\1';
    if (int_endian == 1)
      flags[2] = 'l';
  }

  assert(sizeof(cs_gnum_t) < 255);
  assert(sizeof(double) < 255); /* should always be 8 */

  cs_file_write_global(f, flags, 1, 3);
}

/*----------------------------------------------------------------------------
 * Locally sort matrix dump data.
 *
 * parameters:
 *   n_entries <-- Number of local matrix entries
 *   m_coords  <-> Matrix coefficient coordinates (interlaced)
 *   m_vals    <-> Matrix coefficient values
 *----------------------------------------------------------------------------*/

static void
_sort_matrix_dump_data(cs_lnum_t   n_entries,
                       cs_gnum_t  *m_coords,
                       double     *m_vals)
{
  cs_lnum_t ii, jj;
  cs_gnum_t *_m_coords;
  double *_m_vals;

  cs_lnum_t *order = cs_order_gnum_s(NULL, m_coords, 2, n_entries);

  BFT_MALLOC(_m_coords, n_entries*2, cs_gnum_t);

  for (ii = 0; ii < n_entries; ii++) {
    jj = order[ii];
    _m_coords[ii*2] = m_coords[jj*2];
    _m_coords[ii*2+1] = m_coords[jj*2+1];
  }
  memcpy(m_coords, _m_coords, n_entries*2*sizeof(cs_gnum_t));

  BFT_FREE(_m_coords);

  BFT_MALLOC(_m_vals, n_entries, double);

  for (ii = 0; ii < n_entries; ii++)
    _m_vals[ii] = m_vals[order[ii]];

  memcpy(m_vals, _m_vals, n_entries*sizeof(double));

  BFT_FREE(_m_vals);

  BFT_FREE(order);
}

/*----------------------------------------------------------------------------
 * Prepare data for matrix dump.
 *
 * Build local arrays with global matrix coordinates and coefficients.
 *
 * parameters:
 *   m         <-- Pointer to matrix structure
 *   n_entries --> Number of local matrix entries
 *   m_coords  --> Matrix coefficient coordinates (interlaced)
 *   m_vals    --> Matrix coefficient values
 *----------------------------------------------------------------------------*/

static void
_prepare_matrix_dump_data(const cs_matrix_t  *m,
                          cs_lnum_t          *n_entries,
                          cs_gnum_t          **m_coords,
                          double             **m_vals)
{
  cs_lnum_t ii, jj;
  cs_lnum_t _n_entries
    = (m->n_cells*m->db_size[0] + m->n_faces*2) * m->db_size[0];
  cs_gnum_t coo_shift = 1, n_g_rows = 0;

  cs_gnum_t *g_coo_num = NULL;
  cs_gnum_t *_m_coords = NULL;
  double *_m_vals = NULL;

  BFT_MALLOC(g_coo_num, m->n_cells_ext, cs_gnum_t);

  n_g_rows = m->n_cells;

#if defined(HAVE_MPI)
  if (cs_glob_n_ranks > 1) {
    cs_gnum_t local_max;
    cs_gnum_t loc_shift = m->n_cells;
    MPI_Scan(&loc_shift, &coo_shift, 1, CS_MPI_GNUM, MPI_SUM, cs_glob_mpi_comm);
    coo_shift = coo_shift + 1 - loc_shift;
    local_max = m->n_cells + coo_shift - 1;
    MPI_Allreduce(&local_max, &n_g_rows, 1, CS_MPI_GNUM, MPI_MAX,
                  cs_glob_mpi_comm);
  }
#endif

  for (ii = 0; ii < m->n_cells; ii++)
    g_coo_num[ii] = ii + coo_shift;

  if (m->halo != NULL)
    cs_halo_sync_untyped(m->halo,
                         CS_HALO_STANDARD,
                         sizeof(cs_gnum_t),
                         g_coo_num);

  /* Allocate arrays */

  BFT_MALLOC(_m_coords, _n_entries*2, cs_gnum_t);
  BFT_MALLOC(_m_vals, _n_entries, double);

  /* Populate arrays based on matrix type */

  switch(m->type) {
  case CS_MATRIX_NATIVE:
    if (m->db_size[3] == 1)
      _n_entries = _pre_dump_native(m, _m_coords, _m_vals, g_coo_num);
    else
      _n_entries = _b_pre_dump_native(m, _m_coords, _m_vals, g_coo_num);
    break;
  case CS_MATRIX_CSR:
    assert(m->db_size[3] == 1);
    _n_entries = _pre_dump_csr(m, _m_coords, _m_vals, g_coo_num);
    break;
  case CS_MATRIX_CSR_SYM:
    assert(m->db_size[3] == 1);
    _n_entries = _pre_dump_csr_sym(m, _m_coords, _m_vals, g_coo_num);
    break;
  case CS_MATRIX_MSR:
    if (m->db_size[3] == 1)
      _n_entries = _pre_dump_msr(m, _m_coords, _m_vals, g_coo_num);
    else
      _n_entries = _b_pre_dump_msr(m, _m_coords, _m_vals, g_coo_num);
    break;
  default:
    bft_error(__FILE__, __LINE__, 0,
              _("Dump of matrixes in %s format\n"
                "is not operational yet."),
              _(cs_matrix_type_name[m->type]));
    break;
  }

  BFT_FREE(g_coo_num);

  /* Sort values */

  _sort_matrix_dump_data(_n_entries, _m_coords, _m_vals);

  /* Remove references to extra periodicity ghost values if present */

  for (ii = 0, jj = 0; ii < _n_entries; ii++) {
    if (_m_coords[ii*2] <= n_g_rows && _m_coords[ii*2+1] <= n_g_rows) {
      _m_coords[jj*2] = _m_coords[ii*2];
      _m_coords[jj*2+1] = _m_coords[ii*2+1];
      _m_vals[jj] = _m_vals[ii];
      jj += 1;
    }
  }
  _n_entries = jj;

  /* Return arrays */

  *n_entries = _n_entries;
  *m_coords = _m_coords;
  *m_vals = _m_vals;
}

#if defined(HAVE_MPI)

/*----------------------------------------------------------------------------
 * Write matrix data to file in parallel mode.
 *
 * Arrays written are freed by this function.
 *
 * The full matrix is written, whether symmetric or not. Row and column
 * coordinats are 1-to-n based.
 *
 * File format:
 *   - number of matrix entries (1 integer of type cs_gnum_t).
 *   - array of row coordinates (n_entries integers of type cs_gnum_t)
 *   - array of column coordinates (n_entries integers of type cs_gnum_t)
 *   - array of matrix coefficients (n_entries values of type double)
 *
 * parameters:
 *   m <-- Pointer to matrix structure
 *   f <-> associated file pointer
 *----------------------------------------------------------------------------*/

static void
_write_matrix_g(const cs_matrix_t  *m,
                cs_file_t          *f)
{
  int  block_rank_step = 1, min_block_size = 0;
  cs_lnum_t  block_size = 0;
  cs_gnum_t  n_glob_ents = 0;

  cs_gnum_t  *b_coords = NULL, *c_coords = NULL, *r_coords = NULL;
  double  *b_vals = NULL;

  cs_block_dist_info_t bi;

  fvm_io_num_t *io_num = NULL;
  cs_part_to_block_t *d = NULL;

  cs_lnum_t  n_entries = 0;
  cs_gnum_t  *m_coords = NULL;
  double  *m_vals = NULL;

  const cs_datatype_t gnum_type
    = (sizeof(cs_gnum_t) == 8) ? CS_UINT64 : CS_UINT32;

  /* Initialization for matrix coefficients */

  _prepare_matrix_dump_data(m, &n_entries, &m_coords, &m_vals);

  /* Initialization for redistribution */

  io_num = fvm_io_num_create_from_adj_s(NULL, m_coords, n_entries, 2);

  n_glob_ents = fvm_io_num_get_global_count(io_num);

  cs_file_get_default_comm(&block_rank_step, &min_block_size, NULL, NULL);

  bi = cs_block_dist_compute_sizes(cs_glob_rank_id,
                                   cs_glob_n_ranks,
                                   block_rank_step,
                                   min_block_size/2,
                                   n_glob_ents);

  d = cs_part_to_block_create_by_gnum(cs_glob_mpi_comm,
                                      bi,
                                      n_entries,
                                      fvm_io_num_get_global_num(io_num));

  /* Write number of entries */

  cs_file_write_global(f, &n_glob_ents, sizeof(cs_gnum_t), 1);

  /* Distribute to blocks */

  block_size = (bi.gnum_range[1] - bi.gnum_range[0]);

  /* Distribute coordinate blocks on ranks */

  if (block_size > 0)
    BFT_MALLOC(b_coords, block_size*2, cs_gnum_t);

  cs_part_to_block_copy_array(d, gnum_type, 2, m_coords, b_coords);

  BFT_FREE(m_coords);

  /* De-interlace coordinates */

  if (block_size > 0) {
   cs_lnum_t  ii;
   BFT_MALLOC(r_coords, block_size, cs_gnum_t);
   BFT_MALLOC(c_coords, block_size, cs_gnum_t);
   for (ii = 0; ii < block_size; ii++) {
     r_coords[ii] = b_coords[ii*2];
     c_coords[ii] = b_coords[ii*2+1];
   }
   BFT_FREE(b_coords);
  }

  /* Write coordinate blocks */

  cs_file_write_block_buffer(f,
                             r_coords,
                             sizeof(cs_gnum_t),
                             1,
                             bi.gnum_range[0],
                             bi.gnum_range[1]);

  cs_file_write_block_buffer(f,
                             c_coords,
                             sizeof(cs_gnum_t),
                             1,
                             bi.gnum_range[0],
                             bi.gnum_range[1]);

  BFT_FREE(c_coords);
  BFT_FREE(r_coords);

  /* Distribute value blocks on ranks */

  if (block_size > 0)
    BFT_MALLOC(b_vals, block_size, double);

  cs_part_to_block_copy_array(d, CS_DOUBLE, 1, m_vals, b_vals);

  BFT_FREE(m_vals);

  /* Write value blocks */

  cs_file_write_block_buffer(f,
                             b_vals,
                             sizeof(double),
                             1,
                             bi.gnum_range[0],
                             bi.gnum_range[1]);

  BFT_FREE(b_vals);

  /* Free matrix coefficient distribution structures */

  cs_part_to_block_destroy(&d);
  io_num = fvm_io_num_destroy(io_num);
}

#endif /* #if defined(HAVE_MPI) */

/*----------------------------------------------------------------------------
 * Write matrix data to file in serial mode.
 *
 * Arrays written are freed by this function.
 *
 * The full matrix is written, whether symmetric or not. Row and column
 * coordinats are 1-to-n based.
 *
 * File format:
 *   - number of matrix entries (1 integer of type cs_gnum_t).
 *   - array of row coordinates (n_entries integers of type cs_gnum_t)
 *   - array of column coordinates (n_entries integers of type cs_gnum_t)
 *   - array of matrix coefficients (n_entries values of type double)
 *
 * parameters:
 *   m <-- Pointer to matrix structure
 *   f <-> associated file pointer
 *----------------------------------------------------------------------------*/

static void
_write_matrix_l(const cs_matrix_t  *m,
                cs_file_t          *f)
{
  cs_lnum_t  ii;
  cs_gnum_t  n_glob_ents = 0;

  cs_gnum_t  *c_coords = NULL, *r_coords = NULL;

  cs_lnum_t  n_entries = 0;
  cs_gnum_t  *m_coords = NULL;
  double  *m_vals = NULL;

  /* Initialization */

  _prepare_matrix_dump_data(m, &n_entries, &m_coords, &m_vals);

  n_glob_ents = n_entries;

  /* Write number of entries */

  cs_file_write_global(f, &n_glob_ents, sizeof(cs_gnum_t), 1);

  /* De-interlace coordinates */

  BFT_MALLOC(r_coords, n_entries, cs_gnum_t);
  BFT_MALLOC(c_coords, n_entries, cs_gnum_t);
  for (ii = 0; ii < n_entries; ii++) {
    r_coords[ii] = m_coords[ii*2];
    c_coords[ii] = m_coords[ii*2+1];
  }
  BFT_FREE(m_coords);

  /* Write coordinate blocks */

  cs_file_write_global(f, r_coords, sizeof(cs_gnum_t), n_entries);
  cs_file_write_global(f, c_coords, sizeof(cs_gnum_t), n_entries);

  BFT_FREE(r_coords);
  BFT_FREE(c_coords);

  /* Write value blocks */

  cs_file_write_global(f, m_vals, sizeof(double), n_entries);

  BFT_FREE(m_vals);
}

#if defined(HAVE_MPI)

/*----------------------------------------------------------------------------
 * Write vector data to file in parallel mode.
 *
 * File format:
 *   - vector size matrix entries (1 integer of type cs_gnum_t).
 *   - array of vector values (n_elts values of type double)
 *
 * parameters:
 *   n_elts <-- local number of matrix entries
 *   vals   <-- vector element values
 *   f      <-> associated file pointer
 *----------------------------------------------------------------------------*/

static void
_write_vector_g(cs_lnum_t         n_elts,
                const cs_real_t  *vals,
                cs_file_t        *f)
{
  cs_lnum_t  ii;

  int        block_rank_step = 1, min_block_size = 0;
  cs_lnum_t  block_size = 0;
  cs_gnum_t  coo_shift = 1;
  cs_gnum_t  local_max = 0, n_glob_ents = 0;

  cs_gnum_t  *g_elt_num = NULL;
  double  *b_vals = NULL;

  cs_block_dist_info_t bi;

  cs_part_to_block_t *d = NULL;

  cs_gnum_t loc_shift = n_elts;
  MPI_Scan(&loc_shift, &coo_shift, 1, CS_MPI_GNUM, MPI_SUM, cs_glob_mpi_comm);
  coo_shift = coo_shift - loc_shift;

  /* Get maximum global number value */

  if (n_elts > 0)
    local_max = n_elts + coo_shift;

  MPI_Allreduce(&local_max, &n_glob_ents, 1, CS_MPI_GNUM, MPI_MAX,
                cs_glob_mpi_comm);

  BFT_MALLOC(g_elt_num, n_elts, cs_gnum_t);

  for (ii = 0; ii < n_elts; ii++)
    g_elt_num[ii] = ii + coo_shift + 1;

  cs_file_get_default_comm(&block_rank_step, &min_block_size, NULL, NULL);

  /* Redistribution structures */

  bi = cs_block_dist_compute_sizes(cs_glob_rank_id,
                                   cs_glob_n_ranks,
                                   block_rank_step,
                                   min_block_size/2,
                                   n_glob_ents);

  d = cs_part_to_block_create_by_gnum(cs_glob_mpi_comm,
                                      bi,
                                      n_elts,
                                      g_elt_num);

  /* Write number of entries */

  cs_file_write_global(f, &n_glob_ents, sizeof(cs_gnum_t), 1);

  /* Distribute to blocks */

  block_size = (bi.gnum_range[1] - bi.gnum_range[0]);

  if (block_size > 0)
    BFT_MALLOC(b_vals, block_size, double);

  if (sizeof(cs_real_t) != sizeof(double)) {
    double  *p_vals = NULL;
    BFT_MALLOC(p_vals, n_elts, double);
    for (ii = 0; ii < n_elts; ii++)
      p_vals[ii] = vals[ii];
    cs_part_to_block_copy_array(d, CS_DOUBLE, 1, p_vals, b_vals);
    BFT_FREE(p_vals);
  }
  else
    cs_part_to_block_copy_array(d, CS_DOUBLE, 1, vals, b_vals);

  /* Write value blocks */

  cs_file_write_block_buffer(f,
                             b_vals,
                             sizeof(double),
                             1,
                             bi.gnum_range[0],
                             bi.gnum_range[1]);

  BFT_FREE(b_vals);

  /* Free distribution structures */

  cs_part_to_block_destroy(&d);

  BFT_FREE(g_elt_num);
}

#endif /* #if defined(HAVE_MPI) */

/*----------------------------------------------------------------------------
 * Write vector data to file in serial mode.
 *
 * File format:
 *   - vector size matrix entries (1 integer of type cs_gnum_t).
 *   - array of vector values (n_elts values of type double)
 *
 * parameters:
 *   n_elts <-- local number of matrix entries
 *   vals   <-- vector element values
 *   f      <-> associated file pointer
 *----------------------------------------------------------------------------*/

static void
_write_vector_l(cs_lnum_t         n_elts,
                const cs_real_t  *vals,
                cs_file_t        *f)
{
  cs_gnum_t  n_glob_ents = n_elts;

  /* Write number of entries */

  cs_file_write_global(f, &n_glob_ents, sizeof(cs_gnum_t), 1);

  /* Write values */

  if (sizeof(cs_real_t) != sizeof(double)) {
    cs_lnum_t ii;
    double  *p_vals = NULL;
    BFT_MALLOC(p_vals, n_elts, double);
    for (ii = 0; ii < n_elts; ii++)
      p_vals[ii] = vals[ii];
    cs_file_write_global(f, p_vals, sizeof(double), n_elts);
    BFT_FREE(p_vals);
  }
  else
    cs_file_write_global(f, vals, sizeof(double), n_elts);
}

/*! (DOXYGEN_SHOULD_SKIP_THIS) \endcond */

/*============================================================================
 * Public function definitions
 *============================================================================*/

/*----------------------------------------------------------------------------
 * Compute diagonal dominance metric.
 *
 * parameters:
 *   matrix <-- pointer to matrix structure
 *   dd     --> diagonal dominance (normalized)
 *----------------------------------------------------------------------------*/

void
cs_matrix_diag_dominance(const cs_matrix_t  *matrix,
                         cs_real_t           dd[])
{
  const cs_halo_t *halo = matrix->halo;

  switch(matrix->type) {
  case CS_MATRIX_NATIVE:
    if (matrix->db_size[3] == 1)
      _diag_dom_native(matrix, dd);
    else
      _b_diag_dom_native(matrix, dd);
    break;
  case CS_MATRIX_CSR:
    assert(matrix->db_size[3] == 1);
    _diag_dom_csr(matrix, dd);
    break;
  case CS_MATRIX_CSR_SYM:
    assert(matrix->db_size[3] == 1);
    _diag_dom_csr_sym(matrix, dd);
    break;
  case CS_MATRIX_MSR:
    if (matrix->db_size[3] == 1)
      _diag_dom_msr(matrix, dd);
    else
      _b_diag_dom_msr(matrix, dd);
    break;
    break;
  default:
    bft_error(__FILE__, __LINE__, 0,
              _("Extraction of diagonal dominance of matrixes in %s format\n"
                "is not operational yet."),
              _(cs_matrix_type_name[matrix->type]));
    break;
  }

  /* Sync ghost cells as a precaution */

  if (halo != NULL) {
    if (matrix->db_size[3] == 1)
      cs_halo_sync_var(halo, CS_HALO_STANDARD, dd);
    else {
      cs_halo_sync_var_strided(halo, CS_HALO_STANDARD, dd, matrix->db_size[1]);
      if (halo->n_transforms > 0 && matrix->db_size[0] == 3)
        cs_halo_perio_sync_var_vect(halo,
                                    CS_HALO_STANDARD,
                                    dd,
                                    matrix->db_size[1]);
    }
  }
}

/*----------------------------------------------------------------------------
 * Dump a linear system matrix and right-hand side to file.
 *
 * parameters:
 *   matrix <-- pointer to matrix structure
 *   rhs    <-- right hand side vector
 *   name   <-- identifier string used in file name
 *----------------------------------------------------------------------------*/

void
cs_matrix_dump_linear_system(const cs_matrix_t  *matrix,
                             const cs_real_t     rhs[],
                             const char         *name)
{
  char filename[64];
  cs_gnum_t n_g_rows = matrix->n_cells;

  cs_file_t  *f = NULL;

#if defined(HAVE_MPI)
  if (cs_glob_n_ranks > 1) {
    cs_gnum_t n_l_rows = matrix->n_cells;
    MPI_Allreduce(&n_l_rows, &n_g_rows, 1, CS_MPI_GNUM, MPI_SUM,
                  cs_glob_mpi_comm);
  }
#endif

  snprintf(filename, 63, "%s_%010llu", name, (unsigned long long)n_g_rows);
  filename[63] = '\0';

  f = cs_file_open_default(filename, CS_FILE_MODE_WRITE);

  _write_header_simple(f);

#if defined(HAVE_MPI)
  if (cs_glob_n_ranks > 1) {
    _write_matrix_g(matrix, f);
    _write_vector_g(matrix->n_cells, rhs, f);
  }
#endif
  if (cs_glob_n_ranks == 1) {
    _write_matrix_l(matrix, f);
    _write_vector_l(matrix->n_cells, rhs, f);
  }

  f = cs_file_free(f);
}

/*----------------------------------------------------------------------------
 * Test matrix dump operations.
 *
 * parameters:
 *   n_cells     <-- number of local cells
 *   n_cells_ext <-- number of cells including ghost cells (array size)
 *   n_faces     <-- local number of internal faces
 *   cell_num    <-- global cell numbers (1 to n)
 *   face_cell   <-- face -> cells connectivity (1 to n)
 *   halo        <-- cell halo structure
 *   numbering   <-- vectorization or thread-related numbering info, or NULL
 *----------------------------------------------------------------------------*/

void
cs_matrix_dump_test(cs_lnum_t              n_cells,
                    cs_lnum_t              n_cells_ext,
                    cs_lnum_t              n_faces,
                    const cs_gnum_t       *cell_num,
                    const cs_lnum_2_t     *face_cell,
                    const cs_halo_t       *halo,
                    const cs_numbering_t  *numbering)
{
  cs_lnum_t  ii;
  int  test_id;

  cs_real_t  *da = NULL, *xa = NULL, *rhs = NULL;
  int diag_block_size[4] = {3, 3, 3, 9};
  int extra_diag_block_size[4] = {1, 1, 1, 1};

  const int n_tests = 7;
  const char *name[] = {"matrix_native",
                        "matrix_native_sym",
                        "matrix_native_block",
                        "matrix_csr",
                        "matrix_csr_sym",
                        "matrix_msr",
                        "matrix_msr_block"};
  const cs_matrix_type_t type[] = {CS_MATRIX_NATIVE,
                                   CS_MATRIX_NATIVE,
                                   CS_MATRIX_NATIVE,
                                   CS_MATRIX_CSR,
                                   CS_MATRIX_CSR_SYM,
                                   CS_MATRIX_MSR,
                                   CS_MATRIX_MSR};
  const bool sym_flag[] = {false, true, false, false, true, false, false};
  const int block_flag[] = {0, 0, 1, 0, 0, 0, 1};

  /* Allocate and initialize  working arrays */
  /*-----------------------------------------*/

  BFT_MALLOC(rhs, n_cells_ext*diag_block_size[1], cs_real_t);

  BFT_MALLOC(da, n_cells_ext*diag_block_size[3], cs_real_t);
  BFT_MALLOC(xa, n_faces*2, cs_real_t);

# pragma omp parallel for
  for (ii = 0; ii < n_cells_ext*diag_block_size[3]; ii++)
    da[ii] = 1.0 + ii*0.1/n_cells_ext;
# pragma omp parallel for
  for (ii = 0; ii < n_cells_ext*diag_block_size[1]; ii++)
    rhs[ii] = ii*0.1/n_cells_ext;

# pragma omp parallel for
  for (ii = 0; ii < n_faces; ii++) {
    xa[ii*2] = 0.5*(1.0 + ii*1.0/n_faces);
    xa[ii*2 + 1] = -0.5*(1.0 + ii*1.0/n_faces);
  }

  /* Loop on variant types */
  /*-----------------------*/

  for (test_id = 0; test_id < n_tests; test_id++) {

    int *_diag_block_size = (block_flag[test_id]) ? diag_block_size : NULL;
    int *_extra_diag_block_size = (block_flag[test_id]-1) ? extra_diag_block_size : NULL;

    cs_matrix_structure_t
      *ms = cs_matrix_structure_create(type[test_id],
                                       true,
                                       n_cells,
                                       n_cells_ext,
                                       n_faces,
                                       cell_num,
                                       face_cell,
                                       halo,
                                       numbering);
    cs_matrix_t *m = cs_matrix_create(ms);

    cs_matrix_set_coefficients(m,
                               sym_flag[test_id],
                               _diag_block_size,
                               _extra_diag_block_size,
                               da,
                               xa);

    cs_matrix_dump_linear_system(m, rhs, name[test_id]);

    cs_matrix_release_coefficients(m);

    cs_matrix_destroy(&m);
    cs_matrix_structure_destroy(&ms);
  }

  BFT_FREE(rhs);

  BFT_FREE(da);
  BFT_FREE(xa);
}

/*----------------------------------------------------------------------------*/

END_C_DECLS
