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

subroutine cou1di &
!================

 ( nfabor ,                                                       &
   isvtb  , icodcl ,                                              &
   rcodcl )

!===============================================================================

! FONCTION :
! ---------

! LECTURE DE DONNEES RELATIVES A UN COUPLAGE AVEC SYRTHES

!-------------------------------------------------------------------------------
!ARGU                             ARGUMENTS
!__________________.____._____.________________________________________________.
! name             !type!mode ! role                                           !
!__________________!____!_____!________________________________________________!
! nfabor           ! i  ! <-- ! number of boundary faces                       !
! isvtb            ! e  ! <-- ! numero du scalaire couple                      !
! icodcl           ! te ! --> ! code de condition limites aux faces            !
!  (nfabor,nvarcl) !    !     !  de bord                                       !
!                  !    !     ! = 1   -> dirichlet                             !
!                  !    !     ! = 3   -> densite de flux                       !
!                  !    !     ! = 4   -> glissemt et u.n=0 (vitesse)           !
!                  !    !     ! = 5   -> frottemt et u.n=0 (vitesse)           !
!                  !    !     ! = 6   -> rugosite et u.n=0 (vitesse)           !
!                  !    !     ! = 9   -> entree/sortie libre (vitesse          !
!                  !    !     !  entrante eventuelle     bloquee               !
! rcodcl           ! tr ! --> ! valeur des conditions aux limites              !
!  (nfabor,nvarcl) !    !     !  aux faces de bord                             !
!                  !    !     ! rcodcl(1) = valeur du dirichlet                !
!                  !    !     ! rcodcl(2) = valeur du coef. d'echange          !
!                  !    !     !  ext. (infinie si pas d'echange)               !
!                  !    !     ! rcodcl(3) = valeur de la densite de            !
!                  !    !     !  flux (negatif si gain) w/m2 ou                !
!                  !    !     !  hauteur de rugosite (m) si icodcl=6           !
!                  !    !     ! pour les vitesses (vistl+visct)*gradu          !
!                  !    !     ! pour la pression             dt*gradp          !
!                  !    !     ! pour les scalaires                             !
!                  !    !     !        cp*(viscls+visct/sigmas)*gradt          !
!__________________!____!_____!________________________________________________!

!     Type: i (integer), r (real), s (string), a (array), l (logical),
!           and composite types (ex: ra real array)
!     mode: <-- input, --> output, <-> modifies data, --- work array
!===============================================================================

!===============================================================================
! Module files
!===============================================================================

use paramx
use numvar
use optcal
use cstnum
use cstphy
use entsor
use pointe

!===============================================================================

implicit none

! Arguments

integer          nfabor
integer          isvtb  , icodcl(nfabor,nvarcl)
double precision rcodcl(nfabor,nvarcl,3)

! Local variables


integer          ii , ivar
integer          ifac
integer          icldef
integer          mode
double precision temper, enthal

!===============================================================================


! Sans specification, une face couplee est une face de type paroi

icldef = 5

ivar = isca(isvtb)

do ii = 1, nfpt1d

   ifac = ifpt1d(ii)

   if ((icodcl(ifac,ivar) .ne. 1) .and.                           &
       (icodcl(ifac,ivar) .ne. 5) .and.                           &
       (icodcl(ifac,ivar) .ne. 6)) icodcl(ifac,ivar) = icldef

   rcodcl(ifac,ivar,1) = tppt1d(ii)
   rcodcl(ifac,ivar,2) = rinfin
   rcodcl(ifac,ivar,3) = 0.d0

enddo

! Conversion eventuelle temperature -> enthalpie

if (isvtb.eq.iscalt .and. itherm.eq.2) then

  do ii = 1, nfpt1d

    ifac = ifpt1d(ii)

    temper = rcodcl(ifac,ivar,1)
    mode   = -1
    call usthht(mode,enthal,temper)
    !==========
    rcodcl(ifac,ivar,1) = enthal

  enddo

endif

end subroutine


