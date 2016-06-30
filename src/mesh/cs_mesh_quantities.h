#ifndef __CS_MESH_QUANTITIES_H__
#define __CS_MESH_QUANTITIES_H__

/*============================================================================
 * Management of mesh quantities
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
#include "cs_mesh.h"

/*----------------------------------------------------------------------------*/

BEGIN_C_DECLS

/*=============================================================================
 * Local Macro definitions
 *============================================================================*/

/*============================================================================
 * Type definition
 *============================================================================*/

/* Structure associated to mesh quantities management */

typedef struct {

  cs_real_t     *cell_cen;       /* Cell center coordinates  */
  cs_real_t     *cell_vol;       /* Cell volume */

  cs_real_t     *i_face_normal;  /* Surface normal of interior faces.
                                    (L2 norm equals area of the face) */
  cs_real_t     *b_face_normal;  /* Surface normal of border faces.
                                    (L2 norm equals area of the face) */
  cs_real_t     *i_face_cog;     /* Center of gravity of interior faces */
  cs_real_t     *b_face_cog;     /* Center of gravity of border faces */

  cs_real_t     *i_face_surf;    /* Surface of interior faces. */
  cs_real_t     *b_face_surf;    /* Surface of boundary faces. */

  cs_real_t     *dijpf;          /* Vector I'J' for interior faces */
  cs_real_t     *diipb;          /* Vector II'  for border faces */
  cs_real_t     *dofij;          /* Vector OF   for interior faces */
  cs_real_t     *diipf;          /* Vector II'  for interior faces */
  cs_real_t     *djjpf;          /* Vector JJ'  for interior faces */

  cs_real_t     *i_dist;         /* Distance between the cell center and
                                    the center of gravity of interior faces */
  cs_real_t     *b_dist;         /* Distance between the cell center and
                                    the center of gravity of border faces */

  cs_real_t     *weight;         /* Interior faces weighting factor */

  cs_real_t      min_vol;        /* Minimum cell volume */
  cs_real_t      max_vol;        /* Maximum cell volume */
  cs_real_t      tot_vol;        /* Total volume */

  cs_real_33_t  *cocgb_s_it;     /* coupling of gradient compponents for
                                    iterative reconstruction at boundary */
  cs_real_33_t  *cocg_s_it;      /* coupling of gradient compponents for
                                    iterative reconstruction */
  cs_real_33_t  *cocgb_s_lsq;    /* coupling of gradient compponents for
                                    least-square reconstruction at boundary */
  cs_real_33_t  *cocg_s_lsq;     /* coupling of gradient compponents for
                                    least-square reconstruction */

  cs_real_33_t  *cocg_it;        /* Interleaved cocg matrix
                                    for iterative gradients */
  cs_real_33_t  *cocg_lsq;       /* Interleaved cocg matrix
                                    for least square gradients */

  cs_int_t      *b_sym_flag;     /* Symmetry flag for boundary faces */
  unsigned      *bad_cell_flag;  /* Flag (mask) for bad cells detected */

} cs_mesh_quantities_t ;

/*============================================================================
 * Static global variables
 *============================================================================*/

/* Pointer to mesh quantities structure associated to the main mesh */

extern cs_mesh_quantities_t  *cs_glob_mesh_quantities;

/*============================================================================
 * Public function prototypes for API Fortran
 *============================================================================*/

/*----------------------------------------------------------------------------
 * Query or modification of the option for computing cell centers.
 *
 * This function returns 1 or 2 according to the selected algorithm.
 *
 * Fortran interface :
 *
 * SUBROUTINE ALGCEN (IOPT)
 * *****************
 *
 * INTEGER          IOPT        : <-> : Choice of the algorithm
 *                                      < 0 : query
 *                                        0 : computation based
 *                                            on faces (default choice)
 *                                        1 : computation based
 *                                            on vertices
 *----------------------------------------------------------------------------*/

void
CS_PROCF (algcen, ALGCEN) (cs_int_t  *const iopt);

/*----------------------------------------------------------------------------
 * Set behavior for computing the cocg matrixes for the iterative algo
 * and for the Least square method for scalar and vector gradients.
 *
 * Fortran interface :
 *
 * subroutine comcoc (imrgra)
 * *****************
 *
 * integer          imrgra        : <-- : gradient reconstruction option
 *----------------------------------------------------------------------------*/

void
CS_PROCF (comcoc, COMCOC) (const cs_int_t  *const imrgra);

/*=============================================================================
 * Public function prototypes
 *============================================================================*/

/*----------------------------------------------------------------------------
 * Query or modification of the option for computing cell centers.
 *
 *  < 0 : query
 *    0 : computation based on faces (default choice)
 *    1 : computation based on vertices
 *
 * algo_choice  <--  choice of algorithm to compute cell centers.
 *
 * returns:
 *  1 or 2 according to the selected algorithm.
 *----------------------------------------------------------------------------*/

int
cs_mesh_quantities_cell_cen_choice(const int algo_choice);

/*----------------------------------------------------------------------------
 * Compute cocg for iterative gradient reconstruction for scalars.
 *
 * parameters:
 *   gradient_option <-- gradient option (Fortran IMRGRA)
 *----------------------------------------------------------------------------*/

void
cs_mesh_quantities_set_cocg_options(int  gradient_option);

/*----------------------------------------------------------------------------
 * Create a mesh quantities structure.
 *
 * returns:
 *   pointer to created cs_mesh_quantities_t structure
 *----------------------------------------------------------------------------*/

cs_mesh_quantities_t  *
cs_mesh_quantities_create(void);

/*----------------------------------------------------------------------------
 * Destroy a mesh quantities structure
 *
 * parameters:
 *   mesh_quantities <-- pointer to a cs_mesh_quantities_t structure
 *
 * returns:
 *  NULL
 *----------------------------------------------------------------------------*/

cs_mesh_quantities_t *
cs_mesh_quantities_destroy(cs_mesh_quantities_t  *mesh_quantities);

/*----------------------------------------------------------------------------
 * Compute mesh quantities
 *
 * parameters:
 *   mesh            <-- pointer to a cs_mesh_t structure
 *   mesh_quantities <-> pointer to a cs_mesh_quantities_t structure
 *----------------------------------------------------------------------------*/

void
cs_mesh_quantities_compute(const cs_mesh_t       *mesh,
                           cs_mesh_quantities_t  *mesh_quantities);

/*----------------------------------------------------------------------------
 * Compute mesh quantities
 *
 * parameters:
 *   mesh            <-- pointer to a cs_mesh_t structure
 *   mesh_quantities <-> pointer to a cs_mesh_quantities_t structure
 *----------------------------------------------------------------------------*/

void
cs_mesh_quantities_sup_vectors(const cs_mesh_t       *mesh,
                               cs_mesh_quantities_t  *mesh_quantities);

/*----------------------------------------------------------------------------
 * Compute internal and border face normal.
 *
 * parameters:
 *   mesh            <-- pointer to a cs_mesh_t structure
 *   p_i_face_normal <-> pointer to the internal face normal array
 *   p_b_face_normal <-> pointer to the border face normal array
 *----------------------------------------------------------------------------*/

void
cs_mesh_quantities_face_normal(const cs_mesh_t   *mesh,
                               cs_real_t         *p_i_face_normal[],
                               cs_real_t         *p_b_face_normal[]);

/*----------------------------------------------------------------------------
 * Compute interior face centers and normals.
 *
 * The corresponding arrays are allocated by this function, and it is the
 * caller's responsibility to free them when they are no longer needed.
 *
 * parameters:
 *   mesh            <-- pointer to a cs_mesh_t structure
 *   p_i_face_cog    <-> pointer to the interior face center array
 *   p_i_face_normal <-> pointer to the interior face normal array
 *----------------------------------------------------------------------------*/

void
cs_mesh_quantities_i_faces(const cs_mesh_t   *mesh,
                           cs_real_t         *p_i_face_cog[],
                           cs_real_t         *p_i_face_normal[]);

/*----------------------------------------------------------------------------
 * Compute border face centers and normals.
 *
 * The corresponding arrays are allocated by this function, and it is the
 * caller's responsibility to free them when they are no longer needed.
 *
 * parameters:
 *   mesh            <-- pointer to a cs_mesh_t structure
 *   p_b_face_cog    <-> pointer to the border face center array
 *   p_b_face_normal <-> pointer to the border face normal array
 *----------------------------------------------------------------------------*/

void
cs_mesh_quantities_b_faces(const cs_mesh_t   *mesh,
                           cs_real_t         *p_b_face_cog[],
                           cs_real_t         *p_b_face_normal[]);

/*----------------------------------------------------------------------------
 * Check that no negative volumes are present, and exit on error otherwise.
 *
 * parameters:
 *   mesh            <-- pointer to mesh structure
 *   mesh_quantities <-- pointer to mesh quantities structure
 *   allow_error     <-- 1 if errors are allowed, 0 otherwise
 *----------------------------------------------------------------------------*/

void
cs_mesh_quantities_check_vol(const cs_mesh_t             *mesh,
                             const cs_mesh_quantities_t  *mesh_quantities,
                             int                          allow_error);

/*----------------------------------------------------------------------------
 * Update mesh quantities relative to extended ghost cells when the
 * neighborhood is reduced.
 *
 * parameters:
 *   mesh            <-- pointer to a cs_mesh_t structure
 *   mesh_quantities <-> pointer to a cs_mesh_quantities_t structure
 *----------------------------------------------------------------------------*/

void
cs_mesh_quantities_reduce_extended(const cs_mesh_t       *mesh,
                                   cs_mesh_quantities_t  *mesh_quantities);

/*----------------------------------------------------------------------------
 * Return the number of times mesh quantities have been computed.
 *
 * returns:
 *   number of times mesh quantities have been computed
 *----------------------------------------------------------------------------*/

int
cs_mesh_quantities_compute_count(void);

/*----------------------------------------------------------------------------
 * Dump a cs_mesh_quantities_t structure
 *
 * parameters:
 *   mesh            <-- pointer to a cs_mesh_t structure
 *   mesh_quantities <-- pointer to a cs_mesh_quantities_t structure
 *----------------------------------------------------------------------------*/

void
cs_mesh_quantities_dump(const cs_mesh_t             *mesh,
                        const cs_mesh_quantities_t  *mesh_quantities);

/*----------------------------------------------------------------------------*/

END_C_DECLS

#endif /* __CS_MESH_QUANTITIES_H__ */
