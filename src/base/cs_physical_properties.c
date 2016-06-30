/*============================================================================
 * Compute properties for water with Freesteam
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

#include <assert.h>
#include <math.h>
#include <stdarg.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#if defined(HAVE_DLOPEN)
#include <dlfcn.h>
#endif

/*----------------------------------------------------------------------------
 *  Local headers
 *----------------------------------------------------------------------------*/

#include "bft_error.h"
#include "bft_mem.h"
#include "bft_printf.h"

/*----------------------------------------------------------------------------
 *  Header for the current file
 *----------------------------------------------------------------------------*/

#include "cs_physical_properties.h"
#if defined(HAVE_EOS)
#include "cs_eos.hxx"
#endif

#if defined(HAVE_FREESTEAM)
#include <freesteam/steam_ph.h>
#include <freesteam/steam_pT.h>
#include <freesteam/steam_ps.h>
#include <freesteam/steam_pu.h>
#include <freesteam/steam_pv.h>
#include <freesteam/steam_Ts.h>
#include <freesteam/steam_Tx.h>

#include <freesteam/region1.h>
#include <freesteam/region2.h>
#include <freesteam/region3.h>
#include <freesteam/region4.h>
#endif

/*----------------------------------------------------------------------------*/

BEGIN_C_DECLS

/*! \cond DOXYGEN_SHOULD_SKIP_THIS */

/*============================================================================
 * Local macro definitions
 *============================================================================*/

/* Directory name separator
   (historically, '/' for Unix/Linux, '\' for Windows, ':' for Mac
   but '/' should work for all on modern systems) */

#define DIR_SEPARATOR '/'

/*============================================================================
 * Type definitions
 *============================================================================*/

/* Thermal table structure */

typedef struct {

  char        *material;                              /* material choice (water, ...) */
  char        *method;                                /* method choice (cathare, thetis, freesteam, ...) */
  char        *reference;                             /* reference (automatic) */
  char        *phas;                                  /* phas choice (liquid/gas) */
  int          type;                                  /* 0 for user
                                                       * 1 for freesteam
                                                       * 2 (other) */
  cs_phys_prop_thermo_plane_type_t   thermo_plane;
  int          temp_scale;                            /* temperature scale if needed
                                                       *     1 for kelvin
                                                       *     2 for Celsius */

} cs_thermal_table_t;

/*----------------------------------------------------------------------------
 * Function pointer types
 *----------------------------------------------------------------------------*/

typedef void
(cs_eos_create_t)(char *EOSMethod,
                  char *EOSRef);

typedef void
(cs_eos_destroy_t)(void);

typedef void
(cs_phys_prop_eos_t)(cs_phys_prop_thermo_plane_type_t   thermo_plane,
                     cs_phys_prop_type_t                property,
                     const cs_lnum_t                    n_vals,
                     double                             var1[],
                     double                             var2[],
                     cs_real_t                          val[]);

/*============================================================================
 * Static global variables
 *============================================================================*/

cs_thermal_table_t *cs_glob_thermal_table = NULL;

static void                *_cs_eos_dl_lib = NULL;
static cs_eos_create_t     *_cs_eos_create = NULL;
static cs_eos_destroy_t    *_cs_eos_destroy = NULL;
static cs_phys_prop_eos_t  *_cs_phys_prop_eos = NULL;

/*----------------------------------------------------------------------------
 * Create an empty thermal_table structure
 *----------------------------------------------------------------------------*/

static cs_thermal_table_t *
_thermal_table_create(void)
{
  cs_thermal_table_t  *tt = NULL;

  BFT_MALLOC(tt, 1, cs_thermal_table_t);

  tt->material     = NULL;
  tt->method       = NULL;
  tt->reference    = NULL;
  tt->phas         = NULL;
  tt->type         = 0;
  tt->temp_scale   = 0;
  tt->thermo_plane = CS_PHYS_PROP_PLANE_PH;

  return tt;
}

#if defined(HAVE_DLOPEN) && defined(HAVE_EOS)

/*----------------------------------------------------------------------------
 * Get a shared library function pointer for a writer plugin
 *
 * parameters:
 *   name             <-- name of function symbol in library
 *
 * returns:
 *   pointer to function in shared library
 *----------------------------------------------------------------------------*/

static void *
_get_eos_dl_function_pointer(const char  *name)
{
  void  *retval = NULL;
  char  *error = NULL;

  assert(_cs_eos_dl_lib != NULL);

  dlerror();    /* Clear any existing error */

  retval = dlsym(_cs_eos_dl_lib, name);
  error = dlerror();

  if (error != NULL)
    bft_error(__FILE__, __LINE__, 0,
              _("Error calling dlsym: %s\n"), error);

  return retval;
}

#endif

/*! (DOXYGEN_SHOULD_SKIP_THIS) \endcond */

/*=============================================================================
 * Public function definitions
 *============================================================================*/

/*----------------------------------------------------------------------------*/
/*!
 * \brief Define thermal table.
 */
/*----------------------------------------------------------------------------*/

void
cs_thermal_table_set(const char *material,
                     const char *method,
                     const char *phas,
                     const char *reference,
                     cs_phys_prop_thermo_plane_type_t thermo_plane,
                     const int   temp_scale)
{
  if (cs_glob_thermal_table == NULL)
    cs_glob_thermal_table = _thermal_table_create();

  BFT_MALLOC(cs_glob_thermal_table->material,  strlen(material) +1,  char);
  BFT_MALLOC(cs_glob_thermal_table->reference, strlen(reference) +1, char);
  BFT_MALLOC(cs_glob_thermal_table->phas,      strlen(phas) +1,      char);
  strcpy(cs_glob_thermal_table->material,  material);
  strcpy(cs_glob_thermal_table->reference, reference);
  strcpy(cs_glob_thermal_table->phas,      phas);

  if (strcmp(method, "freesteam") == 0 ||
      strcmp(material, "user_material") == 0) {
    BFT_MALLOC(cs_glob_thermal_table->method,    strlen(method) +1,    char);
    strcpy(cs_glob_thermal_table->reference, reference);
    if (strcmp(method, "freesteam") == 0)
      cs_glob_thermal_table->type = 1;
    else
      cs_glob_thermal_table->type = 0;
  }
  else {
    BFT_MALLOC(cs_glob_thermal_table->method,    strlen(method) +5,    char);
    strcpy(cs_glob_thermal_table->method, "EOS_");
    strcat(cs_glob_thermal_table->method, method);
    cs_glob_thermal_table->type = 2;
#if defined(HAVE_EOS)
    {
      char  *lib_path = NULL;
      const char *pkglibdir = cs_base_get_pkglibdir();

      /* Open from shared library */
      BFT_MALLOC(lib_path,
                 strlen(pkglibdir) + 1 + 3 + strlen("cs_eos") + 3 + 1,
                 char);
      sprintf(lib_path, "%s%c%s.so", pkglibdir, DIR_SEPARATOR, "cs_eos");
      _cs_eos_dl_lib = dlopen(lib_path, RTLD_LAZY);
      BFT_FREE(lib_path);

      /* Load symbols from shared library */

      if (_cs_eos_dl_lib == NULL)
        bft_error(__FILE__, __LINE__, 0,
                  _("Error loading %s: %s."), lib_path, dlerror());

      /* Function pointers need to be double-casted so as to first convert
         a (void *) type to a memory address and then convert it back to the
         original type. Otherwise, the compiler may issue a warning.
         This is a valid ISO C construction. */

      _cs_eos_create = (cs_eos_create_t *)  (intptr_t)
        _get_eos_dl_function_pointer("cs_eos_create");
      _cs_eos_destroy = (cs_eos_destroy_t *)  (intptr_t)
        _get_eos_dl_function_pointer("cs_eos_destroy");
      _cs_phys_prop_eos = (cs_phys_prop_eos_t *)  (intptr_t)
        _get_eos_dl_function_pointer("cs_phys_prop_eos");

      _cs_eos_create(cs_glob_thermal_table->method, cs_glob_thermal_table->reference);
    }
#endif
  }
  cs_glob_thermal_table->thermo_plane = thermo_plane;
  cs_glob_thermal_table->temp_scale = temp_scale;
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief finalize thermal table.
 */
/*----------------------------------------------------------------------------*/

void
cs_thermal_table_finalize(void)
{
  if (cs_glob_thermal_table != NULL) {
#if defined(HAVE_EOS)
    if (cs_glob_thermal_table->type == 2) {
      _cs_eos_destroy();
      if (dlclose(_cs_eos_dl_lib) != 0)
        bft_error(__FILE__, __LINE__, 0,
                  _("Error unloading library: %s."), dlerror());
      _cs_eos_create = NULL;
      _cs_eos_destroy = NULL;
      _cs_phys_prop_eos = NULL;
    }
#endif
    BFT_FREE(cs_glob_thermal_table->material);
    BFT_FREE(cs_glob_thermal_table->method);
    BFT_FREE(cs_glob_thermal_table->phas);
    BFT_FREE(cs_glob_thermal_table->reference);
    BFT_FREE(cs_glob_thermal_table);
  }
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Compute a property.
 *
 * \param[in]   property      property queried
 * \param[in]   n_vals        number of values
 * \param[in]   var1          values on first plane axis
 * \param[in]   var2          values on second plane axis
 * \param[out]  val           resulting property values
 */
/*----------------------------------------------------------------------------*/

void
cs_phys_prop_compute(cs_phys_prop_type_t                property,
                     const cs_lnum_t                    n_vals,
                     const cs_real_t                    var1[],
                     const cs_real_t                    var2[],
                     cs_real_t                          val[])
{
  double *val_compute;
  BFT_MALLOC(val_compute, n_vals, double);
  for (int ii = 0; ii < n_vals; ii++) {
    if (cs_glob_thermal_table->temp_scale == 2)
      val_compute[ii] = var2[ii] + 273.15;
    else
      val_compute[ii] = var2[ii];
  }
  if (cs_glob_thermal_table->type == 1) {
    cs_phys_prop_freesteam(cs_glob_thermal_table->thermo_plane,
                           property,
                           n_vals,
                           var1,
                           val_compute,
                           val);
  }
#if defined(HAVE_EOS)
  else if (cs_glob_thermal_table->type == 2) {
    _cs_phys_prop_eos(cs_glob_thermal_table->thermo_plane,
                      property,
                      n_vals,
                      var1,
                      val_compute,
                      val);
  }
#endif
  BFT_FREE(val_compute);
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Compute properties with Freesteam in a defined thermal plane.
 *
 * \param[in]   thermo_plane  thermodynamic plane
 * \param[in]   property      property queried
 * \param[in]   n_vals        number of values
 * \param[in]   var1          values on first plane axis
 * \param[in]   var2          values on second plane axis
 * \param[out]  val           resulting property values
 */
/*----------------------------------------------------------------------------*/

void
cs_phys_prop_freesteam(cs_phys_prop_thermo_plane_type_t   thermo_plane,
                       cs_phys_prop_type_t                property,
                       const cs_lnum_t                    n_vals,
                       const cs_real_t                    var1[],
                       const cs_real_t                    var2[],
                       cs_real_t                          val[])
{
#if defined(HAVE_FREESTEAM)
  if (thermo_plane == CS_PHYS_PROP_PLANE_PH) {
    for (cs_lnum_t i = 0; i < n_vals; i++) {
      SteamState S0 = freesteam_set_ph(var1[i], var2[i]);
      switch (property) {
      case CS_PHYS_PROP_PRESSURE:
        bft_error(__FILE__, __LINE__, 0,
                  _("bad choice: you choose to work in the %s plane."), "ph");
        break;
      case CS_PHYS_PROP_TEMPERATURE:
        val[i] = freesteam_T(S0);
        break;
      case CS_PHYS_PROP_ENTHALPY:
        bft_error(__FILE__, __LINE__, 0,
                  _("bad choice: you choose to work in the %s plane."), "ph");
        break;
      case CS_PHYS_PROP_ENTROPY:
        val[i] = freesteam_s(S0);
        break;
      case CS_PHYS_PROP_ISOBARIC_HEAT_CAPACITY:
        val[i] = freesteam_cp(S0);
        break;
      case CS_PHYS_PROP_ISOCHORIC_HEAT_CAPACITY:
        val[i] = freesteam_cv(S0);
        break;
      case CS_PHYS_PROP_SPECIFIC_VOLUME:
        val[i] = freesteam_v(S0);
        break;
      case CS_PHYS_PROP_DENSITY:
        val[i] = freesteam_rho(S0);
        break;
      case CS_PHYS_PROP_INTERNAL_ENERGY:
        val[i] = freesteam_u(S0);
        break;
      case CS_PHYS_PROP_QUALITY:
        val[i] = freesteam_x(S0);
        break;
      case CS_PHYS_PROP_THERMAL_CONDUCTIVITY:
        val[i] = freesteam_k(S0);
        break;
      case CS_PHYS_PROP_DYNAMIC_VISCOSITY:
        val[i] = freesteam_mu(S0);
        break;
      case CS_PHYS_PROP_SPEED_OF_SOUND:
        val[i] = freesteam_w(S0);
        break;
      }
    }
  }
  else if (thermo_plane == CS_PHYS_PROP_PLANE_PT) {
    for (cs_lnum_t i = 0; i < n_vals; i++) {
      SteamState S0 = freesteam_set_pT(var1[i], var2[i]);
      switch (property) {
      case CS_PHYS_PROP_PRESSURE:
        bft_error(__FILE__, __LINE__, 0,
                  _("bad choice: you choose to work in the %s plane."), "pT");
        break;
      case CS_PHYS_PROP_TEMPERATURE:
        bft_error(__FILE__, __LINE__, 0,
                  _("bad choice: you choose to work in the %s plane."), "pT");
        break;
      case CS_PHYS_PROP_ENTHALPY:
        val[i] = freesteam_h(S0);
        break;
      case CS_PHYS_PROP_ENTROPY:
        val[i] = freesteam_s(S0);
        break;
      case CS_PHYS_PROP_ISOBARIC_HEAT_CAPACITY:
        val[i] = freesteam_cp(S0);
        break;
      case CS_PHYS_PROP_ISOCHORIC_HEAT_CAPACITY:
        val[i] = freesteam_cv(S0);
        break;
      case CS_PHYS_PROP_SPECIFIC_VOLUME:
        val[i] = freesteam_v(S0);
        break;
      case CS_PHYS_PROP_DENSITY:
        val[i] = freesteam_rho(S0);
        break;
      case CS_PHYS_PROP_INTERNAL_ENERGY:
        val[i] = freesteam_u(S0);
        break;
      case CS_PHYS_PROP_QUALITY:
        val[i] = freesteam_x(S0);
        break;
      case CS_PHYS_PROP_THERMAL_CONDUCTIVITY:
        val[i] = freesteam_k(S0);
        break;
      case CS_PHYS_PROP_DYNAMIC_VISCOSITY:
        val[i] = freesteam_mu(S0);
        break;
      case CS_PHYS_PROP_SPEED_OF_SOUND:
        val[i] = freesteam_w(S0);
        break;
      }
    }
  }
  else if (thermo_plane == CS_PHYS_PROP_PLANE_PS) {
    for (cs_lnum_t i = 0; i < n_vals; i++) {
      SteamState S0 = freesteam_set_ps(var1[i], var2[i]);
      switch (property) {
      case CS_PHYS_PROP_PRESSURE:
        bft_error(__FILE__, __LINE__, 0,
                  _("bad choice: you choose to work in the %s plane."), "ps");
        break;
      case CS_PHYS_PROP_TEMPERATURE:
        val[i] = freesteam_T(S0);
        break;
      case CS_PHYS_PROP_ENTHALPY:
        val[i] = freesteam_h(S0);
        break;
      case CS_PHYS_PROP_ENTROPY:
        bft_error(__FILE__, __LINE__, 0,
                  _("bad choice: you choose to work in the %s plane."), "ps");
        break;
      case CS_PHYS_PROP_ISOBARIC_HEAT_CAPACITY:
        val[i] = freesteam_cp(S0);
        break;
      case CS_PHYS_PROP_ISOCHORIC_HEAT_CAPACITY:
        val[i] = freesteam_cv(S0);
        break;
      case CS_PHYS_PROP_SPECIFIC_VOLUME:
        val[i] = freesteam_v(S0);
        break;
      case CS_PHYS_PROP_DENSITY:
        val[i] = freesteam_rho(S0);
        break;
      case CS_PHYS_PROP_INTERNAL_ENERGY:
        val[i] = freesteam_u(S0);
        break;
      case CS_PHYS_PROP_QUALITY:
        val[i] = freesteam_x(S0);
        break;
      case CS_PHYS_PROP_THERMAL_CONDUCTIVITY:
        val[i] = freesteam_k(S0);
        break;
      case CS_PHYS_PROP_DYNAMIC_VISCOSITY:
        val[i] = freesteam_mu(S0);
        break;
      case CS_PHYS_PROP_SPEED_OF_SOUND:
        val[i] = freesteam_w(S0);
        break;
      }
    }
  }
  else if (thermo_plane == CS_PHYS_PROP_PLANE_PU) {
    for (cs_lnum_t i = 0; i < n_vals; i++) {
      SteamState S0 = freesteam_set_pu(var1[i], var2[i]);
      switch (property) {
      case CS_PHYS_PROP_PRESSURE:
        bft_error(__FILE__, __LINE__, 0,
                  _("bad choice: you choose to work in the %s plane."), "pu");
        break;
      case CS_PHYS_PROP_TEMPERATURE:
        val[i] = freesteam_T(S0);
        break;
      case CS_PHYS_PROP_ENTHALPY:
        val[i] = freesteam_h(S0);
        break;
      case CS_PHYS_PROP_ENTROPY:
        val[i] = freesteam_s(S0);
        break;
      case CS_PHYS_PROP_ISOBARIC_HEAT_CAPACITY:
        val[i] = freesteam_cp(S0);
        break;
      case CS_PHYS_PROP_ISOCHORIC_HEAT_CAPACITY:
        val[i] = freesteam_cv(S0);
        break;
      case CS_PHYS_PROP_SPECIFIC_VOLUME:
        val[i] = freesteam_v(S0);
        break;
      case CS_PHYS_PROP_DENSITY:
        val[i] = freesteam_rho(S0);
        break;
      case CS_PHYS_PROP_INTERNAL_ENERGY:
        bft_error(__FILE__, __LINE__, 0,
                  _("bad choice: you choose to work in the %s plane."), "pu");
        break;
      case CS_PHYS_PROP_QUALITY:
        val[i] = freesteam_x(S0);
        break;
      case CS_PHYS_PROP_THERMAL_CONDUCTIVITY:
        val[i] = freesteam_k(S0);
        break;
      case CS_PHYS_PROP_DYNAMIC_VISCOSITY:
        val[i] = freesteam_mu(S0);
        break;
      case CS_PHYS_PROP_SPEED_OF_SOUND:
        val[i] = freesteam_w(S0);
        break;
      }
    }
  }
  else if (thermo_plane == CS_PHYS_PROP_PLANE_PV) {
    for (cs_lnum_t i = 0; i < n_vals; i++) {
      SteamState S0 = freesteam_set_pv(var1[i], var2[i]);
      switch (property) {
      case CS_PHYS_PROP_PRESSURE:
        bft_error(__FILE__, __LINE__, 0,
                  _("bad choice: you choose to work in the %s plane."), "pv");
        break;
      case CS_PHYS_PROP_TEMPERATURE:
        val[i] = freesteam_T(S0);
        break;
      case CS_PHYS_PROP_ENTHALPY:
        val[i] = freesteam_h(S0);
        break;
      case CS_PHYS_PROP_ENTROPY:
        val[i] = freesteam_s(S0);
        break;
      case CS_PHYS_PROP_ISOBARIC_HEAT_CAPACITY:
        val[i] = freesteam_cp(S0);
        break;
      case CS_PHYS_PROP_ISOCHORIC_HEAT_CAPACITY:
        val[i] = freesteam_cv(S0);
        break;
      case CS_PHYS_PROP_SPECIFIC_VOLUME:
        bft_error(__FILE__, __LINE__, 0,
                  _("bad choice: you choose to work in the %s plane."), "pv");
        break;
      case CS_PHYS_PROP_DENSITY:
        val[i] = freesteam_rho(S0);
        break;
      case CS_PHYS_PROP_INTERNAL_ENERGY:
        val[i] = freesteam_u(S0);
        break;
      case CS_PHYS_PROP_QUALITY:
        val[i] = freesteam_x(S0);
        break;
      case CS_PHYS_PROP_THERMAL_CONDUCTIVITY:
        val[i] = freesteam_k(S0);
        break;
      case CS_PHYS_PROP_DYNAMIC_VISCOSITY:
        val[i] = freesteam_mu(S0);
        break;
      case CS_PHYS_PROP_SPEED_OF_SOUND:
        val[i] = freesteam_w(S0);
        break;
      }
    }
  }
  else if (thermo_plane == CS_PHYS_PROP_PLANE_TS) {
    for (cs_lnum_t i = 0; i < n_vals; i++) {
      SteamState S0 = freesteam_set_Ts(var1[i], var2[i]);
      switch (property) {
      case CS_PHYS_PROP_PRESSURE:
        val[i] = freesteam_p(S0);
        break;
      case CS_PHYS_PROP_TEMPERATURE:
        bft_error(__FILE__, __LINE__, 0,
                  _("bad choice: you choose to work in the %s plane."), "Ts");
        break;
      case CS_PHYS_PROP_ENTHALPY:
        val[i] = freesteam_h(S0);
        break;
      case CS_PHYS_PROP_ENTROPY:
        bft_error(__FILE__, __LINE__, 0,
                  _("bad choice: you choose to work in the %s plane."), "Ts");
        break;
      case CS_PHYS_PROP_ISOBARIC_HEAT_CAPACITY:
        val[i] = freesteam_cp(S0);
        break;
      case CS_PHYS_PROP_ISOCHORIC_HEAT_CAPACITY:
        val[i] = freesteam_cv(S0);
        break;
      case CS_PHYS_PROP_SPECIFIC_VOLUME:
        val[i] = freesteam_v(S0);
        break;
      case CS_PHYS_PROP_DENSITY:
        val[i] = freesteam_rho(S0);
        break;
      case CS_PHYS_PROP_INTERNAL_ENERGY:
        val[i] = freesteam_u(S0);
        break;
      case CS_PHYS_PROP_QUALITY:
        val[i] = freesteam_x(S0);
        break;
      case CS_PHYS_PROP_THERMAL_CONDUCTIVITY:
        val[i] = freesteam_k(S0);
        break;
      case CS_PHYS_PROP_DYNAMIC_VISCOSITY:
        val[i] = freesteam_mu(S0);
        break;
      case CS_PHYS_PROP_SPEED_OF_SOUND:
        val[i] = freesteam_w(S0);
        break;
      }
    }
  }
  else if (thermo_plane == CS_PHYS_PROP_PLANE_TX) {
    for (cs_lnum_t i = 0; i < n_vals; i++) {
      SteamState S0 = freesteam_set_Tx(var1[i], var2[i]);
      switch (property) {
      case CS_PHYS_PROP_PRESSURE:
        val[i] = freesteam_p(S0);
        break;
      case CS_PHYS_PROP_TEMPERATURE:
        bft_error(__FILE__, __LINE__, 0,
                  _("bad choice: you choose to work in the %s plane."), "Tx");
        break;
      case CS_PHYS_PROP_ENTHALPY:
        val[i] = freesteam_h(S0);
        break;
      case CS_PHYS_PROP_ENTROPY:
        val[i] = freesteam_s(S0);
        break;
      case CS_PHYS_PROP_ISOBARIC_HEAT_CAPACITY:
        val[i] = freesteam_cp(S0);
        break;
      case CS_PHYS_PROP_ISOCHORIC_HEAT_CAPACITY:
        val[i] = freesteam_cv(S0);
        break;
      case CS_PHYS_PROP_SPECIFIC_VOLUME:
        val[i] = freesteam_v(S0);
        break;
      case CS_PHYS_PROP_DENSITY:
        val[i] = freesteam_rho(S0);
        break;
      case CS_PHYS_PROP_INTERNAL_ENERGY:
        val[i] = freesteam_u(S0);
        break;
      case CS_PHYS_PROP_QUALITY:
        bft_error(__FILE__, __LINE__, 0,
                  _("bad choice: you choose to work in the %s plane."), "Tx");
        break;
      case CS_PHYS_PROP_THERMAL_CONDUCTIVITY:
        val[i] = freesteam_k(S0);
        break;
      case CS_PHYS_PROP_DYNAMIC_VISCOSITY:
        val[i] = freesteam_mu(S0);
        break;
      case CS_PHYS_PROP_SPEED_OF_SOUND:
        val[i] = freesteam_w(S0);
        break;
      }
    }
  }
#else
  bft_error(__FILE__, __LINE__, 0,
            _("Freesteam support not available in this build."));
#endif
}

/*----------------------------------------------------------------------------*/

END_C_DECLS
