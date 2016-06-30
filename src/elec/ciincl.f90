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

!> \file ciincl.f90
!> [EDL] Paul's modification : EDL Module=========================================

module ciincl

  !=============================================================================

  !> [Commentaires Paul/Juan : Ici, vous pouvez ajouter les module que vous souhaitez
  !> Exemple : use paramax]

  !=============================================================================

  !--> PARAMETRES POUR LE MODULE CI
  !    =================================

  ! -----  Définition des constantes de domaine/intrinsèques
  !    ===========
  !
  !	nbzmax		--> nombre de milieu max. définis dans le domaine
  !	nbz		--> Nombre de zones utilisées
  !	iz		--> Indice de la zone utilisée
  !	zone(nbzmax)	--> Contient le nom de la couleur de chaque zone du domaine
  !	modcond		--> 0 : Adbsorption - 1 : Corrosion
  !     qelem           --> Charge élémentaire
  !     epsil0          --> Permittivité absolue
  !     boltz           --> Constante Boltzmann
  !     epsilr(nbzmax)	--> Permitivitté relative dans chaque milieu
  !     rhomas(nbzmax)  --> Densité massique dans chaque milieu
  !	zpl		--> Valence des ions positifs du liquide
  !	znl		--> Valence des ions négatifs du liquide
  !	zps		--> Valence des ions positifs du solide
  !	zns		--> Valence des ions négatifs du solide
  !	temp		--> Température (K)
  !	alphaci		--> Coefficient multiplicateur du grad+(phi+) "Vient de l'adimensionnement"
  
  integer nbzmax
  parameter(nbzmax = 10)

  double precision  epsil0,boltz, temp
  !parameter(qelem = 1.6d-19)
  parameter(epsil0 = 8.85d-12)
  parameter(boltz = 1.38d-23)
  parameter(temp = 298.d0)

  double precision, save :: epsilr(nbzmax),rhomas(nbzmax),alphaci, qelem
  character(len=8), save :: zone(nbzmax)
  integer, save          :: nbz, iz, modcond, zpl, znl, zps, zns

  !--> DECLARATION DES COEFFICIENT DE DIFFUSION DANS CHAQUE MILIEU
  !    ===========
  !
  !     dpl(nbzmax)   --> Coefficient de diffusion de l'espèce positive du liquide [AL+]
  !	dnl(nbzmax)   --> Coefficient de diffusion de l'espèce négative du liquide [BL-]
  !	dl(nbzmax)    --> Coefficient de diffusion de l'espèce neutre du liquide   [ALBL]
  !	
  !     dps(nbzmax)   --> Coéfficient de diffusion de l'espèce positive du solide [CS+]
  !	dns(nbzmax)   --> Coefficient de diffusion de l'espèce négative du solide [DS-]
  !	ds(nbzmax)    --> Coefficient de diffusion de l'espèce neutre du solide   [CSDS]
  !	
  !	dsln(nbzmax)   --> Coefficient de diffusion de l'espèce neutre combinée SL [CSBL]
  !	dslp(nbzmax)   --> Coefficient de diffusion de l'espèce neutre combinée SL [DSAL]
  
  double precision, save :: dpl(nbzmax),dnl(nbzmax),dl(nbzmax),dps(nbzmax),dns(nbzmax),ds(nbzmax),dsln(nbzmax),dslp(nbzmax)

  !--> DELCARATION DES ESPECES CHIMIQUES
  !    ===========
  !
  !     npl(nbzmax)	--> Concentration de l'espèce chimique positive du liquide [AL+]
  !     nnl(nbzmax)	--> Concentration de l'espèce chimique négative du liquide [BL-]
  !     nl(nbzmax)	--> Concentration de l'espèce chimique neutre du liquide   [ALBL]
  !
  !     nps(nbzmax)	--> Concentration de l'espèce chimique positive du solide [CS+] 
  !     nns(nbzmax)	--> Concentration de l'espèce chimique négative du solide [DS-]
  !     ns(nbzmax)	--> Concentration de l'espèce chimique neutre du solide   [CSDS]
  !
  !     nsln(nbzmax)	--> Concentration de l'espèce chimique neutre combinée SL négatif [CSBL]
  !	nslp(nbzmax)	--> Concentration de l'espèce chimique neutre combinée SL positif [DSAL]

  double precision, save :: npl(nbzmax),nnl(nbzmax),nl(nbzmax),nps(nbzmax),nns(nbzmax),ns(nbzmax),nsln(nbzmax),nslp(nbzmax)

  !--> DECLARATION DES COEFFICIENTS DE REACTION CHIMIQUE
  !    ===========
  !
  !     kdl(nbzmax)     --> Taux de dissociation [ALBL]
  !     krl(nbzmax)     --> Taux de recombinaison[AL+ + BL-]
  !
  !     kds(nbzmax)     --> Taux de dissociation [CSDS]
  !     krs(nbzmax)	--> Taux de recombinaison[CS+ + DS-]
  !
  !     kfsln(nbzmax)     --> Taux de réaction directe [CS + BL-]
  !     krsln(nbzmax)	--> Taux de réaction inverse [CSBL]
  !
  !     kfslp(nbzmax)     --> Taux de réaction directe [DS + AL+]
  !     krslp(nbzmax)	--> Taux de réaction inverse [DSAL]

  double precision, save :: kdl(nbzmax),krl(nbzmax),kds(nbzmax),krs(nbzmax),kfsln(nbzmax),krsln(nbzmax),kfslp(nbzmax),krslp(nbzmax)

  !=============================================================================

contains

  !=============================================================================

end module ciincl
