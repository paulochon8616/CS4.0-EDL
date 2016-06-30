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

#include "cs_base.h"
#include "cs_blas.h"
#include "cs_grid.h"
#include "cs_halo.h"
#include "cs_log.h"
#include "cs_matrix.h"
#include "cs_matrix_default.h"
#include "cs_mesh.h"
#include "cs_mesh_quantities.h"
#include "cs_parall.h"
#include "cs_post.h"
#include "cs_sles.h"
#include "cs_sles_it.h"
#include "cs_timer.h"

/*----------------------------------------------------------------------------
 *  Header for the current file
 *----------------------------------------------------------------------------*/

#include "cs_multigrid.h"

/*----------------------------------------------------------------------------*/

BEGIN_C_DECLS

/*! \cond DOXYGEN_SHOULD_SKIP_THIS */

/*=============================================================================
 * Local Macro Definitions
 *============================================================================*/

#define EPZERO  1.E-12
#define RINFIN  1.E+30

#if !defined(HUGE_VAL)
#define HUGE_VAL  1.E+12
#endif

/* Minimum size for OpenMP loops (needs benchmarking to adjust) */
#define CS_THR_MIN 128

/* SIMD unit size to ensure SIMD alignement (2 to 4 required on most
 * current architectures, so 16 should be enough on most architectures
 * through at least 2012) */

#define CS_SIMD_SIZE(s) (((s-1)/16+1)*16)

/*=============================================================================
 * Local Type Definitions
 *============================================================================*/

/*----------------------------------------------------------------------------
 * Local Structure Definitions
 *----------------------------------------------------------------------------*/

/* Basic per linear system options and logging */
/*---------------------------------------------*/

typedef struct _cs_multigrid_info_t {

  /* Settings */

  cs_sles_it_type_t    type[3];             /* Descent/ascent smoother
                                               and solver type */

  int                  n_max_cycles;        /* Maximum allowed cycles */

  int                  n_max_iter[3];       /* maximum iterations allowed
                                               (descent/ascent/coarse) */
  int                  poly_degree[3];      /* polynomial preconditioning degree
                                               (descent/ascent/coarse) */

  double               precision_mult[3];   /* solver precision multiplier
                                               (descent/ascent/coarse) */

  /* Logging */

  unsigned             n_calls[2];          /* Number of times grids built
                                               (0) or solved (1) */

  unsigned long long   n_levels_tot;        /* Total accumulated number of
                                               grid levels built */
  unsigned             n_levels[3];         /* Number of grid levels:
                                               [last, min, max] */

  unsigned             n_cycles[3];         /* Number of cycles for
                                               system resolution:
                                               [min, max, total] */

  cs_timer_counter_t   t_tot[2];            /* Total time used:
                                               [build, solve] */

} cs_multigrid_info_t;

/* Per level info and logging */
/*----------------------------*/

typedef struct _cs_multigrid_level_info_t {

  unsigned long long   n_ranks[4];          /* Number of ranks for this level:
                                               [last, min, max, total] */
  unsigned long long   n_g_cells[4];        /* Global number of cells
                                               (last, min, max, total) */
  unsigned long long   n_elts[3][4];        /* Mean number of cells,
                                               cells + ghosts, and faces
                                               across ranks (last, min, max,
                                               total) */
  double               unbalance[3][4];     /* Unbalance for cells, cells
                                               + ghosts, and faces
                                               (last, min, max, total) */

  unsigned long long   n_it_solve[4];       /* Number of iterations for
                                               solving [last, min, max, total] */
  unsigned long long   n_it_ds_smoothe[4];  /* Number of iterations for
                                               descent smoothing:
                                                 [last, min, max, total] */
  unsigned long long   n_it_as_smoothe[4];  /* Number of iterations for
                                               ascent smoothing:
                                                 [last, min, max, total] */

  unsigned             n_calls[6];          /* Total number of calls:
                                               build, solve, descent smoothe,
                                               ascent smoothe, restrict from
                                               finer, prolong to finer */

  cs_timer_counter_t   t_tot[6];            /* Total timers count:
                                               [build, solve, descent smoothe,
                                               ascent smoothe, restrict from
                                               finer, prolong to finer] */

} cs_multigrid_level_info_t;

/* Grid hierarchy */
/*----------------*/

typedef struct _cs_multigrid_setup_data_t {

  /* Setup */

  unsigned        n_levels;           /* Current number of grid levels */
  unsigned        n_levels_alloc;     /* Allocated number of grid levels */

  cs_grid_t     **grid_hierarchy;     /* Array of grid pointers */
  cs_sles_it_t  **sles_hierarchy;     /* Pointer to contexts for  associated
                                         iterative solvers (i*2: descent, coarse;
                                         i*2+1: ascent) */

  /* Arrays used only for solving, but maintained until free,
     so as to be usable by convergence error handler. */

  double         exit_initial_residue;  /* Last level initial residue */
  double         exit_residue;          /* Last residue */
  int            exit_level;            /* Last level during solve */
  int            exit_cycle_id;         /* Last cycle id during solve */

  cs_real_t     *rhs_vx_buf;            /* Coarse grid "right hand sides"
                                           and corrections buffer */
  cs_real_t    **rhs_vx;                /* Coarse grid "right hand sides"
                                           and corrections */

} cs_multigrid_setup_data_t;

/* Grid hierarchy */
/*----------------*/

struct _cs_multigrid_t {

  /* Settings */

  int        aggregation_limit;  /* Maximum allowed fine cells per coarse cell */
  int        coarsening_type;    /* Coarsening traversal type:
                                    0: algebraic with natural face traversal;
                                    1: algebraic with face traveral by criteria;
                                    2: algebraic with Hilbert face traversal; */
  int        n_levels_max;       /* Maximum number of grid levels */
  cs_gnum_t  n_g_cells_min;      /* Global number of cells on coarse grids
                                    under which no coarsening occurs */

  int        post_cell_max;      /* If > 0, activates postprocessing of
                                    coarsening, projecting coarse cell
                                    numbers (modulo post_cell_max)
                                    on the base grid */

  double     p0p1_relax;         /* p0/p1 relaxation_parameter */

  /* Data for postprocessing callback */

  int        n_levels_post;      /* Current number of postprocessed levels */

  int      **post_cell_num;      /* If post_cell_max > 0, array of
                                    (n_levels - 1) arrays of projected
                                    coarse cell numbers on the base grid */

  int      **post_cell_rank;     /* If post_cell_max > 0 and grid merging
                                    is active, array of (n_levels - 1) arrays
                                    of projected coarse cell ranks on the
                                    base grid */
  char      *post_name;          /* Name for postprocessing */

  /* Options and maintained state (statistics) */

  cs_multigrid_level_info_t  *lv_info;      /* Info for each level */
  cs_multigrid_info_t         info;         /* Base multigrid info */

  /* Data available between "setup" and "solve" states */

  cs_multigrid_setup_data_t  *setup_data;   /* setup data */

};

/*============================================================================
 *  Global variables
 *============================================================================*/

static unsigned  _multigrid_in_use = false; /* Used for logging */

/*============================================================================
 * Private function definitions
 *============================================================================*/

/*----------------------------------------------------------------------------
 * Initialize multigrid info structure.
 *
 * parameters:
 *   name <-- system name
 *   info <-- pointer to multigrid info structure
 *----------------------------------------------------------------------------*/

static void
_multigrid_info_init(cs_multigrid_info_t *info)
{
  int i;

  /* Options */

  info->type[0] = CS_SLES_PCG;
  info->type[1] = CS_SLES_PCG;
  info->type[2] = CS_SLES_PCG;

  info->n_max_cycles = 100;

  info->n_max_iter[0] = 10;
  info->n_max_iter[1] = 10;
  info->n_max_iter[2] = 10000;

  info->poly_degree[0] = 0;
  info->poly_degree[1] = 0;
  info->poly_degree[2] = 0;

  /* In theory, one should increase precision on coarsest mesh,
     but in practice, it is more efficient to have a lower precision,
     so we choose coarse_precision = global_precision; */

  info->precision_mult[0] = 1.;
  info->precision_mult[1] = 1.;
  info->precision_mult[2] = 1.;

  /* Counting and timing */

  for (i = 0; i < 2; i++)
    info->n_calls[i] = 0;

  info->n_levels_tot = 0;

  for (i = 0; i < 3; i++) {
    info->n_levels[i] = 0;
    info->n_cycles[i] = 0;
  }

  for (i = 0; i < 2; i++)
    CS_TIMER_COUNTER_INIT(info->t_tot[i]);
}

/*----------------------------------------------------------------------------
 * Initialize multigrid level info structure.
 *
 * parameters:
 *   name <-- system name
 *   info <-- pointer to multigrid info structure
 *----------------------------------------------------------------------------*/

static void
_multigrid_level_info_init(cs_multigrid_level_info_t *info)
{
  int i;

  memset(info, 0, sizeof(cs_multigrid_level_info_t));

  for (i = 0; i < 3; i++) {
    info->unbalance[i][0] = HUGE_VALF;
    info->unbalance[i][1] = 0.;
  }

  for (i = 0; i < 6; i++)
    CS_TIMER_COUNTER_INIT(info->t_tot[i]);
}

/*----------------------------------------------------------------------------
 * Output information regarding multigrid options.
 *
 * parameters:
 *   mg <-> pointer to multigrid structure
 *----------------------------------------------------------------------------*/

static void
_multigrid_setup_log(const cs_multigrid_t *mg)
{
  cs_log_printf(CS_LOG_SETUP,
                _("  Solver type:                       multigrid\n"
                  "  Coarsening type:                   %s\n"
                  "    Max fine cells per coarse cell:  %d\n"
                  "    Maximum number of levels :       %d\n"
                  "    Minimum number of coarse cells:  %llu\n"
                  "    P0/P1 relaxation parameter:      %g\n"
                  "  Maximum number of cycles:          %d\n"),
                _(cs_grid_coarsening_type_name[mg->coarsening_type]),
                mg->aggregation_limit,
                mg->n_levels_max, (unsigned long long)(mg->n_g_cells_min),
                mg->p0p1_relax, mg->info.n_max_cycles);

  const char *stage_name[] = {"Descent smoother",
                              "Ascent smoother",
                              "Coarsest level solver"};

  for (int i = 0; i < 3; i++) {
    cs_log_printf(CS_LOG_SETUP,
                  _("  %s:\n"
                    "    Type:                            %s\n"
                    "    Preconditioning:                 "),
                  _(stage_name[i]),
                  _(cs_sles_it_type_name[mg->info.type[i]]));

    if (mg->info.poly_degree[i] < 0)
      cs_log_printf(CS_LOG_SETUP, _("none\n"));
    else if (mg->info.poly_degree[i] == 0)
      cs_log_printf(CS_LOG_SETUP, _("diagonal\n"));
    else
      cs_log_printf(CS_LOG_SETUP, _("polynomial, degree %d\n"),
                      mg->info.poly_degree[i]);
    cs_log_printf(CS_LOG_SETUP,
                  _("    Maximum number of iterations:    %d\n"
                    "    Precision multiplier:            %g\n"),
                  mg->info.n_max_iter[i],
                  mg->info.precision_mult[i]);
  }

  cs_log_printf(CS_LOG_SETUP,
                _("  Postprocess coarsening:            %d\n"),
                mg->post_cell_max);
}

/*----------------------------------------------------------------------------
 * Output information regarding multigrid resolution.
 *
 * parameters:
 *   mg <-> pointer to multigrid structure
 *----------------------------------------------------------------------------*/

static void
_multigrid_performance_log(const cs_multigrid_t *mg)
{
  unsigned i;

  unsigned long long n_builds_denom = CS_MAX(mg->info.n_calls[0], 1);
  unsigned long long n_solves_denom = CS_MAX(mg->info.n_calls[1], 1);
  int n_lv_min = mg->info.n_levels[1];
  int n_lv_max = mg->info.n_levels[2];
  int n_lv_mean = (int)(mg->info.n_levels_tot / n_builds_denom);
  int n_cy_mean = (int)(mg->info.n_cycles[2] / n_solves_denom);

  char tmp_s[6][64] =  {"", "", "", "", "", ""};
  const char *stage_name[2] = {N_("Construction:"), N_("Resolution:")};
  const char *lv_stage_name[6] = {N_("build:"), N_("solve:"),
                                  N_("descent smoothe:"), N_("ascent smoothe:"),
                                  N_("restrict:"), N_("prolong:")};

  cs_log_printf(CS_LOG_PERFORMANCE,
                 _("\n"
                   "  Multigrid:\n"
                   "    Coarsening: %s\n"),
                 _(cs_grid_coarsening_type_name[mg->coarsening_type]));

  if (mg->info.type[0] != CS_SLES_N_IT_TYPES) {

    const char *descent_smoother_name = cs_sles_it_type_name[mg->info.type[0]];
    const char *ascent_smoother_name = cs_sles_it_type_name[mg->info.type[1]];

    if (mg->info.type[0] == mg->info.type[1])
      cs_log_printf(CS_LOG_PERFORMANCE,
                    _("  Smoother: %s\n"),
                    _(descent_smoother_name));
    else
      cs_log_printf(CS_LOG_PERFORMANCE,
                    _("  Descent smoother:     %s\n"
                      "  Ascent smoother:      %s\n"),
                    _(descent_smoother_name), _(ascent_smoother_name));

    cs_log_printf(CS_LOG_PERFORMANCE,
                  _("  Coarsest level solver:       %s\n"),
                  _(cs_sles_it_type_name[mg->info.type[2]]));

  }

  sprintf(tmp_s[0], "%-36s", "");
  cs_log_strpadl(tmp_s[1], _(" mean"), 12, 64);
  cs_log_strpadl(tmp_s[2], _("minimum"), 12, 64);
  cs_log_strpadl(tmp_s[3], _("maximum"), 12, 64);

  cs_log_printf(CS_LOG_PERFORMANCE,
                "\n  %s %s %s %s\n",
                tmp_s[0], tmp_s[1], tmp_s[2], tmp_s[3]);

  cs_log_strpad(tmp_s[0], _("Number of coarse levels:"), 36, 64);
  cs_log_strpad(tmp_s[1], _("Number of cycles:"), 36, 64);

  cs_log_printf(CS_LOG_PERFORMANCE,
                "  %s %12d %12d %12d\n",
                tmp_s[0], n_lv_mean, n_lv_min, n_lv_max);
  cs_log_printf(CS_LOG_PERFORMANCE,
                "  %s %12d %12d %12d\n\n",
                tmp_s[1], n_cy_mean,
                (int)(mg->info.n_cycles[0]), (int)(mg->info.n_cycles[1]));

  cs_log_timer_array_header(CS_LOG_PERFORMANCE,
                            2,                  /* indent, */
                            "",                 /* header title */
                            true);              /* calls column */
  cs_log_timer_array(CS_LOG_PERFORMANCE,
                     2,                  /* indent, */
                     2,                  /* n_lines */
                     stage_name,
                     mg->info.n_calls,
                     mg->info.t_tot);

  sprintf(tmp_s[0], "%-36s", "");
  cs_log_strpadl(tmp_s[1], _(" mean"), 12, 64);
  cs_log_strpadl(tmp_s[2], _("minimum"), 12, 64);
  cs_log_strpadl(tmp_s[3], _("maximum"), 12, 64);

  cs_log_printf(CS_LOG_PERFORMANCE,
                "\n  %s %s %s %s\n",
                tmp_s[0], tmp_s[1], tmp_s[2], tmp_s[3]);

  for (i = 0; i <= mg->info.n_levels[2]; i++) {

    const cs_multigrid_level_info_t *lv_info = mg->lv_info + i;
    unsigned long long n_lv_builds = lv_info->n_calls[0];

    if (n_lv_builds < 1)
      continue;

    cs_log_strpad(tmp_s[0], _("Number of cells:"), 34, 64);
    cs_log_printf(CS_LOG_PERFORMANCE,
                  _("  Grid level %d:\n"
                    "    %s %12llu %12llu %12llu\n"),
                  i, tmp_s[0],
                  lv_info->n_g_cells[3] / n_lv_builds,
                  lv_info->n_g_cells[1], lv_info->n_g_cells[2]);

#if defined(HAVE_MPI)

    if (cs_glob_n_ranks == 1) {
      cs_log_strpad(tmp_s[1], _("Number of faces:"), 34, 64);
      cs_log_printf(CS_LOG_PERFORMANCE,
                    "    %s %12llu %12llu %12llu\n",
                    tmp_s[1],
                    lv_info->n_elts[2][3] / n_lv_builds,
                    lv_info->n_elts[2][1], lv_info->n_elts[2][2]);
    }

#endif
    if (cs_glob_n_ranks > 1) {
      cs_log_strpad(tmp_s[0], _("Number of active ranks:"), 34, 64);
      cs_log_printf(CS_LOG_PERFORMANCE,
                    "    %s %12llu %12llu %12llu\n",
                    tmp_s[0],
                    lv_info->n_ranks[3] / n_lv_builds,
                    lv_info->n_ranks[1], lv_info->n_ranks[2]);
      cs_log_strpad(tmp_s[0], _("Mean local cells:"), 34, 64);
      cs_log_strpad(tmp_s[1], _("Mean local cells + ghosts:"), 34, 64);
      cs_log_strpad(tmp_s[2], _("Mean local faces:"), 34, 64);
      cs_log_printf(CS_LOG_PERFORMANCE,
                    "    %s %12llu %12llu %12llu\n"
                    "    %s %12llu %12llu %12llu\n"
                    "    %s %12llu %12llu %12llu\n",
                    tmp_s[0],
                    lv_info->n_elts[0][3] / n_lv_builds,
                    lv_info->n_elts[0][1], lv_info->n_elts[0][2],
                    tmp_s[1],
                    lv_info->n_elts[1][3] / n_lv_builds,
                    lv_info->n_elts[1][1], lv_info->n_elts[1][2],
                    tmp_s[2],
                    lv_info->n_elts[2][3] / n_lv_builds,
                    lv_info->n_elts[2][1], lv_info->n_elts[2][2]);
      cs_log_strpad(tmp_s[0], _("Cells unbalance:"), 34, 64);
      cs_log_strpad(tmp_s[1], _("Cells + ghosts unbalance:"), 34, 64);
      cs_log_strpad(tmp_s[2], _("Faces unbalance"), 34, 64);
      cs_log_printf(CS_LOG_PERFORMANCE,
                    "    %-34s %12.3f %12.3f %12.3f\n"
                    "    %-34s %12.3f %12.3f %12.3f\n"
                    "    %-34s %12.3f %12.3f %12.3f\n",
                    tmp_s[0],
                    lv_info->unbalance[0][3] / n_lv_builds,
                    lv_info->unbalance[0][1], lv_info->unbalance[0][2],
                    tmp_s[1],
                    lv_info->unbalance[1][3] / n_lv_builds,
                    lv_info->unbalance[1][1], lv_info->unbalance[1][2],
                    tmp_s[2],
                    lv_info->unbalance[2][3] / n_lv_builds,
                    lv_info->unbalance[2][1], lv_info->unbalance[2][2]);
    }

    if (lv_info->n_calls[1] > 0) {
      cs_log_strpad(tmp_s[0], _("Iterations for solving:"), 34, 64);
      cs_log_printf(CS_LOG_PERFORMANCE,
                    "    %s %12llu %12llu %12llu\n",
                    tmp_s[0],
                    lv_info->n_it_solve[3] / lv_info->n_calls[1],
                    lv_info->n_it_solve[1], lv_info->n_it_solve[2]);
    }

    if (lv_info->n_calls[2] > 0) {
      cs_log_strpad(tmp_s[1], _("Descent smoother iterations:"), 34, 64);
      cs_log_printf(CS_LOG_PERFORMANCE,
                    "    %s %12llu %12llu %12llu\n",
                    tmp_s[1],
                    lv_info->n_it_ds_smoothe[3] / lv_info->n_calls[2],
                    lv_info->n_it_ds_smoothe[1], lv_info->n_it_ds_smoothe[2]);
    }

    if (lv_info->n_calls[3] > 0) {
      cs_log_strpad(tmp_s[2], _("Ascent smoother iterations:"), 34, 64);
      cs_log_printf(CS_LOG_PERFORMANCE,
                    "    %s %12llu %12llu %12llu\n",
                    tmp_s[2],
                    lv_info->n_it_as_smoothe[3] / lv_info->n_calls[3],
                    lv_info->n_it_as_smoothe[1], lv_info->n_it_as_smoothe[2]);
    }
  }

  cs_log_timer_array_header(CS_LOG_PERFORMANCE,
                            2,                  /* indent, */
                            "",                 /* header title */
                            true);              /* calls column */

  for (i = 0; i <= mg->info.n_levels[2]; i++) {

    const cs_multigrid_level_info_t *lv_info = mg->lv_info + i;

    cs_log_printf(CS_LOG_PERFORMANCE,
                  _("  Grid level %d:\n"), i);

    cs_log_timer_array(CS_LOG_PERFORMANCE,
                       4,                  /* indent, */
                       6,                  /* n_lines */
                       lv_stage_name,
                       lv_info->n_calls,
                       lv_info->t_tot);

  }
}

/*----------------------------------------------------------------------------
 * Create empty structure used to maintain setup data
 * (between cs_sles_setup and cs_sles_free type calls.
 *
 * returns:
 *   pointer to multigrid setup data structure
 *----------------------------------------------------------------------------*/

static cs_multigrid_setup_data_t *
_multigrid_setup_data_create(void)
{
  cs_multigrid_setup_data_t *mgd;

  BFT_MALLOC(mgd, 1, cs_multigrid_setup_data_t);

  mgd->n_levels = 0;
  mgd->n_levels_alloc = 0;

  mgd->grid_hierarchy = NULL;
  mgd->sles_hierarchy = NULL;

  mgd->exit_initial_residue = -1.;
  mgd->exit_residue = -1.;
  mgd->exit_level = -1.;
  mgd->exit_cycle_id = -1.;

  mgd->rhs_vx_buf = NULL;
  mgd->rhs_vx = NULL;

  return mgd;
}

/*----------------------------------------------------------------------------
 * Add grid to multigrid structure hierarchy.
 *
 * parameters:
 *   mg   <-- multigrid structure
 *   grid <-- grid to add
 *----------------------------------------------------------------------------*/

static void
_multigrid_add_level(cs_multigrid_t  *mg,
                     cs_grid_t       *grid)
{
  cs_multigrid_setup_data_t *mgd = mg->setup_data;

  unsigned ii;

  /* Reallocate arrays if necessary */

  if (mgd->n_levels == mgd->n_levels_alloc) {

    /* Max previous */
    unsigned int n_lv_max_prev = CS_MAX(mg->info.n_levels[2] + 1,
                                        mgd->n_levels);

    if (mgd->n_levels_alloc == 0) {
      mgd->n_levels_alloc = n_lv_max_prev;
      if (mgd->n_levels_alloc == 0)
        mgd->n_levels_alloc = 10;
    }
    else
      mgd->n_levels_alloc *= 2;

    BFT_REALLOC(mgd->grid_hierarchy, mgd->n_levels_alloc, cs_grid_t *);
    BFT_REALLOC(mgd->sles_hierarchy, mgd->n_levels_alloc*2, cs_sles_it_t *);

    for (ii = mgd->n_levels; ii < mgd->n_levels_alloc; ii++)
      mgd->grid_hierarchy[ii] = NULL;

    if (n_lv_max_prev < mgd->n_levels_alloc) {
      BFT_REALLOC(mg->lv_info, mgd->n_levels_alloc, cs_multigrid_level_info_t);
      for (ii = n_lv_max_prev; ii < mgd->n_levels_alloc; ii++)
      _multigrid_level_info_init(mg->lv_info + ii);
    }

  }

  mgd->grid_hierarchy[mgd->n_levels] = grid;

  if (mg->post_cell_num != NULL) {
    int n_max_post_levels = (int)(mg->info.n_levels[2]) - 1;
    BFT_REALLOC(mg->post_cell_num, mgd->n_levels_alloc, int *);
    for (ii = n_max_post_levels + 1; ii < mgd->n_levels_alloc; ii++)
      mg->post_cell_num[ii] = NULL;
  }

  if (mg->post_cell_rank != NULL) {
    int n_max_post_levels = (int)(mg->info.n_levels[2]) - 1;
    BFT_REALLOC(mg->post_cell_rank, mgd->n_levels_alloc, int *);
    for (ii = n_max_post_levels + 1; ii < mgd->n_levels_alloc; ii++)
      mg->post_cell_rank[ii] = NULL;
  }

  /* Update associated info */

  {
    int  n_ranks;
    cs_lnum_t  n_cells, n_cells_with_ghosts, n_faces;
    cs_gnum_t  n_g_cells;
    cs_multigrid_level_info_t  *lv_info = mg->lv_info + mgd->n_levels;

    cs_grid_get_info(grid,
                     NULL,
                     NULL,
                     NULL,
                     NULL,
                     &n_ranks,
                     &n_cells,
                     &n_cells_with_ghosts,
                     &n_faces,
                     &n_g_cells);

    mg->info.n_levels[0] = mgd->n_levels - 1;

    lv_info->n_ranks[0] = n_ranks;
    if (lv_info->n_ranks[1] > (unsigned)n_ranks)
      lv_info->n_ranks[1] = n_ranks;
    else if (lv_info->n_ranks[2] < (unsigned)n_ranks)
      lv_info->n_ranks[2] = n_ranks;
    lv_info->n_ranks[3] += n_ranks;

    lv_info->n_g_cells[0] = n_g_cells;
    if (lv_info->n_g_cells[1] > n_g_cells)
      lv_info->n_g_cells[1] = n_g_cells;
    else if (lv_info->n_g_cells[2] < n_g_cells)
      lv_info->n_g_cells[2] = n_g_cells;
    lv_info->n_g_cells[3] += n_g_cells;

    lv_info->n_elts[0][0] = n_cells;
    lv_info->n_elts[1][0] = n_cells_with_ghosts;
    lv_info->n_elts[2][0] = n_faces;

    for (ii = 0; ii < 3; ii++) {
      if (lv_info->n_elts[ii][1] > lv_info->n_elts[ii][0])
        lv_info->n_elts[ii][1] = lv_info->n_elts[ii][0];
      else if (lv_info->n_elts[ii][2] < lv_info->n_elts[ii][0])
        lv_info->n_elts[ii][2] = lv_info->n_elts[ii][0];
      lv_info->n_elts[ii][3] += lv_info->n_elts[ii][0];
    }

#if defined(HAVE_MPI)

    if (cs_glob_n_ranks > 1) {
      cs_gnum_t tot_sizes[3], max_sizes[3];
      cs_gnum_t loc_sizes[3] = {n_cells, n_cells_with_ghosts, n_faces};
      MPI_Allreduce(loc_sizes, tot_sizes, 3, CS_MPI_GNUM, MPI_SUM,
                    cs_glob_mpi_comm);
      MPI_Allreduce(loc_sizes, max_sizes, 3, CS_MPI_GNUM, MPI_MAX,
                    cs_glob_mpi_comm);
      for (ii = 0; ii < 3; ii++) {
        lv_info->unbalance[ii][0] = (  max_sizes[ii]
                                     / (tot_sizes[ii]*1.0/n_ranks)) - 1.0;
        if (lv_info->unbalance[ii][1] > lv_info->unbalance[ii][0])
          lv_info->unbalance[ii][1] = lv_info->unbalance[ii][0];
        else if (lv_info->unbalance[ii][2] < lv_info->unbalance[ii][0])
          lv_info->unbalance[ii][2] = lv_info->unbalance[ii][0];
        lv_info->unbalance[ii][3] += lv_info->unbalance[ii][0];
      }
    }

#endif /* defined(HAVE_MPI) */

    if (lv_info->n_calls[0] == 0) {
      lv_info->n_ranks[1] = n_ranks;
      lv_info->n_g_cells[1] = n_g_cells;
      for (ii = 0; ii < 3; ii++) {
        lv_info->n_elts[ii][1] = lv_info->n_elts[ii][0];
#if defined(HAVE_MPI)
        lv_info->unbalance[ii][1] = lv_info->unbalance[ii][0];
#endif
      }
    }

    lv_info->n_calls[0] += 1;
  }

  /* Ready for next level */

  mgd->n_levels += 1;
}

/*----------------------------------------------------------------------------
 * Add postprocessing info to multigrid hierarchy
 *
 * parameters:
 *   mg           <-> multigrid structure
 *   name         <-- postprocessing name
 *   n_base_cells <-- number of cells in base grid
 *----------------------------------------------------------------------------*/

static void
_multigrid_add_post(cs_multigrid_t  *mg,
                    const char      *name,
                    cs_lnum_t        n_base_cells)
{
  cs_multigrid_setup_data_t *mgd = mg->setup_data;

  int ii;

  assert(mg != NULL);

  if (mg->post_cell_max < 1)
    return;

  mg->n_levels_post = mgd->n_levels - 1;

  BFT_REALLOC(mg->post_name, strlen(name) + 1, char);
  strcpy(mg->post_name, name);

  assert(mg->n_levels_post <= mg->n_levels_max);

  /* Reallocate arrays if necessary */

  if (mg->post_cell_num == NULL) {
    BFT_MALLOC(mg->post_cell_num, mg->n_levels_max, int *);
    for (ii = 0; ii < mg->n_levels_max; ii++)
      mg->post_cell_num[ii] = NULL;
  }

  if (mg->post_cell_rank == NULL && cs_grid_get_merge_stride() > 1) {
    BFT_MALLOC(mg->post_cell_rank, mg->n_levels_max, int *);
    for (ii = 0; ii < mg->n_levels_max; ii++)
      mg->post_cell_rank[ii] = NULL;
  }

  for (ii = 0; ii < mg->n_levels_post; ii++) {
    BFT_REALLOC(mg->post_cell_num[ii], n_base_cells, int);
    cs_grid_project_cell_num(mgd->grid_hierarchy[ii+1],
                             n_base_cells,
                             mg->post_cell_max,
                             mg->post_cell_num[ii]);
  }

  if (mg->post_cell_rank != NULL) {
    for (ii = 0; ii < mg->n_levels_post; ii++) {
      BFT_REALLOC(mg->post_cell_rank[ii], n_base_cells, int);
      cs_grid_project_cell_rank(mgd->grid_hierarchy[ii+1],
                                n_base_cells,
                                mg->post_cell_rank[ii]);
    }
  }
}

/*----------------------------------------------------------------------------
 * Post process variables associated with Multigrid hierarchy
 *
 * parameters:
 *   mgh <-- multigrid hierarchy
 *   ts  <-- time step status structure
 *----------------------------------------------------------------------------*/

static void
_cs_multigrid_post_function(void                  *mgh,
                            const cs_time_step_t  *ts)
{
  int ii;
  size_t name_len;
  char *var_name = NULL;
  cs_multigrid_t *mg = mgh;
  const char *base_name = NULL;
  const int nt_cur = (ts != NULL) ? ts->nt_cur : -1;

  /* Return if necessary structures inconsistent or have been destroyed */

  if (mg == NULL)
    return;

  if (mg->post_cell_num == NULL || cs_post_mesh_exists(-1) != true)
    return;

  /* Allocate name buffer */

  base_name = mg->post_name;
  name_len = 3 + strlen(base_name) + 1 + 3 + 1 + 4 + 1;
  BFT_MALLOC(var_name, name_len, char);

  /* Loop on grid levels */

  for (ii = 0; ii < mg->n_levels_post; ii++) {

    sprintf(var_name, "mg %s %2d %3d",
            base_name, (ii+1), nt_cur);

    cs_post_write_var(-1,
                      var_name,
                      1,
                      false,
                      true,
                      CS_POST_TYPE_int,
                      mg->post_cell_num[ii],
                      NULL,
                      NULL,
                      NULL);

    BFT_FREE(mg->post_cell_num[ii]);

    if (mg->post_cell_rank != NULL) {

      sprintf(var_name, "rk %s %2d %3d",
              base_name, (ii+1), nt_cur);

      cs_post_write_var(-1,
                        var_name,
                        1,
                        false,
                        true,
                        CS_POST_TYPE_int,
                        mg->post_cell_rank[ii],
                        NULL,
                        NULL,
                        NULL);

      BFT_FREE(mg->post_cell_rank[ii]);

    }

  }
  mg->n_levels_post = 0;

  BFT_FREE(var_name);
}

/*----------------------------------------------------------------------------
 * Setup multigrid sparse linear equation solvers on existing hierarchy.
 *
 * parameters:
 *   mg        <-> pointer to multigrid solver info and context
 *   name      <-- linear system name
 *   verbosity <-- associated verbosity
 *----------------------------------------------------------------------------*/

static void
_multigrid_setup_sles_it(cs_multigrid_t  *mg,
                         const char      *name,
                         int              verbosity)
{
  cs_timer_t t0, t1;

  cs_multigrid_level_info_t *mg_lv_info;
  const cs_grid_t *g;
  const cs_matrix_t *m;

  /* Initialization */

  t0 = cs_timer_time();

  cs_multigrid_setup_data_t *mgd = mg->setup_data;

  cs_lnum_t stride = 1; /* For diagonal blocks */

  /* Prepare solver context */

  unsigned n_levels = mgd->n_levels;

  unsigned i = 0;

  g = mgd->grid_hierarchy[i];
  m = cs_grid_get_matrix(g);

  mg_lv_info = mg->lv_info + i;

  mgd->sles_hierarchy[0]
    = cs_sles_it_create(mg->info.type[0],
                        mg->info.poly_degree[0],
                        mg->info.n_max_iter[0],
                        false); /* stats not updated here */

#if defined(HAVE_MPI)
  cs_sles_it_set_mpi_reduce_comm(mgd->sles_hierarchy[0], cs_grid_get_comm(g));
#endif

  cs_sles_it_setup(mgd->sles_hierarchy[0], name, m, verbosity - 2);
  mgd->sles_hierarchy[1] = NULL;

  t1 = cs_timer_time();
  cs_timer_counter_add_diff(&(mg_lv_info->t_tot[0]), &t0, &t1);

  /* Intermediate grids */

  for (i = 1; i < n_levels - 1; i++) {

    t0 = t1;

    g = mgd->grid_hierarchy[i];
    m = cs_grid_get_matrix(g);

    mg_lv_info = mg->lv_info + i;

    mgd->sles_hierarchy[i*2]
      = cs_sles_it_create(mg->info.type[0],
                          mg->info.poly_degree[0],
                          mg->info.n_max_iter[0],
                          false); /* stats not updated here */

    mgd->sles_hierarchy[i*2+1]
      = cs_sles_it_create(mg->info.type[1],
                          mg->info.poly_degree[1],
                          mg->info.n_max_iter[1],
                          false); /* stats not updated here */

    cs_sles_it_set_shareable(mgd->sles_hierarchy[i*2 + 1],
                             mgd->sles_hierarchy[i*2]);

    cs_sles_it_setup(mgd->sles_hierarchy[i*2], "", m, verbosity - 2);
    cs_sles_it_setup(mgd->sles_hierarchy[i*2+1], "", m, verbosity - 2);

#if defined(HAVE_MPI)
    {
      MPI_Comm lv_comm = cs_grid_get_comm(mgd->grid_hierarchy[i]);
      cs_sles_it_set_mpi_reduce_comm(mgd->sles_hierarchy[i*2], lv_comm);
      cs_sles_it_set_mpi_reduce_comm(mgd->sles_hierarchy[i*2+1], lv_comm);
    }
#endif

    t1 = cs_timer_time();
    cs_timer_counter_add_diff(&(mg_lv_info->t_tot[0]), &t0, &t1);

  }

  /* Coarsest grid */

  if (n_levels > 1) {

    t0 = t1;

    i = n_levels - 1;

    g = mgd->grid_hierarchy[i];
    m = cs_grid_get_matrix(g);

    mg_lv_info = mg->lv_info + i;

    mgd->sles_hierarchy[i*2]
      = cs_sles_it_create(mg->info.type[2],
                          mg->info.poly_degree[2],
                          mg->info.n_max_iter[2],
                          false); /* stats not updated here */

#if defined(HAVE_MPI)
    cs_sles_it_set_mpi_reduce_comm(mgd->sles_hierarchy[i*2],
                                   cs_grid_get_comm(mgd->grid_hierarchy[i]));
#endif

    cs_sles_it_setup(mgd->sles_hierarchy[i*2], "", m, verbosity - 2);
    mgd->sles_hierarchy[i*2+1] = NULL;

    /* Diagonal block size is the same for all levels */

    const int *db_size = cs_matrix_get_diag_block_size(m);
    stride = db_size[1];

  }

  /* Allocate working array for coarse right hand sides and corrections */

  BFT_MALLOC(mgd->rhs_vx, mgd->n_levels*2, cs_real_t *);

  mgd->rhs_vx[0] = NULL;
  mgd->rhs_vx[1] = NULL;

  if (mgd->n_levels > 1) {

    size_t wr_size = 0;
    for (i = 1; i < mgd->n_levels; i++) {
      size_t block_size
        = cs_grid_get_n_cells_max(mgd->grid_hierarchy[i])*stride;
      block_size = CS_SIMD_SIZE(block_size);
      wr_size += block_size;
    }

    BFT_MALLOC(mgd->rhs_vx_buf, wr_size*2, cs_real_t);

    size_t block_size_shift = 0;

    for (i = 1; i < mgd->n_levels; i++) {
      size_t block_size
        = cs_grid_get_n_cells_max(mgd->grid_hierarchy[i])*stride;
      mgd->rhs_vx[i*2] = mgd->rhs_vx_buf+ block_size_shift;
      block_size_shift += block_size;
      mgd->rhs_vx[i*2+1] = mgd->rhs_vx_buf + block_size_shift;
      block_size_shift += block_size;
    }

  }

  /* Timing */

  t1 = cs_timer_time();
  cs_timer_counter_add_diff(&(mg_lv_info->t_tot[0]), &t0, &t1);
}

/*----------------------------------------------------------------------------
 * Compute dot product, summing result over all ranks.
 *
 * parameters:
 *   n_elts <-- local number of elements
 *   x      <-- vector in s = x.x
 *
 * returns:
 *   result of s = x.x
 *----------------------------------------------------------------------------*/

inline static double
_dot_product_xx(cs_int_t          n_elts,
                const cs_real_t  *x)
{
  double s = cs_dot_xx(n_elts, x);

#if defined(HAVE_MPI)

  if (cs_glob_n_ranks > 1) {
    double _sum;
    MPI_Allreduce(&s, &_sum, 1, MPI_DOUBLE, MPI_SUM, cs_glob_mpi_comm);
    s = _sum;
  }

#endif /* defined(HAVE_MPI) */

  return s;
}

/*----------------------------------------------------------------------------
 * Test if convergence is attained.
 *
 * parameters:
 *   var_name        <-- variable name
 *   n_f_cells       <-- number of cells on fine mesh
 *   n_max_cycles    <-- maximum number of cycles
 *   cycle_id        <-- number of current cycle
 *
 *   verbosity       <-- verbosity level
 *   n_iters         <-- number of iterations
 *   precision       <-- precision limit
 *   r_norm          <-- residue normalization
 *   initial_residue <-- initial residue
 *   residue         <-> residue
 *   rhs             <-- right-hand side
 *
 * returns:
 *   convergence status
 *----------------------------------------------------------------------------*/

static cs_sles_convergence_state_t
_convergence_test(const char         *var_name,
                  cs_int_t            n_f_cells,
                  int                 n_max_cycles,
                  int                 cycle_id,
                  int                 verbosity,
                  int                 n_iters,
                  double              precision,
                  double              r_norm,
                  double              initial_residue,
                  double             *residue,
                  const cs_real_t     rhs[])
{
  const char cycle_h_fmt[]
    = N_("  ---------------------------------------------------\n"
         "    n.     | Cumulative iterations | Norm. residual\n"
         "    cycles | on fine mesh          | on fine mesh\n"
         "  ---------------------------------------------------\n");
  const char cycle_t_fmt[]
    = N_("  ---------------------------------------------------\n");
  const char cycle_cv_fmt[]
    = N_("     %4d  |               %6d  |  %12.4e\n");

  const char cycle_fmt[]
    = N_("   N. cycles: %4d; Fine mesh cumulative iter: %5d; "
         "Norm. residual %12.4e\n");

  /* Compute residue */

  *residue = sqrt(_dot_product_xx(n_f_cells, rhs));

  if (cycle_id == 1)
    initial_residue = *residue;

  if (*residue < precision*r_norm) {

    if (verbosity == 2)
      bft_printf(_(cycle_fmt), cycle_id, n_iters, *residue/r_norm);
    else if (verbosity > 2) {
      bft_printf(_(cycle_h_fmt));
      bft_printf(_(cycle_cv_fmt),
                 cycle_id, n_iters, *residue/r_norm);
      bft_printf(_(cycle_t_fmt));
    }
    return CS_SLES_CONVERGED;
  }

  else if (cycle_id >= n_max_cycles) {

    if (verbosity > 0) {
      if (verbosity == 1)
        bft_printf(_(cycle_fmt), cycle_id, n_iters, *residue/r_norm);
      else if (verbosity > 1) {
        bft_printf(_(cycle_h_fmt));
        bft_printf(_(cycle_fmt),
                   cycle_id, n_iters, *residue/r_norm);
        bft_printf(_(cycle_t_fmt));
      }
      bft_printf(_(" @@ Warning: algebraic multigrid for [%s]\n"
                   "    ********\n"
                   "    Maximum number of cycles (%d) reached.\n"),
                 var_name, n_max_cycles);

    }
    return CS_SLES_MAX_ITERATION;
  }

  else {

    if (verbosity > 2)
      bft_printf(_(cycle_fmt), cycle_id, n_iters, *residue/r_norm);

    if (*residue > initial_residue * 10000.0 && *residue > 100.)
      return CS_SLES_DIVERGED;

#if (__STDC_VERSION__ >= 199901L)
    if (isnan(*residue) || isinf(*residue))
      return CS_SLES_DIVERGED;
#endif
  }

  return CS_SLES_ITERATING;
}

/*----------------------------------------------------------------------------
 * Update level information iteration counts
 *
 * parameters:
 *   lv_info_it <-> logged number of iterations (last, min, max, total)
 *   n_iter     <-- current number of iterations
 *----------------------------------------------------------------------------*/

static inline void
_lv_info_update_stage_iter(unsigned long long  lv_info_it[],
                           unsigned            n_iter)
{
  lv_info_it[0] = n_iter;
  if (n_iter < lv_info_it[1])
    lv_info_it[1] = n_iter;
  else if (n_iter > lv_info_it[2])
    lv_info_it[2] = n_iter;
  if (lv_info_it[1] == 0)
    lv_info_it[1] = n_iter;
  lv_info_it[3] += n_iter;
}

/*----------------------------------------------------------------------------
 * Compute buffer size required for level names
 *
 * parameters:
 *   name     <-- linear system name
 *   n_levels <-- number multigrid levels
 *
 * returns:
 *   buffer size needed for level names
 *----------------------------------------------------------------------------*/

static size_t
_level_names_size(const char  *name,
                  int          n_levels)
{
  /* Format name width */

  int w = 1;
  for (int i = n_levels/10; i > 0; i /=10)
    w += 1;

  /* First part: pointers */

  size_t retval = n_levels*sizeof(char *)*2;
  retval = CS_SIMD_SIZE(retval);

  /* Second part: buffers */
  size_t buf_size = 0;

  if (n_levels > 1)
    buf_size =   (strlen(name) + strlen(":descent:") + w + 1)
               * (n_levels-1)*2;
  retval += CS_SIMD_SIZE(buf_size);

  return retval;
}

/*----------------------------------------------------------------------------
 * Initialize level names
 *
 * parameters:
 *   name     <-- linear system name
 *   n_levels <-- number multigrid levels
 *   buffer   <-- buffer
 *----------------------------------------------------------------------------*/

static void
_level_names_init(const char  *name,
                  int          n_levels,
                  void        *buffer)
{
  /* Format name width */

  int w = 1;
  for (int i = n_levels/10; i > 0; i /=10)
    w += 1;

  /* First part: pointers */

  size_t ptr_size = n_levels*sizeof(char *)*2;
  ptr_size = CS_SIMD_SIZE(ptr_size);

  char *_buffer = buffer;
  char **_lv_names = buffer;
  const char **lv_names = (const char **)_lv_names;
  const size_t name_len = strlen(name) + strlen(":descent:") + w + 1;

  lv_names[0] = name;
  lv_names[1] = NULL;

  /* Second part: buffers */

  for (int i = 1; i < n_levels -1; i++) {
    lv_names[i*2] = _buffer + ptr_size + (i-1)*2*name_len;
    lv_names[i*2+1] = lv_names[i*2] + name_len;
    sprintf(_lv_names[i*2], "%s:descent:%0*d", name, w, i);
    sprintf(_lv_names[i*2+1], "%s:ascent:%0*d", name, w, i);
  }

  if (n_levels > 1) {
    int i = n_levels - 1;
    lv_names[i*2] = _buffer + ptr_size + (i-1)*2*name_len;
    lv_names[i*2+1] = NULL;
    sprintf(_lv_names[i*2], "%s:coarse:%0*d", name, w, i);
  }
}

/*----------------------------------------------------------------------------
 * Sparse linear system resolution using multigrid.
 *
 * parameters:
 *   mg              <-- multigrid system
 *   lv_names        <-- names of linear systems
 *                       (indexed as mg->setup_data->sles_hierarchy)
 *   verbosity       <-- verbosity level
 *   rotation_mode   <-- halo update option for rotational periodicity
 *   cycle_id        <-- id of currect cycle
 *   n_equiv_iter    <-> equivalent number of iterations
 *   precision       <-- solver precision
 *   r_norm          <-- residue normalization
 *   initial_residue <-> initial residue
 *   residue         <-> residue
 *   rhs             <-- right hand side
 *   vx              --> system solution
 *   aux_size        <-- number of elements in aux_vectors (in bytes)
 *   aux_vectors     --- optional working area (allocation otherwise)
 *
 * returns:
 *   convergence status
 *----------------------------------------------------------------------------*/

static cs_sles_convergence_state_t
_multigrid_cycle(cs_multigrid_t       *mg,
                 const char          **lv_names,
                 int                   verbosity,
                 cs_halo_rotation_t    rotation_mode,
                 int                   cycle_id,
                 int                  *n_equiv_iter,
                 double                precision,
                 double                r_norm,
                 double               *initial_residue,
                 double               *residue,
                 const cs_real_t      *rhs,
                 cs_real_t            *vx,
                 size_t                aux_size,
                 void                 *aux_vectors)
{
  int level, coarsest_level;
  cs_lnum_t ii, jj;
  cs_timer_t t0, t1;

  int db_size[4] = {1, 1, 1, 1};
  int eb_size[4] = {1, 1, 1, 1};
  cs_sles_convergence_state_t cvg = CS_SLES_ITERATING, c_cvg = CS_SLES_ITERATING;
  int n_iter = 0;
  double _residue = -1.;
  double _initial_residue = 0.;

  size_t _aux_r_size = aux_size / sizeof(cs_real_t);
  cs_lnum_t n_cells = 0, n_cells_ext = 0;
  cs_gnum_t n_g_cells = 0;
  cs_real_t r_norm_l = r_norm;

  double denom_n_g_cells_0 = 1.0;

  cs_multigrid_setup_data_t *mgd = mg->setup_data;
  cs_multigrid_level_info_t  *lv_info = NULL;

  cs_real_t *_aux_vectors = aux_vectors;
  cs_real_t *restrict wr = NULL;
  cs_real_t *restrict vx_lv = NULL;

  const cs_real_t *restrict rhs_lv = NULL;
  const cs_matrix_t  *_matrix = NULL;
  const cs_grid_t *f = NULL, *c= NULL;

  bool end_cycle = false;

  /* Initialization */

  coarsest_level = mgd->n_levels - 1;

  f = mgd->grid_hierarchy[0];

  cs_grid_get_info(f,
                   NULL,
                   NULL,
                   db_size,
                   eb_size,
                   NULL,
                   &n_cells,
                   &n_cells_ext,
                   NULL,
                   &n_g_cells);

  denom_n_g_cells_0 = 1.0 / n_g_cells;

  /* Allocate wr or use working area
     (note the finest grid could have less element than a coarser
     grid to wich rank merging has been applied, hence the test below) */

  size_t wr_size = n_cells_ext*db_size[1];
  for (level = 1; level < (int)(mgd->n_levels); level++) {
    cs_lnum_t n_cells_max
      = cs_grid_get_n_cells_max(mgd->grid_hierarchy[level]);
    wr_size = CS_MAX(wr_size, (size_t)(n_cells_max*db_size[1]));
    wr_size = CS_SIMD_SIZE(wr_size);
  }

  if (_aux_r_size >= wr_size) {
    wr = aux_vectors;
    _aux_vectors = wr + wr_size;
    _aux_r_size -= wr_size;
  }
  else
    BFT_MALLOC(wr, wr_size, cs_real_t);

  /* map arrays for rhs and vx;
     for the finest level, simply point to input and output arrays */

  mgd->rhs_vx[0] = NULL; /* Use _rhs_level when necessary to avoid const warning */
  mgd->rhs_vx[1] = vx;

  /* Descent */
  /*---------*/

  if (verbosity > 2)
    bft_printf(_("  Multigrid cycle: descent\n"));

  for (level = 0; level < coarsest_level; level++) {

    lv_info = mg->lv_info + level;
    t0 = cs_timer_time();

    rhs_lv = (level == 0) ? rhs : mgd->rhs_vx[level*2];
    vx_lv = mgd->rhs_vx[level*2 + 1];

    c = mgd->grid_hierarchy[level+1];

    /* Smoother pass */

    if (verbosity > 2)
      bft_printf(_("    level %3d: smoother\n"), level);

    _matrix = cs_grid_get_matrix(f);

    c_cvg = cs_sles_it_solve(mgd->sles_hierarchy[level*2],
                             lv_names[level*2],
                             _matrix,
                             verbosity - 2,
                             rotation_mode,
                             precision*mg->info.precision_mult[0],
                             r_norm_l,
                             &n_iter,
                             &_residue,
                             rhs_lv,
                             vx_lv,
                             _aux_r_size*sizeof(cs_real_t),
                             _aux_vectors);

    _initial_residue
      = cs_sles_it_get_last_initial_residue(mgd->sles_hierarchy[level*2]);

    if (level == 0 && cycle_id == 1)
      *initial_residue = _initial_residue;

    if (c_cvg < CS_SLES_BREAKDOWN) {
      end_cycle = true;
      break;
    }

    /* Restrict residue
       TODO: get residue from cs_sles_solve(). This optimisation would
       require adding an argument and exercising caution to ensure the
       correct sign and meaning of the residue
       (regarding timing, this stage is part of the descent smoother) */

    cs_matrix_vector_multiply(rotation_mode,
                              _matrix,
                              vx_lv,
                              wr);

    if (db_size[0] == 1) {
#     pragma omp parallel for if(n_cells > CS_THR_MIN)
      for (ii = 0; ii < n_cells; ii++)
        wr[ii] = rhs_lv[ii] - wr[ii];
    }
    else {
#     pragma omp parallel for private(jj) if(n_cells > CS_THR_MIN)
      for (ii = 0; ii < n_cells; ii++) {
        for (jj = 0; jj < db_size[0]; jj++)
        wr[ii*db_size[1] + jj] =   rhs_lv[ii*db_size[1] + jj]
                                 - wr[ii*db_size[1] + jj];
      }
    }

    /* Convergence test in beginning of cycle (fine mesh) */

    if (level == 0) {

      cvg = _convergence_test(lv_names[0],
                              n_cells*db_size[1],
                              mg->info.n_max_cycles,
                              cycle_id,
                              verbosity,
                              lv_info->n_it_ds_smoothe[0],
                              precision,
                              r_norm,
                              *initial_residue,
                              residue,
                              wr);

      /* If converged or cycle limit reached, break from descent loop */

      if (cvg != 0) {
        c_cvg = cvg;
        end_cycle = true;
        t1 = cs_timer_time();
        cs_timer_counter_add_diff(&(lv_info->t_tot[2]), &t0, &t1);
        lv_info->n_calls[2] += 1;
        _lv_info_update_stage_iter(lv_info->n_it_ds_smoothe, n_iter);

        *n_equiv_iter += n_iter * n_g_cells * denom_n_g_cells_0;
        break;
      }

    }

    t1 = cs_timer_time();
    cs_timer_counter_add_diff(&(lv_info->t_tot[2]), &t0, &t1);
    lv_info->n_calls[2] += 1;
    _lv_info_update_stage_iter(lv_info->n_it_ds_smoothe, n_iter);

    *n_equiv_iter += n_iter * n_g_cells * denom_n_g_cells_0;

    /* Prepare for next level */

    cs_grid_restrict_cell_var(f, c, wr, mgd->rhs_vx[(level+1)*2]);

    cs_grid_get_info(c,
                     NULL,
                     NULL,
                     NULL,
                     NULL,
                     NULL,
                     &n_cells,
                     &n_cells_ext,
                     NULL,
                     &n_g_cells);

    f = c;

    /* Initialize correction */

    cs_real_t *restrict vx_lv1 = mgd->rhs_vx[(level+1)*2 + 1];
    if (db_size[0] == 1) {
#     pragma omp parallel for if(n_cells > CS_THR_MIN)
      for (ii = 0; ii < n_cells; ii++)
        vx_lv1[ii] = 0.0;
    }
    else {
#     pragma omp parallel for private(jj) if(n_cells > CS_THR_MIN)
      for (ii = 0; ii < n_cells; ii++) {
        for (jj = 0; jj < db_size[0]; jj++)
          vx_lv1[ii*db_size[1] + jj] = 0.0;
      }
    }

    t0 = cs_timer_time();
    cs_timer_counter_add_diff(&(lv_info->t_tot[4]), &t1, &t0);
    lv_info->n_calls[4] += 1;

  } /* End of loop on levels (descent) */

  if (end_cycle == false) {

    /* Resolve coarsest level to convergence */
    /*---------------------------------------*/

    if (verbosity > 2)
      bft_printf(_("  Resolution on coarsest level\n"));

    assert(level == coarsest_level);
    assert(c == mgd->grid_hierarchy[coarsest_level]);

    /* coarsest level == 0 should never happen, but we play it safe */
    rhs_lv = (level == 0) ?  rhs : mgd->rhs_vx[coarsest_level*2];
    vx_lv = mgd->rhs_vx[level*2 + 1];

    _matrix = cs_grid_get_matrix(c);

    _initial_residue = _residue;

    lv_info = mg->lv_info + level;
    t0 = cs_timer_time();

    c_cvg = cs_sles_it_solve(mgd->sles_hierarchy[level*2],
                             lv_names[level*2],
                             _matrix,
                             verbosity - 2,
                             rotation_mode,
                             precision*mg->info.precision_mult[2],
                             r_norm_l,
                             &n_iter,
                             &_residue,
                             rhs_lv,
                             vx_lv,
                             _aux_r_size*sizeof(cs_real_t),
                             _aux_vectors);

    t1 = cs_timer_time();
    cs_timer_counter_add_diff(&(lv_info->t_tot[1]), &t0, &t1);
    lv_info->n_calls[1] += 1;
    _lv_info_update_stage_iter(lv_info->n_it_solve, n_iter);

    _initial_residue
      = cs_sles_it_get_last_initial_residue(mgd->sles_hierarchy[level*2]);

    *n_equiv_iter += n_iter * n_g_cells * denom_n_g_cells_0;

    if (c_cvg < CS_SLES_BREAKDOWN)
      end_cycle = true;

  }

  if (end_cycle == false) {

    /* Ascent */
    /*--------*/

    if (verbosity > 2)
      bft_printf(_("  Multigrid cycle: ascent\n"));

    for (level = coarsest_level - 1; level > -1; level--) {

      vx_lv = mgd->rhs_vx[level*2 + 1];;

      lv_info = mg->lv_info + level;

      c = mgd->grid_hierarchy[level+1];
      f = mgd->grid_hierarchy[level];

      cs_grid_get_info(f,
                       NULL,
                       NULL,
                       NULL,
                       NULL,
                       NULL,
                       &n_cells,
                       &n_cells_ext,
                       NULL,
                       &n_g_cells);

      /* Prolong correction */

      t0 = cs_timer_time();

      cs_real_t *restrict vx_lv1 = mgd->rhs_vx[(level+1)*2 + 1];
      cs_grid_prolong_cell_var(c, f, vx_lv1, wr);

      if (db_size[0] == 1) {
#       pragma omp parallel for if(n_cells > CS_THR_MIN)
        for (ii = 0; ii < n_cells; ii++)
          vx_lv[ii] += wr[ii];
      }
      else {
#       pragma omp parallel for private(jj) if(n_cells > CS_THR_MIN)
        for (ii = 0; ii < n_cells; ii++) {
          for (jj = 0; jj < db_size[0]; jj++)
            vx_lv[ii*db_size[1]+jj] += wr[ii*db_size[1]+jj];
        }
      }

      t1 = cs_timer_time();
      cs_timer_counter_add_diff(&(lv_info->t_tot[5]), &t0, &t1);
      lv_info->n_calls[5] += 1;

      /* Smoother pass if level > 0
         (smoother not called for finest mesh, as it will be called in
         descent phase of the next cycle, before the convergence test). */

      if (level > 0) {

        if (verbosity > 2)
          bft_printf(_("    level %3d: smoother\n"), level);

        _matrix = cs_grid_get_matrix(f);

        rhs_lv = mgd->rhs_vx[level*2];

        c_cvg = cs_sles_it_solve(mgd->sles_hierarchy[level*2+1],
                                 lv_names[level*2+1],
                                 _matrix,
                                 verbosity - 2,
                                 rotation_mode,
                                 precision*mg->info.precision_mult[1],
                                 r_norm_l,
                                 &n_iter,
                                 &_residue,
                                 rhs_lv,
                                 vx_lv,
                                 _aux_r_size*sizeof(cs_real_t),
                                 _aux_vectors);

        t0 = cs_timer_time();
        cs_timer_counter_add_diff(&(lv_info->t_tot[3]), &t1, &t0);
        lv_info->n_calls[3] += 1;
        _lv_info_update_stage_iter(lv_info->n_it_as_smoothe, n_iter);

        _initial_residue
          = cs_sles_it_get_last_initial_residue(mgd->sles_hierarchy[level*2+1]);

        *n_equiv_iter += n_iter * n_g_cells * denom_n_g_cells_0;

        if (c_cvg < CS_SLES_BREAKDOWN)
          break;
      }

    } /* End loop on levels (ascent) */

  } /* End of tests on end_cycle */

  mgd->exit_level = level;
  mgd->exit_residue = _residue;
  if (level == 0)
    mgd->exit_initial_residue = *initial_residue;
  else
    mgd->exit_initial_residue = _initial_residue;
  mgd->exit_cycle_id = cycle_id;

  /* Free memory */

  return cvg;
}

/*! (DOXYGEN_SHOULD_SKIP_THIS) \endcond */

/*============================================================================
 * Public function definitions
 *============================================================================*/

/*----------------------------------------------------------------------------*/
/*!
 * \brief Initialize multigrid solver API.
 */
/*----------------------------------------------------------------------------*/

void
cs_multigrid_initialize(void)
{
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Finalize multigrid solver API.
 */
/*----------------------------------------------------------------------------*/

void
cs_multigrid_finalize(void)
{
  _multigrid_in_use = false;
  cs_grid_finalize();
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Indicate if multigrid solver API is used for at least one system.
 *
 * \return  true if at least one system uses a multigrid solver,
 *          false otherwise
 */
/*----------------------------------------------------------------------------*/

bool
cs_multigrid_needed(void)
{
  return _multigrid_in_use;
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Define and associate a multigrid sparse linear system solver
 *        for a given field or equation name.
 *
 * If this system did not previously exist, it is added to the list of
 * "known" systems. Otherwise, its definition is replaced by the one
 * defined here.
 *
 * This is a utility function: if finer control is needed, see
 * \ref cs_sles_define and \ref cs_multigrid_create.
 *
 * Note that this function returns a pointer directly to the multigrid solver
 * management structure. This may be used to set further options, for
 * example calling \ref cs_multigrid_set_coarsening_options and
 * \ref cs_multigrid_set_solver_options.
 * If needed, \ref cs_sles_find may be used to obtain a pointer to the
 * matching \ref cs_sles_t container.
 *
 * \param[in]  f_id  associated field id, or < 0
 * \param[in]  name  associated name if f_id < 0, or NULL
 *
 * \return  pointer to new multigrid info and context
 */
/*----------------------------------------------------------------------------*/

cs_multigrid_t *
cs_multigrid_define(int          f_id,
                    const char  *name)
{
  cs_multigrid_t *
    mg = cs_multigrid_create();

  cs_sles_t *sc = cs_sles_define(f_id,
                                 name,
                                 mg,
                                 "cs_multigrid_t",
                                 cs_multigrid_setup,
                                 cs_multigrid_solve,
                                 cs_multigrid_free,
                                 cs_multigrid_log,
                                 cs_multigrid_copy,
                                 cs_multigrid_destroy);

  cs_sles_set_error_handler(sc,
                            cs_multigrid_error_post_and_abort);

  return mg;
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Create multigrid linear system solver info and context.
 *
 * The multigrid variant is an ACM (Additive Corrective Multigrid) method.
 *
 * \return  pointer to new multigrid info and context
 */
/*----------------------------------------------------------------------------*/

cs_multigrid_t *
cs_multigrid_create(void)
{
  int ii;
  cs_multigrid_t *mg;

  /* Increment number of setups */

  _multigrid_in_use = true;

  BFT_MALLOC(mg, 1, cs_multigrid_t);

  mg->aggregation_limit = 3;
  mg->coarsening_type = 0;
  mg->n_levels_max = 25;
  mg->n_g_cells_min = 30;

  mg->post_cell_max = 0;

  mg->p0p1_relax = 0.95;

  _multigrid_info_init(&(mg->info));

  mg->n_levels_post = 0;

  mg->setup_data = NULL;

  BFT_MALLOC(mg->lv_info, mg->n_levels_max, cs_multigrid_level_info_t);

  for (ii = 0; ii < mg->n_levels_max; ii++)
    _multigrid_level_info_init(mg->lv_info + ii);

  mg->post_cell_num = NULL;
  mg->post_cell_rank = NULL;
  mg->post_name = NULL;

  return mg;
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Destroy multigrid linear system solver info and context.
 *
 * \param[in, out]  context  pointer to multigrid linear solver info
 *                           (actual type: cs_multigrid_t  **)
 */
/*----------------------------------------------------------------------------*/

void
cs_multigrid_destroy(void  **context)
{
  cs_multigrid_t *mg = (cs_multigrid_t *)(*context);

  if (mg == NULL)
    return;

  BFT_FREE(mg->lv_info);

  if (mg->post_cell_num != NULL) {
    int n_max_post_levels = (int)(mg->info.n_levels[2]) - 1;
    for (int i = 0; i < n_max_post_levels; i++)
      if (mg->post_cell_num[i] != NULL)
        BFT_FREE(mg->post_cell_num[i]);
    BFT_FREE(mg->post_cell_num);
  }

  if (mg->post_cell_rank != NULL) {
    int n_max_post_levels = (int)(mg->info.n_levels[2]) - 1;
    for (int i = 0; i < n_max_post_levels; i++)
      if (mg->post_cell_rank[i] != NULL)
        BFT_FREE(mg->post_cell_rank[i]);
    BFT_FREE(mg->post_cell_rank);
  }

  BFT_FREE(mg->post_name);

  BFT_FREE(mg);
  *context = (void *)mg;
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Create multigrid sparse linear system solver info and context
 *        based on existing info and context.
 *
 * \param[in]  context  pointer to reference info and context
 *                      (actual type: cs_multigrid_t  *)
 *
 * \return  pointer to newly created solver info object
 *          (actual type: cs_multigrid_t  *)
 */
/*----------------------------------------------------------------------------*/

void *
cs_multigrid_copy(const void  *context)
{
  cs_multigrid_t *d = NULL;

  if (context != NULL) {
    const cs_multigrid_t *c = context;
    d = cs_multigrid_create();
    /* Beginning of cs_multigrid_info_t contains settings, the rest logging */
    memcpy(&(d->info), &(c->info),
           offsetof(cs_multigrid_info_t, n_calls));
    /* Same here: settings at beginningof structure */
    memcpy(d, c, offsetof(cs_multigrid_t, n_levels_post));
  }

  return d;
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Log multigrid solver info.
 *
 * \param[in]  context   pointer to iterative solver info and context
 *                       (actual type: cs_multigrid_t  *)
 * \param[in]  log_type  log type
 */
/*----------------------------------------------------------------------------*/

void
cs_multigrid_log(const void  *context,
                 cs_log_t     log_type)
{
  const cs_multigrid_t  *mg = context;

  if (log_type == CS_LOG_SETUP)
    _multigrid_setup_log(mg);

  else if (log_type == CS_LOG_PERFORMANCE)
    _multigrid_performance_log(mg);
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Set multigrid coarsening parameters.
 *
 * \param[in, out]  mg                 pointer to multigrid info and context
 * \param[in]       aggregation_limit  maximum allowed fine cells
 *                                     per coarse cell
 * \param[in]       coarsening_type    coarsening type:
 *                                      0: algebraic, natural face traversal;
 *                                      1: algebraic, face traveral by criteria;
 *                                      2: algebraic, Hilbert face traversal;
 * \param[in]      n_max_levels        maximum number of grid levels
 * \param[in]      min_g_cells         global number of cells on coarse grids
 *                                     under which no coarsening occurs
 * \param[in]      p0p1_relax          p0/p1 relaxation_parameter
 * \param[in]      postprocess         if > 0, postprocess coarsening
 *                                     (uses coarse cell numbers
 *                                      modulo this value)
 */
/*----------------------------------------------------------------------------*/

void
cs_multigrid_set_coarsening_options(cs_multigrid_t  *mg,
                                    int              aggregation_limit,
                                    int              coarsening_type,
                                    int              n_max_levels,
                                    cs_gnum_t        min_g_cells,
                                    double           p0p1_relax,
                                    int              postprocess)
{
  if (mg == NULL)
    return;

  mg->aggregation_limit = aggregation_limit;
  mg->coarsening_type = coarsening_type;
  mg->n_levels_max = n_max_levels;
  mg->n_g_cells_min = min_g_cells;

  mg->post_cell_max = postprocess;

  mg->p0p1_relax = p0p1_relax;
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Set multigrid parameters for associated iterative solvers.
 *
 * \param[in, out]  mg                      pointer to multigrid info
 *                                          and context
 * \param[in]       descent_smoother_type   type of smoother for descent
 * \param[in]       ascent_smoother_type    type of smoother for ascent
 * \param[in]       coarse_solver_type      type of solver for coarsest grid
 * \param[in]       n_max_cycles            maximum number of cycles
 * \param[in]       n_max_iter_descent      maximum iterations
 *                                          per descent smoothing
 * \param[in]       n_max_iter_ascent       maximum iterations
 *                                          per ascent smmothing
 * \param[in]       n_max_iter_coarse       maximum iterations
 *                                          per coarsest solution
 * \param[in]       poly_degree_descent     preconditioning polynomial degree
 *                                          for descent phases (0: diagonal)
 * \param[in]       poly_degree_ascent      preconditioning polynomial degree
 *                                          for ascent phases (0: diagonal)
 * \param[in]       poly_degree_coarse      preconditioning polynomial degree
 *                                          for coarse solver (0: diagonal)
 * \param[in]      precision_mult_descent   precision multiplier
 *                                          for descent smoothers (levels >= 1)
 * \param[in]      precision_mult_ascent    precision multiplier
 *                                          for ascent smoothers
 * \param[in]      precision_mult_coarse    precision multiplier
 *                                          for coarsest grid
 */
/*----------------------------------------------------------------------------*/

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
                                double              precision_mult_coarse)
{
  if (mg == NULL)
    return;

  cs_multigrid_info_t  *info = &(mg->info);

  info->type[0] = descent_smoother_type;
  info->type[1] = ascent_smoother_type;
  info->type[2] = coarse_solver_type;

  info->n_max_cycles = n_max_cycles;

  info->n_max_iter[0] = n_max_iter_descent;
  info->n_max_iter[1] = n_max_iter_ascent;
  info->n_max_iter[2] = n_max_iter_coarse;

  info->poly_degree[0] = poly_degree_descent;
  info->poly_degree[1] = poly_degree_ascent;
  info->poly_degree[2] = poly_degree_coarse;

  info->precision_mult[0] = precision_mult_descent;
  info->precision_mult[1] = precision_mult_ascent;
  info->precision_mult[2] = precision_mult_coarse;
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Setup multigrid sparse linear equation solver.
 *
 * \param[in, out]  context    pointer to multigrid solver info and context
 *                             (actual type: cs_multigrid_t  *)
 * \param[in]       name       pointer to name of linear system
 * \param[in]       a          associated matrix
 * \param[in]       verbosity  associated verbosity
 */
/*----------------------------------------------------------------------------*/

void
cs_multigrid_setup(void               *context,
                   const char         *name,
                   const cs_matrix_t  *a,
                   int                 verbosity)
{
  cs_multigrid_t  *mg = context;

  cs_timer_t t0, t1, t2;

  int n_coarse_ranks = cs_glob_n_ranks;
  int n_coarse_ranks_prev = 0;
  cs_lnum_t n_cells = 0;
  cs_lnum_t n_cells_with_ghosts = 0;
  cs_lnum_t n_faces = 0;
  cs_gnum_t n_g_cells = 0;
  cs_gnum_t n_g_cells_prev = 0;

  cs_int_t grid_lv = 0;
  cs_multigrid_level_info_t *mg_lv_info = NULL;

  const cs_mesh_t  *mesh = cs_glob_mesh;
  const cs_mesh_quantities_t  *mq = cs_glob_mesh_quantities;

  cs_grid_t *g = NULL;

  /* Destroy previous hierarchy if necessary */

  if (mg->setup_data != NULL)
    cs_multigrid_free(mg);

  /* Initialization */

  t0 = cs_timer_time();

  if (verbosity > 1)
    bft_printf(_("\n Construction of grid hierarchy for \"%s\"\n"),
               name);

  mg->setup_data = _multigrid_setup_data_create();

  /* Build coarse grids hierarchy */
  /*------------------------------*/

  bool symmetric = cs_matrix_is_symmetric(a);
  const int *diag_block_size = cs_matrix_get_diag_block_size(a);
  const int *extra_diag_block_size = cs_matrix_get_extra_diag_block_size(a);

  const cs_real_t *da = cs_matrix_get_diagonal(a);
  const cs_real_t *xa = cs_matrix_get_extra_diagonal(a);

  g = cs_grid_create_from_shared(mesh->n_cells,
                                 mesh->n_cells_with_ghosts,
                                 mesh->n_i_faces,
                                 symmetric,
                                 diag_block_size,
                                 extra_diag_block_size,
                                 (const cs_lnum_2_t *)(mesh->i_face_cells),
                                 mesh->halo,
                                 mesh->i_face_numbering,
                                 mq->cell_cen,
                                 mq->cell_vol,
                                 mq->i_face_normal,
                                 da,
                                 xa);

  _multigrid_add_level(mg, g); /* Assign to hierarchy */

  /* Add info */

  n_cells = mesh->n_cells;
  n_cells_with_ghosts = mesh->n_cells_with_ghosts;
  n_faces = mesh->n_i_faces;
  n_g_cells = mesh->n_g_cells;

  mg_lv_info = mg->lv_info;

  t1 = cs_timer_time();
  cs_timer_counter_add_diff(&(mg_lv_info->t_tot[0]), &t0, &t1);

  while (true) {

    n_g_cells_prev = n_g_cells;
    n_coarse_ranks_prev = n_coarse_ranks;

    /* Recursion test */

    if (grid_lv >= mg->n_levels_max)
      break;

    /* Build coarser grid from previous grid */

    grid_lv += 1;

    if (verbosity > 2)
      bft_printf(_("\n   building level %2d grid\n"), grid_lv);

    g = cs_grid_coarsen(g,
                        verbosity,
                        mg->coarsening_type,
                        mg->aggregation_limit,
                        mg->p0p1_relax);

    cs_grid_get_info(g,
                     &grid_lv,
                     &symmetric,
                     NULL,
                     NULL,
                     &n_coarse_ranks,
                     &n_cells,
                     &n_cells_with_ghosts,
                     &n_faces,
                     &n_g_cells);

    _multigrid_add_level(mg, g); /* Assign to hierarchy */

    /* Print coarse mesh stats */

    if (verbosity > 2) {

#if defined(HAVE_MPI)

      if (cs_glob_n_ranks > 1) {

        int lcount[2], gcount[2];
        int n_c_min, n_c_max, n_f_min, n_f_max;

        lcount[0] = n_cells; lcount[1] = n_faces;
        MPI_Allreduce(lcount, gcount, 2, MPI_INT, MPI_MAX,
                      cs_glob_mpi_comm);
        n_c_max = gcount[0]; n_f_max = gcount[1];

        lcount[0] = n_cells; lcount[1] = n_faces;
        MPI_Allreduce(lcount, gcount, 2, MPI_INT, MPI_MIN,
                      cs_glob_mpi_comm);
        n_c_min = gcount[0]; n_f_min = gcount[1];

        bft_printf
          (_("                                  total       min        max\n"
             "     number of cells:     %12llu %10d %10d\n"
             "     number of faces:                  %10d %10d\n"),
           (unsigned long long)n_g_cells, n_c_min, n_c_max, n_f_min, n_f_max);
      }

#endif

      if (cs_glob_n_ranks == 1)
        bft_printf(_("     number of cells:     %10d\n"
                     "     number of faces:     %10d\n"),
                   (int)n_cells, (int)n_faces);

    }

    mg_lv_info = mg->lv_info + grid_lv;
    mg_lv_info->n_ranks[0] = n_coarse_ranks;
    mg_lv_info->n_elts[0][0] = n_cells;
    mg_lv_info->n_elts[1][0] = n_cells_with_ghosts;
    mg_lv_info->n_elts[2][0] = n_faces;

    t2 = cs_timer_time();
    cs_timer_counter_add_diff(&(mg_lv_info->t_tot[0]), &t1, &t2);
    t1 = t2;

    /* If too few cells were grouped, we stop at this level */

    if (n_g_cells <= mg->n_g_cells_min)
      break;
    else if (n_g_cells > (0.8 * n_g_cells_prev)
        && n_coarse_ranks == n_coarse_ranks_prev)
      break;
  }

  /* Print final info */

  if (verbosity > 1)
    bft_printf
      (_("   number of coarse grids:           %d\n"
         "   number of cells in coarsest grid: %llu\n\n"),
       grid_lv, (unsigned long long)n_g_cells);

  /* Prepare preprocessing info if necessary */

  if (mg->post_cell_max > 0) {
    if (mg->info.n_calls[0] == 0)
      cs_post_add_time_dep_output(_cs_multigrid_post_function, (void *)mg);
    _multigrid_add_post(mg, name, mesh->n_cells);
  }

  /* Update info */

#if defined(HAVE_MPI)

  /* In parallel, get global (average) values from local values */

  if (cs_glob_n_ranks > 1) {

    int i, j;
    cs_gnum_t *_n_elts_l = NULL, *_n_elts_s = NULL, *_n_elts_m = NULL;

    BFT_MALLOC(_n_elts_l, 3*grid_lv, cs_gnum_t);
    BFT_MALLOC(_n_elts_s, 3*grid_lv, cs_gnum_t);
    BFT_MALLOC(_n_elts_m, 3*grid_lv, cs_gnum_t);

    for (i = 0; i < grid_lv; i++) {
      cs_multigrid_level_info_t *mg_inf = mg->lv_info + i;
      for (j = 0; j < 3; j++)
        _n_elts_l[i*3 + j] = mg_inf->n_elts[j][0];
    }

    MPI_Allreduce(_n_elts_l, _n_elts_s, 3*grid_lv, CS_MPI_GNUM, MPI_SUM,
                  cs_glob_mpi_comm);
    MPI_Allreduce(_n_elts_l, _n_elts_m, 3*grid_lv, CS_MPI_GNUM, MPI_MAX,
                  cs_glob_mpi_comm);

    for (i = 0; i < grid_lv; i++) {
      cs_multigrid_level_info_t *mg_inf = mg->lv_info + i;
      cs_gnum_t n_g_ranks = mg_inf->n_ranks[0];
      for (j = 0; j < 3; j++) {
        cs_gnum_t tmp_max = n_g_ranks * _n_elts_m[i*3+j];
        mg_inf->n_elts[j][0] = (_n_elts_s[i*3+j] + n_g_ranks/2) / n_g_ranks;
        mg_inf->unbalance[j][0] = (float)(tmp_max*1.0/_n_elts_s[i*3+j]);
      }
    }

    BFT_FREE(_n_elts_m);
    BFT_FREE(_n_elts_s);
    BFT_FREE(_n_elts_l);

  }

#endif

  mg->info.n_levels_tot += grid_lv;

  mg->info.n_levels[0] = grid_lv;

  if (mg->info.n_calls[0] > 0) {
    if (mg->info.n_levels[0] < mg->info.n_levels[1])
      mg->info.n_levels[1] = mg->info.n_levels[0];
    if (mg->info.n_levels[0] > mg->info.n_levels[2])
      mg->info.n_levels[2] = mg->info.n_levels[0];
  }
  else {
    mg->info.n_levels[1] = mg->info.n_levels[0];
    mg->info.n_levels[2] = mg->info.n_levels[0];
  }

  mg->info.n_calls[0] += 1;

  /* Setup solvers */

  _multigrid_setup_sles_it(mg, name, verbosity);

  /* Update timers */

  t2 = cs_timer_time();
  cs_timer_counter_add_diff(&(mg->info.t_tot[0]), &t0, &t2);
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Call multigrid sparse linear equation solver.
 *
 * \param[in, out]  context        pointer to multigrid solver info and context
 *                                 (actual type: cs_multigrid_t  *)
 * \param[in]       name           pointer to name of linear system
 * \param[in]       a              matrix
 * \param[in]       verbosity      associated verbosity
 * \param[in]       rotation_mode  halo update option for rotational periodicity
 * \param[in]       precision      solver precision
 * \param[in]       r_norm         residue normalization
 * \param[out]      n_iter         number of "equivalent" iterations
 * \param[out]      residue        residue
 * \param[in]       rhs            right hand side
 * \param[in, out]  vx             system solution
 * \param[in]       aux_size       size of aux_vectors (in bytes)
 * \param           aux_vectors    optional working area
 *                                 (internal allocation if NULL)
 *
 * \return  convergence state
 */
/*----------------------------------------------------------------------------*/

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
                   void                *aux_vectors)
{
  cs_timer_t t0, t1;
  t0 = cs_timer_time();

  cs_sles_convergence_state_t cvg = CS_SLES_ITERATING;

  cs_multigrid_t *mg = context;
  cs_multigrid_info_t *mg_info = &(mg->info);

  const int *db_size = cs_matrix_get_diag_block_size(a);

  assert(db_size[0] == db_size[1]);

  cs_lnum_t n_rows = cs_matrix_get_n_rows(a);

  /* Initialize number of equivalent iterations and residue,
     check for immediate return,
     solve sparse linear system using multigrid algorithm. */

  *n_iter = 0;
  unsigned n_cycles = 0;

  if (mg->setup_data == NULL) {
    /* Stop solve timer to switch to setup timer */
    t1 = cs_timer_time();
    cs_timer_counter_add_diff(&(mg->info.t_tot[1]), &t0, &t1);

    /* Setup grid hierarchy */
    cs_multigrid_setup(context, name, a, verbosity);

    /* Restart solve timer */
    t0 = cs_timer_time();
  }

  /* Buffer size sufficient to avoid local reallocation for most solvers */
  size_t  lv_names_size = _level_names_size(name, mg->setup_data->n_levels);
  size_t  _aux_size =   lv_names_size
                      + n_rows * 6 * db_size[1] * sizeof(cs_real_t);
  unsigned char *_aux_buf = aux_vectors;

  if (_aux_size > aux_size)
    BFT_MALLOC(_aux_buf, _aux_size, unsigned char);
  else
    _aux_size = aux_size;

  _level_names_init(name, mg->setup_data->n_levels, _aux_buf);
  const char **lv_names = (const char **)_aux_buf;

  if (verbosity == 2) /* More detailed headers later if > 2 */
    bft_printf(_("Multigrid [%s]:\n"), name);

  /* Initial residue should be improved, but this is consistent
     with the legacy (by increment) case */

  double initial_residue = -1;

  *residue = initial_residue; /* not known yet, so be safe */

  /* Cycle to solution */

  while (cvg == CS_SLES_ITERATING) {

    int cycle_id = n_cycles + 1;

    if (verbosity > 2)
      bft_printf(_("Multigrid [%s]: cycle %4d\n"), name, cycle_id);

    cvg = _multigrid_cycle(mg,
                           lv_names,
                           verbosity,
                           rotation_mode,
                           cycle_id,
                           n_iter,
                           precision,
                           r_norm,
                           &initial_residue,
                           residue,
                           rhs,
                           vx,
                           _aux_size - lv_names_size,
                           _aux_buf + lv_names_size);

    n_cycles++;
  }

  if (_aux_buf != aux_vectors)
    BFT_FREE(_aux_buf);

  /* Update statistics */

  t1 = cs_timer_time();

  /* Update stats on number of iterations (last, min, max, total) */

  mg_info->n_cycles[2] += n_cycles;

  if (mg_info->n_calls[1] > 0) {
    if (mg_info->n_cycles[0] > n_cycles)
      mg_info->n_cycles[0] = n_cycles;
    if (mg_info->n_cycles[1] < n_cycles)
      mg_info->n_cycles[1] = n_cycles;
  }
  else {
    mg_info->n_cycles[0] = n_cycles;
    mg_info->n_cycles[1] = n_cycles;
  }

  /* Update number of resolutions and timing data */

  mg_info->n_calls[1] += 1;
  cs_timer_counter_add_diff(&(mg->info.t_tot[1]), &t0, &t1);

  return cvg;
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Free multigrid sparse linear equation solver setup context.
 *
 * This function frees resolution-related data, incuding the current
 * grid hierarchy, but does not free the whole context,
 * as info used for logging (especially performance data) is maintained.
 *
 * \param[in, out]  context  pointer to multigrid solver info and context
 *                           (actual type: cs_multigrid_t  *)
 */
/*----------------------------------------------------------------------------*/

void
cs_multigrid_free(void  *context)
{
  cs_multigrid_t *mg = context;

  cs_timer_t t0, t1;

  /* Initialization */

  t0 = cs_timer_time();

  if (mg->setup_data != NULL) {

    cs_multigrid_setup_data_t *mgd = mg->setup_data;

    /* Free coarse solution data */

    BFT_FREE(mgd->rhs_vx);
    BFT_FREE(mgd->rhs_vx_buf);

    /* Destroy solver hierarchy */

    for (int i = mgd->n_levels - 1; i > -1; i--) {
      for (int j = 0; j < 2; j++) {
        if (mgd->sles_hierarchy[i*2+j] != NULL) {
          void *sles_it = mgd->sles_hierarchy[i*2 + j];
          cs_sles_it_destroy(&sles_it);
        }
      }
    }
    BFT_FREE(mgd->sles_hierarchy);

    /* Destroy grid hierarchy */

    for (int i = mgd->n_levels - 1; i > -1; i--)
      cs_grid_destroy(mgd->grid_hierarchy + i);
    BFT_FREE(mgd->grid_hierarchy);

    BFT_FREE(mg->setup_data);

  }

  /* Update timers */

  t1 = cs_timer_time();
  cs_timer_counter_add_diff(&(mg->info.t_tot[0]), &t0, &t1);
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Error handler for multigrid sparse linear equation solver.
 *
 * In case of divergence or breakdown, this error handler outputs
 * postprocessing data to assist debugging, then aborts the run.
 * It does nothing in case the maximum iteration count is reached.

 * \param[in, out]  context        pointer to multigrid solver info and context
 *                                 (actual type: cs_multigrid_t  *)
 * \param[in]       state          convergence state
 * \param[in]       name           pointer to name of linear system
 * \param[in]       a              matrix
 * \param[in]       rotation_mode  halo update option for rotational periodicity
 * \param[in]       rhs            right hand side
 * \param[in, out]  vx             system solution
 */
/*----------------------------------------------------------------------------*/

void
cs_multigrid_error_post_and_abort(void                         *context,
                                  cs_sles_convergence_state_t   state,
                                  const char                   *name,
                                  const cs_matrix_t            *a,
                                  cs_halo_rotation_t            rotation_mode,
                                  const cs_real_t               rhs[],
                                  cs_real_t                     vx[])
{
  if (state >= CS_SLES_MAX_ITERATION)
    return;

  const cs_multigrid_t  *mg = context;
  cs_multigrid_setup_data_t *mgd = mg->setup_data;

  int level = mgd->exit_level;

  int mesh_id = cs_post_init_error_writer_cells();

  if (mesh_id != 0) {

    char var_name[32];

    int lv_id = 0;
    cs_real_t *var = NULL, *da = NULL;

    int i;
    int db_size[4] = {1, 1, 1, 1};
    int eb_size[4] = {1, 1, 1, 1};

    const cs_grid_t *g = mgd->grid_hierarchy[0];
    const cs_lnum_t n_base_cells = cs_grid_get_n_cells(g);
    const cs_matrix_t  *_matrix = NULL;

    BFT_MALLOC(var, cs_grid_get_n_cells_ext(g), cs_real_t);
    BFT_MALLOC(da, cs_grid_get_n_cells_ext(g), cs_real_t);

    /* Output info on main level */

    cs_sles_post_error_output_def(name,
                                  mesh_id,
                                  rotation_mode,
                                  a,
                                  rhs,
                                  vx);

    /* Output diagonal and diagonal dominance for all coarse levels */

    for (lv_id = 1; lv_id < (int)(mgd->n_levels); lv_id++) {

      g = mgd->grid_hierarchy[lv_id];

      cs_grid_get_info(g,
                       NULL,
                       NULL,
                       db_size,
                       eb_size,
                       NULL,
                       NULL,
                       NULL,
                       NULL,
                       NULL);


      _matrix = cs_grid_get_matrix(g);

      cs_matrix_copy_diagonal(_matrix, da);
      cs_grid_project_var(g, n_base_cells, da, var);
      sprintf(var_name, "Diag_%04d", lv_id);
      cs_sles_post_error_output_var(var_name, mesh_id, db_size[1], var);

      cs_grid_project_diag_dom(g, n_base_cells, var);
      sprintf(var_name, "Diag_Dom_%04d", lv_id);
      cs_sles_post_error_output_var(var_name, mesh_id, db_size[1], var);
    }

    /* Output info on current level if > 0 */

    if (level > 0) {

      cs_lnum_t ii;
      cs_lnum_t n_cells = 0;
      cs_lnum_t n_cells_ext = 0;

      cs_real_t *c_res = NULL;

      g = mgd->grid_hierarchy[level];

      cs_grid_get_info(g,
                       NULL,
                       NULL,
                       db_size,
                       eb_size,
                       NULL,
                       &n_cells,
                       &n_cells_ext,
                       NULL,
                       NULL);

      cs_grid_project_var(g, n_base_cells, mgd->rhs_vx[level*2], var);
      sprintf(var_name, "RHS_%04d", level);
      cs_sles_post_error_output_var(var_name, mesh_id, db_size[1], var);

      cs_grid_project_var(g, n_base_cells, mgd->rhs_vx[level*2+1], var);
      sprintf(var_name, "X_%04d", level);
      cs_sles_post_error_output_var(var_name, mesh_id, db_size[1], var);

      /* Compute residual */

      BFT_MALLOC(c_res, n_cells_ext*db_size[1], cs_real_t);

      _matrix = cs_grid_get_matrix(g);

      cs_matrix_vector_multiply(rotation_mode,
                                _matrix,
                                mgd->rhs_vx[level*2+1],
                                c_res);

      const cs_real_t *c_rhs_lv = mgd->rhs_vx[level*2];
      for (ii = 0; ii < n_cells; ii++) {
        for (i = 0; i < db_size[0]; i++)
          c_res[ii*db_size[1] + i]
            = fabs(c_res[ii*db_size[1] + i] - c_rhs_lv[ii*db_size[1] + i]);
      }

      cs_grid_project_var(g, n_base_cells, c_res, var);

      BFT_FREE(c_res);

      sprintf(var_name, "Residual_%04d", level);
      cs_sles_post_error_output_var(var_name, mesh_id, db_size[1], var);
    }

    cs_post_finalize();

    BFT_FREE(da);
    BFT_FREE(var);
  }

  /* Now abort */

  const char *error_type[] = {N_("divergence"), N_("breakdown")};
  int err_id = (state == CS_SLES_BREAKDOWN) ? 1 : 0;

  if (level == 0)
    bft_error(__FILE__, __LINE__, 0,
              _("algebraic multigrid [%s]: %s after %d cycles:\n"
                "  initial residual: %11.4e; current residual: %11.4e"),
              name, _(error_type[err_id]), mgd->exit_cycle_id,
              mgd->exit_initial_residue, mgd->exit_residue);
  else
    bft_error(__FILE__, __LINE__, 0,
              _("algebraic multigrid [%s]: %s after %d cycles\n"
                "  during resolution at level %d:\n"
                "  initial residual: %11.4e; current residual: %11.4e"),
              name, _(error_type[err_id]),
              mgd->exit_cycle_id, level,
              mgd->exit_initial_residue, mgd->exit_residue);
}

/*----------------------------------------------------------------------------*/

END_C_DECLS
