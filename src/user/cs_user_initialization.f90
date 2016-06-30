!-------------------------------------------------------------------------------

!VERS

! This file is part of Code_Saturne, a general-purpose CFD tool.
!
! Copyright (C) 1998-2016 EDF S.A.
!
! This program is free software; you can redistribute it and/or modify it under
! the terms of the GNU General Public License as published by the Free Software
! Foundation; either version 2 of the License, or (at your option) any later
! version.
!
! This program is distributed in the hope that it will be useful, but WITHOUT
! ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
! FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
! details.
!
! You should have received a copy of the GNU General Public License along with
! this program; if not, write to the Free Software Foundation, Inc., 51 Franklin
! Street, Fifth Floor, Boston, MA 02110-1301, USA.

!-------------------------------------------------------------------------------

!===============================================================================
! Purpose:
! -------

!> \file cs_user_initialization.f90
!>
!> \brief Initialize variables
!>
!> This subroutine is called at beginning of the computation
!> (restart or not) before the loop time step.
!>
!> This subroutine enables to initialize or modify (for restart)
!> unkown variables and time step values.
!>
!> \c rom and \c viscl values are equal to \c ro0 and \c viscl0 or initialize
!> by reading the restart file.
!> variable diffusivity and cp variables (when there are defined) have no value
!> excepted if they are read from a restart file.
!>
!> Modification of the behaviour law of physical quantities (rom, viscl,
!> viscls, cp) is not done here. It is the purpose of the user subroutine
!> \ref usphyv (in cs_user_physical_properties.f90)
!>
!> \section cs_user_initialization_cell_id Cells identification
!>
!> Cell value field ids
!>
!> - Density:                        \c iprpfl(irom)
!> - Dynamic molecular viscosity:    \c iprpfl(iviscl)
!> - Turbulent viscosity:            \c iprpfl(ivisct)
!> - Specific heat:                  \c iprpfl(icp)
!> - Diffusivity(lambda):            \c field_get_key_int(ivarfl(isca(iscal)),
!>                                      kivisl, ...)
!>
!> Cells may be identified using the \ref getcel subroutine.
!> The syntax of this subroutine is described in the
!> \ref cs_user_boundary_conditions subroutine,
!> but a more thorough description can be found in the user guide.
!
!-------------------------------------------------------------------------------

!-------------------------------------------------------------------------------
! Arguments
!______________________________________________________________________________.
!  mode           name          role                                           !
!______________________________________________________________________________!
!> \param[in]     nvar          total number of variables
!> \param[in]     nscal         total number of scalars
!> \param[in]     dt            time step (per cell)
!_______________________________________________________________________________

subroutine cs_user_initialization &
 ( nvar   , nscal  ,                                              &
   dt     )

!===============================================================================

!===============================================================================
! Module files
!===============================================================================

use paramx
use pointe
use numvar
use optcal
use cstphy
use cstnum
use entsor
use parall
use period
use ppppar
use ppthch
use coincl
use cpincl
use ppincl
use atincl
use ctincl
use elincl
use ppcpfu
use cs_coal_incl
use cs_fuel_incl
use mesh
use field
use turbomachinery

!===============================================================================

implicit none

! Arguments

integer          nvar   , nscal

double precision dt(ncelet)

! Local variables

! INSERT_VARIABLE_DEFINITIONS_HERE

integer, allocatable, dimension(:) :: lstelt

!===============================================================================

! TEST_TO_REMOVE_FOR_USE_OF_SUBROUTINE_START

if (1.eq.1) then
!       Tag to know if a call to this subroutine has already been done
  iusini = 0
  return
endif

! TEST_TO_REMOVE_FOR_USE_OF_SUBROUTINE_END

!===============================================================================
! Initialization
!===============================================================================

allocate(lstelt(ncel)) ! temporary array for cells selection

! INSERT_MAIN_CODE_HERE

!--------
! Formats
!--------

!----
! End
!----

deallocate(lstelt) ! temporary array for cells selection

return
end subroutine cs_user_initialization
