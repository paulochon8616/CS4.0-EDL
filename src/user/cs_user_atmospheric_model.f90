!-------------------------------------------------------------------------------

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

subroutine usatdv &
     ( imode )

!===============================================================================
!  Purpose:
!  -------
!            Atmospheric module subroutine
!
!             User definition of the vertical 1D arrays
!             User initialization of corresponding 1D ground model
!-------------------------------------------------------------------------------
! Arguments
!__________________.____._____.________________________________________________.
! name             !type!mode ! role                                           !
!__________________!____!_____!________________________________________________!
!__________________!____!_____!________________________________________________!

!     TYPE : E (ENTIER), R (REEL), A (ALPHANUMERIQUE), T (TABLEAU)
!            L (LOGIQUE)   .. ET TYPES COMPOSES (EX : TR TABLEAU REEL)
!     MODE : <-- donnee, --> resultat, <-> Donnee modifiee
!            --- tableau de travail
!===============================================================================

!===============================================================================
! Module files
!===============================================================================

use paramx
use numvar
use optcal
use cstphy
use cstnum
use entsor
use parall
use period
use ppppar
use ppthch
use ppincl
use atincl
use atsoil
use mesh

implicit none

!===============================================================================

! Arguments

integer           imode

!===============================================================================
! Local variables

integer           ii,iiv
double precision :: zzmax,ztop
double precision, save :: zvmax

!==============================================================================

!===============================================================================
! TEST_TO_REMOVE_FOR_USE_OF_SUBROUTINE_START
!===============================================================================

if(1.eq.1) return

!===============================================================================
! TEST_TO_REMOVE_FOR_USE_OF_SUBROUTINE_END
!===============================================================================

if (imode.eq.0) then
  write(nfecra,*) 'defining the dimensions of the 1D vertical arrays'
else
  write(nfecra,*) 'defining the coordinates and levels of the 1D vertical arrays'
endif


! 1. Defining the max vertical level:
!====================================
! For the first call (imode = 0) the user should fill the maximum height of the
! 1D model (zvmax), the numbert of 1D verticals and the number of levels
! If the 1D radiative model, the profiles will be extended to 11000m (troposhere)

if (imode.eq.0) then

  nvert = 1
  kvert = 50
  kmx = kvert
  zvmax = 1975.d0 ! for Wangara

  ! If 1D radiative model: complete the vertical array up to 11000
  if (iatra1.gt.0) then
    ztop = 11000.d0
    zzmax = (int(zvmax)/1000)*1000.d0

    do while(zzmax.le.(ztop-1000.d0))
      zzmax = zzmax + 1000.d0
      kmx = kmx + 1
    enddo
  endif

else

  ! 2. Defining the  coordinates and levels of the vertical arrays:
  !===============================================================
  ! for the second call (after allocating the arrays)
  ! the user should fill the arrays

  ! Vertical levels:

  zvert(1) = 0.d0
  zvert(2)  = 5.d0
  zvert(3)  = 20.5d0
  zvert(4)  = 42.0d0
  zvert(5)  = 65.0d0
  zvert(6)  = 89.5d0
  zvert(7)  = 115.0d0
  zvert(8)  = 142.0d0
  zvert(9)  = 170.5d0
  zvert(10) = 199.5d0
  zvert(11) = 230.0d0
  zvert(12) = 262.0d0
  zvert(13) = 294.5d0
  zvert(14) = 328.5d0
  zvert(15) = 363.5d0
  zvert(16) = 399.0d0
  zvert(17) = 435.5d0
  zvert(18) = 473.5d0
  zvert(19) = 512.0d0
  zvert(20) = 551.0d0
  zvert(21) = 591.5d0
  zvert(22) = 632.5d0
  zvert(23) = 674.0d0
  zvert(24) = 716.0d0
  zvert(25) = 759.0d0
  zvert(26) = 802.5d0
  zvert(27) = 846.5d0
  zvert(28) = 891.5d0
  zvert(29) = 936.5d0
  zvert(30) = 982.0d0
  zvert(31) = 1028.0d0
  zvert(32) = 1074.5d0
  zvert(33) = 1122.0d0
  zvert(34) = 1169.5d0
  zvert(35) = 1217.0d0
  zvert(36) = 1265.5d0
  zvert(37) = 1314.5d0
  zvert(38) = 1363.5d0
  zvert(39) = 1413.0d0
  zvert(40) = 1462.5d0
  zvert(41) = 1512.5d0
  zvert(42) = 1563.0d0
  zvert(43) = 1613.5d0
  zvert(44) = 1664.5d0
  zvert(45) = 1715.5d0
  zvert(46) = 1767.0d0
  zvert(47) = 1818.5d0
  zvert(48) = 1870.0d0
  zvert(49) = 1922.5d0
  zvert(50) = 1975.0d0

  ! If 1D radiative model: complete the vertical array up to 11000 m
  if (iatra1.gt.0) then
    ztop = 11000.d0
    ii = kvert
    zzmax = (int(zvert(ii))/1000)*1000.d0

    do while(zzmax.le.(ztop-1000.d0))
      zzmax = zzmax+1000.d0
      ii = ii + 1
      zvert(ii) = zzmax
    enddo

  endif

  ! 3 - Initializing the position of each vertical
  !==============================================

  do iiv = 1, nvert

    ! xy coordinates of vertical iiv:
    xyvert(iiv,1) = 50.d0  !x coordinate
    xyvert(iiv,2) = 50.d0  !y coordinate
    xyvert(iiv,3) = 1.d0   !kmin (in case of relief)

    ! 4 - Initializing the soil table of each vertical grid
    !=====================================================

    soilvert(iiv)%albedo  = 0.25d0
    soilvert(iiv)%emissi  = 0.965d0
    soilvert(iiv)%ttsoil  = 14.77d0
    soilvert(iiv)%totwat  = 0.0043d0
    soilvert(iiv)%pressure = 1023.d0
    soilvert(iiv)%density = 1.23d0
    soilvert(iiv)%foir = 0.d0
    soilvert(iiv)%fos  = 0.d0

  enddo
endif

return
end subroutine usatdv


!===============================================================================


subroutine usatsoil &
     !==================
     ( iappel )

!===============================================================================
! Purpose:
! -------

!     User subroutine.

!     Data Entry for the atmospheric ground model.


! Introduction:
!=============

! Define the different values which can be taken by iappel:
!--------------------------------------------------------

! iappel = 1 (only one call on initialization):
!            Computation of the cells number where we impose a
!            Ground Model

! iappel = 2 (only one call on initialization):
!            users may defined the ground face composition
!            Warning : be coherent with the dimension of the array pourcent_sol
!            It's also possible to modified the tab_sol array of the ground
!            type constants
!
!===============================================================================
! Module files
!===============================================================================

use paramx
use numvar
use optcal
use cstphy
use cstnum
use entsor
use parall
use period
use ppppar
use ppthch
use ppincl
use atincl
use atsoil
use mesh

!===============================================================================

implicit none

! Arguments
!-------------------------------------------------------------------
integer          iappel

! Local variables
!-------------------------------------------------------------------
integer          ifac , ifbt1d , ilelt , nlelt , isol

integer, allocatable, dimension(:) :: lstelt

!===============================================================================

!===============================================================================
! TEST_TO_REMOVE_FOR_USE_OF_SUBROUTINE_START
!===============================================================================

if(1.eq.1) return

!===============================================================================
! TEST_TO_REMOVE_FOR_USE_OF_SUBROUTINE_END
!===============================================================================

ifbt1d = 0
allocate(lstelt(nfabor))

!===============================================================================
! APPEL 1.  INITIALIZATIONS
!===============================================================================

if (iappel.eq.1) then
  ! On precise la couleur du sol
  call getfbr('75',nlelt,lstelt)
  do ilelt = 1, nlelt
    ifbt1d = ifbt1d + 1
  enddo
  nfmodsol = ifbt1d

  allocate(indsol(nfmodsol))

  do ilelt = 1, nlelt
    ifac = lstelt(ilelt)
    indsol(ilelt) = ifac
  enddo
  ! On precise le nombre sol utilise pour le modele
  ! 5 dans le cas bati, 7 dans le cas bati dense/mixte/diffus
  nbrsol = 5
  ! On renseigne la teneur en eau des deux reservoirs
  ! (necessaire pour l'initialisation)
  w1ini = 0.d0
  w2ini = 0.0d0
endif


if (iappel.eq.2) then
  ! Modification pour cas Wangara, dans ce cas la on a Csol(mineral=4) = 1.7e-5
  ! ainsi que zoth = 1.2e-3
  tab_sol(4)%csol = 1.7e-5
  tab_sol(4)%rugthe = 0.0012

  ! Initialization of the pourcent_sol array
  do ifac = 1, nfmodsol
    do isol = 1, nbrsol
      pourcent_sol(ifac,isol) = 0
    enddo
    pourcent_sol(ifac,4) = 100
  enddo
endif

!===============================================================================

deallocate(lstelt)  ! temporary array for boundary faces selection

return
end subroutine usatsoil

