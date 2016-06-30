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

!> \file cscpfb.f90
!> \brief Preparation of sending variables for coupling between two instances
!> of Code_Saturne via boundary faces.
!> Received indformation will be transformed into boundary condition
!> in subroutine \ref csc2cl.

!------------------------------------------------------------------------------
! Arguments
!------------------------------------------------------------------------------
!   mode          name          role
!------------------------------------------------------------------------------
!> \param[in]     nscal         total number of scalars
!> \param[in]     nptdis
!> \param[in]     numcpl
!> \param[in]     nvcpto
!> \param[in]     locpts
!> \param[in]     coopts
!> \param[in]     djppts
!> \param[in]     pndpts
!> \param[in,out] rvdis
!> \param[in]     dofpts
!______________________________________________________________________________

subroutine cscpfb &
 ( nscal  ,                                                       &
   nptdis , numcpl , nvcpto,                                      &
   locpts ,                                                       &
   coopts , djppts , pndpts ,                                     &
   rvdis  , dofpts )

!===============================================================================
! Module files
!===============================================================================

use paramx
use pointe
use numvar
use optcal
use dimens, only: nvar
use cstphy
use cstnum
use entsor
use parall
use period
use cplsat
use rotation
use mesh
use field
use field_operator

!===============================================================================

implicit none

! Arguments

integer          nscal
integer          nptdis , numcpl , nvcpto

integer          locpts(nptdis)

double precision coopts(3,nptdis), djppts(3,nptdis)
double precision pndpts(nptdis), dofpts(3,nptdis)
double precision rvdis(nptdis,nvcpto)

! Local variables

integer          ipt    , iel    , isou
integer          ivar   , iscal
integer          inc    , iccocg , iprev
integer          ipos
integer          itytu0

double precision xjjp   , yjjp   , zjjp
double precision d2s3
double precision xjpf,yjpf,zjpf,jpf
double precision xx, yy, zz, fra(8)
double precision omegal(3), omegad(3), omegar(3), omgnrl, omgnrd, omgnrr
double precision vitent, daxis2

double precision, allocatable, dimension(:,:,:) :: gradv
double precision, allocatable, dimension(:,:) :: grad
double precision, allocatable, dimension(:) :: trav1, trav2, trav3, trav4
double precision, allocatable, dimension(:) :: trav5, trav6, trav7, trav8

double precision, dimension(:), pointer :: crom
double precision, dimension(:,:), pointer :: vel
double precision, dimension(:), pointer :: cvar_pr, cvar_k, cvar_ep
double precision, dimension(:), pointer :: cvar_phi, cvar_fb, cvar_omg
double precision, dimension(:), pointer :: cvar_var, cvar_scal

!===============================================================================

! Map field arrays
call field_get_val_v(ivarfl(iu), vel)

call field_get_val_s(ivarfl(ipr), cvar_pr)

if (itytur.eq.2) then
  call field_get_val_s(ivarfl(ik), cvar_k)
  call field_get_val_s(ivarfl(iep), cvar_ep)
else if (itytur.eq.3) then
  call field_get_val_s(ivarfl(iep), cvar_ep)
else if (iturb.eq.50) then
  call field_get_val_s(ivarfl(ik), cvar_k)
  call field_get_val_s(ivarfl(iep), cvar_ep)
  call field_get_val_s(ivarfl(iphi), cvar_phi)
  call field_get_val_s(ivarfl(ifb), cvar_fb)
else if (iturb.eq.60) then
  call field_get_val_s(ivarfl(ik), cvar_k)
  call field_get_val_s(ivarfl(iomg), cvar_omg)
endif

!=========================================================================
! 1.  INITIALISATIONS
!=========================================================================

! Gradient options for all operations here

iprev  = 0
inc    = 1
iccocg = 1

! Initialize variables to avoid compiler warnings

vitent = 0.d0

! Allocate temporary arrays

allocate(grad(3,ncelet))
allocate(gradv(3,3,ncelet))

allocate(trav1(nptdis))
allocate(trav2(nptdis))
allocate(trav3(nptdis))
allocate(trav4(nptdis))
allocate(trav5(nptdis))
allocate(trav6(nptdis))
allocate(trav7(nptdis))
allocate(trav8(nptdis))

d2s3 = 2.d0/3.d0

call field_get_val_s(icrom, crom)

if (icormx(numcpl).eq.1) then

  call rotation_to_array(1, fra)

  ! Get rotation array of all instances in all cases
  ! TODO check axes are the same
  ! (any axis being allowed for a domain with no rotation)

  omegal(1) = fra(1)*fra(7)
  omegal(2) = fra(2)*fra(7)
  omegal(3) = fra(3)*fra(7)

  call tbrcpl(numcpl,3,3,omegal,omegad)

  ! Vecteur vitesse relatif d'une instance a l'autre
  omegar(1) = omegal(1) - omegad(1)
  omegar(2) = omegal(2) - omegad(2)
  omegar(3) = omegal(3) - omegad(3)

  omgnrl = sqrt(omegal(1)**2 + omegal(2)**2 + omegal(3)**2)
  omgnrd = sqrt(omegad(1)**2 + omegad(2)**2 + omegad(3)**2)
  omgnrr = sqrt(omegar(1)**2 + omegar(2)**2 + omegar(3)**2)

else

  omegal(1) = 0.d0
  omegal(2) = 0.d0
  omegal(3) = 0.d0

  omegar(1) = 0.d0
  omegar(2) = 0.d0
  omegar(3) = 0.d0

  omgnrl = 0.d0
  omgnrd = 0.d0
  omgnrr = 0.d0

endif

! On part du principe que l'on envoie les bonnes variables �
! l'instance distante et uniquement celles-l�.

! De plus, les variables sont envoy�es dans l'ordre:

!     - vitesse
!     - pression
!     - grandeurs turbulentes (selon le mod�le)
!   Et ensuite :
!     - scalaires physique particuli�re (pas encore trait�s)
!     - scalaires utilisateur
!     - vitesse de maillage (non coupl�e, donc non envoy�e)


ipos = 0

!=========================================================================
! 1.  Prepare for velocity
!=========================================================================

call field_gradient_vector(ivarfl(iu), iprev, imrgra, inc,  &
                           gradv)

do isou = 1, 3

  ipos = ipos + 1

  ! For a specific face to face coupling, geometric assumptions are made

  if (ifaccp.eq.1) then

    do ipt = 1, nptdis

      iel = locpts(ipt)

      ! Pour la vitesse on veut imposer un dirichlet de vitesse qui "imite"
      ! ce qui se passe pour une face interne. On se donne le choix entre
      ! UPWIND, SOLU et CENTRE (parties comment�es selon le choix retenu).
      ! Pour l'instant seul le CENTRE respecte ce qui se passerait pour la
      ! diffusion si on avait un seul domaine

      ! -- UPWIND

      !        xjjp = djppts(1,ipt)
      !        yjjp = djppts(2,ipt)
      !        zjjp = djppts(3,ipt)

      !        rvdis(ipt,ipos) = vel(isou,iel)

      ! -- SOLU

      !        xjf = coopts(1,ipt) - xyzcen(1,iel)
      !        yjf = coopts(2,ipt) - xyzcen(2,iel)
      !        zjf = coopts(3,ipt) - xyzcen(3,iel)

      !        rvdis(ipt,ipos) = vel(isou,iel) &
      !          + xjf*gradv(1,isou,iel) + yjf*gradv(2,isou,iel) &
      !          + zjf*gradv(3,isou,iel)

      ! -- CENTRE

      xjjp = djppts(1,ipt)
      yjjp = djppts(2,ipt)
      zjjp = djppts(3,ipt)

      rvdis(ipt,ipos) =   vel(isou,iel)            &
                        + xjjp*gradv(1,isou,iel)   &
                        + yjjp*gradv(2,isou,iel)   &
                        + zjjp*gradv(3,isou,iel)

      ! On prend en compte la vitesse d'entrainement en rep�re relatif
      if (icormx(numcpl).eq.1) then

        if (isou.eq.1) then
          vitent =   omegar(2)*(xyzcen(3,iel)+zjjp) &
                   - omegar(3)*(xyzcen(2,iel)+yjjp)
        elseif (isou.eq.2) then
          vitent =   omegar(3)*(xyzcen(1,iel)+xjjp) &
                   - omegar(1)*(xyzcen(3,iel)+zjjp)
        elseif (isou.eq.3) then
          vitent =   omegar(1)*(xyzcen(2,iel)+yjjp) &
                   - omegar(2)*(xyzcen(1,iel)+xjjp)
        endif

        rvdis(ipt,ipos) = rvdis(ipt,ipos) + vitent

      endif

    enddo

    ! For a generic coupling, no assumption can be made

  else

    do ipt = 1, nptdis

      iel = locpts(ipt)

      xjjp = dofpts(1,ipt) + djppts(1,ipt)
      yjjp = dofpts(2,ipt) + djppts(2,ipt)
      zjjp = dofpts(3,ipt) + djppts(3,ipt)

      rvdis(ipt,ipos) =   vel(isou,iel)            &
                        + xjjp*gradv(1,isou,iel)   &
                        + yjjp*gradv(2,isou,iel)   &
                        + zjjp*gradv(3,isou,iel)

    enddo

  endif

enddo
!       Fin de la boucle sur les composantes de la vitesse

!=========================================================================
! 2.  Prepare for pressure
!=========================================================================

ipos = ipos + 1

call field_gradient_scalar(ivarfl(ipr), iprev, imrgra, inc,  &
                           iccocg,                           &
                           grad)

! For a specific face to face coupling, geometric assumptions are made

if (ifaccp.eq.1) then

  do ipt = 1, nptdis

    iel = locpts(ipt)

    ! --- Pour la pression on veut imposer un dirichlet tel que le gradient
    !     de pression se conserve entre les deux domaines coupl�s Pour cela
    !     on impose une interpolation centr�e

    xjjp = djppts(1,ipt)
    yjjp = djppts(2,ipt)
    zjjp = djppts(3,ipt)

    rvdis(ipt,ipos) = cvar_pr(iel) &
         + xjjp*grad(1,iel) + yjjp*grad(2,iel) + zjjp*grad(3,iel)

    ! On prend en compte le potentiel centrifuge en rep�re relatif
    if (icormx(numcpl).eq.1) then

      ! Calcul de la distance a l'axe de rotation
      ! On suppose que les axes sont confondus...

      xx = xyzcen(1,iel) + xjjp
      yy = xyzcen(2,iel) + yjjp
      zz = xyzcen(3,iel) + zjjp

      daxis2 =   (omegar(2)*zz - omegar(3)*yy)**2 &
               + (omegar(3)*xx - omegar(1)*zz)**2 &
               + (omegar(1)*yy - omegar(2)*xx)**2

      daxis2 = daxis2 / omgnrr**2

      rvdis(ipt,ipos) = rvdis(ipt,ipos)                         &
           + 0.5d0*crom(iel)*(omgnrl**2 - omgnrd**2)*daxis2

    endif

  enddo

  ! For a generic coupling, no assumption can be made

else

  do ipt = 1, nptdis

    iel = locpts(ipt)

    xjpf = coopts(1,ipt) - xyzcen(1,iel)- djppts(1,ipt)
    yjpf = coopts(2,ipt) - xyzcen(2,iel)- djppts(2,ipt)
    zjpf = coopts(3,ipt) - xyzcen(3,iel)- djppts(3,ipt)

    if (pndpts(ipt).ge.0.d0.and.pndpts(ipt).le.1.d0) then
      jpf = -1.d0*sqrt(xjpf**2+yjpf**2+zjpf**2)
    else
      jpf =       sqrt(xjpf**2+yjpf**2+zjpf**2)
    endif

    rvdis(ipt,ipos) = (xjpf*grad(1,iel)+yjpf*grad(2,iel)+zjpf*grad(3,iel))  &
         /jpf

  enddo

endif
!       Fin pour la pression

!=========================================================================
! 3.  PREPARATION DES GRANDEURS TURBULENTES
!=========================================================================

itytu0 = iturcp(numcpl)/10

!=========================================================================
!       3.1 Turbulence dans l'instance locale : mod�les k-epsilon
!=========================================================================

if (itytur.eq.2) then

!=======================================================================
!          3.1.1. INTERPOLATION EN J'
!=======================================================================

  call field_gradient_scalar(ivarfl(ik), iprev, imrgra, inc,      &
                             iccocg,                              &
                             grad)

  ! For a specific face to face coupling, geometric assumptions are made

  if (ifaccp.eq.1) then

    do ipt = 1, nptdis

      iel = locpts(ipt)

      xjjp = djppts(1,ipt)
      yjjp = djppts(2,ipt)
      zjjp = djppts(3,ipt)

      trav1(ipt) = cvar_k(iel)                         &
           + xjjp*grad(1,iel) + yjjp*grad(2,iel) + zjjp*grad(3,iel)

    enddo

    ! For a generic coupling, no assumption can be made

  else

    do ipt = 1, nptdis

      iel = locpts(ipt)

      xjjp = djppts(1,ipt)
      yjjp = djppts(2,ipt)
      zjjp = djppts(3,ipt)

      trav1(ipt) = cvar_k(iel)                         &
           + xjjp*grad(1,iel) + yjjp*grad(2,iel) + zjjp*grad(3,iel)

    enddo

  endif

  !         Pr�paration des donn�es: interpolation de epsilon en J'

  call field_gradient_scalar(ivarfl(iep), iprev, imrgra, inc,     &
                             iccocg,                              &
                             grad)

  ! For a specific face to face coupling, geometric assumptions are made

  if (ifaccp.eq.1) then

    do ipt = 1, nptdis

      iel = locpts(ipt)

      xjjp = djppts(1,ipt)
      yjjp = djppts(2,ipt)
      zjjp = djppts(3,ipt)

      trav2(ipt) = cvar_ep(iel)                        &
           + xjjp*grad(1,iel) + yjjp*grad(2,iel) + zjjp*grad(3,iel)

    enddo

    ! For a generic coupling, no assumption can be made

  else

    do ipt = 1, nptdis

      iel = locpts(ipt)

      xjjp = djppts(1,ipt)
      yjjp = djppts(2,ipt)
      zjjp = djppts(3,ipt)

      trav2(ipt) = cvar_ep(iel)                        &
           + xjjp*grad(1,iel) + yjjp*grad(2,iel) + zjjp*grad(3,iel)

    enddo

  endif


!=======================================================================
!          3.1.2.   Transfert de variable � "iso-mod�le"
!=======================================================================

  if (itytu0.eq.2) then

    !           Energie turbulente
    !           ------------------
    ipos = ipos + 1

    do ipt = 1, nptdis
      rvdis(ipt,ipos) = trav1(ipt)
    enddo

    !           Dissipation turbulente
    !           ----------------------
    ipos = ipos + 1

    do ipt = 1, nptdis
      rvdis(ipt,ipos) = trav2(ipt)
    enddo

    !=======================================================================
    !          3.1.3.   Transfert de k-eps vers Rij-eps
    !=======================================================================

  elseif (itytu0.eq.3) then

    ! Rij tensor
    ! ------------
    ! Diagonal R11,R22,R33

    do isou =1, 3

      ipos = ipos + 1

      do ipt = 1, nptdis
        rvdis(ipt,ipos) = d2s3*trav1(ipt)
      enddo

    enddo

    ! Terms R12,R13,R23

    do isou = 1, 3

      ! Velocity gradient has already been computed above

      do ipt = 1, nptdis

        iel = locpts(ipt)

        if (isou.eq.1) then
          trav3(ipt) = gradv(2,isou,iel)
          trav4(ipt) = gradv(3,isou,iel)
        elseif(isou.eq.2) then
          trav5(ipt) = gradv(1,isou,iel)
          trav6(ipt) = gradv(3,isou,iel)
        elseif(isou.eq.3) then
          trav7(ipt) = gradv(1,isou,iel)
          trav8(ipt) = gradv(2,isou,iel)
        endif

      enddo

    enddo ! loop on velocity components

    ! R12
    ipos = ipos + 1

    do ipt = 1, nptdis
      rvdis(ipt,ipos) = -2.0d0*trav1(ipt)**2*cmu / max(1.0d-10, trav2(ipt)) &
                        *0.5d0*(trav3(ipt) + trav5(ipt))
    enddo

    ! R13
    ipos = ipos + 1

    do ipt = 1, nptdis
      rvdis(ipt,ipos) = -2.0d0*trav1(ipt)**2*cmu / max(1.0d-10, trav2(ipt)) &
                        *0.5d0*(trav4(ipt) + trav7(ipt))
    enddo

    ! R23
    ipos = ipos + 1

    do ipt = 1, nptdis
      rvdis(ipt,ipos) = -2.0d0*trav1(ipt)**2*cmu / max(1.0d-10,trav2(ipt)) &
                        *0.5d0*(trav6(ipt) + trav8(ipt))
    enddo

    ! Turbulente dissipation
    ipos = ipos + 1

    do ipt = 1, nptdis
      rvdis(ipt,ipos) = trav2(ipt)
    enddo

    !=======================================================================
    !          3.1.4.   Transfert de k-eps vers v2f
    !=======================================================================

  elseif (iturcp(numcpl).eq.50) then

    !   ATTENTION: CAS NON PRIS EN COMPTE (ARRET DU CALCUL DANS CSCINI.F)

    !=======================================================================
    !          3.1.5.   Transfert de k-eps vers k-omega
    !=======================================================================

  elseif (iturcp(numcpl).eq.60) then

    !           Energie turbulente
    !           -----------------
    ipos = ipos + 1

    do ipt = 1, nptdis
      rvdis(ipt,ipos) = trav1(ipt)
    enddo

    !           Omega
    !           -----
    ipos = ipos + 1

    do ipt = 1, nptdis
      rvdis(ipt,ipos) = trav2(ipt) / cmu / max(1.0d-10, trav1(ipt))
    enddo


  endif

  !=========================================================================
  !       3.2 Turbulence dans l'instance locale : mod�le Rij-epsilon
  !=========================================================================

elseif (itytur.eq.3) then

  !=======================================================================
  !          3.2.1. INTERPOLATION EN J'
  !=======================================================================

  ! Pr�paration des donn�es: interpolation des Rij en J'

  do isou = 1, 6

    if (isou.eq.1) ivar = ir11
    if (isou.eq.2) ivar = ir22
    if (isou.eq.3) ivar = ir33
    if (isou.eq.4) ivar = ir12
    if (isou.eq.5) ivar = ir13
    if (isou.eq.6) ivar = ir23

    call field_get_val_s(ivarfl(ivar), cvar_var)

    call field_gradient_scalar(ivarfl(ivar), iprev, imrgra, inc,    &
                               iccocg,                              &
                               grad)

    ! For a specific face to face coupling, geometric assumptions are made

    if (ifaccp.eq.1) then

      do ipt = 1, nptdis

        iel = locpts(ipt)

        xjjp = djppts(1,ipt)
        yjjp = djppts(2,ipt)
        zjjp = djppts(3,ipt)

        if (isou.eq.1) then
          trav1(ipt) = cvar_var(iel) &
             + xjjp*grad(1,iel) + yjjp*grad(2,iel) + zjjp*grad(3,iel)
        else if (isou.eq.2) then
          trav2(ipt) = cvar_var(iel) &
             + xjjp*grad(1,iel) + yjjp*grad(2,iel) + zjjp*grad(3,iel)
        else if (isou.eq.3) then
          trav3(ipt) = cvar_var(iel) &
             + xjjp*grad(1,iel) + yjjp*grad(2,iel) + zjjp*grad(3,iel)
        else if (isou.eq.4) then
          trav4(ipt) = cvar_var(iel) &
             + xjjp*grad(1,iel) + yjjp*grad(2,iel) + zjjp*grad(3,iel)
        else if (isou.eq.5) then
          trav5(ipt) = cvar_var(iel) &
             + xjjp*grad(1,iel) + yjjp*grad(2,iel) + zjjp*grad(3,iel)
        else if (isou.eq.6) then
          trav6(ipt) = cvar_var(iel) &
             + xjjp*grad(1,iel) + yjjp*grad(2,iel) + zjjp*grad(3,iel)
        endif

      enddo

      ! For a generic coupling, no assumption can be made

    else

      do ipt = 1, nptdis

        iel = locpts(ipt)

        xjjp = djppts(1,ipt)
        yjjp = djppts(2,ipt)
        zjjp = djppts(3,ipt)

        if (isou.eq.1) then
          trav1(ipt) = cvar_var(iel) &
             + xjjp*grad(1,iel) + yjjp*grad(2,iel) + zjjp*grad(3,iel)
        else if (isou.eq.2) then
          trav2(ipt) = cvar_var(iel) &
             + xjjp*grad(1,iel) + yjjp*grad(2,iel) + zjjp*grad(3,iel)
        else if (isou.eq.3) then
          trav3(ipt) = cvar_var(iel) &
             + xjjp*grad(1,iel) + yjjp*grad(2,iel) + zjjp*grad(3,iel)
        else if (isou.eq.4) then
          trav4(ipt) = cvar_var(iel) &
             + xjjp*grad(1,iel) + yjjp*grad(2,iel) + zjjp*grad(3,iel)
        else if (isou.eq.5) then
          trav5(ipt) = cvar_var(iel) &
             + xjjp*grad(1,iel) + yjjp*grad(2,iel) + zjjp*grad(3,iel)
        else if (isou.eq.6) then
          trav6(ipt) = cvar_var(iel) &
             + xjjp*grad(1,iel) + yjjp*grad(2,iel) + zjjp*grad(3,iel)
        endif

      enddo

    endif

  enddo

  ! Pr�paration des donn�es: interpolation de epsilon en J'

  call field_gradient_scalar(ivarfl(iep), iprev, imrgra, inc,     &
                             iccocg,                              &
                             grad)

  ! For a specific face to face coupling, geometric assumptions are made

  if (ifaccp.eq.1) then

    do ipt = 1, nptdis

      iel = locpts(ipt)

      xjjp = djppts(1,ipt)
      yjjp = djppts(2,ipt)
      zjjp = djppts(3,ipt)

      trav7(ipt) = cvar_ep(iel)                        &
           + xjjp*grad(1,iel) + yjjp*grad(2,iel) + zjjp*grad(3,iel)

    enddo

    ! For a generic coupling, no assumption can be made

  else

    do ipt = 1, nptdis

      iel = locpts(ipt)

      xjjp = djppts(1,ipt)
      yjjp = djppts(2,ipt)
      zjjp = djppts(3,ipt)

      trav7(ipt) = cvar_ep(iel)                        &
           + xjjp*grad(1,iel) + yjjp*grad(2,iel) + zjjp*grad(3,iel)

    enddo

  endif

!=======================================================================
!          3.2.2. Transfert de variable � "iso-mod�le"
!=======================================================================

  if (itytu0.eq.3) then

    !           Tensions de Reynolds
    !           --------------------
    do isou = 1, 6

      ipos = ipos + 1

      if (isou.eq.1) then
        do ipt = 1, nptdis
          rvdis(ipt,ipos) = trav1(ipt)
        enddo
      else if (isou.eq.2) then
        do ipt = 1, nptdis
          rvdis(ipt,ipos) = trav2(ipt)
        enddo
      else if (isou.eq.3) then
        do ipt = 1, nptdis
          rvdis(ipt,ipos) = trav3(ipt)
        enddo
      else if (isou.eq.4) then
        do ipt = 1, nptdis
          rvdis(ipt,ipos) = trav4(ipt)
        enddo
      else if (isou.eq.5) then
        do ipt = 1, nptdis
          rvdis(ipt,ipos) = trav5(ipt)
        enddo
      else if (isou.eq.6) then
        do ipt = 1, nptdis
          rvdis(ipt,ipos) = trav6(ipt)
        enddo
      endif

    enddo

    !           Dissipation turbulente
    !           ----------------------
    ipos = ipos + 1

    do ipt = 1, nptdis
      rvdis(ipt,ipos) = trav7(ipt)
    enddo

    !=======================================================================
    !          3.2.3. Transfert de Rij-epsilon vers k-epsilon
    !=======================================================================

  elseif (itytu0.eq.2) then

    !           Energie turbulente
    !           ------------------
    ipos = ipos + 1

    do ipt = 1, nptdis
      rvdis(ipt,ipos) = 0.5d0*(trav1(ipt) + trav2(ipt) + trav3(ipt))
    enddo

    !           Dissipation turbulente
    !           ----------------------
    ipos = ipos + 1

    do ipt = 1, nptdis
      rvdis(ipt,ipos) = trav7(ipt)
    enddo

    !=======================================================================
    !          3.2.4. Transfert de Rij-epsilon vers v2f
    !=======================================================================

  elseif (iturcp(numcpl).eq.50) then

    !    ATTENTION: CAS NON PRIS EN COMPTE (ARRET DU CALCUL DANS CSCINI.F)

    !=======================================================================
    !          3.2.5. Transfert de Rij-epsilon vers k-omega
    !=======================================================================

  elseif (iturcp(numcpl).eq.60) then

    !           Energie turbulente
    !           ------------------
    ipos = ipos + 1

    do ipt = 1, nptdis
      rvdis(ipt,ipos) = 0.5d0*(trav1(ipt) + trav2(ipt) + trav3(ipt))
    enddo

    !           Omega
    !           -----
    ipos = ipos + 1

    do ipt = 1, nptdis
      rvdis(ipt,ipos) = trav7(ipt) / cmu / max(1.0d-10, rvdis(ipt,ipos-1))
    enddo

  endif

  !==============================================================================
  !       3.3 Turbulence dans l'instance locale : mod�le v2f (phi-model)
  !==============================================================================

elseif (iturb.eq.50) then

  !=======================================================================
  !          3.3.1. INTERPOLATION EN J'
  !=======================================================================

  !         Pr�paration des donn�es: interpolation de k en J'

  call field_gradient_scalar(ivarfl(ik), iprev, imrgra, inc,      &
                             iccocg,                              &
                             grad)

  ! For a specific face to face coupling, geometric assumptions are made

  if (ifaccp.eq.1) then

    do ipt = 1, nptdis

      iel = locpts(ipt)

      xjjp = djppts(1,ipt)
      yjjp = djppts(2,ipt)
      zjjp = djppts(3,ipt)

      trav1(ipt) = cvar_k(iel)                         &
           + xjjp*grad(1,iel) + yjjp*grad(2,iel) + zjjp*grad(3,iel)

    enddo

    ! For a generic coupling, no assumption can be made

  else

    do ipt = 1, nptdis

      iel = locpts(ipt)

      xjjp = djppts(1,ipt)
      yjjp = djppts(2,ipt)
      zjjp = djppts(3,ipt)

      trav1(ipt) = cvar_k(iel)                         &
           + xjjp*grad(1,iel) + yjjp*grad(2,iel) + zjjp*grad(3,iel)

    enddo

  endif

  ! Pr�paration des donn�es: interpolation de epsilon en J'

  call field_gradient_scalar(ivarfl(iep), iprev, imrgra, inc,  &
                             iccocg,                           &
                             grad)

  ! For a specific face to face coupling, geometric assumptions are made

  if (ifaccp.eq.1) then

    do ipt = 1, nptdis

      iel = locpts(ipt)

      xjjp = djppts(1,ipt)
      yjjp = djppts(2,ipt)
      zjjp = djppts(3,ipt)

      trav2(ipt) = cvar_ep(iel)                        &
           + xjjp*grad(1,iel) + yjjp*grad(2,iel) + zjjp*grad(3,iel)

    enddo

    ! For a generic coupling, no assumption can be made

  else

    do ipt = 1, nptdis

      iel = locpts(ipt)

      xjjp = djppts(1,ipt)
      yjjp = djppts(2,ipt)
      zjjp = djppts(3,ipt)

      trav2(ipt) = cvar_ep(iel)                        &
           + xjjp*grad(1,iel) + yjjp*grad(2,iel) + zjjp*grad(3,iel)

    enddo

  endif

  !         Pr�paration des donn�es: interpolation de Phi en J'

  call field_gradient_scalar(ivarfl(iphi), iprev, imrgra, inc,  &
                             iccocg,                            &
                             grad)

  do ipt = 1, nptdis

    iel = locpts(ipt)

    xjjp = djppts(1,ipt)
    yjjp = djppts(2,ipt)
    zjjp = djppts(3,ipt)

    trav3(ipt) = cvar_phi(iel)                        &
         + xjjp*grad(1,iel) + yjjp*grad(2,iel) + zjjp*grad(3,iel)

  enddo

  !         Pr�paration des donn�es: interpolation de F-barre en J'

  call field_gradient_scalar(ivarfl(ifb), iprev, imrgra, inc,  &
                             iccocg,                           &
                             grad)

  ! For a specific face to face coupling, geometric assumptions are made

  if (ifaccp.eq.1) then

    do ipt = 1, nptdis

      iel = locpts(ipt)

      xjjp = djppts(1,ipt)
      yjjp = djppts(2,ipt)
      zjjp = djppts(3,ipt)

      trav4(ipt) = cvar_fb(iel)                        &
           + xjjp*grad(1,iel) + yjjp*grad(2,iel) + zjjp*grad(3,iel)

    enddo

    ! For a generic coupling, no assumption can be made

  else

    do ipt = 1, nptdis

      iel = locpts(ipt)

      xjjp = djppts(1,ipt)
      yjjp = djppts(2,ipt)
      zjjp = djppts(3,ipt)

      trav4(ipt) = cvar_fb(iel)                        &
           + xjjp*grad(1,iel) + yjjp*grad(2,iel) + zjjp*grad(3,iel)

    enddo

  endif

!=======================================================================
!          3.3.2. Transfert de variable � "iso-mod�le"
!=======================================================================

  if (iturcp(numcpl).eq.50) then

    !           Energie turbulente
    !           ------------------
    ipos = ipos + 1

    do ipt = 1, nptdis
      rvdis(ipt,ipos) = trav1(ipt)
    enddo

    !           Dissipation turbulente
    !           ----------------------
    ipos = ipos + 1

    do ipt = 1, nptdis
      rvdis(ipt,ipos) = trav2(ipt)
    enddo

    !           Phi
    !           ---
    ipos = ipos + 1

    do ipt = 1, nptdis
      rvdis(ipt,ipos) = trav3(ipt)
    enddo

    !           F-barre
    !           -------
    ipos = ipos + 1

    do ipt = 1, nptdis
      rvdis(ipt,ipos) = trav4(ipt)
    enddo


    !         ATTENTION: LE COUPLAGE ENTRE UN MODELE V2F ET UN MODELE DE
    !         TURBULENCE DIFFERENT N'EST PAS PRIS EN COMPTE

  elseif (itytu0.eq.2) then
  elseif (itytu0.eq.3) then
  elseif (iturcp(numcpl).eq.60) then
  endif

!==============================================================================
!       3.4 Turbulence dans l'instance locale : mod�le omega SST
!==============================================================================

elseif (iturb.eq.60) then

  !=======================================================================
  !          3.4.1. INTERPOLATION EN J'
  !=======================================================================

  !         Pr�paration des donn�es: interpolation de k en J'

  call field_gradient_scalar(ivarfl(ik), iprev, imrgra, inc,  &
                             iccocg,                          &
                             grad)

  ! For a specific face to face coupling, geometric assumptions are made

  if (ifaccp.eq.1) then

    do ipt = 1, nptdis

      iel = locpts(ipt)

      xjjp = djppts(1,ipt)
      yjjp = djppts(2,ipt)
      zjjp = djppts(3,ipt)

      trav1(ipt) = cvar_k(iel)                         &
           + xjjp*grad(1,iel) + yjjp*grad(2,iel) + zjjp*grad(3,iel)

    enddo

    ! For a generic coupling, no assumption can be made

  else

    do ipt = 1, nptdis

      iel = locpts(ipt)

      xjjp = djppts(1,ipt)
      yjjp = djppts(2,ipt)
      zjjp = djppts(3,ipt)

      trav1(ipt) = cvar_k(iel)                         &
           + xjjp*grad(1,iel) + yjjp*grad(2,iel) + zjjp*grad(3,iel)

    enddo

  endif

  !         Pr�paration des donn�es: interpolation de omega en J'

  call field_gradient_scalar(ivarfl(iomg), iprev, imrgra, inc,  &
                             iccocg,                            &
                             grad)

  ! For a specific face to face coupling, geometric assumptions are made

  if (ifaccp.eq.1) then

    do ipt = 1, nptdis

      iel = locpts(ipt)

      xjjp = djppts(1,ipt)
      yjjp = djppts(2,ipt)
      zjjp = djppts(3,ipt)

      trav2(ipt) = cvar_omg(iel)                        &
           + xjjp*grad(1,iel) + yjjp*grad(2,iel) + zjjp*grad(3,iel)

    enddo

    ! For a generic coupling, no assumption can be made

  else

    do ipt = 1, nptdis

      iel = locpts(ipt)

      xjjp = djppts(1,ipt)
      yjjp = djppts(2,ipt)
      zjjp = djppts(3,ipt)

      trav2(ipt) = cvar_omg(iel)                        &
           + xjjp*grad(1,iel) + yjjp*grad(2,iel) + zjjp*grad(3,iel)

    enddo

  endif

  !=======================================================================
  !          3.4.2. Transfert de variable � "iso-mod�le"
  !=======================================================================

  if (iturcp(numcpl).eq.60) then

    !           Energie turbulente
    !           ------------------
    ipos = ipos + 1

    do ipt = 1, nptdis
      rvdis(ipt,ipos) = trav1(ipt)
    enddo

    !           Omega
    !           -----
    ipos = ipos + 1

    do ipt = 1, nptdis
      rvdis(ipt,ipos) = trav2(ipt)
    enddo

  elseif (itytu0.eq.2) then

    !========================================================================
    !          3.4.3. Transfert de k-omega vers k-epsilon
    !========================================================================
    !           Energie turbulente
    !           ------------------
    ipos = ipos + 1

    do ipt = 1, nptdis
      rvdis(ipt,ipos) = trav1(ipt)
    enddo

    !           Omega
    !           -----
    ipos = ipos + 1

    do ipt = 1, nptdis
      rvdis(ipt,ipos) = trav2(ipt)*cmu*trav1(ipt)
    enddo

    !========================================================================
    !          3.4.3. Transfert de k-omega vers Rij-epsilon
    !========================================================================

  elseif (itytu0.eq.3) then

    !           Tenseur Rij
    !            ----------
    !           Termes de la diagonal R11,R22,R33

    do isou =1, 3

      ipos = ipos + 1

      do ipt = 1, nptdis
        rvdis(ipt,ipos) = d2s3*trav1(ipt)
      enddo

    enddo

    !           Termes R12,R13,R23

    do isou = 1, 3

      ! Velocity gradient has already been computed above

      do ipt = 1, nptdis

        iel = locpts(ipt)

        if (isou.eq.1) then
          trav3(ipt) = gradv(2,isou,iel)
          trav4(ipt) = gradv(3,isou,iel)
        elseif (isou.eq.2) then
          trav5(ipt) = gradv(1,isou,iel)
          trav6(ipt) = gradv(3,isou,iel)
        elseif (isou.eq.3) then
          trav7(ipt) = gradv(1,isou,iel)
          trav8(ipt) = gradv(2,isou,iel)
        endif

      enddo

    enddo
    !           Fin de la boucle sur les composantes de la vitesse

    !           R12
    ipos = ipos + 1

    do ipt = 1, nptdis
      rvdis(ipt,ipos) = -2.0d0*trav1(ipt) / max(1.0d-10, trav2(ipt))  &
                        *0.5d0*(trav3(ipt) + trav5(ipt))
    enddo

    !           R13
    ipos = ipos + 1

    do ipt = 1, nptdis
      rvdis(ipt,ipos) = -2.0d0*trav1(ipt) / max(1.0d-10, trav2(ipt))  &
                        *0.5d0*(trav4(ipt) + trav7(ipt))
    enddo

    !           R23
    ipos = ipos + 1

    do ipt = 1, nptdis
      rvdis(ipt,ipos) = -2.0d0*trav1(ipt) / max(1.0d-10, trav2(ipt))  &
                        *0.5d0*(trav6(ipt) + trav8(ipt))
    enddo

    !           Dissipation turbulente
    !           ----------------------
    ipos = ipos + 1

    do ipt = 1, nptdis
      rvdis(ipt,ipos) = trav2(ipt)*cmu*trav1(ipt)
    enddo

    !=======================================================================
    !          3.3.4. Transfert de k-omega vers v2f
    !=======================================================================

  elseif (iturcp(numcpl).eq.50) then

    !  ATTENTION: CAS NON PRIS EN COMPTE. ARRET DU CALCUL DANS cscini.f90

  endif

endif

!=========================================================================
! 4.  PREPARATION DES SCALAIRES
!=========================================================================

if (nscal.gt.0) then

  do iscal = 1, nscal

    ipos = ipos + 1

    ivar = isca(iscal)
    call field_get_val_s(ivarfl(isca(iscal)), cvar_scal)

! --- Calcul du gradient du scalaire pour interpolation

    call field_gradient_scalar(ivarfl(ivar), iprev, imrgra, inc,  &
                               iccocg,                            &
                               grad)

    ! For a specific face to face coupling, geometric assumptions are made

    if (ifaccp.eq.1) then

      do ipt = 1, nptdis

        iel = locpts(ipt)

! --- Pour les scalaires on veut imposer un dirichlet. On se laisse
!     le choix entre UPWIND, SOLU ou CENTRE. Seul le centr� respecte
!     la diffusion si il n'y avait qu'un seul domaine

! -- UPWIND

!        rvdis(ipt,ipos) = cvar_scal(iel)

! -- SOLU

!        xjf = coopts(1,ipt) - xyzcen(1,iel)
!        yjf = coopts(2,ipt) - xyzcen(2,iel)
!        zjf = coopts(3,ipt) - xyzcen(3,iel)

!        rvdis(ipt,ipos) = cvar_scal(iel) &
!          + xjf*grad(1,iel) + yjf*grad(2,iel) + zjf*grad(3,iel)

! -- CENTRE

        xjjp = djppts(1,ipt)
        yjjp = djppts(2,ipt)
        zjjp = djppts(3,ipt)

        rvdis(ipt,ipos) = cvar_scal(iel) &
          + xjjp*grad(1,iel) + yjjp*grad(2,iel) + zjjp*grad(3,iel)

      enddo

    ! For a generic coupling, no assumption can be made

    else

      do ipt = 1, nptdis

        iel = locpts(ipt)

        xjjp = djppts(1,ipt)
        yjjp = djppts(2,ipt)
        zjjp = djppts(3,ipt)

        rvdis(ipt,ipos) = cvar_scal(iel)                             &
          + xjjp*grad(1,iel) + yjjp*grad(2,iel) + zjjp*grad(3,iel)

      enddo

    endif

  enddo

endif

! Free memory

deallocate(gradv)
deallocate(grad)

deallocate(trav1, trav2, trav3, trav4)
deallocate(trav5, trav6, trav7, trav8)

return
end subroutine
