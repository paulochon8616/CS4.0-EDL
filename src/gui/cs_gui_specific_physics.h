#ifndef __CS_GUI_SPECIFIC_PHYSICS_H__
#define __CS_GUI_SPECIFIC_PHYSICS_H__

/*============================================================================
 * Management of the GUI parameters file: specific physics
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
 * Local headers
 *----------------------------------------------------------------------------*/

#include "cs_base.h"

/*----------------------------------------------------------------------------*/

BEGIN_C_DECLS

/*============================================================================
 * Type definitions
 *============================================================================*/

/*============================================================================
 * Public Fortran function prototypes
 *============================================================================*/

/*-----------------------------------------------------------------------------
 * Predefined physics indicator.
 *
 * Fortran Interface:
 *
 * SUBROUTINE UIPPMO
 * *****************
 *
 * INTEGER          IPPMOD <--  specific physics indicator array
 * INTEGER          ICOD3P  --> diffusion flame in fast complete chemistry
 * INTEGER          ICODEQ  --> diffusion flame in fast chemistry to equilibrium
 * INTEGER          ICOEBU  --> Eddy Break Up premixing flame
 * INTEGER          ICOBML  --> Bray - Moss - Libby premixing flame
 * INTEGER          ICOLWC  --> Libby Williams premixing flame
 * INTEGER          ICP3PL  --> Coal combustion. Combustible moyen local
 * INTEGER          ICPL3C  --> Coal combustion coupled with lagrangien approach
 * INTEGER          ICFUEL  --> Fuel combustion
 * INTEGER          IELJOU  --> Joule effect
 * INTEGER          IELARC  --> electrical arc
 * INTEGER          IELION  --> ionique mobility
 * INTEGER          ICOMPF  --> compressible without shock
 * INTEGER          IATMOS  --> atmospheric flows
 * INTEGER          IAEROS  --> cooling tower
 * INTEGER          INDJON  --> INDJON=1: a JANAF enthalpy-temperature
 *                              tabulation is used. INDJON=1: users tabulation
 * INTEGER          IEOS    --> compressible
 * INTEGER          IEQCO2  --> CO2 massic fraction transport
 * INTEGER          IDARCY  --> darcy model
 *
 *----------------------------------------------------------------------------*/

void CS_PROCF (uippmo, UIPPMO) (int *const ippmod,
                                int *const icod3p,
                                int *const icodeq,
                                int *const icoebu,
                                int *const icobml,
                                int *const icolwc,
                                int *const iccoal,
                                int *const icpl3c,
                                int *const icfuel,
                                int *const ieljou,
                                int *const ielarc,
                                int *const ielion,
                                int *const icompf,
                                int *const iatmos,
                                int *const iaeros,
                                int *const ieos,
                                int *const ieqco2,
                                int *const idarcy);

/*----------------------------------------------------------------------------
 * Density under relaxation
 *
 * Fortran Interface:
 *
 * SUBROUTINE UICPI1 (SRROM)
 * *****************
 * DOUBLE PRECISION SRROM   <--   density relaxation
 * DOUBLE PRECISION DIFTL0  <--   dynamic diffusion
 *----------------------------------------------------------------------------*/

void CS_PROCF (uicpi1, UICPI1) (double *const srrom,
                                double *const diftl0);

/*----------------------------------------------------------------------------
 * Temperature for D3P Gas Combustion
 *
 * Fortran Interface:
 *
 * SUBROUTINE UICPI2 (SRROM)
 * *****************
 * DOUBLE PRECISION Toxy   <--   Oxydant temperature
 * DOUBLE PRECISION Tfuel  <--   Fuel temperature
 *----------------------------------------------------------------------------*/

void CS_PROCF (uicpi2, UICPI2) (double *const toxy,
                                double *const tfuel);

/*----------------------------------------------------------------------------
 * Electrical model : read parameters
 *
 * Fortran Interface:
 *
 * subroutine uieli1
 * *****************
 * integer         ieljou    -->   joule model
 * integer         ielarc    -->   arc model
 * integer         ielcor    <--   scaling electrical variables
 * double          couimp    <--   imposed current intensity
 * double          puisim    <--   imposed power
 * integer         modrec    <--   scaling type for electric arc
 * integer         idrecal   <--   current density component used to scaling
 *                                 (modrec ==2)
 * char            crit_reca <--   define criteria for plane used to scaling (modrec ==2)
 *----------------------------------------------------------------------------*/

void CS_PROCF (uieli1, UIELI1) (const int    *const ieljou,
                                const int    *const ielarc,
                                      int    *const ielcor,
                                      double *const couimp,
                                      double *const puisim,
                                      int    *const modrec,
                                      int    *const idreca,
                                      double *const crit_reca);

/*----------------------------------------------------------------------------
 * Electrical model : define plane for elreca
 *
 * Fortran Interface:
 *
 * subroutine uielrc
 * *****************
 * integer         izreca    <--   define plane used to scaling (modrec ==2)
 * char            crit_reca <--   define criteria for plane used to scaling (modrec ==2)
 *----------------------------------------------------------------------------*/

void CS_PROCF (uielrc, UIELRC) (int    *const izreca,
                                double *const crit_reca);

/*----------------------------------------------------------------------------
 * Atmospheric flows: read of meteorological file of data
 *
 * Fortran Interface:
 *
 * subroutine uiati1
 * *****************
 * integer         imeteo   <--   on/off index
 * char(*)         fmeteo   <--   meteo file name
 * int             len      <--   meteo file name destination string length
 *----------------------------------------------------------------------------*/

void CS_PROCF (uiati1, UIATI1) (int           *imeteo,
                                char          *fmeteo,
                                int           *len
                                CS_ARGF_SUPP_CHAINE);


/*----------------------------------------------------------------------------
 * Indirection between the solver numbering and the XML one
 * for physical properties of the activated specific physics (pulverized solid fuels)
 *----------------------------------------------------------------------------*/

void CS_PROCF (uisofu, UISOFU) (const int    *const ippmod,
                                const int    *const iccoal,
                                const int    *const icpl3c,
                                const int    *const iirayo,
                                const int    *const iihmpr,
                                const int    *const ncharm,
                                      int    *const ncharb,
                                      int    *const nclpch,
                                      int    *const nclacp,
                                const int    *const ncpcmx,
                                      int    *const ichcor,
                                      double *const diam20,
                                      double *const cch,
                                      double *const hch,
                                      double *const och,
                                      double *const nch,
                                      double *const sch,
                                      double *const ipci,
                                      double *const pcich,
                                      double *const cp2ch,
                                      double *const rho0ch,
                                      double *const thcdch,
                                      double *const cck,
                                      double *const hck,
                                      double *const ock,
                                      double *const nck,
                                      double *const sck,
                                      double *const xashch,
                                      double *const xashsec,
                                      double *const xwatch,
                                      double *const h0ashc,
                                      double *const cpashc,
                                      int    *const iy1ch,
                                      double *const y1ch,
                                      int    *const iy2ch,
                                      double *const y2ch,
                                      double *const a1ch,
                                      double *const a2ch,
                                      double *const e1ch,
                                      double *const e2ch,
                                      double *const crepn1,
                                      double *const crepn2,
                                      double *const ahetch,
                                      double *const ehetch,
                                      int    *const iochet,
                                      double *const ahetc2,
                                      double *const ehetc2,
                                      int    *const ioetc2,
                                      double *const ahetwt,
                                      double *const ehetwt,
                                      int    *const ioetwt,
                                      int    *const ieqnox,
                                      int    *const imdnox,
                                      int    *const irb,
                                      int    *const ihtco2,
                                      int    *const ihth2o,
                                      double *const qpr,
                                      double *const fn,
                                      double *const ckabs1,
                                      int    *const noxyd,
                                      double *const oxyo2,
                                      double *const oxyn2,
                                      double *const oxyh2o,
                                      double *const oxyco2,
                                      double *const repnck,
                                      double *const repnle,
                                      double *const repnlo);

/*----------------------------------------------------------------------------
 * Copy name of thermophysical data file from C to Fortran
 *----------------------------------------------------------------------------*/

void CS_PROCF(cfnmtd, CFNMTD) (char          *fstr,    /* --> Fortran string */
                               int           *len      /* --> String Length  */
                               CS_ARGF_SUPP_CHAINE);


/*----------------------------------------------------------------------------
 * darcy model : read parameters
 *
 * Fortran Interface:
 *
 * subroutine uidai1
 * *****************
 * integer         iricha          -->   richards model
 * integer         permeability    <--   permeability type
 * integer         diffusion       <--   diffusion type
 * integer         unsteady        <--   steady flow
 * integer         convergence     <--   convergence criterion of Newton scheme
 * integer         gravity         <--   check if gravity is taken into account
 * double          gravity_x       <--   x component for gravity vector
 * double          gravity_y       <--   y component for gravity vector
 * double          gravity_z       <--   z component for gravity vector
 *----------------------------------------------------------------------------*/

void CS_PROCF (uidai1, UIDAI1) (const int    *const idarcy,
                                      int    *const permeability,
                                      int    *const diffusion,
                                      int    *const unsteady,
                                      int    *const convergence,
                                      int    *const gravity,
                                      double *gravity_x,
                                      double *gravity_y,
                                      double *gravity_z);


/*=============================================================================
 * Public function prototypes
 *============================================================================*/

/*-----------------------------------------------------------------------------
 * Return the name of a thermophysical model.
 *
 * parameter:
 *   model_thermo          -->  thermophysical model
 *----------------------------------------------------------------------------*/

char *
cs_gui_get_thermophysical_model(const char *const model_thermo);

/*-----------------------------------------------------------------------------
 * Modify double numerical parameters.
 *
 * parameters:
 *   param               -->  label of the numerical parameter
 *   keyword            <-->  value of the numerical parameter
 *----------------------------------------------------------------------------*/

void
cs_gui_numerical_double_parameters(const char   *const param,
                                         double *const keyword);

/*-----------------------------------------------------------------------------
 * Return if a predifined physics model is activated.
 *----------------------------------------------------------------------------*/

int
cs_gui_get_activ_thermophysical_model(void);

/*------------------------------------------------------------------------------
 * Set GUI-defined labels for the atmospheric module
 *----------------------------------------------------------------------------*/

void
cs_gui_labels_atmospheric(void);

/*------------------------------------------------------------------------------
 * Set GUI-defined labels for the coal combustion module
 *
 * parameters:
 *   n_coals   <-- number of coals
 *   n_classes <-- number of coal classes
 *----------------------------------------------------------------------------*/

void
cs_gui_labels_coal_combustion(int  n_coals,
                              int  n_classes);

/*------------------------------------------------------------------------------
 * Set GUI-defined labels for the electric arcs module
 *
 * parameters:
 *   n_gasses <-- number of constituent gasses
 *----------------------------------------------------------------------------*/

void
cs_gui_labels_electric_arcs(int  n_gasses);

/*------------------------------------------------------------------------------
 * Set GUI-defined labels for the gas combustion variables
 *----------------------------------------------------------------------------*/

void
cs_gui_labels_gas_combustion(void);

/*------------------------------------------------------------------------------
 * Set GUI-defined labels for the compressible model variables
 *----------------------------------------------------------------------------*/

void
cs_gui_labels_compressible(void);

/*----------------------------------------------------------------------------*/

END_C_DECLS

#endif /* __CS_GUI_SPECIFIC_PHYSICS_H__ */
