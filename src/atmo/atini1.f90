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

subroutine atini1
!================


!===============================================================================
!  FONCTION  :
!  ---------

!   INIT DES OPTIONS DES VARIABLES POUR LA VERSION ATMOSPHERIQUE
!      EN COMPLEMENT DE CE QUI A DEJA ETE FAIT DANS USIPSU

!-------------------------------------------------------------------------------
! Arguments
!__________________.____._____.________________________________________________.
! name             !type!mode ! role                                           !
!__________________!____!_____!________________________________________________!
!__________________!____!_____!________________________________________________!

!     Type: i (integer), r (real), s (string), a (array), l (logical),
!           and composite types (ex: ra real array)
!     mode: <-- input, --> output, <-> modifies data, --- work array
!===============================================================================

!===============================================================================
! Module files
!===============================================================================

use paramx
use dimens
use ihmpre
use numvar
use optcal
use cstphy
use entsor
use cstnum
use ppppar
use ppthch
use ppincl
use atincl
use atsoil
use atchem
use atimbr
use siream
use field

!===============================================================================

implicit none

! Local variables

integer          ii, isc, jj

!===============================================================================

!===============================================================================
! 0. VERIFICATIONS
!===============================================================================

if (ippmod(iatmos).ge.2) then
  if (itytur.ne.2) then
    write(nfecra, 1002)
    call csexit(1)
  endif
endif

if (ippmod(iatmos).le.1) then
  if (iatra1.eq.1.or.iatsoil.eq.1) then
    write(nfecra, 1003)
    call csexit(1)
  endif
endif

!===============================================================================
! 1. INFORMATIONS GENERALES
!===============================================================================

!--> constants used in the atmospheric physics module
!    (see definition in atincl.h):

ps = 1.0d5
rvsra = 1.608d0
cpvcpa = 1.866d0
clatev = 2.501d6
gammat = -6.5d-03
rvap = rvsra*rair

! ---> Masse volumique et viscosite
irovar = 0
ivivar = 0

!===============================================================================
! 2. VARIABLES TRANSPORTEES pour IPPMOD(IATMOS) = 1 or 2
!===============================================================================

! 2.1  Dry atmosphere
! ===================

if (ippmod(iatmos).eq.1) then

  ! for the dry atmosphere case, non constant density
  irovar = 1

  ! Donnees physiques ou numeriques propres aux scalaires

  do isc = 1, nscapp

    jj = iscapp(isc)

    if (iscavr(jj).le.0) then
      visls0(jj) = viscl0
    endif

    blencv(isca(jj)) = 1.d0

  enddo

endif

! 2.2  Humid atmosphere
! =====================

if (ippmod(iatmos).eq.2) then

  ! for the humid atmosphere case, non constant density
  irovar = 1

  ! Donnees physiques ou numeriques propres aux scalaires

  do isc = 1, nscapp

    jj = iscapp(isc)

    if (iscavr(jj).le.0) then
      visls0(jj) = viscl0
    endif

    blencv(isca(jj)) = 1.d0

  enddo

endif

!===============================================================================
! 5. Turbulent Schmidt and Prandtl number for atmospheric flows
!===============================================================================

if (nscal.gt.0) then
  do ii = 1, nscal
    sigmas(ii) = 0.7d0
  enddo
endif

!===============================================================================
! 6. Force RIJ Matrix stabilisation for all atmospheric models
!===============================================================================

if (itytur.eq.3) irijnu = 1

!--------
! FORMATS
!--------

#if defined(_CS_LANG_FR)

 1002 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''ENTREE DES DONNEES               ',/,&
'@    =========                                               ',/,&
'@    PHYSIQUE PARTICULIERE (ATMOSPHERIQUE) DEMANDEE          ',/,&
'@                                                            ',/,&
'@  Seul le modele de turbulence k-eps est disponible avec    ',/,&
'@   le module atmosphere humide (ippmod(iatmos) = 2).        ',/,&
'@  Le calcul ne sera pas execute.                            ',/,&
'@                                                            ',/,&
'@  Verifier usipsu (cs_user_parameters.f90)                  ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 1003 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''ENTREE DES DONNEES               ',/,&
'@    =========                                               ',/,&
'@    PHYSIQUE PARTICULIERE (ATMOSPHERIQUE) DEMANDEE          ',/,&
'@                                                            ',/,&
'@  Les modeles de sol (iatsoil) et de rayonnement (iatra1)   ',/,&
'@   ne sont disponilbes qu''avec le module atmosphere        ',/,&
'@   humide (ippomod(iatmos) = 2).                            ',/,&
'@  Le calcul ne sera pas execute.                            ',/,&
'@                                                            ',/,&
'@  Verifier usipsu (cs_user_parameters.f90)                  ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

#else

 1000 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@  WARNING:   STOP WHILE READING INPUT DATA               ',/,&
'@    =========                                               ',/,&
'@                ATMOSPHERIC  MODULE                         ',/,&
'@                                                            ',/,&
'@  ISCALT IS SPECIFIED AUTOMATICALLY.                        ',/,&
'@  iscalt should not be specified in usipsu, here:           ',/,&
'@       ISCALT  = ', I10                                      ,/,&
'@  Computation CAN NOT run.                                  ',/,&
'@                                                            ',/,&
'@  Check the input data given through the User Interface     ',/,&
'@   or in cs_user_parameters.f90.                            ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 1001 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@  WARNING:   STOP WHILE READING INPUT DATA               ',/,&
'@    =========                                               ',/,&
'@                ATMOSPHERIC  MODULE                         ',/,&
'@                                                            ',/,&
'@  ISCACP IS SPECIFIED AUTOMATICALLY.                        ',/,&
'@  For the scalar ', I10 ,' iscacp  should not be specified  ',/,&
'@   in usipsu, here:                                         ',/,&
'@          ISCACP(',I10   ,') = ',I10                         ,/,&
'@  Computation CAN NOT run.                                  ',/,&
'@                                                            ',/,&
'@  Check the input data given through the User Interface     ',/,&
'@   or in cs_user_parameters.f90.                            ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 1002 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@  WARNING:   STOP WHILE READING INPUT DATA               ',/,&
'@    =========                                               ',/,&
'@                ATMOSPHERIC  MODULE                         ',/,&
'@                                                            ',/,&
'@  Only k-eps turbulence model is available with humid       ',/,&
'@   atmosphere module (ippmod(iatmos) = 2).                  ',/,&
'@  Computation CAN NOT run.                                  ',/,&
'@                                                            ',/,&
'@  Check the input data given through the User Interface     ',/,&
'@   or in cs_user_parameters.f90.                            ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 1003 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@  WARNING:   STOP WHILE READING INPUT DATA               ',/,&
'@    =========                                               ',/,&
'@                ATMOSPHERIC  MODULE                         ',/,&
'@                                                            ',/,&
'@  Ground model (iatsoil) and radiative model (iatra1)       ',/,&
'@   are only available with humid atmosphere module          ',/,&
'@   (ippmod(iatmos) = 2).                                    ',/,&
'@  Computation CAN NOT run.                                  ',/,&
'@                                                            ',/,&
'@  Check the input data given through the User Interface     ',/,&
'@   or in cs_user_parameters.f90.                            ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

#endif

!----
! End
!----

return
end subroutine atini1
