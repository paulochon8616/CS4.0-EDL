#ifndef __CS_MESH_LOCATION_H__
#define __CS_MESH_LOCATION_H__

/*============================================================================
 * Mesh locations management.
 *============================================================================*/

/*
  This file is part of the Code_Saturne Kernel, element of the
  Code_Saturne CFD tool.

  Copyright (C) 1998-2016 EDF S.A., France

  contact: saturne-support@edf.fr

  The Code_Saturne Kernel is free software; you can redistribute it
  and/or modify it under the terms of the GNU General Public License
  as published by the Free Software Foundation; either version 2 of
  the License, or (at your option) any later version.

  The Code_Saturne Kernel is distributed in the hope that it will be
  useful, but WITHOUT ANY WARRANTY; without even the implied warranty
  of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with the Code_Saturne Kernel; if not, write to the
  Free Software Foundation, Inc.,
  51 Franklin St, Fifth Floor,
  Boston, MA  02110-1301  USA
*/

/*----------------------------------------------------------------------------*/

#if defined(HAVE_MPI)
#include <mpi.h>
#endif

/*----------------------------------------------------------------------------
 *  Local headers
 *----------------------------------------------------------------------------*/

#include "cs_defs.h"
#include "cs_mesh.h"

/*----------------------------------------------------------------------------*/

BEGIN_C_DECLS

/*=============================================================================
 * Macro definitions
 *============================================================================*/

/*============================================================================
 * Type definitions
 *============================================================================*/

/* Mesh location types */

typedef enum {

  CS_MESH_LOCATION_NONE,
  CS_MESH_LOCATION_CELLS,
  CS_MESH_LOCATION_INTERIOR_FACES,
  CS_MESH_LOCATION_BOUNDARY_FACES,
  CS_MESH_LOCATION_VERTICES,
  CS_MESH_LOCATION_PARTICLES,
  CS_MESH_LOCATION_OTHER

} cs_mesh_location_type_t;

/* Opaque mesh location object */

typedef struct _cs_mesh_location_t cs_mesh_location_t;

/*----------------------------------------------------------------------------
 * Function pointer to mesh location elements selection definition.
 *
 * If non-empty and not containing all elements, a list of elements
 * of the parent mesh belonging to the location should be allocated
 * (using BFT_MALLOC) and defined by this function when called.
 * This list's lifecycle is then managed by the mesh location object.
 *
 * parameters:
 *   m           <-- pointer to associated mesh structure.
 *   location_id <-- id of associated location.
 *   n_elts      --> number of selected elements
 *   elt_list    --> list of selected elements (0 to n-1 numbering).
 *----------------------------------------------------------------------------*/

typedef void
(cs_mesh_location_select_t) (const cs_mesh_t   *m,
                             int                location_id,
                             cs_lnum_t         *n_elts,
                             cs_lnum_t        **elt_list);

/*=============================================================================
 * Global variables
 *============================================================================*/

/* Names associated with location types */

extern const char  *cs_mesh_location_type_name[];

/*=============================================================================
 * Public function prototypes
 *============================================================================*/

/*----------------------------------------------------------------------------
 * Return number of mesh locations defined.
 *----------------------------------------------------------------------------*/

int
cs_mesh_location_n_locations(void);

/*----------------------------------------------------------------------------
 * Initialize mesh location API.
 *
 * By default, 5 mesh locations are built, matching the 5 first values of
 * the cs_mesh_location_type_t enum: CS_MESH_LOCATION_NONE for global
 * values, CS_MESH_LOCATION_CELLS for the cells of the (default) global mesh,
 * CS_MESH_LOCATION_INTERIOR_FACES and CS_MESH_LOCATION_BOUNDARY_FACES for
 * its faces, and CS_MESH_LOCATION_VERTICES for its vertices.
 *
 * Locations should then be built once the global mesh is complete, and
 * its halo structures completed.
 *----------------------------------------------------------------------------*/

void
cs_mesh_location_initialize(void);

/*----------------------------------------------------------------------------
 * Finalize mesh location API.
 *----------------------------------------------------------------------------*/

void
cs_mesh_location_finalize(void);

/*----------------------------------------------------------------------------
 * Associate mesh locations with a mesh.
 *
 * If mesh_id is negative, all defined mesh locations are associated
 * (which is useful for the common case where only one mesh is present).
 * If mesh_id is non-negative, only the location with the matching
 * id is associated (which may be useful when multiple meshes are defined).
 *
 * The number of elements are computed based on the underlying mesh,
 * and element lists are built for mesh subset locations.
 *
 * parameters:
 *   mesh <-- pointer to associated mesh structure
 *   id   <-- id of mesh location
 *----------------------------------------------------------------------------*/

void
cs_mesh_location_build(cs_mesh_t  *mesh,
                       int         id);

/*----------------------------------------------------------------------------
 * Define a new mesh location.
 *
 * So as to define a subset of mesh entities of a given type, an optional
 * selection criteria may be given.
 *
 * parameters:
 *   name      <-- name of location to define
 *   type      <-- type of location to define
 *   criteria  <-- selection criteria for associated elements, or NULL
 *
 * returns:
 *   id of newly defined created mesh location
 *----------------------------------------------------------------------------*/

int
cs_mesh_location_define(const char               *name,
                        cs_mesh_location_type_t   type,
                        const char               *criteria);

/*----------------------------------------------------------------------------
 * Define a new mesh location.
 *
 * So as to define a subset of mesh entities of a given type, a pointer
 * to a selection function may be given.
 *
 * This requires more programming but allows finer control than selection
 * criteria, as the function has access to the complete mesh structure.
 *
 * parameters:
 *   name <-- name of location to define
 *   type <-- type of location to define
 *   func <-- pointer to selection function for associated elements, or NULL
 *
 * returns:
 *   id of newly defined created mesh location
 *----------------------------------------------------------------------------*/

int
cs_mesh_location_define_by_func(const char                 *name,
                                cs_mesh_location_type_t     type,
                                cs_mesh_location_select_t  *func);

/*----------------------------------------------------------------------------
 * Get a mesh location's name.
 *
 * parameters:
 *   id <-- id of mesh location
 *
 * returns:
 *   pointer to mesh location name
 *----------------------------------------------------------------------------*/

const char *
cs_mesh_location_get_name(int id);

/*----------------------------------------------------------------------------
 * Get a mesh location's type.
 *
 * parameters:
 *   id <-- id of mesh location
 *
 * returns:
 *    mesh location type
 *----------------------------------------------------------------------------*/

cs_mesh_location_type_t
cs_mesh_location_get_type(int id);

/*----------------------------------------------------------------------------
 * Get a mesh location's number of elements.
 *
 * A pointer to a array of 3 values is returned:
 *   0: local number of elements
 *   1: with standard ghost elements (if applicable)
 *   2: with extended ghost elements (if applicable)
 *
 * parameters:
 *   id <-- id of mesh location
 *
 * returns:
 *   array of numbers of elements.
 *----------------------------------------------------------------------------*/

const cs_lnum_t *
cs_mesh_location_get_n_elts(int id);

/*----------------------------------------------------------------------------
 * Get a mesh location's elements list, if present.
 *
 * A list of elements is defined if the location is a subset of a main
 * location type.
 *
 * parameters:
 *   id <-- id of mesh location
 *
 * returns:
 *   pointer to elements list (0 to n-1 numbering).
 *----------------------------------------------------------------------------*/

const cs_lnum_t *
cs_mesh_location_get_elt_list(int id);

/*----------------------------------------------------------------------------*/

END_C_DECLS

#endif /* __CS_MESH_LOCATION_H__ */
