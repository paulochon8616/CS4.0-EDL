#ifndef __CS_GRADIENT_H__
#define __CS_GRADIENT_H__

/*============================================================================
 * Gradient reconstruction.
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

/*----------------------------------------------------------------------------
 * Gradient reconstruction method
 *----------------------------------------------------------------------------*/

typedef enum {

  CS_GRADIENT_ITER,              /* Iterative */
  CS_GRADIENT_LSQ,               /* Least-squares */
  CS_GRADIENT_LSQ_ITER_OLD,      /* LSQ followed by iterative (old) */
  CS_GRADIENT_ITER_OLD           /* Iterative (old) */

} cs_gradient_type_t;

/*============================================================================
 *  Global variables
 *============================================================================*/

/* Short names for gradient types */

extern const char *cs_gradient_type_name[];

/*============================================================================
 * Public function prototypes for Fortran API
 *============================================================================*/

/*----------------------------------------------------------------------------
 * Compute cell gradient of scalar field or component of vector or
 * tensor field.
 *----------------------------------------------------------------------------*/

void CS_PROCF (cgdcel, CGDCEL)
(
 const cs_int_t   *const ivar,        /* <-- variable number                  */
 const cs_int_t   *const imrgra,      /* <-- gradient computation mode        */
 const cs_int_t   *const ilved,       /* <-- 1: interleaved; 0: non-interl.   */
 const cs_int_t   *const inc,         /* <-- 0 or 1: increment or not         */
 const cs_int_t   *const iccocg,      /* <-- 1 or 0: recompute COCG or not    */
 const cs_int_t   *const n_r_sweeps,  /* <-- >1: with reconstruction          */
 const cs_int_t   *const idimtr,      /* <-- 0, 1, 2: scalar, vector, tensor
                                             in case of rotation              */
 const cs_int_t   *const iphydp,      /* <-- use hydrosatatic pressure        */
 const cs_int_t   *const ipond,       /* <-- >0: weighted gradient computation*/
 const cs_int_t   *const iwarnp,      /* <-- verbosity level                  */
 const cs_int_t   *const imligp,      /* <-- type of clipping                 */
 const cs_real_t  *const epsrgp,      /* <-- precision for iterative gradient
                                             calculation                      */
 const cs_real_t  *const extrap,      /* <-- extrapolate gradient at boundary */
 const cs_real_t  *const climgp,      /* <-- clipping coefficient             */
       cs_real_3_t       f_ext[],      /* <-- exterior force generating the
                                             hydrostatic pressure             */
 const cs_real_t         coefap[],    /* <-- boundary condition term          */
 const cs_real_t         coefbp[],    /* <-- boundary condition term          */
       cs_real_t         pvar[],      /* <-- gradient's base variable         */
       cs_real_t         ktvar[],     /* <-- gradient coefficient variable    */
       cs_real_t         grdini[]     /* <-> gradient (interleaved or not)    */
);

/*----------------------------------------------------------------------------
 * Compute cell gradient of vector field.
 *----------------------------------------------------------------------------*/

void CS_PROCF (cgdvec, CGDVEC)
(
 const cs_int_t         *const ivar,
 const cs_int_t         *const imrgra,    /* <-- gradient computation mode    */
 const cs_int_t         *const inc,       /* <-- 0 or 1: increment or not     */
 const cs_int_t         *const n_r_sweeps,/* <-- >1: with reconstruction      */
 const cs_int_t         *const iwarnp,    /* <-- verbosity level              */
 const cs_int_t         *const imligp,    /* <-- type of clipping             */
 const cs_real_t        *const epsrgp,    /* <-- precision for iterative
                                                 gradient calculation         */
 const cs_real_t        *const climgp,    /* <-- clipping coefficient         */
 const cs_real_3_t             coefav[],  /* <-- boundary condition term      */
 const cs_real_33_t            coefbv[],  /* <-- boundary condition term      */
       cs_real_3_t             pvar[],    /* <-- gradient's base variable     */
       cs_real_33_t            gradv[]    /* <-> gradient of the variable
                                                 (du_i/dx_j : gradv[][i][j])  */
);

/*=============================================================================
 * Public function prototypes
 *============================================================================*/

/*----------------------------------------------------------------------------
 * Initialize gradient computation API.
 *----------------------------------------------------------------------------*/

void
cs_gradient_initialize(void);

/*----------------------------------------------------------------------------
 * Finalize gradient computation API.
 *----------------------------------------------------------------------------*/

void
cs_gradient_finalize(void);

/*----------------------------------------------------------------------------
 * Compute cell gradient of scalar field or component of vector or
 * tensor field.
 *
 * parameters:
 *   var_name       <-- variable name
 *   gradient_type  <-- gradient type
 *   halo_type      <-- halo type
 *   inc            <-- if 0, solve on increment; 1 otherwise
 *   recompute_cocg <-- should COCG FV quantities be recomputed ?
 *   n_r_sweeps     <-- if > 1, number of reconstruction sweeps
 *   tr_dim         <-- 2 for tensor with periodicity of rotation,
 *                      0 otherwise
 *   hyd_p_flag     <-- flag for hydrostatic pressure
 *   verbosity      <-- verbosity level
 *   clip_mode      <-- clipping mode
 *   epsilon        <-- precision for iterative gradient calculation
 *   extrap         <-- boundary gradient extrapolation coefficient
 *   clip_coeff     <-- clipping coefficient
 *   f_ext          <-- exterior force generating the hydrostatic pressure
 *   bc_coeff_a     <-- boundary condition term a
 *   bc_coeff_b     <-- boundary condition term b
 *   var            <-> gradient's base variable
 *   c_weight       <-- weighted gradient coefficient variable,
 *                      or NULL
 *   grad           --> gradient
 *----------------------------------------------------------------------------*/

void
cs_gradient_scalar(const char                *var_name,
                   cs_gradient_type_t         gradient_type,
                   cs_halo_type_t             halo_type,
                   int                        inc,
                   bool                       recompute_cocg,
                   int                        n_r_sweeps,
                   int                        tr_dim,
                   int                        hyd_p_flag,
                   int                        verbosity,
                   int                        clip_mode,
                   double                     epsilon,
                   double                     extrap,
                   double                     clip_coeff,
                   cs_real_3_t                f_ext[],
                   const cs_real_t            bc_coeff_a[],
                   const cs_real_t            bc_coeff_b[],
                   cs_real_t        *restrict var,
                   cs_real_t        *restrict c_weight,
                   cs_real_3_t      *restrict grad);

/*----------------------------------------------------------------------------
 * Compute cell gradient of a vector field.
 *
 * parameters:
 *   var_name       <-- variable name
 *   gradient_type  <-- gradient type
 *   halo_type      <-- halo type
 *   inc            <-- if 0, solve on increment; 1 otherwise
 *   n_r_sweeps     <-- if > 1, number of reconstruction sweeps
 *   verbosity      <-- verbosity level
 *   clip_mode      <-- clipping mode
 *   epsilon        <-- precision for iterative gradient calculation
 *   clip_coeff     <-- clipping coefficient
 *   bc_coeff_a     <-- boundary condition term a
 *   bc_coeff_b     <-- boundary condition term b
 *   var            <-> gradient's base variable
 *   gradv          --> gradient (du_i/dx_j : gradv[][i][j])
 *----------------------------------------------------------------------------*/

void
cs_gradient_vector(const char                *var_name,
                   cs_gradient_type_t         gradient_type,
                   cs_halo_type_t             halo_type,
                   int                        inc,
                   int                        n_r_sweeps,
                   int                        verbosity,
                   int                        clip_mode,
                   double                     epsilon,
                   double                     clip_coeff,
                   const cs_real_3_t          bc_coeff_a[],
                   const cs_real_33_t         bc_coeff_b[],
                   cs_real_3_t      *restrict var,
                   cs_real_33_t     *restrict gradv);

/*----------------------------------------------------------------------------
 * Determine gradient type by Fortran "imrgra" value
 *
 * parameters:
 *   imrgra         <-- Fortran gradient option
 *   gradient_type  --> gradient type
 *   halo_type      --> halo type
 *----------------------------------------------------------------------------*/

void
cs_gradient_type_by_imrgra(int                  imrgra,
                           cs_gradient_type_t  *gradient_type,
                           cs_halo_type_t      *halo_type);

/*----------------------------------------------------------------------------*/

END_C_DECLS

#endif /* __CS_GRADIENT__ */
