#ifndef __CS_MATRIX_BUILDING_H__
#define __CS_MATRIX_BUILDING_H__

/*============================================================================
 * Matrix building
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
#include "cs_halo.h"

/*----------------------------------------------------------------------------*/

BEGIN_C_DECLS

/*=============================================================================
 * Local Macro definitions
 *============================================================================*/

/*============================================================================
 * Type definition
 *============================================================================*/

/*============================================================================
 *  Global variables
 *============================================================================*/

/*============================================================================
 * Public function prototypes for Fortran API
 *============================================================================*/

/*----------------------------------------------------------------------------
 * Wrapper to cs_matrix_scalar (or its counterpart for
 * symmetric matrices)
 *----------------------------------------------------------------------------*/

void CS_PROCF (matrix, MATRIX)
(
 const cs_int_t  *const   iconvp,
 const cs_int_t  *const   idiffp,
 const cs_int_t  *const   ndircp,
 const cs_int_t  *const   isym,
 const cs_real_t *const   thetap,
 const cs_int_t  *const   imucpp,
 const cs_real_t          coefbp[],
 const cs_real_t          cofbfp[],
 const cs_real_t          rovsdt[],
 const cs_real_t          i_massflux[],
 const cs_real_t          b_massflux[],
 const cs_real_t          i_visc[],
 const cs_real_t          b_visc[],
 const cs_real_t          xcpp[],
 cs_real_t                da[],
 cs_real_t                xa[]
);

/*----------------------------------------------------------------------------
 * Wrapper to cs_matrix_vector (or its counterpart for
 * symmetric matrices)
 *----------------------------------------------------------------------------*/

void CS_PROCF (matrxv, MATRXV)
(
 const cs_int_t  *const   iconvp,
 const cs_int_t  *const   idiffp,
 const cs_int_t  *const   ndircp,
 const cs_int_t  *const   isym,
 const cs_real_t *const   thetap,
 const cs_real_33_t       coefbu[],
 const cs_real_33_t       cofbfu[],
 const cs_real_33_t       fimp[],
 const cs_real_t          i_massflux[],
 const cs_real_t          b_massflux[],
 const cs_real_t          i_visc[],
 const cs_real_t          b_visc[],
 cs_real_33_t             da[],
 cs_real_t                xa[]
);

/*----------------------------------------------------------------------------
 * Wrapper to cs_matrix_time_step
 *----------------------------------------------------------------------------*/

void CS_PROCF (matrdt, MATRDT)
(
 const cs_int_t  *const   iconvp,
 const cs_int_t  *const   idiffp,
 const cs_int_t  *const   isym,
 const cs_real_t          coefbp[],
 const cs_real_t          cofbfp[],
 const cs_real_t          i_massflux[],
 const cs_real_t          b_massflux[],
 const cs_real_t          i_visc[],
 const cs_real_t          b_visc[],
 cs_real_t                da[]
);

/*----------------------------------------------------------------------------
 * Wrapper to cs_matrix_anisotropic_diffusion (or its counterpart for
 * symmetric matrices)
 *----------------------------------------------------------------------------*/

void CS_PROCF (matrvv, MATRVV)
(
 const cs_int_t  *const   iconvp,
 const cs_int_t  *const   idiffp,
 const cs_int_t  *const   ndircp,
 const cs_int_t  *const   isym,
 const cs_real_t *const   thetap,
 const cs_real_33_t       coefbu[],
 const cs_real_33_t       cofbfu[],
 const cs_real_33_t       fimp[],
 const cs_real_t          i_massflux[],
 const cs_real_t          b_massflux[],
 const cs_real_33_t       i_visc[],
 const cs_real_t          b_visc[],
 cs_real_33_t             da[],
 cs_real_332_t            xa[]
);

/*=============================================================================
 * Public function prototypes
 *============================================================================*/

/*----------------------------------------------------------------------------*/
/*!
 * \brief Build the diffusion matrix for a scalar field.
 * (symmetric matrix).
 *
 * The diffusion is not reconstructed.
 * The matrix is split into a diagonal block (number of cells)
 * and an extra diagonal part (of dimension the number of internal
 * faces).
 *
 * \param[in]     m             pointer to mesh structure
 * \param[in]     idiffp        indicator
 *                               - 1 diffusion
 *                               - 0 otherwise
 * \param[in]     ndircp        indicator
 *                               - 0 if the diagonal stepped aside
 * \param[in]     thetap        weighting coefficient for the theta-scheme,
 *                               - thetap = 0: explicit scheme
 *                               - thetap = 0.5: time-centered
 *                               scheme (mix between Crank-Nicolson and
 *                               Adams-Bashforth)
 *                               - thetap = 1: implicit scheme
 * \param[in]     cofbfp        boundary condition array for the variable flux
 *                               (implicit part)
 * \param[in]     rovsdt        working array
 * \param[in]     i_visc        \f$ \mu_\fij \dfrac{S_\fij}{\ipf \jpf} \f$
 *                               at interior faces for the matrix
 * \param[in]     b_visc        \f$ S_\fib \f$
 *                               at border faces for the matrix
 * \param[out]    da            diagonal part of the matrix
 * \param[out]    xa            extra diagonal part of the matrix
 */
/*----------------------------------------------------------------------------*/

void
cs_sym_matrix_scalar(const cs_mesh_t          *m,
                     int                       idiffp,
                     int                       ndircp,
                     double                    thetap,
                     const cs_real_t           cofbfp[],
                     const cs_real_t           rovsdt[],
                     const cs_real_t           i_visc[],
                     const cs_real_t           b_visc[],
                     cs_real_t       *restrict da,
                     cs_real_t       *restrict xa);

/*----------------------------------------------------------------------------*/
/*!
 * \brief Build the advection/diffusion matrix for a scalar field.
 *
 * The advection is upwind, the diffusion is not reconstructed.
 * The matrix is split into a diagonal block (number of cells)
 * and an extra diagonal part (of dimension 2 time the number of internal
 * faces).
 *
 * \param[in]     m             pointer to mesh structure
 * \param[in]     iconvp        indicator
 *                               - 1 advection
 *                               - 0 otherwise
 * \param[in]     idiffp        indicator
 *                               - 1 diffusion
 *                               - 0 otherwise
 * \param[in]     ndircp        indicator
 *                               - 0 if the diagonal stepped aside
 * \param[in]     thetap        weighting coefficient for the theta-scheme,
 *                               - thetap = 0: explicit scheme
 *                               - thetap = 0.5: time-centered
 *                               scheme (mix between Crank-Nicolson and
 *                               Adams-Bashforth)
 *                               - thetap = 1: implicit scheme
 * \param[in]     imucpp        indicator
 *                               - 0 do not multiply the convective term by Cp
 *                               - 1 do multiply the convective term by Cp
 * \param[in]     coefbp        boundary condition array for the variable
 *                               (implicit part)
 * \param[in]     cofbfp        boundary condition array for the variable flux
 *                               (implicit part)
 * \param[in]     rovsdt        working array
 * \param[in]     i_massflux    mass flux at interior faces
 * \param[in]     b_massflux    mass flux at border faces
 * \param[in]     i_visc        \f$ \mu_\fij \dfrac{S_\fij}{\ipf \jpf} \f$
 *                               at interior faces for the matrix
 * \param[in]     b_visc        \f$ S_\fib \f$
 *                               at border faces for the matrix
 * \param[in]     xcpp          array of specific heat (Cp)
 * \param[out]    da            diagonal part of the matrix
 * \param[out]    xa            extra interleaved diagonal part of the matrix
 */
/*----------------------------------------------------------------------------*/

void
cs_matrix_scalar(const cs_mesh_t          *m,
                 int                       iconvp,
                 int                       idiffp,
                 int                       ndircp,
                 double                    thetap,
                 int                       imucpp,
                 const cs_real_t           coefbp[],
                 const cs_real_t           cofbfp[],
                 const cs_real_t           rovsdt[],
                 const cs_real_t           i_massflux[],
                 const cs_real_t           b_massflux[],
                 const cs_real_t           i_visc[],
                 const cs_real_t           b_visc[],
                 const cs_real_t           xcpp[],
                 cs_real_t       *restrict da,
                 cs_real_2_t     *restrict xa);

/*----------------------------------------------------------------------------*/
/*!
 * \brief Build the diffusion matrix for a vector field
 * (symmetric matrix).
 *
 * The diffusion is not reconstructed.
 * The matrix is split into a diagonal block (3x3 times number of cells)
 * and an extra diagonal part (of dimension the number of internal
 * faces).
 *
 * \param[in]     m             pointer to mesh structure
 * \param[in]     idiffp        indicator
 *                               - 1 diffusion
 *                               - 0 otherwise
 * \param[in]     ndircp        indicator
 *                               - 0 if the diagonal stepped aside
 * \param[in]     thetap        weighting coefficient for the theta-scheme,
 *                               - thetap = 0: explicit scheme
 *                               - thetap = 0.5: time-centered
 *                               scheme (mix between Crank-Nicolson and
 *                               Adams-Bashforth)
 *                               - thetap = 1: implicit scheme
 * \param[in]     cofbfu        boundary condition array for the variable flux
 *                               (implicit part - 3x3 tensor array)
 * \param[in]     i_visc        \f$ \mu_\fij \dfrac{S_\fij}{\ipf \jpf} \f$
 *                               at interior faces for the matrix
 * \param[in]     b_visc        \f$ \mu_\fib \dfrac{S_\fib}{\ipf \centf} \f$
 *                               at border faces for the matrix
 * \param[out]    da            diagonal part of the matrix
 * \param[out]    xa            extra interleaved diagonal part of the matrix
 */
/*----------------------------------------------------------------------------*/

void
cs_sym_matrix_vector(const cs_mesh_t          *m,
                     int                       idiffp,
                     int                       ndircp,
                     double                    thetap,
                     const cs_real_33_t        cofbfu[],
                     const cs_real_33_t        fimp[],
                     const cs_real_t           i_visc[],
                     const cs_real_t           b_visc[],
                     cs_real_33_t    *restrict da,
                     cs_real_t       *restrict xa);

/*----------------------------------------------------------------------------*/
/*!
 * \brief Build the advection/diffusion matrix for a vector field
 * (non-symmetric matrix).
 *
 * The advection is upwind, the diffusion is not reconstructed.
 * The matrix is split into a diagonal block (3x3 times number of cells)
 * and an extra diagonal part (of dimension 2 time the number of internal
 * faces).
 *
 * \param[in]     m             pointer to mesh structure
 * \param[in]     iconvp        indicator
 *                               - 1 advection
 *                               - 0 otherwise
 * \param[in]     idiffp        indicator
 *                               - 1 diffusion
 *                               - 0 otherwise
 * \param[in]     ndircp        indicator
 *                               - 0 if the diagonal stepped aside
 * \param[in]     thetap        weighting coefficient for the theta-scheme,
 *                               - thetap = 0: explicit scheme
 *                               - thetap = 0.5: time-centered
 *                               scheme (mix between Crank-Nicolson and
 *                               Adams-Bashforth)
 *                               - thetap = 1: implicit scheme
 * \param[in]     coefbu        boundary condition array for the variable
 *                               (implicit part - 3x3 tensor array)
 * \param[in]     cofbfu        boundary condition array for the variable flux
 *                               (implicit part - 3x3 tensor array)
 * \param[in]     i_massflux    mass flux at interior faces
 * \param[in]     b_massflux    mass flux at border faces
 * \param[in]     i_visc        \f$ \mu_\fij \dfrac{S_\fij}{\ipf \jpf} \f$
 *                               at interior faces for the matrix
 * \param[in]     b_visc        \f$ \mu_\fib \dfrac{S_\fib}{\ipf \centf} \f$
 *                               at border faces for the matrix
 * \param[out]    da            diagonal part of the matrix
 * \param[out]    xa            extra interleaved diagonal part of the matrix
 */
/*----------------------------------------------------------------------------*/

void
cs_matrix_vector(const cs_mesh_t          *m,
                 int                       iconvp,
                 int                       idiffp,
                 int                       ndircp,
                 double                    thetap,
                 const cs_real_33_t        coefbu[],
                 const cs_real_33_t        cofbfu[],
                 const cs_real_33_t        fimp[],
                 const cs_real_t           i_massflux[],
                 const cs_real_t           b_massflux[],
                 const cs_real_t           i_visc[],
                 const cs_real_t           b_visc[],
                 cs_real_33_t    *restrict da,
                 cs_real_2_t     *restrict xa);

/*----------------------------------------------------------------------------*/
/*!
 * \brief Build the diagonal of the advection/diffusion matrix
 * for determining the variable time step, flow, Fourier.
 *
 * \param[in]     m             pointer to mesh structure
 * \param[in]     iconvp        indicator
 *                               - 1 advection
 *                               - 0 otherwise
 * \param[in]     idiffp        indicator
 *                               - 1 diffusion
 *                               - 0 otherwise
 * \param[in]     isym          indicator
 *                               - 1 symmetric matrix
 *                               - 2 non symmmetric matrix
 * \param[in]     coefbp        boundary condition array for the variable
 *                               (implicit part)
 * \param[in]     cofbfp        boundary condition array for the variable flux
 *                               (implicit part)
 * \param[in]     i_massflux    mass flux at interior faces
 * \param[in]     b_massflux    mass flux at border faces
 * \param[in]     i_visc        \f$ \mu_\fij \dfrac{S_\fij}{\ipf \jpf} \f$
 *                               at interior faces for the matrix
 * \param[in]     b_visc        \f$ S_\fib \f$
 *                               at border faces for the matrix
 * \param[out]    da            diagonal part of the matrix
 */
/*----------------------------------------------------------------------------*/

void
cs_matrix_time_step(const cs_mesh_t          *m,
                    int                       iconvp,
                    int                       idiffp,
                    int                       isym,
                    const cs_real_t           coefbp[],
                    const cs_real_t           cofbfp[],
                    const cs_real_t           i_massflux[],
                    const cs_real_t           b_massflux[],
                    const cs_real_t           i_visc[],
                    const cs_real_t           b_visc[],
                    cs_real_t       *restrict da);

/*----------------------------------------------------------------------------*/
/*!
 * \brief Build the advection/diffusion matrix for a vector field with a
 * tensorial diffusivity.
 *
 * The advection is upwind, the diffusion is not reconstructed.
 * The matrix is split into a diagonal block (3x3 times number of cells)
 * and an extra diagonal part (of dimension 2 times 3x3 the number of internal
 * faces).
 *
 * \param[in]     m             pointer to mesh structure
 * \param[in]     iconvp        indicator
 *                               - 1 advection
 *                               - 0 otherwise
 * \param[in]     idiffp        indicator
 *                               - 1 diffusion
 *                               - 0 otherwise
 * \param[in]     ndircp        indicator
 *                               - 0 if the diagonal stepped aside
 * \param[in]     thetap        weighting coefficient for the theta-scheme,
 *                               - thetap = 0: explicit scheme
 *                               - thetap = 0.5: time-centered
 *                               scheme (mix between Crank-Nicolson and
 *                               Adams-Bashforth)
 *                               - thetap = 1: implicit scheme
 * \param[in]     coefbu        boundary condition array for the variable
 *                               (implicit part - 3x3 tensor array)
 * \param[in]     cofbfu        boundary condition array for the variable flux
 *                               (implicit part - 3x3 tensor array)
 * \param[in]     fimp
 * \param[in]     i_massflux    mass flux at interior faces
 * \param[in]     b_massflux    mass flux at border faces
 * \param[in]     i_visc        \f$ \mu_\fij \dfrac{S_\fij}{\ipf \jpf} \f$
 *                               at interior faces for the matrix
 * \param[in]     b_visc        \f$ \mu_\fib \dfrac{S_\fib}{\ipf \centf} \f$
 *                               at border faces for the matrix
 * \param[out]    da            diagonal part of the matrix
 * \param[out]    xa            extra interleaved diagonal part of the matrix
 */
/*----------------------------------------------------------------------------*/

void
cs_matrix_anisotropic_diffusion(const cs_mesh_t          *m,
                                int                       iconvp,
                                int                       idiffp,
                                int                       ndircp,
                                double                    thetap,
                                const cs_real_33_t        coefbu[],
                                const cs_real_33_t        cofbfu[],
                                const cs_real_33_t        fimp[],
                                const cs_real_t           i_massflux[],
                                const cs_real_t           b_massflux[],
                                const cs_real_33_t        i_visc[],
                                const cs_real_t           b_visc[],
                                cs_real_33_t    *restrict da,
                                cs_real_332_t   *restrict xa);

/*----------------------------------------------------------------------------*/
/*!
 * \brief Build the diffusion matrix for a vector field with a
 * tensorial diffusivity (symmetric matrix).
 *
 * The diffusion is not reconstructed.
 * The matrix is split into a diagonal block (3x3 times number of cells)
 * and an extra diagonal part (of dimension 3x3 the number of internal
 * faces).
 *
 * \param[in]     idiffp        indicator
 *                               - 1 diffusion
 *                               - 0 otherwise
 * \param[in]     ndircp        indicator
 *                               - 0 if the diagonal stepped aside
 * \param[in]     thetap        weighting coefficient for the theta-scheme,
 *                               - thetap = 0: explicit scheme
 *                               - thetap = 0.5: time-centered
 *                               scheme (mix between Crank-Nicolson and
 *                               Adams-Bashforth)
 *                               - thetap = 1: implicit scheme
 * \param[in]     cofbfu        boundary condition array for the variable flux
 *                               (implicit part - 3x3 tensor array)
 * \param[in]     fimp
 * \param[in]     i_visc        \f$ \mu_\fij \dfrac{S_\fij}{\ipf \jpf} \f$
 *                               at interior faces for the matrix
 * \param[in]     b_visc        \f$ \mu_\fib \dfrac{S_\fib}{\ipf \centf} \f$
 *                               at border faces for the matrix
 * \param[out]    da            diagonal part of the matrix
 * \param[out]    xa            extra interleaved diagonal part of the matrix
 */
/*----------------------------------------------------------------------------*/

void
cs_sym_matrix_anisotropic_diffusion(const cs_mesh_t           *m,
                                    int                       idiffp,
                                    int                       ndircp,
                                    double                    thetap,
                                    const cs_real_33_t        cofbfu[],
                                    const cs_real_33_t        fimp[],
                                    const cs_real_33_t        i_visc[],
                                    const cs_real_t           b_visc[],
                                    cs_real_33_t    *restrict da,
                                    cs_real_33_t    *restrict xa);

/*----------------------------------------------------------------------------*/

END_C_DECLS

#endif /* __CS_MATRIX_BUILDING_H__ */
