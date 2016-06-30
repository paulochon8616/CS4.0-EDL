#ifndef __CS_TURBULENCE_MODEL_H__
#define __CS_TURBULENCE_MODEL_H__

/*============================================================================
 * Base turbulence model data.
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

#include "cs_defs.h"

/*----------------------------------------------------------------------------*/

BEGIN_C_DECLS

/*=============================================================================
 * Macro definitions
 *============================================================================*/

/*============================================================================
 * Type definitions
 *============================================================================*/

/* turbulence model general options descriptor */
/*---------------------------------------------*/

typedef struct {

  int           iturb;        /* turbulence model
                                 - 0: no turbulence model (laminar flow)
                                 - 10: mixing length model
                                 - 20: standard k-epsilon model
                                 - 21: k-epsilon model with Linear
                                       Production (LP) correction
                                 - 30: Rij-epsilon (LRR)
                                 - 31: Rij-epsilon (SSG)
                                 - 32: Rij-epsilon (EBRSM)
                                 - 40: LES (constant Smagorinsky model)
                                 - 41: LES ("classical" dynamic Smagorisky
                                       model)
                                 - 42: LES (WALE)
                                 - 50: v2f phi-model
                                 - 51: v2f BL-v2-k
                                 - 60: k-omega SST
                                 - 70: Spalart-Allmaras model */
  int           itytur;       /* class of turbulence model (integer value
                                 iturb/10) */
  int           nvarcl;       /* number of variable plus number of turbulent
                                 fluxes (used by the boundary conditions) */

} cs_turb_model_t;

/* rans turbulence model descriptor */
/*----------------------------------*/

typedef struct {

  int           irccor;       /* activation of rotation/curvature correction for
                                 an eddy viscosity turbulence models
                                 - 0: false
                                 - 1: true */
  int           itycor;       /* type of rotation/curvature correction for an
                                 eddy viscosity turbulence models
                                 - 1: Cazalbou correction (default when irccor=1
                                      and itytur=2 or 5)
                                 - 2: Spalart-Shur correction (default when
                                      irccor=1 and iturb=60 or 70) */
  int           idirsm;       /* turbulent diffusion model for second moment
                                 closure
                                 - 0: scalar diffusivity (Shir model)
                                 - 1: tensorial diffusivity (Daly and Harlow
                                      model, default model) */
  int           iclkep;       /* clipping of k and epsilon
                                 - 0: absolute value clipping
                                 - 1: coupled clipping based on physical
                                      relationships */
  int           igrhok;       /* take (2/3 rho grad k) in the momentum
                                 equation
                                 - 1: true
                                 - 0: false (default) */
  int           igrake;       /* buoyant term in k-epsilon
                                 - 1: true (default if rho is variable)
                                 - 0: false */
  int           igrari;       /* buoyant term in Rij-epsilon
                                 - 1: true (default if rho is variable)
                                 - 0: false */
  int           ikecou;       /* partially coupled version of
                                 k-epsilon (only for iturb=20)
                                 - 1: true (default)
                                 - 0: false */
  int           irijnu;       /* pseudo eddy viscosity in the matrix of momentum
                                 equation to partially implicit div( rho R )
                                 - 1: true
                                 - 0: false (default) */
  int           irijrb;       /* accurate treatment of R at the boundary (see
                                 \ref condli)
                                 - 1: true
                                 - 0: false (default) */
  int           irijec;       /* wall echo term of R
                                 - 1: true
                                 - 0: false (default) */
  int           idifre;       /* whole treatment of the diagonal part of the
                                 diffusion tensor of R and epsilon
                                 - 1: true (default)
                                 - 0: simplified treatment */
  int           iclsyr;       /* partial implicitation of symmetry BCs of R
                                 - 1: true (default)
                                 - 0: false */
  int           iclptr;       /* partial implicitation of wall BCs of R
                                 - 1: true
                                 - 0: false (default) */
  double        almax;        /* characteristic macroscopic length of the
                                 domain */
  double        uref;         /* characteristic flow velocity */
  double        xlomlg;       /* mixing length */

} cs_turb_rans_model_t;

/* les turbulence model descriptor */
/*---------------------------------*/

typedef struct {

  int           idries;       /* Van Driest smoothing at the wall (only for
                                 itytur=4)
                                 - 1: true
                                 - 0: false */
  int           ivrtex;       /* vortex method (in LES)
                                 - 1: true
                                 - 0: false (default) */

} cs_turb_les_model_t;

/*============================================================================
 * Static global variables
 *============================================================================*/

/* Pointer to main turbulence model descriptor structure */

extern const cs_turb_model_t         *cs_glob_turb_model;

/* Pointer to RANS turbulence model descriptor structure */

extern const cs_turb_rans_model_t    *cs_glob_turb_rans_model;

/* Pointer to LES turbulence model descriptor structure */

extern const cs_turb_les_model_t     *cs_glob_turb_les_model;

/* Constant for turbulence models */

extern const double cs_turb_xkappa;
extern const double cs_turb_cstlog;
extern const double cs_turb_apow;
extern const double cs_turb_bpow;
extern double cs_turb_dpow;
extern const double cs_turb_cmu;
extern double cs_turb_cmu025;
extern const double cs_turb_ce1;
extern const double cs_turb_ce2;
extern const double cs_turb_ce4;
extern const double cs_turb_sigmak;
extern double cs_turb_sigmae;
extern const double cs_turb_crij1;
extern const double cs_turb_crij2;
extern const double cs_turb_crij3;
extern const double cs_turb_crijp1;
extern const double cs_turb_crijp2;
extern const double cs_turb_cssge2;
extern const double cs_turb_cssgs1;
extern const double cs_turb_cssgs2;
extern const double cs_turb_cssgr1;
extern const double cs_turb_cssgr2;
extern const double cs_turb_cssgr3;
extern const double cs_turb_cssgr4;
extern const double cs_turb_cssgr5;
extern const double cs_turb_cebms1;
extern const double cs_turb_cebms2;
extern const double cs_turb_cebmr1, cebmr2, cebmr3, cebmr4, cebmr5, cebmr6;
extern double cs_turb_csrij;
extern const double cs_turb_cebme2;
extern const double cs_turb_cebmmu;
extern const double cs_turb_xcl;
extern const double cs_turb_xa1;
extern const double cs_turb_xct;
extern const double cs_turb_xceta;
extern const double cs_turb_cpale1;
extern const double cs_turb_cpale2;
extern const double cs_turb_cpale3;
extern const double cs_turb_cpale4;
extern const double cs_turb_cpalse;
extern const double cs_turb_cpalmu;
extern const double cs_turb_cpalc1;
extern const double cs_turb_cpalc2;
extern const double cs_turb_cpalct;
extern const double cs_turb_cpalcl;
extern const double cs_turb_cpalet;
extern const double cs_turb_ckwsk1;
extern const double cs_turb_ckwsk2;
extern const double cs_turb_ckwsw1;
extern const double cs_turb_ckwsw2;
extern const double cs_turb_ckwbt1;
extern const double cs_turb_ckwbt2;
extern double cs_turb_ckwgm1;
extern double cs_turb_ckwgm2;
extern const double cs_turb_ckwa1;
extern const double cs_turb_ckwc1;
extern const double cs_turb_csab1;
extern const double cs_turb_csab2;
extern const double cs_turb_csasig;
extern const double cs_turb_csav1;
extern double cs_turb_csaw1;
extern const double cs_turb_csaw2;
extern const double cs_turb_csaw3;
extern const double cs_turb_cssr1;
extern const double cs_turb_cssr2;
extern const double cs_turb_cssr3;
extern const double cs_turb_ccaze2;
extern const double cs_turb_ccazsc;
extern const double cs_turb_ccaza;
extern const double cs_turb_ccazb;
extern const double cs_turb_ccazc;
extern const double cs_turb_ccazd;
extern const double cs_turb_xlesfl;
extern const double cs_turb_ales;
extern const double cs_turb_bles;
extern const double cs_turb_csmago;
extern const double cs_turb_xlesfd;
extern double cs_turb_smagmx;
extern const double cs_turb_cdries;
extern const double cs_turb_cv2fa1;
extern const double cs_turb_cv2fe2;
extern const double cs_turb_cv2fmu;
extern const double cs_turb_cv2fc1;
extern const double cs_turb_cv2fc2;
extern const double cs_turb_cv2fct;
extern const double cs_turb_cv2fcl;
extern const double cs_turb_cv2fet;
extern const double cs_turb_cwale;
extern const double cs_turb_xiafm;
extern const double cs_turb_etaafm;
extern const double cs_turb_c1trit;
extern const double cs_turb_c2trit;
extern const double cs_turb_c3trit;
extern const double cs_turb_c4trit;
extern const double cs_turb_cthafm;
extern const double cs_turb_cthdfm;

/*=============================================================================
 * Public function prototypes
 *============================================================================*/

/*----------------------------------------------------------------------------*/

END_C_DECLS

#endif /* __CS_TURBULENCE_MODEL_H__ */
