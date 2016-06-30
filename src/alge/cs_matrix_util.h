#ifndef __CS_MATRIX_UTIL_H__
#define __CS_MATRIX_UTIL_H__

/*============================================================================
 * Utilitary functions for sparse matrixes.
 *============================================================================*/

/*----------------------------------------------------------------------------
 *  Local headers
 *----------------------------------------------------------------------------*/

#include "cs_defs.h"

#include "cs_halo.h"
#include "cs_numbering.h"

#include "cs_matrix.h"

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
 * Compute diagonal dominance metric.
 *
 * parameters:
 *   matrix <-- pointer to matrix structure
 *   dd     --> diagonal dominance (normalized)
 *----------------------------------------------------------------------------*/

void
cs_matrix_diag_dominance(const cs_matrix_t  *matrix,
                         cs_real_t           dd[]);

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
                             const char         *name);

/*----------------------------------------------------------------------------
 * Test matrix dump operations.
 *
 * parameters:
 *   n_cells     <-- number of local cells
 *   n_cells_ext <-- number of cells including ghost cells (array size)
 *   n_faces     <-- local number of internal faces
 *   cell_num    <-- global cell numbers (1 to n)
 *   face_cell   <-- face -> cells connectivity
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
                    const cs_numbering_t  *numbering);

/*----------------------------------------------------------------------------*/

END_C_DECLS

#endif /* __CS_MATRIX_UTIL_H__ */
