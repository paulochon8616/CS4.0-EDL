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

subroutine cs_coal_radst &
!=======================
  ( ivar   , ncelet , ncel   ,        &
    volume , propce , smbrs  , rovsdt )
!===============================================================================
!  FONCTION  :
!  ---------

! ROUTINE PHYSIQUE PARTICULIERE : FLAMME CHARBON PULVERISE
!   PRISE EN COMPTE DES TERMES SOURCES RADIATIFS
!   IMPLICITE ET EXPLICITE DANS L'EQUATION DES PARTICULES
!   DE LA CLASSE ICLA

!-------------------------------------------------------------------------------
! Arguments
!__________________.____._____.________________________________________________.
! name             !type!mode ! role                                           !
!__________________!____!_____!________________________________________________!
! ivar             ! e  ! <-- ! numero de la variable scalaire                 !
!                  !    !     !   energie (enthalpie h2) pour le               !
!                  !    !     !   charbon                                      !
! ncelet           ! i  ! <-- ! number of extended (real + ghost) cells        !
! ncel             ! i  ! <-- ! number of cells                                !
! volume(ncelet    ! tr ! <-- ! volume des cellules                            !
! propce(ncelet, *)! ra ! <-- ! physical properties at cell centers            !
! smbrs(ncelet     ! tr ! <-- ! second membre du systeme                       !
! rovsdt(ncelet    ! tr ! <-- ! diagonale du systeme                           !
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
use cstnum
use cstphy
use entsor
use numvar
use ppppar
use ppthch
use ppincl
use radiat
use cs_coal_incl
use field

!===============================================================================

implicit none

! Arguments

integer          ivar , ncelet, ncel

double precision volume(ncelet)
double precision smbrs(ncelet)
double precision rovsdt(ncelet)
double precision propce(ncelet,*)

! Local variables

integer          iel , numcla , ipcl
integer          keyccl

!===============================================================================
! 1. Initialization
!===============================================================================

! Key id of the coal scalar class
call field_get_key_id("scalar_class", keyccl)

! index of the coal particle class
call field_get_key_int(ivarfl(ivar), keyccl, numcla)
ipcl   = 1+numcla

!===============================================================================
! 2. PRISE EN COMPTE DES TERMES SOURCES RADIATIFS
!===============================================================================


do iel = 1, ncel
  propce(iel,ipproc(itsri(ipcl))) = max(-propce(iel,ipproc(itsri(ipcl))),zero)
enddo

do iel = 1, ncel
  if ( propce(iel,ipproc(ix2(numcla))) .gt. epzero ) then

!--> PARTIE EXPLICITE

    smbrs(iel)  = smbrs(iel) +  propce(iel,ipproc(itsre(ipcl)))*volume(iel) &
                               *propce(iel,ipproc(ix2(numcla)))

!--> PARTIE IMPLICITE

    rovsdt(iel) = rovsdt(iel) + propce(iel,ipproc(itsri(ipcl)))*volume(iel)
  endif

enddo

!--------
! Formats
!--------

!----
! End
!----

return
end subroutine
