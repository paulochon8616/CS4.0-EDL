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

subroutine lagrus &
!================

 ( ncelet , ncel   ,                                              &
   croule )

!===============================================================================
! FONCTION :
! ----------

!       SOUS-PROGRAMME DU MODULE LAGRANGIEN :
!       -----------------------------------

!     Roulette russe et clonage applique aux particules
!     suivant un critere d'importance (CROULE)

!-------------------------------------------------------------------------------
! Arguments
!__________________.____._____.________________________________________________.
! name             !type!mode ! role                                           !
!__________________!____!_____!________________________________________________!
! ncelet           ! i  ! <-- ! number of extended (real + ghost) cells        !
! ncel             ! i  ! <-- ! number of cells                                !
! ntersl           ! e  ! <-- ! nbr termes sources de couplage retour          !
! nvlsta           ! e  ! <-- ! nombre de var statistiques lagrangien          !
! croule(ncelet)   ! tr ! <-- ! critere d'importance                           !
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
use cstnum
use optcal
use entsor
use lagpar
use lagran

!===============================================================================

implicit none

! Arguments

integer          ncelet , ncel

double precision croule(ncelet)

! Local variables

integer          iel    , ield    , nclo
integer          npt    , n       , n1      , nc
double precision aux(1) , coeff  , pnew

!===============================================================================

!===============================================================================
! 0. Initialisation
!===============================================================================

!     NPCLON : NOMBRE DE NOUVELLES PARTICULES PAR CLONNAGE

!     NPKILL : NOMBRE DE PARTICULES VICTIMES DE LA ROULETTE RUSSE

!     NPCSUP : NOMBRE DE PARTICULES QUI ON SUBIT LE CLONNAGE

npclon = 0
npcsup = 0
npkill = 0

dnpclo = 0.d0
dnpcsu = 0.d0
dnpkil = 0.d0

!===============================================================================
! 1. Clonage / Fusion (ou "Roulette Russe")
!===============================================================================


! Boucle sur les particules

do npt = 1,nbpart

  if (ipepa(jisor,npt).ne.ipepa(jisora,npt)) then

    iel  = ipepa(jisor,npt)
    ield = ipepa(jisora,npt)

! Rapport des fonction d'importance entre la cellule de depart
! et celle d'arrivee

    coeff = croule(iel) / croule(ield)

    if (coeff.lt.1.d0) then

!---------------
! ROULETTE RUSSE
!---------------

      n1 = 1
      call zufall(n1,aux(1))

      if (aux(1).lt.coeff) then

! La particule survit avec une probabilite COEFF

        pepa(jrpoi,npt) = pepa(jrpoi,npt)/coeff

      else

! La particule est supprimee avec une probabilite (1-COEFF)

        ipepa(jisor,npt) = 0
        npkill = npkill + 1
        dnpkil = dnpkil + pepa(jrpoi,npt)
      endif

    else if (coeff.gt.1.d0) then

!--------
! CLONAGE
!--------

      n = int(coeff)
      n1 = 1
      call zufall(n1,aux(1))

      if (aux(1).lt.(coeff-dble(n))) then

! Clonage en N+1 particules

        nclo = n + 1

      else

! Clonage en N particules

        nclo = n

      endif

      if (lagr_resize_particle_set(nbpart+npclon+nclo+1) .lt. 0) then
        write(nfecra,5000)
        goto 1000
      endif

      npcsup = npcsup + 1
      dnpcsu = dnpcsu + pepa(jrpoi,npt)
      pnew = pepa(jrpoi,npt) / dble(nclo)

      do nc = 1,nclo

        npclon = npclon + 1
        dnpclo = dnpclo + pnew

        call lagr_part_copy(nbpart+npclon, npt)

        pepa(jrpoi,nbpart+npclon) = pnew

      enddo

! Modif de la particule elle meme

      ipepa(jisor,npt) = 0

    endif
  endif
enddo

 1000 continue

! Actualisation du nouveau nombre de particules

nbpart = nbpart + npclon
dnbpar = dnbpar + dnpclo

!===============================================================================
! 2. On elimine les particules qui ont perdu � la Roulette Russe
!    et celles qui ont subit le clonage.
!===============================================================================

! FIXME : rewrite former lageli function

!!$call lageli(npars, dnpars)

! if ( npars.ne.(npkill+npcsup) ) then
!   write(nfecra,9000)
!   call csexit(1)
!   !==========
! endif

!-------
! FORMAT
!-------

 5000 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : MODULE LAGRANGIEN                           ',/,&
'@    =========                                               ',/,&
'@                CLONAGE / FUSION DES PARTICULES             ',/,&
'@                                                            ',/,&
'@  Le nombre global de nouvelles particules clonees          ',/,&
'@    conduit � un nombre global de particules superieur au   ',/,&
'@    maximum defini via cs_lagr_set_n_g_particles_max.       ',/,&
'@                                                            ',/,&
'@  On ne clone plus de particules pour cette iteration.      ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

!----
! FIN
!----

end subroutine
