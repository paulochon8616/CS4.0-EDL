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

subroutine lagphy &
!================

 ( ntersl , nvlsta , nvisbr ,                                     &
   iprev  , dt     , propce ,                                     &
   taup   , tlag   , tempct ,                                     &
   cpgd1  , cpgd2  , cpght  )

!===============================================================================
! FONCTION :
! ----------

!   SOUS-PROGRAMME DU MODULE LAGRANGIEN :
!   -------------------------------------

!     INTEGRATION DES EDS CONCERNANT LES PHYSIQUES PARTICULIERES
!       LIEES AUX PARTICULES :

!         - Temperature du fluide vu par les particules,
!         - Temperature des particules,
!         - Diametre des particules
!         - Masse des particules
!         - Variables liees aux grains de charbon (Temp,MCH,MCK),
!         - Variables Utilisateur supplementaires.

!-------------------------------------------------------------------------------
! Arguments
!__________________.____._____.________________________________________________.
! name             !type!mode ! role                                           !
!__________________!____!_____!________________________________________________!
! ntersl           ! e  ! <-- ! nbr termes sources de couplage retour          !
! nvlsta           ! e  ! <-- ! nombre de var statistiques lagrangien          !
! nvisbr           ! e  ! <-- ! nombre de statistiques aux frontieres          !
! iprev            ! e  ! <-- ! time step indicator for fields                 !
!                  !    !     !   0: use fields at current time step           !
!                  !    !     !   1: use fields at previous time step          !
! dt(ncelet)       ! ra ! <-- ! time step (per cell)                           !
! propce(ncelet, *)! ra ! <-- ! physical properties at cell centers            !
! taup(nbpart)     ! tr ! <-- ! temps caracteristique dynamique                !
! tlag(nbpart)     ! tr ! <-- ! temps caracteristique fluide                   !
! tempct           ! tr ! <-- ! temps caracteristique thermique                !
!  (nbpart,2)      !    !     !                                                !
! cpgd1,cpgd2,     ! tr ! --> ! termes de devolatilisation 1 et 2 et           !
!  cpght(nbpart)   !    !     !   de combusion heterogene (charbon             !
!                  !    !     !   avec couplage retour thermique)              !
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
use cstphy
use cstnum
use optcal
use entsor
use lagpar
use lagran
use mesh

!===============================================================================

implicit none

! Arguments

integer          ntersl , nvlsta , nvisbr
integer          iprev

double precision dt(ncelet)
double precision propce(ncelet,*)
double precision taup(nbpart) , tlag(nbpart,3) , tempct(nbpart,2)
double precision cpgd1(nbpart) , cpgd2(nbpart) , cpght(nbpart)

! Local variables

!===============================================================================

!===============================================================================
! 1.  INITIALISATIONS
!===============================================================================


!===============================================================================
! 2. INTEGRATION DE LA TEMPERATURE FLUIDE VU PAR LES PARTICULES
!===============================================================================

if ( iphyla.eq.2 .or. (iphyla.eq.1 .and. itpvar.eq.1) ) then

  call lagitf                                                     &
  !==========
  ( iprev, propce )

endif

!===============================================================================
! 3. INTEGRATION DE LA TEMPERATURE DES PARTICULES
!===============================================================================

if ( iphyla.eq.1 .and. itpvar.eq.1 ) then

  call lagitp                                                     &
  !==========
  ( propce , tempct )

endif

!===============================================================================
! 4. INTEGRATION DU DIAMETRE DES PARTICULES
!===============================================================================

if ( iphyla.eq.1 .and. idpvar.eq.1 ) then

  call lagidp
  !==========

endif

!===============================================================================
! 5. INTEGRATION DE LA MASSE DES PARTICULES
!===============================================================================

if (iphyla.eq.1 .and. impvar.eq.1) then

  call lagimp
  !==========

endif

!===============================================================================
! 6. INTEGRATION DES EQUATIONS DU CHARBON : HP, MCH, MCK
!===============================================================================

if (iphyla.eq.2) then

  call lagich                                                     &
  !==========
  ( propce , tempct , cpgd1  , cpgd2  , cpght  )

endif

!===============================================================================
! 7. INTEGRATION DES VARIABLES UTILISATEURS SUPPLEMENTAIRES
!===============================================================================

if (nvls.ge.1) then

  call uslaed                                                     &
  !==========
    ( ntersl , nvlsta , nvisbr ,                                  &
      dt     ,                                                    &
      taup   , tlag   , tempct )

endif

!===============================================================================

!----
! FIN
!----

end subroutine
