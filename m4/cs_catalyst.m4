dnl--------------------------------------------------------------------------------
dnl
dnl This file is part of Code_Saturne, a general-purpose CFD tool.
dnl
dnl Copyright (C) 1998-2016 EDF S.A.
dnl
dnl This program is free software; you can redistribute it and/or modify it under
dnl the terms of the GNU General Public License as published by the Free Software
dnl Foundation; either version 2 of the License, or (at your option) any later
dnl version.
dnl
dnl This program is distributed in the hope that it will be useful, but WITHOUT
dnl ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
dnl FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
dnl details.
dnl
dnl You should have received a copy of the GNU General Public License along with
dnl this program; if not, write to the Free Software Foundation, Inc., 51 Franklin
dnl Street, Fifth Floor, Boston, MA 02110-1301, USA.
dnl
dnl--------------------------------------------------------------------------------

# CS_AC_TEST_CATALYST
#--------------------
# modifies or sets cs_have_catalyst, CATALYST_CPPFLAGS, CATALYST_LDFLAGS, and CATALYST_LIBS
# depending on libraries found

AC_DEFUN([CS_AC_TEST_CATALYST], [

cs_have_catalyst=no

# Configure options
#------------------

AC_ARG_WITH(catalyst,
            [AS_HELP_STRING([--with-catalyst=PATH],
                            [specify prefix directory for CATALYST])],
            [if test "x$withval" = "x"; then
               with_catalyst=no
             fi],
            [with_catalyst=no])

# Check for CMake first
#----------------------

if test "x$with_catalyst" != "xno" ; then

  saved_CPPFLAGS="$CPPFLAGS"
  saved_LDFLAGS="$LDFLAGS"
  saved_LIBS="$LIBS"

  CATALYST_LIBS=""

  CPPFLAGS="${CPPFLAGS} ${CATALYST_CPPFLAGS}"
  LDFLAGS="${CATALYST_LDFLAGS} ${LDFLAGS}"
  LIBS="${CATALYST_LIBS} ${LIBS}"

  # Test for CMake

  AC_ARG_VAR([CMAKE], [CMake cross platform make])

  if test "x$CMAKE" = "x" ; then
    AC_PATH_PROGS([CMAKE], [cmake])
  fi

  if test "$CMAKE" = : ; then
    AC_MSG_FAILURE([cannot find CMake, Catalyst plugin cannot be installed])
  fi

fi

if test "x$with_catalyst" != "xno" ; then

  # Check for a Catalyst library
  #-----------------------------

  cs_prv_dir=`pwd`
  cs_abs_srcdir=`cd $srcdir && pwd`

  mkdir catalyst_test && cd catalyst_test
  "$CMAKE" -DCMAKE_PREFIX_PATH="$with_catalyst" "$cs_abs_srcdir/build-aux/catalyst" >&5

  if test $? = 0 ; then

    CATALYST_CPPFLAGS=`grep CXX_DEFINES CMakeFiles/CoProcessingTest.dir/flags.make | sed -e 's/^@<:@^=@:>@*=@<:@\ @:>@*//'`
    CATALYST_INCLUDES=`grep CXX_INCLUDES CMakeFiles/CoProcessingTest.dir/flags.make | sed -e 's/^@<:@^=@:>@*=@<:@\ @:>@*//'`
    CATALYST_CPPFLAGS="${CATALYST_CPPFLAGS} ${CATALYST_INCLUDES}"
    CATALYST_CXXFLAGS=`grep CXX_FLAGS CMakeFiles/CoProcessingTest.dir/flags.make | sed -e 's/^@<:@^=@:>@*=@<:@\ @:>@*//'`
    cs_link_opts=`sed -e 's/^.*CoProcessingTest//' CMakeFiles/CoProcessingTest.dir/link.txt`
    for a in $cs_link_opts; do
      case "{$a}" in
      -l*) CATALYST_LIBS="${CATALYST_LIBS} ${a}"
           ;;
      *)   if test -f "$a" ; then
             CATALYST_LIBS="${CATALYST_LIBS} -Wl,${a}"
           else
             CATALYST_LDFLAGS="${CATALYST_LDFLAGS} ${a}"
           fi
           ;;
      esac
    done
    unset cs_link_opts

    cs_have_catalyst=yes;

  fi

  cd "$cs_prv_dir"
  rm -rf "$cs_prv_dir"/catalyst_test
  rm -rf "$cs_prv_dir"/CMakeFiles
  rm -rf "$cs_prv_dir"/CMakeCache.txt

  # Report Catalyst support
  #------------------------

  if test "x$cs_have_catalyst" = "xyes" ; then
    AC_DEFINE([HAVE_CATALYST], 1, [Catalyst co-processing support])
  elif test "x$cs_have_catalyst" = "xno" ; then
    if test "x$with_catalyst" != "xcheck" ; then
      AC_MSG_FAILURE([Catalyst co-processing support requested, but test for Catalyst failed!])
    else
      AC_MSG_WARN([no Catalyst co-processing support])
    fi
  fi

  if test "x$cs_have_catalyst" = "xno"; then
    CATALYST_LIBS=""
  fi

  CPPFLAGS="$saved_CPPFLAGS"
  LDFLAGS="$saved_LDFLAGS"
  LIBS="$saved_LIBS"

  unset saved_CPPFLAGS
  unset saved_LDFLAGS
  unset saved_LIBS

fi

AM_CONDITIONAL(HAVE_CATALYST, test x$cs_have_catalyst = xyes)
AM_CONDITIONAL(LINK_CATALYST, test x$cs_link_catalyst = xyes)

AC_SUBST(cs_have_catalyst)
AC_SUBST(CATALYST_CPPFLAGS)
AC_SUBST(CATALYST_CXXFLAGS)
AC_SUBST(CATALYST_LDFLAGS)
AC_SUBST(CATALYST_LIBS)
AC_SUBST(CATALYSTRUNPATH)

])dnl
