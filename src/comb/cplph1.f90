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

subroutine cplph1 &
!================

 ( ncelet , ncel   ,                                              &
   nitbcp , nrtbcp , nitbmc , nrtbmc , nitbwo , nrtbwo ,          &
   f1m    , f2m    , f3m    , f4m    , f3p2m  , f4p2m  ,          &
   enth   ,                                                       &
   propce , rom1   )

!===============================================================================
! FONCTION :
! --------

!   SOUS-PROGRAMME DU MODULE LAGRANGIEN COUPLE CHARBON PULVERISE :
!   --------------------------------------------------------------

!    ROUTINE UTILISATEUR POUR PHYSIQUE PARTICULIERE

!      COMBUSTION EULERIENNE DE CHARBON PULVERISE ET
!      TRANSPORT LAGRANGIEN DES PARTICULES DE CHARBON

! CALCUL DES PROPRIETES PHYSIQUES DE LA PHASE GAZEUSE
!  VALEURS CELLULES
!  ----------------
!  TEMPERATURE, MASSE VOLUMIQUE ET CONCENTRATIONS MOYENNES
!  (UTILISATION D'UNE PDF RECTANGLE-DIRAC)


!     CLONE DE CPPHY1


! REACTIONS HETEROGENES
!   - Pyrolyse
!     Composition elementaire de la mole de matieres volatiles
!     Le charbon reactif s'ecrit C(1)H(ALPHA)O(BETA)

!       -(k1)-> ALPHA/4 CH4  + BETA CO + (1-ALPHA/4-BETA)    Coke
!     Charbon reactif
!       -(k2)-> ALPHA/Y CXHY + BETA CO + (1-ALPHA/RYSX-BETA) Coke

!       Avec RYSX = Y/X

!   - Combustion heterogene

!     Coke + 1/2 (O2 + XSI N2) -> CO + XSI/2 N2

!   - Reactions en phase gaz

! (4/(4-RYSX)) CH4 + (O2 + XSI N2)   -(1)->  4/X/(4-RYSX)*CXHY + 2 H2O
!                                           + XSI N2
! CXHY + X/4*(2+RYSX) (O2 + XSI N2)  -(2)->  X CO + Y/2 H2O
!                                           + X/4*(2+RYSX)*XSI N2
!           CO + 1/2 (O2 + XSI N2)  -(3)->  CO2 + XSI/2 N2

! CHOIX DES VARIABLES

!  F1 est la fractions massique des matieres volatiles : CH4  + CO
!  F2 est la fractions massique des matieres volatiles : CXHY + CO
!  F3 est la fraction massique de carbone venant de la combustion
!    heterogene

!  Soit Y les fractions massiques et Z les concentrations (moles/kg)
!    indice f avant reaction, b final

! PDF CONJOINTE DEGENERE EN UNE PDF 1D DE TYPE RECTANGLE - DIRAC

! Arguments
!__________________.____._____.________________________________________________.
! name             !type!mode ! role                                           !
!__________________!____!_____!________________________________________________!
! ncelet           ! i  ! <-- ! number of extended (real + ghost) cells        !
! ncel             ! i  ! <-- ! number of cells                                !
! nitbcp           ! e  ! <-- ! taille du macro tableau cp entiers             !
! nrtbcp           ! e  ! <-- ! taille du macro tableau cp reels               !
! nitbmc           ! e  ! <-- ! taille du macro tableau mc entiers             !
! nrtbmc           ! e  ! <-- ! taille du macro tableau mc reels               !
! nitbwo           ! e  ! <-- ! taille du macro tableau work entiers           !
! nrtbwo           ! e  ! <-- ! taille du macro tableau work reels             !
! pa               ! tr ! <-- ! pression absolue en pascals                    !
! f1m              ! tr ! <-- ! moyenne du traceur 1 mvl [chx1+co]             !
! f2m              ! tr ! <-- ! moyenne du traceur 2 mvl [chx2+co]             !
! f3m              ! tr ! <-- ! moyenne du traceur 3 (co c.het)                !
! f4m              ! tr ! <-- ! moyenne du traceur 4 (air)                     !
! f3p2m            ! tr ! <-- ! variance du traceur 3 (co c.het)               !
! f4p2m            ! tr ! <-- ! variance du traceur 4 (air)                    !
! enth             ! tr ! <-- ! enthalpie en j/kg  soit du gaz                 !
!                  !    !     !                    soit du melange             !
! propce(ncelet, *)! ra ! <-- ! physical properties at cell centers            !
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
use ppppar
use ppthch
use coincl
use cpincl
use ppincl

!===============================================================================

implicit none

! Arguments

integer          ncelet , ncel
integer          nitbcp , nrtbcp
integer          nitbmc , nrtbmc
integer          nitbwo , nrtbwo

double precision f1m(ncelet), f2m(ncelet)
double precision f3m(ncelet), f4m(ncelet)
double precision f3p2m(ncelet), f4p2m(ncelet)
double precision enth(ncelet), rom1(ncelet)

double precision propce(ncelet,*)

! Local variables

integer          iel    , ice
integer          iitbcp , iitbmc , iitbwo
integer          ipcte1
integer          ipcyf1 , ipcyf2 , ipcyf3 , ipcyox
integer          ipcyp1 , ipcyp2 , ipcyin , ipcyce

double precision wmolme , wmchx1 , wmchx2

integer, allocatable, dimension(:,:) :: itbcp, itbmc, itbwo

double precision, allocatable, dimension(:,:) :: rtbcp, rtbmc, rtbwo

!===============================================================================

!===============================================================================
! 1. INITIALISATIONS
!===============================================================================

! Allocate temporary arrays
allocate(itbcp(ncelet,nitbcp))
allocate(itbmc(ncelet,nitbmc))
allocate(itbwo(ncelet,nitbwo))

allocate(rtbcp(ncelet,nrtbcp))
allocate(rtbmc(ncelet,nrtbmc))
allocate(rtbwo(ncelet,nrtbwo))

! --- Initialisation memoire


! --- Initialisation des tableaux d'entiers de travail

do iel = 1, ncel
  do iitbcp = 1, nitbcp
    itbcp(iel,iitbcp) = 0
  enddo
  do iitbmc = 1, nitbmc
    itbmc(iel,iitbmc) = 0
  enddo
  do iitbwo = 1, nitbwo
    itbwo(iel,iitbwo) = 0
  enddo
enddo

! --- Initialisation des tableaux de reels de travail

do iel = 1, ncel
  do iitbcp = 1, nrtbcp
    rtbcp(iel,iitbcp) = zero
  enddo
  do iitbmc = 1, nrtbmc
    rtbmc(iel,iitbmc) = zero
  enddo
  do iitbwo = 1, nrtbwo
    rtbwo(iel,iitbwo) = zero
  enddo
enddo


!===============================================================================
! 2. DETERMINATION DU TYPE DE PDF
!===============================================================================

! --> Determination du type de PDF

! ---- Reconstitution de 3 moyennes et de 1 variance

call cppdf4                                                       &
!==========
( ncelet , ncel   ,                                               &
  f1m    , f2m    , f3m    , f4m    , f4p2m  ,                    &
  itbcp(1,1) ,                                                    &
!         INDPDF
  rtbcp(1,1) , rtbcp(1,2) , rtbcp(1,3) , rtbcp(1,4)  )
!         SI7          SI8          SP2M         F4I7


!===============================================================================
! 3. CALCUL DES PARAMETRES DE LA PDF CENTREE RECTANGLE - PICS DE DIRAC
!===============================================================================

call cppdfr                                                       &
!==========
 ( ncelet , ncel   ,                                              &
   itbcp(1,1) , rtbcp(1,1) , rtbcp(1,2) , rtbcp(1,3) ,            &
!          INTPDF       SI7          SI8          SP2M
   rtbcp(1,5) , rtbcp(1,6) , rtbcp(1,7) , rtbcp(1,8) ,            &
!          DSI7         DSI8         SDEB         SFIN
   rtbcp(1,9)  )
!          HAUT


!===============================================================================
! 4. CALCUL DES CONCENTRATIONS MOYENNES
!===============================================================================


ipcyf1 = ipproc(iym1(ichx1))
ipcyf2 = ipproc(iym1(ichx2))
ipcyf3 = ipproc(iym1(ico  ))
ipcyox = ipproc(iym1(io2  ))
ipcyp1 = ipproc(iym1(ico2 ))
ipcyp2 = ipproc(iym1(ih2o ))
ipcyin = ipproc(iym1(in2  ))

call cplym1                                                       &
!==========
 ( ncelet , ncel   , nitbmc , nrtbmc ,                            &
   f1m    , f2m    , f3m    , f4m    ,                            &
   itbcp(1,1) ,                                                   &
!          INTPDF
   rtbcp(1,1) , rtbcp(1,2) , rtbcp(1,3) , rtbcp(1,4) ,            &
!          SI7          SI8          SP2M         F4I7
   rtbcp(1,5) , rtbcp(1,6) , rtbcp(1,7) , rtbcp(1,8) ,            &
!          DSI7         DSI8         SDEB         SFIN
   rtbcp(1,9) ,                                                   &
!          HAUT
   propce(1,ipcyf1) , propce(1,ipcyf2) , propce(1,ipcyf3) ,       &
   propce(1,ipcyox) , propce(1,ipcyp1) , propce(1,ipcyp2) ,       &
   propce(1,ipcyin) ,                                             &
   itbmc      , rtbmc      ,                                      &
!          MACRO TABLEAU MULTI CHARBONS ENTIERS REELS
   itbwo(1,1) ,                                                   &
   rtbwo(1,1) , rtbwo(1,2) , rtbwo(1,3), rtbwo(1,4) )
!          TABLEAUX DE TRAVAIL

! IMPORTANT : Voir dams PPINI1 pour savoir comment est range RTBMC

! --> Clipping eventuel des fractions massiques

do iel = 1, ncel
  do ice = 1, (ngaze-2*ncharb)
    ipcyce = ipproc(iym1(ice))
    if ( abs(propce(iel,ipcyce)).lt.epsicp )                      &
         propce(iel,ipcyce) = zero
  enddo
enddo


!===============================================================================
! 4. CALCUL DE LA TEMPERATURE ET DE LA MASSE VOLUMIQUE
!===============================================================================

ipcte1 = ipproc(itemp1)

!  CALCUL DE LA TEMPERATURE DU GAZ
!     EN FONCTION DE L'ENTHALPIE DU GAZ ET DES CONCENTRATIONS

  call cpteh1                                                     &
  !==========
 ( ncelet , ncel   , nitbmc , nrtbmc ,                            &
   enth,                                                          &
   propce(1,ipcyf1), propce(1,ipcyf2), propce(1,ipcyf3),          &
   propce(1,ipcyox), propce(1,ipcyp1), propce(1,ipcyp2),          &
   propce(1,ipcyin),                                              &
   propce(1,ipcte1),                                              &
   itbmc      , rtbmc      ,                                      &
!          MACRO TABLEAU MULTI CHARBONS ENTIERS REELS
   rtbwo(1,1) , rtbwo(1,2) )
!          TABLEAUX DE TRAVAIL

ipcte1 = ipproc(itemp1)
do iel = 1, ncel
  wmchx1 = wmolat(iatc)+rtbmc(iel,ix1mc)*wmolat(iath)
  wmchx2 = wmolat(iatc)+rtbmc(iel,ix2mc)*wmolat(iath)
  wmolme = propce(iel,ipcyf1)/wmchx1                              &
         + propce(iel,ipcyf2)/wmchx2                              &
         + propce(iel,ipcyf3)/wmole(ico )                         &
         + propce(iel,ipcyox)/wmole(io2 )                         &
         + propce(iel,ipcyp1)/wmole(ico2)                         &
         + propce(iel,ipcyp2)/wmole(ih2o)                         &
         + propce(iel,ipcyin)/wmole(in2 )

! stockage de la masse molaire du melange

  propce(iel,ipproc(immel)) = 1.d0 / wmolme

! ---- On ne met pas la pression mecanique IPR
!      mais P0

  rom1(iel) = p0/(wmolme*rr*propce(iel,ipcte1))
enddo

! Free memory
deallocate(itbcp, itbmc, itbwo)
deallocate(rtbcp, rtbmc, rtbwo)

!===============================================================================

!--------
! FORMATS
!--------


!----
! FIN
!----

return
end subroutine