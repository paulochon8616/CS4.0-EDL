#ifndef __CS_GUI_UTIL_H__
#define __CS_GUI_UTIL_H__

/*============================================================================
 * Management of the GUI parameters file: xpath request and utilities
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
 * Public function prototypes for Fortran API
 *============================================================================*/

/*-----------------------------------------------------------------------------
 * Return the information if the requested xml file is missing
 *
 * Fortran Interface:
 *
 * SUBROUTINE CSIHMP (IIHMPR)
 * *****************
 *
 * INTEGER          IIHMPR   <--   1 if the file exists, 0 otherwise
 *----------------------------------------------------------------------------*/

void
CS_PROCF (csihmp, CSIHMP) (int *const iihmpr);

/*=============================================================================
 * Public function prototypes
 *============================================================================*/

/*-----------------------------------------------------------------------------
 * Indicate if an XML file has been loaded
 *
 * returns:
 *   1 if an XML file has been loaded, 0 otherwise
 *----------------------------------------------------------------------------*/

int
cs_gui_file_is_loaded(void);

/*----------------------------------------------------------------------------
 * Load the XML file in memory.
 *
 * parameter:
 *   filename <-- XML file containing the parameters
 *
 * returns:
 *   error code (0 in case of success)
 *----------------------------------------------------------------------------*/

int
cs_gui_load_file(const char  *filename);

/*-----------------------------------------------------------------------------
 * Check the xml file version.
 *----------------------------------------------------------------------------*/

void
cs_gui_check_version(void);

/*----------------------------------------------------------------------------
 * Initialize the path for the xpath request with the root node.
 *
 * returns:
 *   the root path
 *----------------------------------------------------------------------------*/

char*
cs_xpath_init_path(void);

/*----------------------------------------------------------------------------
 * Initialize the path for the xpath request with a short way.
 *
 * returns:
 *   the short path.
 *----------------------------------------------------------------------------*/

char*
cs_xpath_short_path(void);

/*----------------------------------------------------------------------------
 * Add all elements (*) to the path.
 *
 * parameter:
 *   path <--> path for the xpath request
 *----------------------------------------------------------------------------*/

void
cs_xpath_add_all_elements(char  **path);

/*----------------------------------------------------------------------------
 * Add an element (i.e. markup's label) to the path.
 *
 * parameters:
 *   path    <-> path for the xpath request
 *   element <-- label of the new element in the path
 *----------------------------------------------------------------------------*/

void
cs_xpath_add_element(char        **path,
                     const char   *element);

/*----------------------------------------------------------------------------
 * Add a list of elements (i.e. markup's label) to the path.
 *
 * parameters:
 *   path <->  path for the xpath request
 *   nbr  <--  size of the labels list
 *   ...  <--  list of labels of new elements in the path
 *----------------------------------------------------------------------------*/

void
cs_xpath_add_elements(char  **path,
                      int     nbr,
                      ...);

/*----------------------------------------------------------------------------
 * Add an element's attribute to the path.
 *
 * parameters:
 *   path           <-> path for the xpath request
 *   attribute_name <-- label of the new attribute in the path
 *----------------------------------------------------------------------------*/

void
cs_xpath_add_attribute(char        **path,
                       const char   *attribute_name);

/*----------------------------------------------------------------------------
 * Add the i'th element to the path.
 *
 * parameters:
 *   path    <-> path for the xpath request
 *   element <-- label of the new element in the path
 *   num     <-- number of the element's markup
 *----------------------------------------------------------------------------*/

void
cs_xpath_add_element_num(char        **path,
                         const char   *element,
                         int           num);

/*----------------------------------------------------------------------------
 * Add a test on a value associated to an attribute to the path.
 *
 * parameters:
 *   path            <-> path for the xpath request
 *   attribute_type  <-- label of the attribute for the test in the path
 *   attribute_value <-- value of the attribute for the test in the path
 *----------------------------------------------------------------------------*/

void
cs_xpath_add_test_attribute(char        **path,
                            const char   *attribute_type,
                            const char   *attribute_value);

/*----------------------------------------------------------------------------
 * Add the 'text()' xpath function to the path.
 *
 * parameters:
 *   path <->  path for the xpath request
 *----------------------------------------------------------------------------*/

void
cs_xpath_add_function_text(char  **path);

/*----------------------------------------------------------------------------
 * Return a list of attribute node names from the xpath request in an array.
 *
 * Example: from <a attr="c"/><b attr="d"/> return {c,d}
 *
 * parameters:
 *   path <-- path for the xpath request
 *   size --> array size
 *----------------------------------------------------------------------------*/

char**
cs_gui_get_attribute_values(char  *path,
                            int   *size);

/*----------------------------------------------------------------------------
 * Return the value of an element's attribute.
 *
 * Example: from <a b="c"/> return c
 *
 * parameters:
 *   path <-- path for the xpath request
 *----------------------------------------------------------------------------*/

char*
cs_gui_get_attribute_value(char  *path);

/*----------------------------------------------------------------------------
 * Return a list of children nodes name from the xpath request in an array.
 *
 * Example: from <a>3<\a><b>4<\b> return {a,b}
 *
 * parameters:
 *   path <-- path for the xpath request
 *   size --> array size
 *
 * returns:
 *   node's names
 *----------------------------------------------------------------------------*/

char**
cs_gui_get_nodes_name(char  *path,
                      int   *size);

/*----------------------------------------------------------------------------
 * Return a single node's name from the xpath request.
 *
 * parameter:
 *   path <-- path for the xpath request
 *
 * returns:
 *   node's name
 *----------------------------------------------------------------------------*/

char*
cs_gui_get_node_name(char  *path);

/*----------------------------------------------------------------------------
 * Return a list of children text nodes from the xpath request in an array.
 *
 * Example: from <a>3<\a><a>4<\a> return {3,4}
 *
 * parameters:
 *   path <-- path for the xpath request
 *   size --> array size
 *----------------------------------------------------------------------------*/

char**
cs_gui_get_text_values(char  *path,
                       int   *size);

/*----------------------------------------------------------------------------
 * Return a single child text node from the xpath request.
 *
 * parameter:
 *   path <-- path for the xpath request
 *
 * returns:
 *   child node based on request
 *----------------------------------------------------------------------------*/

char*
cs_gui_get_text_value(char  *path);

/*----------------------------------------------------------------------------
 * Query a double value parameter.
 *
 * parameters:
 *   path  <-- path for the xpath request
 *   value --> double result of the xpath request
 *
 * returns:
 *   1 if the xpath request succeeded, 0 otherwise.
 *----------------------------------------------------------------------------*/

int
cs_gui_get_double(char    *path,
                  double  *value);

/*----------------------------------------------------------------------------
 * Query an integer value parameter.
 *
 * parameters:
 *   path  <-- path for the xpath request
 *   value --> double result of the xpath request
 *
 * returns:
 *   1 if the xpath request succeeded, 0 otherwise.
 *----------------------------------------------------------------------------*/

int
cs_gui_get_int(char  *path,
               int   *value);

/*----------------------------------------------------------------------------
 * Query the number of elements (i.e. the number of xml markups)
 * from a xpath request.
 *
 * Example: from <a>3<\a><a>4<\a> return 2
 *
 * parameters:
 *   path <-- path for the xpath request
 *
 * returns:
 *   the number of elements in xpath request
 *----------------------------------------------------------------------------*/

int
cs_gui_get_nb_element(char  *path);

/*----------------------------------------------------------------------------
 * Query the maximum integer value from an xpath request result list.
 *
 * Example: from <a>3<\a><a>4<\a> return 4
 *
 * parameters:
 *   path <-- path for the xpath request
 *
 * returns:
 *   the maximum integer value in the list
 *----------------------------------------------------------------------------*/

int
cs_gui_get_max_value(char  *path);

/*-----------------------------------------------------------------------------
 * Evaluate the "status" attribute value.
 *
 * parameter:
 *   path   <-- path for the xpath request
 *   result --> status="on" return 1, status="off" return 0
 *
 * returns:
 *   1 if the xpath request has succeeded, 0 otherwise
 *----------------------------------------------------------------------------*/

int
cs_gui_get_status(char  *path,
                  int   *result);

/*-----------------------------------------------------------------------------
 * Return the xml markup quantity.
 *
 * parameters:
 *   markup <--  path for the markup
 *   flag   <--  1: initialize the path with the root node;
 *               0: initialize the path with a short way
 *
 * returns:
 *   XML markup quantity
 *----------------------------------------------------------------------------*/

int
cs_gui_get_tag_number(const char  *markup,
                      int          flag);

/*-----------------------------------------------------------------------------
 * Return the number of characters needed to print an integer number
 *
 * parameters:
 *   num <-- integer number
 *
 * returns:
 *   number of characters required
 *----------------------------------------------------------------------------*/

int
cs_gui_characters_number(int num);

/*-----------------------------------------------------------------------------
 * Compare two strings.
 *
 * parameters:
 *   s1 <-- first string
 *   s2 <-- second string
 *
 * returns:
 *   1 if the strings are equal, 0 otherwise.
 *----------------------------------------------------------------------------*/

int
cs_gui_strcmp(const char  *s1,
              const char  *s2);

/*-----------------------------------------------------------------------------
 * Copy a C string into a Fortran string.
 *
 * parameters:
 *   chainef <-> Fortran string
 *   chainc  <-- C string
 *   lstrF   <-- maximum length of the Fortran string
 *----------------------------------------------------------------------------*/

void
cs_gui_strcpy_c2f(char        *chainef,
                  const char  *chainec,
                  const int    lstrF);

/*-----------------------------------------------------------------------------
 * Test if 2 real values are equal (avoiding compiler warnings)
 *
 * parameters:
 *   v1 <-- first value to compare
 *   v2 <-- second value to compare
 *
 * returns:
 *   1 if values are equal, 0 otherwise
 *----------------------------------------------------------------------------*/

int
cs_gui_is_equal_real(cs_real_t v1,
                     cs_real_t v2);

/*-----------------------------------------------------------------------------
 * Add timing increment to global MEI time counter.
 *
 * parameters:
 *   t <-- timing increment to add
 *----------------------------------------------------------------------------*/

void
cs_gui_add_mei_time(double t);

/*-----------------------------------------------------------------------------
 * Get cumulative global MEI time counter.
 *
 * returns:
 *   cumulative global MEI time counter
 *----------------------------------------------------------------------------*/

double
cs_gui_get_mei_times(void);

/*----------------------------------------------------------------------------*/

END_C_DECLS

#endif /* __CS_GUI_UTIL_H__ */
