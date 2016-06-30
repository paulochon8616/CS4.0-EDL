#ifndef __CS_MULTIGRID_H__
#define __CS_MULTIGRID_H__

/*============================================================================
 * Multigrid solver.
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
#include "cs_sles.h"
#include "cs_sles_it.h"

/*----------------------------------------------------------------------------*/

BEGIN_C_DECLS

/*============================================================================
 * Macro definitions
 *============================================================================*/

/*============================================================================
 * Type definitions
 *============================================================================*/

/* Multigrid linear solver context (opaque) */

typedef struct _cs_multigrid_t  cs_multigrid_t;

/*============================================================================
 *  Global variables
 *============================================================================*/

/*=============================================================================
 * Public function prototypes
 *============================================================================*/

/*----------------------------------------------------------------------------
 * Initialize multigrid solver API.
 *----------------------------------------------------------------------------*/

void
cs_multigrid_initialize(void);

/*----------------------------------------------------------------------------
 * Finalize multigrid solver API.
 *----------------------------------------------------------------------------*/

void
cs_multigrid_finalize(void);

/*----------------------------------------------------------------------------
 * Indicate if multigrid solver API is used for at least one system.
 *
 * returns:
 *   true if at least one system uses a multigrid solver, false otherwise
 *----------------------------------------------------------------------------*/

bool
cs_multigrid_needed(void);

/*----------------------------------------------------------------------------
 * Define and associate a multigrid sparse linear system solver
 * for a given field or equation name.
 *
 * If this system did not previously exist, it is added to the list of
 * "known" systems. Otherwise, its definition is replaced by the one
 * defined here.
 *
 * This is a utility function: if finer control is needed, see
 * cs_sles_define() and cs_multigrid_create().
 *
 * Note that this function returns a pointer directly to the multigrid solver
 * management structure. This may be used to set further options, for
 * example calling cs_multigrid_set_coarsening_options() and
 * cs_multigrid_set_solver_options().
 * If needed, cs_sles_find() may be used to obtain a pointer to the
 * matching cs_sles_t container.
 *
 * parameters:
 *   f_id <-- associated field id, or < 0
 *   name <-- associated name if f_id < 0, or NULL
 *
 * \return  pointer to new multigrid info and context
 */
/*----------------------------------------------------------------------------*/

cs_multigrid_t *
cs_multigrid_define(int          f_id,
                    const char  *name);

/*----------------------------------------------------------------------------
 * Create multigrid linear system solver info and context.
 *
 * The multigrid variant is an ACM (Additive Corrective Multigrid) method.
 *
 * returns:
 *   pointer to new multigrid info and context
 *----------------------------------------------------------------------------*/

cs_multigrid_t *
cs_multigrid_create(void);

/*----------------------------------------------------------------------------
 * Destroy multigrid linear system solver info and context.
 *
 * parameters:
 *   context  <-> pointer to multigrid linear solver info
 *                (actual type: cs_multigrid_t  **)
 *----------------------------------------------------------------------------*/

void
cs_multigrid_destroy(void  **context);

/*----------------------------------------------------------------------------
 * Create multigrid sparse linear system solver info and context
 * based on existing info and context.
 *
 * parameters:
 *   context <-- pointer to reference info and context
 *               (actual type: cs_multigrid_t  *)
 *
 * returns:
 *   pointer to newly created solver info object
 *   (actual type: cs_multigrid_t  *)
 *----------------------------------------------------------------------------*/

void *
cs_multigrid_copy(const void  *context);

/*----------------------------------------------------------------------------
 * Set multigrid coarsening parameters.
 *
 * parameters:
 *   mg                <-> pointer to multigrid info and context
 *   aggregation_limit <-- maximum allowed fine cells per coarse cell
 *   coarsening_type   <-- coarsening type:
 *                          0: algebraic, natural face traversal;
 *                          1: algebraic, face traveral by criteria;
 *                          2: algebraic, Hilbert face traversal;
 *   n_max_levels      <-- maximum number of grid levels
 *   min_g_cells       <-- global number of cells on coarse grids
 *                         under which no coarsening occurs
 *   p0p1_relax        <-- p0/p1 relaxation_parameter
 *   verbosity         <-- verbosity level
 *   postprocess       <-- if > 0, postprocess coarsening
 *                         (using coarse cell numbers modulo this value)
 *----------------------------------------------------------------------------*/

void
cs_multigrid_set_coarsening_options(cs_multigrid_t  *mg,
                                    int              aggregation_limit,
                                    int              coarsening_type,
                                    int              n_max_levels,
                                    cs_gnum_t        min_g_cells,
                                    double           p0p1_relax,
                                    int              postprocess_block_size);

/*----------------------------------------------------------------------------
 * Set multigrid parameters for associated iterative solvers.
 *
 * parameters:
 *   mg                     <-> pointer to multigrid info and context
 *   descent_smoother_type  <-- type of smoother for descent
 *   ascent_smoother_type   <-- type of smoother for ascent
 *   coarse_solver_type     <-- type of solver
 *   n_max_cycles           <-- maximum number of cycles
 *   n_max_iter_descent     <-- maximum iterations per descent phase
 *   n_max_iter_ascent      <-- maximum iterations per descent phase
 *   n_max_iter_coarse      <-- maximum iterations per coarsest solution
 *   poly_degree_descent    <-- preconditioning polynomial degree
 *                              for descent phases (0: diagonal)
 *   poly_degree_ascent     <-- preconditioning polynomial degree
 *                              for ascent phases (0: diagonal)
 *   poly_degree_coarse     <-- preconditioning polynomial degree
 *                              for coarse solver  (0: diagonal)
 *   precision_mult_descent <-- precision multiplier for descent phases
 *                              (levels >= 1)
 *   precision_mult_ascent  <-- precision multiplier for ascent phases
 *   precision_mult_coarse  <-- precision multiplier for coarsest grid
 *----------------------------------------------------------------------------*/

void
cs_multigrid_set_solver_options(cs_multigrid_t     *mg,
                                cs_sles_it_type_t   descent_smoother_type,
                                cs_sles_it_type_t   ascent_smoother_type,
                                cs_sles_it_type_t   coarse_solver_type,
                                int                 n_max_cycles,
                                int                 n_max_iter_descent,
                                int                 n_max_iter_ascent,
                                int                 n_max_iter_coarse,
                                int                 poly_degree_descent,
                                int                 poly_degree_ascent,
                                int                 poly_degree_coarse,
                                double              precision_mult_descent,
                                double              precision_mult_ascent,
                                double              precision_mult_coarse);

/*----------------------------------------------------------------------------
 * Setup multigrid sparse linear equation solver.
 *
 * parameters:
 *   context   <-> pointer to multigrid info and context
 *                 (actual type: cs_multigrid_t  *)
 *   name      <-- pointer to name of linear system
 *   a         <-- associated matrix
 *   verbosity <-- associated verbosity
 *----------------------------------------------------------------------------*/

void
cs_multigrid_setup(void               *context,
                   const char         *name,
                   const cs_matrix_t  *a,
                   int                 verbosity);

/*----------------------------------------------------------------------------
 * Call multigrid sparse linear equation solver.
 *
 * parameters:
 *   context       <-> pointer to iterative sparse linear solver info
 *                     (actual type: cs_multigrid_t  *)
 *   name          <-- pointer to name of linear system
 *   a             <-- matrix
 *   verbosity     <-- associated verbosity
 *   rotation_mode <-- halo update option for rotational periodicity
 *   precision     <-- solver precision
 *   r_norm        <-- residue normalization
 *   n_iter        --> number of iterations
 *   residue       --> residue
 *   rhs           <-- right hand side
 *   vx            <-> system solution
 *   aux_size      <-- number of elements in aux_vectors
 *   aux_vectors   --- optional working area (internal allocation if NULL)
 *
 * returns:
 *   convergence state
 *----------------------------------------------------------------------------*/

cs_sles_convergence_state_t
cs_multigrid_solve(void                *context,
                   const char          *name,
                   const cs_matrix_t   *a,
                   int                  verbosity,
                   cs_halo_rotation_t   rotation_mode,
                   double               precision,
                   double               r_norm,
                   int                 *n_iter,
                   double              *residue,
                   const cs_real_t     *rhs,
                   cs_real_t           *vx,
                   size_t               aux_size,
                   void                *aux_vectors);

/*----------------------------------------------------------------------------
 * Free iterative sparse linear equation solver setup context.
 *
 * Note that this function should free resolution-related data, such as
 * buffers and preconditioning but doesd not free the whole context,
 * as info used for logging (especially performance data) is maintained.

 * parameters:
 *   context <-> pointer to iterative sparse linear solver info
 *               (actual type: cs_multigrid_t  *)
 *----------------------------------------------------------------------------*/

void
cs_multigrid_free(void  *context);

/*----------------------------------------------------------------------------
 * Log sparse linear equation solver info.
 *
 * parameters:
 *   context  <-> pointer to iterative sparse linear solver info
 *                (actual type: cs_multigrid_t  *)
 *   log_type <-- log type
 *----------------------------------------------------------------------------*/

void
cs_multigrid_log(const void  *context,
                 cs_log_t     log_type);

/*----------------------------------------------------------------------------
 * Error handler for multigrid sparse linear equation solver.
 *
 * In case of divergence or breakdown, this error handler outputs
 * postprocessing data to assist debugging, then aborts the run.
 * It does nothing in case the maximum iteration count is reached.
 *
 * parameters:
 *   context       <-> pointer to multigrid sparse linear system solver info
 *                     (actual type: cs_multigrid_t  *)
 *   name          <-- pointer to name of linear system
 *   state         <-- convergence status
 *   a             <-- matrix
 *   rotation_mode <-- halo update option for rotational periodicity
 *   rhs           <-- right hand side
 *   vx            <-> system solution
 */
/*----------------------------------------------------------------------------*/

void
cs_multigrid_error_post_and_abort(void                         *context,
                                  cs_sles_convergence_state_t   state,
                                  const char                   *name,
                                  const cs_matrix_t            *a,
                                  cs_halo_rotation_t            rotation_mode,
                                  const cs_real_t              *rhs,
                                  cs_real_t                    *vx);

/*----------------------------------------------------------------------------*/

END_C_DECLS

#endif /* __CS_MULTIGRID_H__ */
