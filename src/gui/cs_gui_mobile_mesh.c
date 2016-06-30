/*============================================================================
 * Management of the GUI parameters file: mobile mesh
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

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <assert.h>

/*----------------------------------------------------------------------------
 * Local headers
 *----------------------------------------------------------------------------*/

#include "bft_mem.h"
#include "bft_error.h"
#include "bft_printf.h"

#include "mei_evaluate.h"

#include "cs_base.h"
#include "cs_gui_util.h"
#include "cs_gui_variables.h"
#include "cs_gui_boundary_conditions.h"
#include "cs_mesh.h"
#include "cs_prototypes.h"
#include "cs_timer.h"

/*----------------------------------------------------------------------------
 * Header for the current file
 *----------------------------------------------------------------------------*/

#include "cs_gui_mobile_mesh.h"

/*----------------------------------------------------------------------------*/

BEGIN_C_DECLS

/*! \cond DOXYGEN_SHOULD_SKIP_THIS */

/*=============================================================================
 * Local Macro Definitions
 *============================================================================*/

/* debugging switch */
#define _XML_DEBUG_ 0

/*============================================================================
 * Static variables
 *============================================================================*/

/*-----------------------------------------------------------------------------
 * Possible values for boundary nature
 *----------------------------------------------------------------------------*/

enum ale_boundary_nature
{
  ale_boundary_nature_fixed_wall,
  ale_boundary_nature_sliding_wall,
  ale_boundary_nature_internal_coupling,
  ale_boundary_nature_external_coupling,
  ale_boundary_nature_fixed_velocity,
  ale_boundary_nature_fixed_displacement
};

/*============================================================================
 * Private function definitions
 *============================================================================*/

/*-----------------------------------------------------------------------------
 * Return value for iale method
 *
 * parameters:
 *   param   <-- iale parameter
 *   keyword --> value of the iale parameter
 *----------------------------------------------------------------------------*/

static void
_iale_parameter(const char  *const param,
                double      *const keyword)
{
  char   *path   = NULL;
  char   *type = NULL;
  double  result = 0.0;

  path = cs_xpath_init_path();
  cs_xpath_add_elements(&path, 3, "thermophysical_models", "ale_method", param);

  if (cs_gui_strcmp(param,"mesh_viscosity")) {

    cs_xpath_add_attribute(&path, "type");
    type = cs_gui_get_attribute_value(path);
    if(cs_gui_strcmp(type, "isotrop"))
      *keyword = 0;
    else if (cs_gui_strcmp(type, "orthotrop"))
      *keyword = 1;
    else
      bft_error(__FILE__, __LINE__, 0, _("Invalid xpath: %s\n"), path);

  } else {

    cs_xpath_add_function_text(&path);
    if (cs_gui_get_double(path, &result)) *keyword = result;

  }
  BFT_FREE(type);
  BFT_FREE(path);
}

/*-----------------------------------------------------------------------------
 * Return the status of ALE method
 *
 * parameters:
 *   keyword --> status of ALE tag
 *----------------------------------------------------------------------------*/

static void
_get_ale_status(int  *const keyword)
{
  char *path = NULL;
  int   result;

  path = cs_xpath_init_path();
  cs_xpath_add_elements(&path, 2, "thermophysical_models", "ale_method");
  cs_xpath_add_attribute(&path, "status");

  if(cs_gui_get_status(path, &result))
    *keyword = result;
  else
    *keyword = 0;


  BFT_FREE(path);
}

/*-----------------------------------------------------------------------------
 * Initialize mei tree and check for symbols existence
 *
 * parameters:
 *   formula        <-- mei formula
 *   symbols        <-- array of symbol to check
 *   symbol_nbr     <-- number of symbol in symbols
 *   variables      <-- variables required in the formula
 *   variable_nbr   <-- number of variable in variables
 *   dtref          <-- time step
 *   ttcabs         <-- current time
 *   ntcabs         <-- current iteration number
 *----------------------------------------------------------------------------*/

static mei_tree_t *
cs_gui_init_mei_tree(char         *formula,
                     const char   **symbols,
                     unsigned int symbol_nbr,
                     const char   **variables,
                     const double *variables_value,
                     unsigned int variable_nbr,
                     const double dtref,
                     const double ttcabs,
                     const int    ntcabs)
{
  unsigned int i = 0;

  /* return an empty interpreter */
  mei_tree_t *tree = mei_tree_new(formula);

  /* Insert variables into mei_tree */
  for (i = 0; i < variable_nbr; ++i) {
    double value = 0;

    /* Read value from variables_value if it is not null 0 otherwise */
    if (variables_value)
      value = variables_value[i];
    mei_tree_insert(tree, variables[i], value);
  }

  /* Add commun variables: dt, t, nbIter */
  mei_tree_insert(tree, "dt",   dtref);
  mei_tree_insert(tree, "t",    ttcabs);
  mei_tree_insert(tree, "iter", ntcabs);

  /* try to build the interpreter */
  if (mei_tree_builder(tree))
    bft_error(__FILE__, __LINE__, 0,
              _("Error: can not interpret expression: %s\n"), tree->string);

  /* Check for symbols */
  for (i = 0; i < symbol_nbr; ++i) {
    const char* symbol = symbols[i];

    if (mei_tree_find_symbol(tree, symbol)) {
      bft_error(__FILE__, __LINE__, 0,
                _("Error: can not find the required symbol: %s\n"), symbol);
    }
  }

  return tree;
}

/*-----------------------------------------------------------------------------
 * Return the ale boundary nature
 *----------------------------------------------------------------------------*/

static char *
_get_ale_formula(void)
{
  char *aleFormula;

  char *path = cs_xpath_short_path();
  cs_xpath_add_element(&path, "ale_method");
  cs_xpath_add_element(&path, "formula");
  cs_xpath_add_function_text(&path);

  aleFormula =  cs_gui_get_text_value(path);
  BFT_FREE(path);
  return aleFormula;
}

/*-----------------------------------------------------------------------------
 * Return the ale mesh viscosity
 *----------------------------------------------------------------------------*/

static char *
_get_ale_mesh_viscosity(void)
{
  char *viscosityType;

  char *path = cs_xpath_short_path();
  cs_xpath_add_element(&path, "ale_method");
  cs_xpath_add_element(&path, "mesh_viscosity");
  cs_xpath_add_attribute(&path, "type");

  viscosityType = cs_gui_get_attribute_value(path);
  BFT_FREE(path);
  return viscosityType;
}

/*-----------------------------------------------------------------------------
 * Get the ale boundary formula
 *
 * parameters:
 *   label        <-- boundary label
 *   choice       <-- nature: "fixed_velocity" or "fixed_displacement"
 *----------------------------------------------------------------------------*/

static char*
_get_ale_boundary_formula(const char *const label,
                          const char *const choice)
{
  char* formula;

  char *path = cs_xpath_init_path();
  cs_xpath_add_elements(&path, 2, "boundary_conditions",  "wall");
  cs_xpath_add_test_attribute(&path, "label", label);
  cs_xpath_add_element(&path, "ale");
  cs_xpath_add_test_attribute(&path, "choice", choice);
  cs_xpath_add_element(&path, "formula");
  cs_xpath_add_function_text(&path);

  formula = cs_gui_get_text_value(path);
  BFT_FREE(path);

  return formula;
}

/*-----------------------------------------------------------------------------
 * Get uialcl data for fixed displacement
 *
 * parameters:
 *   label          <-- boundary label
 *   begin          <-- begin index for nodfbr
 *   end            <-- end index for nodfbr
 *   nnod           <-> number of nodes
 *   b_face_vtx_lst <-- nodfbr
 *   impale         --> impale
 *   disale         --> disale
 *   dtref          <-- time step
 *   ttcabs         <-- current time
 *   ntcabs         <-- current iteration number
 *----------------------------------------------------------------------------*/

static void
_uialcl_fixed_displacement(const char       *label,
                           const cs_lnum_t   begin,
                           const cs_lnum_t   end,
                           const cs_lnum_t   b_face_vtx_lst[],
                           int              *impale,
                           cs_real_3_t      *disale,
                           const double      dtref,
                           const double      ttcabs,
                           const int         ntcabs)
{
  int ii = 0;
  mei_tree_t *ev;
  double X_mesh, Y_mesh, Z_mesh;

  const char*  variables[3] = {"mesh_x", "mesh_y", "mesh_z"};
  unsigned int variable_nbr = 3;

  /* Get formula */
  char* formula =_get_ale_boundary_formula(label, "fixed_displacement");

  if (!formula)
    bft_error(__FILE__, __LINE__, 0,
              _("Boundary nature formula is null for %s.\n"), label);

  /* Init mei */
  ev = cs_gui_init_mei_tree(formula, variables, variable_nbr,
                            0, 0, 0, dtref, ttcabs, ntcabs);

  mei_evaluate(ev);

  /* Get mei results */
  X_mesh = mei_tree_lookup(ev, "mesh_x");
  Y_mesh = mei_tree_lookup(ev, "mesh_y");
  Z_mesh = mei_tree_lookup(ev, "mesh_z");

  BFT_FREE(formula);
  mei_tree_destroy(ev);

  /* Set disale and impale */
  for (ii = begin; ii < end; ++ii) {
    cs_lnum_t inod = b_face_vtx_lst[ii];
    if (impale[inod] == 0) {
      disale[inod][0] = X_mesh;
      disale[inod][1] = Y_mesh;
      disale[inod][2] = Z_mesh;
      impale[inod] = 1;
    }
  }
}

/*-----------------------------------------------------------------------------
 * Get uialcl data for fixed velocity
 *
 * parameters:
 *   label        --> boundary label
 *   iuma         --> IUMA
 *   ivma         --> IVMA
 *   iwma         --> IWMA
 *   nfabor       --> Number of boundary faces
 *   ifbr         --> ifbr
 *   rcodcl       <-- RCODCL
 *   dtref        --> time step
 *   ttcabs       --> current time
 *   ntcabs       --> current iteration number
 *----------------------------------------------------------------------------*/

static void
uialcl_fixed_velocity(const char*   label,
                      const int     iuma,
                      const int     ivma,
                      const int     iwma,
                      const int     nfabor,
                      const int     ifbr,
                      double *const rcodcl,
                      const double  dtref,
                      const double  ttcabs,
                      const int     ntcabs)
{
  mei_tree_t *ev;
  const char*  variables[3] = { "mesh_velocity_U",
                                "mesh_velocity_V",
                                "mesh_velocity_W" };

  /* Get formula */
  char* formula =_get_ale_boundary_formula(label, "fixed_velocity");

  if (!formula)
    bft_error(__FILE__, __LINE__, 0,
              _("Boundary nature formula is null for %s.\n"), label);

  /* Init MEI */
  ev = cs_gui_init_mei_tree(formula, variables, 3, 0, 0, 0,
                            dtref, ttcabs, ntcabs);

  mei_evaluate(ev);

  /* Fill  rcodcl */
  rcodcl[(iuma-1) * nfabor + ifbr] = mei_tree_lookup(ev, "mesh_velocity_U");
  rcodcl[(ivma-1) * nfabor + ifbr] = mei_tree_lookup(ev, "mesh_velocity_V");
  rcodcl[(iwma-1) * nfabor + ifbr] = mei_tree_lookup(ev, "mesh_velocity_W");

  BFT_FREE(formula);
  mei_tree_destroy(ev);
}

/*-----------------------------------------------------------------------------
 * Return the ale boundary nature
 *
 * parameters:
 *   label  -->  label of boundary zone
 *----------------------------------------------------------------------------*/

static enum ale_boundary_nature
_get_ale_boundary_nature(const char *const label)
{
  char *ale_boundary_nature;

  enum ale_boundary_nature nature = ale_boundary_nature_fixed_wall;

  char *path = cs_xpath_init_path();
  cs_xpath_add_elements(&path, 2, "boundary_conditions",  "wall");

  cs_xpath_add_test_attribute(&path, "label", label);
  cs_xpath_add_element(&path, "ale");
  cs_xpath_add_attribute(&path, "choice");
  ale_boundary_nature = cs_gui_get_attribute_value(path);

  if (cs_gui_strcmp(ale_boundary_nature, "fixed_boundary"))
    nature = ale_boundary_nature_fixed_wall;
  if (cs_gui_strcmp(ale_boundary_nature, "sliding_boundary"))
    nature = ale_boundary_nature_sliding_wall;
  else if (cs_gui_strcmp(ale_boundary_nature, "internal_coupling"))
    nature = ale_boundary_nature_internal_coupling;
  else if (cs_gui_strcmp(ale_boundary_nature, "external_coupling"))
    nature = ale_boundary_nature_external_coupling;
  else if (cs_gui_strcmp(ale_boundary_nature, "fixed_velocity"))
    nature = ale_boundary_nature_fixed_velocity;
  else if (cs_gui_strcmp(ale_boundary_nature, "fixed_displacement"))
    nature = ale_boundary_nature_fixed_displacement;

  BFT_FREE(path);
  BFT_FREE(ale_boundary_nature);

  return nature;
}

/*-----------------------------------------------------------------------------
 * Get boundary attribute like nature or label
 *
 * parameters:
 *   ith_zone  --> boundary index
 *   nodeName  --> xml attribute name. for example, "nature" or "label"
 *----------------------------------------------------------------------------*/

static char*
get_boundary_attribute(unsigned int ith_zone,
                       const char   *nodeName)
{
  char *result;
  char *path = cs_xpath_init_path();

  cs_xpath_add_element(&path, "boundary_conditions");
  cs_xpath_add_element_num(&path, "boundary", ith_zone);
  cs_xpath_add_attribute(&path, nodeName);

  result = cs_gui_get_attribute_value(path);

  BFT_FREE(path);
  return result;
}

/*-----------------------------------------------------------------------------
 * Init xpath for internal coupling with:
 *
 * boundary_conditions/wall[label=label]/
 * ale[choice=internal_coupling]/node_name, node_sub_name/text()
 *
 * parameters:
 *   label            --> boundary label
 *   node_name        --> xml node name ("initial_displacement")
 *   node_sub_name    --> xml child node of node_name ("X")
 *----------------------------------------------------------------------------*/

static char*
init_internal_coupling_xpath(const char* label,
                             const char* node_name,
                             const char* node_sub_name)
{
  char *path = NULL;

  path = cs_xpath_init_path();
  cs_xpath_add_elements(&path, 2, "boundary_conditions",  "wall");
  cs_xpath_add_test_attribute(&path, "label", label);
  cs_xpath_add_element(&path, "ale");
  cs_xpath_add_test_attribute(&path, "choice", "internal_coupling");
  cs_xpath_add_element(&path, node_name);
  cs_xpath_add_element(&path, node_sub_name);
  cs_xpath_add_function_text(&path);

  return path;
}


/*-----------------------------------------------------------------------------
 * Get internal coupling double
 *
 * parameters:
 *   label            --> boundary label
 *   node_name        --> xml node name ("initial_displacement")
 *   node_sub_name    --> xml child node of node_name ("X")
 *----------------------------------------------------------------------------*/

static double
get_internal_coupling_double(const char* label,
                             const char* node_name,
                             const char* node_sub_name)
{
  double value = 0;
  char *path = init_internal_coupling_xpath(label, node_name, node_sub_name);

  if (!cs_gui_get_double(path, &value))
  {
    bft_error(__FILE__, __LINE__, 0,
              _("cannot get value for %s %s %s"),
                 label, node_name, node_sub_name);
  }
  BFT_FREE(path);

  return value;
}

/*-----------------------------------------------------------------------------
 * Get internal coupling string
 *
 * parameters:
 *   label            --> boundary label
 *   node_name        --> xml node name ("initial_displacement")
 *   node_sub_name    --> xml child node of node_name ("formula")
 *----------------------------------------------------------------------------*/

static char*
get_internal_coupling_string(const char* label,
                             const char* node_name,
                             const char* node_sub_name)
{
  char *path = init_internal_coupling_xpath(label, node_name, node_sub_name);
  char* str  = cs_gui_get_text_value(path);

  BFT_FREE(path);

  return str;
}


/*-----------------------------------------------------------------------------
 * Retreive internal coupling x, y and z XML values
 *
 * parameters:
 *   label      --> boundary label
 *   node_name  --> xml node name ("initial_displacement")
 *   xyz        <-- result matrix
 *----------------------------------------------------------------------------*/

static void
get_internal_coupling_xyz_values(const char *label,
                                 const char *node_name,
                                 double      xyz[3])
{
  xyz[0] = get_internal_coupling_double(label, node_name, "X");
  xyz[1] = get_internal_coupling_double(label, node_name, "Y");
  xyz[2] = get_internal_coupling_double(label, node_name, "Z");
}

/*-----------------------------------------------------------------------------
 * Retreive internal coupling advanced windows double value
 *
 * parameters:
 *   node_name  --> xml node name ("displacement_prediction_alpha")
 *----------------------------------------------------------------------------*/

static void
get_uistr1_advanced_double(const char *const keyword,
                               double *const value)
{
  double result = 0;
  char   *path = cs_xpath_init_path();

  cs_xpath_add_elements(&path, 3, "thermophysical_models", "ale_method", keyword);
  cs_xpath_add_function_text(&path);

  if (cs_gui_get_double(path, &result))
    *value = result;
  BFT_FREE(path);
}

/*-----------------------------------------------------------------------------
 * Retreive internal coupling advanced windows checkbox value
 *
 * parameters:
 *   node_name  --> xml node name ("monitor_point_synchronisation")
 *----------------------------------------------------------------------------*/

static void
get_uistr1_advanced_checkbox(const char *const keyword, int *const value)
{
  int result = 0;
  char *path = cs_xpath_init_path();

  cs_xpath_add_elements(&path, 3, "thermophysical_models", "ale_method", keyword);
  cs_xpath_add_attribute(&path, "status");

  if (cs_gui_get_status(path, &result))
    *value = result;
  BFT_FREE(path);
}

/*-----------------------------------------------------------------------------
 * Retreive data the internal coupling matrices
 *
 * parameters:
 *   label            --> boundary label
 *   node_name        --> xml matrix node name
 *   symbols          --> see cs_gui_init_mei_tree
 *   symbol_nbr       --> see cs_gui_init_mei_tree
 *   variables        --> see cs_gui_init_mei_tree
 *   variables_value  --> see cs_gui_init_mei_tree
 *   variable_nbr     --> see cs_gui_init_mei_tree
 *   output_matrix,   <-- result matrix
 *   dtref            --> time step
 *   ttcabs           --> current time
 *   ntcabs           --> current iteration number
 *----------------------------------------------------------------------------*/

static void
get_internal_coupling_matrix(const char    *label,
                             const char    *node_name,
                             const char    *symbols[],
                             unsigned int  symbol_nbr,
                             const char    **variables,
                             const double  *variables_value,
                             unsigned int  variable_nbr,
                             double        *output_matrix,
                             const double  dtref,
                             const double  ttcabs,
                             const int     ntcabs)
{
  /* Get the formula */
  mei_tree_t *tree;

  unsigned int i = 0;
  char *matrix = get_internal_coupling_string(label, node_name, "formula");

  if (!matrix)
    bft_error(__FILE__, __LINE__, 0,
              _("Formula is null for %s %s"), label, node_name);

  /* Initialize mei */
  tree = cs_gui_init_mei_tree(matrix, symbols, symbol_nbr,
                              variables, variables_value, variable_nbr,
                              dtref, ttcabs, ntcabs);
  mei_evaluate(tree);

  /* Read matrix values */
  for (i = 0; i < symbol_nbr; ++i) {
    const char *symbol = symbols[i];
    output_matrix[i] = mei_tree_lookup(tree, symbol);
  }
  BFT_FREE(matrix);
  mei_tree_destroy(tree);
}

/*-----------------------------------------------------------------------------
 * Retreive data for internal coupling for a specific boundary
 *
 * parameters:
 *   label    --> boundary label
 *   xmstru   <-- Mass matrix
 *   xcstr    <-- Damping matrix
 *   xkstru   <-- Stiffness matrix
 *   forstr   <-- Fluid force matrix
 *   istruc   --> internal coupling boundary index
 *   dtref    --> time step
 *   ttcabs   --> current time
 *   ntcabs   --> current iteration number
 *----------------------------------------------------------------------------*/

static void
get_uistr2_data(const char    *label,
                double *const xmstru,
                double *const xcstru,
                double *const xkstru,
                double *const forstr,
                unsigned int  istruc,
                const double  dtref,
                const double  ttcabs,
                const int     ntcabs)
{
  const char  *m_symbols[] = {"m11", "m12", "m13",
                              "m21", "m22", "m23",
                              "m31", "m32", "m33"};
  const char  *c_symbols[] = {"c11", "c12", "c13",
                              "c21", "c22", "c23",
                              "c31", "c32", "c33"};
  const char  *k_symbols[] = {"k11", "k12", "k13",
                              "k21", "k22", "k23",
                              "k31", "k32", "k33"};

  unsigned int symbol_nbr = sizeof(m_symbols) / sizeof(m_symbols[0]);

  const char   *force_symbols[] = {"fx", "fy", "fz"};
  unsigned int force_symbol_nbr = sizeof(force_symbols) / sizeof(force_symbols[0]);

  const unsigned int  variable_nbr = 3;
  const char *variables[3] = {"fluid_fx", "fluid_fy", "fluid_fz"};
  double variable_values[3];

  /* Get mass matrix, damping matrix and stiffness matrix */

  get_internal_coupling_matrix(label, "mass_matrix", m_symbols,
                               symbol_nbr, 0, 0, 0,
                               &xmstru[istruc * symbol_nbr],
                               dtref, ttcabs, ntcabs);

  get_internal_coupling_matrix(label, "damping_matrix", c_symbols,
                               symbol_nbr, 0, 0, 0,
                               &xcstru[istruc * symbol_nbr],
                               dtref, ttcabs, ntcabs);

  get_internal_coupling_matrix(label, "stiffness_matrix", k_symbols,
                               symbol_nbr, 0, 0, 0,
                               &xkstru[istruc * symbol_nbr],
                               dtref, ttcabs, ntcabs);

  /* Set variable for fluid force matrix */
  variable_values[0] = forstr[istruc * force_symbol_nbr + 0];
  variable_values[1] = forstr[istruc * force_symbol_nbr + 1];
  variable_values[2] = forstr[istruc * force_symbol_nbr + 2];

  /* Get fluid force matrix */
  get_internal_coupling_matrix(label, "fluid_force_matrix",
                               force_symbols, force_symbol_nbr,
                               variables, variable_values, variable_nbr,
                               &forstr[istruc * force_symbol_nbr],
                               dtref, ttcabs, ntcabs);
}

/*! (DOXYGEN_SHOULD_SKIP_THIS) \endcond */

/*============================================================================
 * Public Fortran function definitions
 *============================================================================*/

/*----------------------------------------------------------------------------
 *  uivima
 *
 * ncel     -->  number of cells whithout halo
 * viscmx   <--  VISCMX
 * viscmy   <--  VISCMY
 * viscmz   <--  VISCMZ
 * xyzcen   -->  cell's gravity center
 * dtref    -->  time step
 * ttcabs   --> current time
 * ntcabs   --> current iteration number
 *----------------------------------------------------------------------------*/

void CS_PROCF (uivima, UIVIMA) (const cs_int_t *const ncel,
                                double         *const viscmx,
                                double         *const viscmy,
                                double         *const viscmz,
                                const double   *const xyzcen,
                                double         *const dtref,
                                double         *const ttcabs,
                                const int      *const ntcabs)
{
  int          iel            = 0;
  const char*  symbols[3]     = { "x", "y", "z" };
  const char*  variables[3]   = { "mesh_viscosity_1",
                                  "mesh_viscosity_2",
                                  "mesh_viscosity_3" };
  unsigned int variable_nbr   = 1;

  /* Get formula */
  mei_tree_t *ev;
  char *aleFormula    =_get_ale_formula();
  char *viscosityType =_get_ale_mesh_viscosity();
  unsigned int isOrthotrop = cs_gui_strcmp(viscosityType, "orthotrop");

  if (isOrthotrop)
    variable_nbr = 3;

  if (!aleFormula) {
    bft_printf("Warning : Formula is null for ale. Use constant value\n");
    for (iel = 0; iel < *ncel; iel++) {
      viscmx[iel] = 1.;
      if (isOrthotrop) {
        viscmy[iel] = 1.;
        viscmz[iel] = 1.;
      }
    }
  }
  else {

    /* Init mei */
    ev = cs_gui_init_mei_tree(aleFormula, variables,
                              variable_nbr, symbols, 0, 3,
                              *dtref, *ttcabs, *ntcabs);

    /* for each cell, update the value of the table of symbols for each scalar
       (including the thermal scalar), and evaluate the interpreter */
    for (iel = 0; iel < *ncel; iel++) {
      /* insert symbols */
      mei_tree_insert(ev, "x", xyzcen[3 * iel + 0]);
      mei_tree_insert(ev, "y", xyzcen[3 * iel + 1]);
      mei_tree_insert(ev, "z", xyzcen[3 * iel + 2]);

      mei_evaluate(ev);

      /* Set viscmx, viscmy and viscmz */
      viscmx[iel] = mei_tree_lookup(ev, "mesh_viscosity_1");
      if (isOrthotrop) {
        viscmy[iel] = mei_tree_lookup(ev, "mesh_viscosity_2");
        viscmz[iel] = mei_tree_lookup(ev, "mesh_viscosity_3");
      }
    }
    mei_tree_destroy(ev);
    BFT_FREE(aleFormula);
    BFT_FREE(viscosityType);
  }
}

/*----------------------------------------------------------------------------
 * ALE related keywords
 *
 * Fortran Interface:
 *
 * SUBROUTINE UIALIN
 * *****************
 *
 * INTEGER          IALE    <--  iale method activation
 * INTEGER          NALINF  <--  number of sub iteration of initialization
 *                               of fluid
 * INTEGER          NALIMX  <--  max number of iterations of implicitation of
 *                               the displacement of the structures
 * DOUBLE           EPALIM  <--  realtive precision of implicitation of
 *                               the displacement of the structures
 * INTEGER          IORTVM  <--  type of viscosity of mesh
 *
 *----------------------------------------------------------------------------*/

void CS_PROCF (uialin, UIALIN) (int    *const iale,
                                int    *const nalinf,
                                int    *const nalimx,
                                double *const epalim,
                                int    *const iortvm)
{
  double value;

  _get_ale_status(iale);

  if (*iale) {
    value =(double) *nalinf;
    _iale_parameter("fluid_initialization_sub_iterations", &value);
    *nalinf = (int) value;

    value =(double) *nalimx;
    _iale_parameter("max_iterations_implicitation", &value);
    *nalimx = (int) value;

    _iale_parameter("implicitation_precision", epalim);

    value =(double) *iortvm;
    _iale_parameter("mesh_viscosity", &value);
    *iortvm = (int) value;
  }

#if _XML_DEBUG_
  bft_printf("==>UIALIN\n");
  bft_printf("--iale = %i\n", *iale);
  if (*iale) {
    bft_printf("--nalinf = %i\n", *nalinf);
    bft_printf("--nalimx = %i\n", *nalimx);
    bft_printf("--epalim = %g\n", *epalim);
    bft_printf("--iortvm = %i\n", *iortvm);
  }
#endif
}

/*-----------------------------------------------------------------------------
 *  uialcl
 *
 * parameters:
 *   nozppm       --> Max number of boundary conditions zone
 *   ialtyb       --> ialtyb
 *   impale       --> uialcl_fixed_displacement
 *   disale       --> See uialcl_fixed_displacement
 *   dtref        --> time step
 *   ttcabs       --> current time
 *   ntcabs       --> current iteration number
 *   iuma         --> See uialcl_fixed_velocity
 *   ivma         --> See uialcl_fixed_velocity
 *   iwma         --> See uialcl_fixed_velocity
 *   rcodcl       --> See uialcl_fixed_velocity
 *----------------------------------------------------------------------------*/

void CS_PROCF (uialcl, UIALCL) (const int *const    nozppm,
                                const int *const    ibfixe,
                                const int *const    igliss,
                                const int *const    ivimpo,
                                const int *const    ifresf,
                                int       *const    ialtyb,
                                int       *const    impale,
                                cs_real_3_t        *disale,
                                double    *const    dtref,
                                double    *const    ttcabs,
                                const int *const    ntcabs,
                                const int *const    iuma,
                                const int *const    ivma,
                                const int *const    iwma,
                                double    *const    rcodcl)
{
  double t0;
  int  izone = 0;
  cs_lnum_t  ifac  = 0;
  cs_lnum_t  faces = 0;

  const cs_mesh_t *m = cs_glob_mesh;

  int zones = cs_gui_boundary_zones_number();

  /* At each time-step, loop on boundary faces: */
  for (izone=0 ; izone < zones ; izone++) {
    cs_lnum_t* faces_list = cs_gui_get_faces_list(izone,
                                                  boundaries->label[izone],
                                                  m->n_b_faces,
                                                  *nozppm,
                                                  &faces);

    /* get the ale choice */
    const char* label = boundaries->label[izone];
    enum ale_boundary_nature nature =_get_ale_boundary_nature(label);

    if (nature ==  ale_boundary_nature_fixed_wall) {
      for (ifac = 0; ifac < faces; ifac++) {
        cs_lnum_t ifbr = faces_list[ifac];
        ialtyb[ifbr]  = *ibfixe;
      }
    }
    else if (nature ==  ale_boundary_nature_sliding_wall) {
      for (ifac = 0; ifac < faces; ifac++) {
        cs_lnum_t ifbr = faces_list[ifac];
        ialtyb[ifbr]  = *igliss;
      }
    }
    else if (nature == ale_boundary_nature_fixed_displacement) {
      t0 = cs_timer_wtime();
      for (ifac = 0; ifac < faces; ifac++) {
        cs_lnum_t ifbr = faces_list[ifac];
        _uialcl_fixed_displacement(label,
                                   m->b_face_vtx_idx[ifbr],
                                   m->b_face_vtx_idx[ifbr+1],
                                   m->b_face_vtx_lst, impale, disale,
                                   *dtref, *ttcabs, *ntcabs);
      }
      cs_gui_add_mei_time(cs_timer_wtime() - t0);
    }
    else if (nature == ale_boundary_nature_fixed_velocity) {
      t0 = cs_timer_wtime();
      for (ifac = 0; ifac < faces; ifac++) {
        cs_lnum_t ifbr = faces_list[ifac];
        uialcl_fixed_velocity(label, *iuma, *ivma, *iwma,
                              m->n_b_faces, ifbr, rcodcl,
                              *dtref, *ttcabs, *ntcabs);
        ialtyb[ifbr]  = *ivimpo;
      }
      cs_gui_add_mei_time(cs_timer_wtime() - t0);
    }
    else {
      char *nat = cs_gui_boundary_zone_nature(izone);
      if (cs_gui_strcmp(nat, "free_surface")) {
        for (ifac = 0; ifac < faces; ifac++) {
          cs_lnum_t ifbr = faces_list[ifac];
          ialtyb[ifbr]  = *ifresf;
        }
      }
      BFT_FREE(nat);
    }
    BFT_FREE(faces_list);
  }
}

/*-----------------------------------------------------------------------------
 * Retreive data for internal coupling. Called once at initialization
 *
 * parameters:
 *   nfabor   <-- Number of boundary faces
 *   idfstr   --> Structure definition
 *   mbstru   <-- number of previous structures (-999 or by restart)
 *   aexxst   --> Displacement prediction alpha
 *   bexxst   --> Displacement prediction beta
 *   cfopre   --> Stress prediction alpha
 *   ihistr   --> Monitor point synchronisation
 *   xstr0    <-> Values of the initial displacement
 *   xstreq   <-> Values of the equilibrium displacement
 *   vstr0    <-> Values of the initial velocity
 *----------------------------------------------------------------------------*/

void CS_PROCF (uistr1, UISTR1) (const cs_lnum_t  *nfabor,
                                cs_lnum_t        *idfstr,
                                const int        *mbstru,
                                double           *aexxst,
                                double           *bexxst,
                                double           *cfopre,
                                int              *ihistr,
                                double           *xstr0,
                                double           *xstreq,
                                double           *vstr0)
{
  int  zones;
  int  izone        = 0;
  int  ifac         = 0;
  cs_lnum_t  faces        = 0;
  cs_lnum_t  ifbr         = 0;
  cs_lnum_t  *faces_list  = NULL;
  unsigned int    istruct = 0;

  /* Get advanced data */
  get_uistr1_advanced_double("displacement_prediction_alpha", aexxst);
  get_uistr1_advanced_double("displacement_prediction_beta", bexxst);
  get_uistr1_advanced_double("stress_prediction_alpha", cfopre);
  get_uistr1_advanced_checkbox("monitor_point_synchronisation", ihistr);

  zones = cs_gui_boundary_zones_number();

  /* At each time-step, loop on boundary faces */
  for (izone=0 ; izone < zones ; izone++) {
    char *nature = get_boundary_attribute(izone + 1, "nature");
    char *label  = get_boundary_attribute(izone + 1, "label");

    /* Keep only internal coupling */
    if (  _get_ale_boundary_nature(label)
        == ale_boundary_nature_internal_coupling) {

      if (istruct+1 > *mbstru) { /* Do not overwrite restart data */
        /* Read initial_displacement, equilibrium_displacement and initial_velocity */
        get_internal_coupling_xyz_values(label, "initial_displacement",
                                         &xstr0[3 * istruct]);
        get_internal_coupling_xyz_values(label, "equilibrium_displacement",
                                         &xstreq[3 * istruct]);
        get_internal_coupling_xyz_values(label, "initial_velocity",
                                         &vstr0[3 * istruct]);
      }

      faces_list = cs_gui_get_faces_list(izone, label, *nfabor, 0, &faces);
      /* Set idfstr to positiv index starting at 1 */
      for (ifac = 0; ifac < faces; ifac++) {
        ifbr = faces_list[ifac];
        idfstr[ifbr] = istruct + 1;
      }
      ++istruct;
      BFT_FREE(faces_list);
    }
    BFT_FREE(nature);
    BFT_FREE(label);
  }
}

/*-----------------------------------------------------------------------------
 * Retreive data for internal coupling. Called at each step
 *
 * parameters:
 *   xmstru       <-- Mass matrix
 *   xcstr        <-- Damping matrix
 *   xkstru       <-- Stiffness matrix
 *   forstr       <-- Fluid force matrix
 *   dtref        -->   time step
 *   ttcabs       --> current time
 *   ntcabs       --> current iteration number
 *----------------------------------------------------------------------------*/

void CS_PROCF (uistr2, UISTR2) (double *const  xmstru,
                                double *const  xcstru,
                                double *const  xkstru,
                                double *const  forstr,
                                double *const  dtref,
                                double *const  ttcabs,
                                int    *const  ntcabs)
{
  int          izone   = 0;
  unsigned int istru   = 0;

  int zones   = cs_gui_boundary_zones_number();

  /* At each time-step, loop on boundary faces */
  for (izone=0 ; izone < zones ; izone++) {
    const char *label = boundaries->label[izone];

    /* Keep only internal coupling */
    if (_get_ale_boundary_nature(label) == ale_boundary_nature_internal_coupling) {

#if 0
      /* Read internal coupling data for boundaries */
      for (int ii=0; ii<3; ii++) {
        xmstru = 0.;
        xkstru = 0.;
        xcstru = 0.;
      }
#endif

      get_uistr2_data(label,
                      xmstru,
                      xcstru,
                      xkstru,
                      forstr,
                      istru,
                      *dtref,
                      *ttcabs,
                      *ntcabs);
      ++istru;
    }
  }
}

/*============================================================================
 * Public function definitions
 *============================================================================*/

/*-----------------------------------------------------------------------------
 * Return the viscosity's type of ALE method
 *
 * parameters:
 *   type --> type of viscosity's type
 *----------------------------------------------------------------------------*/

void
cs_gui_get_ale_viscosity_type(int  * type)
{
  char *path = NULL;
  char *buff = NULL;

  path = cs_xpath_init_path();
  cs_xpath_add_elements(&path, 3,
                        "thermophysical_models", "ale_method", "mesh_viscosity");
  cs_xpath_add_attribute(&path, "type");

  buff = cs_gui_get_attribute_value(path);

  if (cs_gui_strcmp(buff, "orthotrop"))
    *type = 1;
  else if (cs_gui_strcmp(buff, "isotrop"))
    *type = 0;
  else
    bft_error(__FILE__, __LINE__, 0, _("Invalid xpath: %s\n"), path);

  BFT_FREE(path);
  BFT_FREE(buff);
}

/*----------------------------------------------------------------------------*/

END_C_DECLS
