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

!> \file iniva0.f90
!> \brief Computed variable initialization.
!> The time step, the indicator of wall distance computation are also
!> initialized just before reading a restart file or use the user
!> initializations.
!>
!------------------------------------------------------------------------------

!------------------------------------------------------------------------------
! Arguments
!------------------------------------------------------------------------------
!   mode          name          role
!------------------------------------------------------------------------------
!> \param[in]     nvar          total number of variables
!> \param[in]     nscal         total number of scalars
!> \param[out]    dt            time step value
!> \param[out]    propce        physical properties at cell centers
!> \param[out]    frcxt         external stress generating hydrostatic pressure
!> \param[out]    prhyd         hydrostatic pressure predicted
!______________________________________________________________________________

subroutine iniva0 &
 ( nvar   , nscal  ,                                              &
   dt     , propce , frcxt  , prhyd)

!===============================================================================
! Module files
!===============================================================================

use paramx
use numvar
use optcal
use cstphy
use cstnum
use dimens, only: nproce
use pointe
use entsor
use albase
use parall
use period
use ppppar
use ppthch
use ppincl
use cplsat
use field
use mesh
use cavitation

!===============================================================================

implicit none

! Arguments

integer          nvar   , nscal

double precision frcxt(3,ncelet), prhyd(ncelet)
double precision dt(ncelet), propce(ncelet,*)

! Local variables

integer          iis   , iscal , iprop
integer          iel   , ifac  , isou
integer          iclip , ii    , jj    , idim
integer          iivisa, iivism
integer          iicpa
integer          ifcvsl
integer          nn
integer          iflid, nfld, ifmaip, bfmaip, iflmas, iflmab
integer          f_id,  f_dim
integer          kscmin, kscmax

logical          interleaved, have_previous

double precision xxk, xcmu, trii

double precision, dimension(:), pointer :: brom, crom, crom_prev2
double precision, dimension(:), pointer :: cofbcp
double precision, dimension(:), pointer :: porosi
double precision, dimension(:,:), pointer :: porosf
double precision, dimension(:), pointer :: field_s_v
double precision, dimension(:,:), pointer :: field_v_v

double precision, dimension(:), pointer :: cvar_pr, cvar_tempk
double precision, dimension(:), pointer :: cvar_k, cvar_ep, cvar_al
double precision, dimension(:), pointer :: cvar_phi, cvar_fb, cvar_omg, cvar_nusa
double precision, dimension(:), pointer :: cvar_r11, cvar_r22, cvar_r33
double precision, dimension(:), pointer :: cvar_r12, cvar_r13, cvar_r23
double precision, dimension(:), pointer :: viscl, visct, cpro_cp, cpro_prtot
double precision, dimension(:), pointer :: cpro_viscls, cproa_viscls

!===============================================================================

!===============================================================================
! 1.  INITIALISATION
!===============================================================================

! Initialize variables to avoid compiler warnings

jj = 0

! En compressible, ISYMPA initialise (= 1) car utile dans le calcul
!     du pas de temps variable avant passage dans les C.L.

if ( ippmod(icompf).ge.0 ) then
  do ifac = 1, nfabor
    isympa(ifac) = 1
  enddo
endif

! Initialize all cell property fields to zero
! (this is useful only for fields which are mapped;
! fields who own their values, such as variables, are already
! initialized after allocation).

do iprop = 1, nproce

  f_id = iprpfl(iprop)

  if (f_id.lt.0) cycle

  call field_get_dim(f_id, f_dim, interleaved)

  if (f_dim.gt.1) then
    call field_get_val_v(f_id, field_v_v)
  else if (f_dim.eq.1) then
    call field_get_val_s(f_id, field_s_v)
  endif

  if (f_dim.gt.1) then
    if (interleaved) then
      !$omp parallel do private(isou)
      do iel = 1, ncelet
        do isou = 1, f_dim
          field_v_v(isou,iel) = 0.d0
        enddo
      enddo
    else
      !$omp parallel do private(isou)
      do iel = 1, ncelet
        do isou = 1, f_dim
          field_v_v(iel,isou) = 0.d0
        enddo
      enddo
    endif
  else
    !$omp parallel do
    do iel = 1, ncelet
      field_s_v(iel) = 0.d0
    enddo
  endif

  call field_current_to_previous(f_id) ! For those properties requiring it.

enddo

!===============================================================================
! 2. PAS DE TEMPS
!===============================================================================

! dt might be used on the halo cells during the ALE initialization
! otherwise dt is synchronized in the pressure correction step.
do iel = 1, ncelet
  dt (iel) = dtref
enddo

!===============================================================================
! 3.  INITIALISATION DES PROPRIETES PHYSIQUES
!===============================================================================

call field_get_val_s(ivarfl(ipr), cvar_pr)

!     Masse volumique
call field_get_val_s(icrom, crom)
call field_get_val_s(ibrom, brom)

!     Masse volumique aux cellules (et au pdt precedent si ordre2 ou icalhy
!     ou cavitation)
do iel = 1, ncel
  crom(iel)  = ro0
enddo
if (iroext.gt.0.or.icalhy.eq.1.or.idilat.gt.1.or.icavit.ge.0) then
  call field_current_to_previous(icrom)
endif
if (icavit.ge.0.or.idilat.gt.1) then
  call field_get_val_s(icroaa, crom_prev2)
  do iel = 1, ncelet
    crom_prev2(iel) = crom(iel)
  enddo
endif

!     Masse volumique aux faces de bord (et au pdt precedent si ordre2)
do ifac = 1, nfabor
  brom(ifac) = ro0
enddo
if (iroext.gt.0.or.icavit.ge.0) then
  call field_current_to_previous(ibrom)
endif

!     In compressible, initialize temperature with reference temperature
!     (temperature is not solved but is a variable nevertheless)
if (ippmod(icompf).ge.0) then
  call field_get_val_s(ivarfl(isca(itempk)), cvar_tempk)
  do iel = 1, ncel
    cvar_tempk(iel) = t0
  enddo
endif

!     Viscosite moleculaire
call field_get_val_s(iprpfl(iviscl), viscl)
call field_get_val_s(iprpfl(ivisct), visct)

!     Viscosite moleculaire aux cellules (et au pdt precedent si ordre2)
do iel = 1, ncel
  viscl(iel) = viscl0
enddo
if(iviext.gt.0) then
  iivisa = ipproc(ivisla)
  do iel = 1, ncel
    propce(iel,iivisa) = viscl(iel)
  enddo
endif
!     Viscosite turbulente aux cellules (et au pdt precedent si ordre2)
do iel = 1, ncel
  visct(iel) = 0.d0
enddo
if(iviext.gt.0) then
  iivisa = ipproc(ivista)
  do iel = 1, ncel
    propce(iel,iivisa) = visct(iel)
  enddo
endif

!     Chaleur massique aux cellules (et au pdt precedent si ordre2)
if(icp.gt.0) then
  call field_get_val_s(iprpfl(icp), cpro_cp)
  do iel = 1, ncel
    cpro_cp(iel) = cp0
  enddo
  if(icpext.gt.0) then
    iicpa  = ipproc(icpa)
    do iel = 1, ncel
      propce(iel,iicpa ) = cpro_cp(iel)
    enddo
  endif
endif

! La pression totale sera initialisee a P0 + rho.g.r dans INIVAR
!  si l'utilisateur n'a pas fait d'initialisation personnelle
! Non valable en compressible
if (ippmod(icompf).lt.0) then
  call field_get_val_s(iprpfl(iprtot), cpro_prtot)
  do iel = 1, ncel
    cpro_prtot(iel) = - rinfin
  enddo
endif

! Diffusivite des scalaires
do iscal = 1, nscal
  call field_get_key_int (ivarfl(isca(iscal)), kivisl, ifcvsl)
  ! Diffusivite aux cellules (et au pdt precedent si ordre2)
  if (ifcvsl.ge.0) then
    call field_get_val_s(ifcvsl, cpro_viscls)
    do iel = 1, ncel
      cpro_viscls(iel) = visls0(iscal)
    enddo
    call field_have_previous(ifcvsl, have_previous)
    if (have_previous) then
      call field_get_val_prev_s(ifcvsl, cproa_viscls)
      do iel = 1, ncel
        cproa_viscls(iel) = visls0(iscal)
      enddo
    endif
  endif
enddo

if (iscalt.gt.0.and.irovar.eq.1) then
  if (iturt(iscalt).gt.0) then
    do iel = 1, ncelet
      propce(iel,ipproc(ibeta)) = 0.d0
    enddo
  endif
endif

! Initialisation of source terms for weakly compressible algorithm
if (idilat.ge.4) then
  do iel = 1, ncel
    propce(iel,ipproc(iustdy(itsrho))) = 0.d0
  enddo
  do iscal = 1, nscal
    do iel = 1, ncel
      propce(iel,ipproc(iustdy(iscal))) = 0.d0
    enddo
  enddo
endif


!     Viscosite de maillage en ALE
if (iale.eq.1) then
  nn = 1
  if (iortvm.eq.1) nn = 3
  do ii = 1, nn
    iivism = ipproc(ivisma(ii))
    do iel = 1, ncel
      propce(iel,iivism) = 1.d0
    enddo
  enddo
endif

! Porosity
if (iporos.ge.1) then
  call field_get_val_s(ipori, porosi)
  do iel = 1, ncelet
    porosi(iel) = 1.d0
  enddo

  ! Tensorial porosity
  if (iporos.eq.2) then
    call field_get_val_v(iporf, porosf)
    do iel = 1, ncelet
      porosf(1, iel) = 1.d0
      porosf(2, iel) = 1.d0
      porosf(3, iel) = 1.d0
      porosf(4, iel) = 0.d0
      porosf(5, iel) = 0.d0
      porosf(6, iel) = 0.d0
    enddo
  endif
endif

!===============================================================================
! 4. INITIALISATION STANDARD DES VARIABLES DE CALCUL
!     On complete ensuite pour les variables turbulentes et les scalaires
!===============================================================================

!     On met la pression P* a PRED0
!$omp parallel do
do iel = 1, ncel
  cvar_pr(iel) = pred0
enddo

! On definit les clipping du taux de vide et on initialize au clipping inf.
if (icavit.ge.0) then

  call field_get_key_id("min_scalar_clipping", kscmin)
  call field_get_key_id("max_scalar_clipping", kscmax)

  call field_set_key_double(ivarfl(ivoidf), kscmin, clvfmn)
  call field_set_key_double(ivarfl(ivoidf), kscmax, clvfmx)

  call field_get_val_s(ivarfl(ivoidf), field_s_v)
  do iel = 1, ncel
    field_s_v(iel) = clvfmn
  enddo

endif

!===============================================================================
! 5. INITIALISATION DE K, RIJ ET EPS
!===============================================================================

!  Si UREF n'a pas ete donnee par l'utilisateur ou a ete mal initialisee
!    (valeur negative), on met les valeurs de k, Rij, eps et omega a
!    -10*GRAND. On testera ensuite si l'utilisateur les a modifiees dans
!    usiniv ou en lisant un fichier suite.

if(itytur.eq.2 .or. itytur.eq.5) then

  call field_get_val_s(ivarfl(ik), cvar_k)
  call field_get_val_s(ivarfl(iep), cvar_ep)

  xcmu = cmu
  if (iturb.eq.50) xcmu = cv2fmu
  if (iturb.eq.51) xcmu = cpalmu

  if (uref.ge.0.d0) then
    do iel = 1, ncel
      cvar_k(iel) = 1.5d0*(0.02d0*uref)**2
      cvar_ep(iel) = cvar_k(iel)**1.5d0*xcmu/almax
    enddo

    iclip = 1
    call clipke(ncelet , ncel   , nvar    ,     &
         iclip  , iwarni(ik))

  else
    do iel = 1, ncel
      cvar_k(iel) = -grand
      cvar_ep(iel) = -grand
    enddo
  endif

  if (iturb.eq.50) then
    call field_get_val_s(ivarfl(iphi), cvar_phi)
    call field_get_val_s(ivarfl(ifb), cvar_fb)
    do iel = 1, ncel
      cvar_phi(iel) = 2.d0/3.d0
      cvar_fb(iel) = 0.d0
    enddo
  endif
  if (iturb.eq.51) then
    call field_get_val_s(ivarfl(ial), cvar_al)
    call field_get_val_s(ivarfl(iphi), cvar_phi)
    do iel = 1, ncel
      cvar_phi(iel) = 2.d0/3.d0
      cvar_al(iel) = 1.d0
    enddo
  endif

elseif(itytur.eq.3) then

  call field_get_val_s(ivarfl(iep), cvar_ep)

  call field_get_val_s(ivarfl(ir11), cvar_r11)
  call field_get_val_s(ivarfl(ir22), cvar_r22)
  call field_get_val_s(ivarfl(ir33), cvar_r33)
  call field_get_val_s(ivarfl(ir12), cvar_r12)
  call field_get_val_s(ivarfl(ir13), cvar_r13)
  call field_get_val_s(ivarfl(ir23), cvar_r23)

  if (uref.ge.0.d0) then

    trii   = (0.02d0*uref)**2

    do iel = 1, ncel
      cvar_r11(iel) = trii
      cvar_r22(iel) = trii
      cvar_r33(iel) = trii
      cvar_r12(iel) = 0.d0
      cvar_r13(iel) = 0.d0
      cvar_r23(iel) = 0.d0
      xxk = 0.5d0*(cvar_r11(iel)+                             &
           cvar_r22(iel)+cvar_r33(iel))
      cvar_ep(iel) = xxk**1.5d0*cmu/almax
    enddo
    iclip = 1
    call clprij(ncelet , ncel   , nvar    ,     &
                iclip  )

  else

    do iel = 1, ncel
      cvar_r11(iel) = -grand
      cvar_r22(iel) = -grand
      cvar_r33(iel) = -grand
      cvar_r12(iel) = -grand
      cvar_r13(iel) = -grand
      cvar_r23(iel) = -grand
      cvar_ep(iel)  = -grand
    enddo

    if(iturb.eq.32)then
      call field_get_val_s(ivarfl(ial), cvar_al)
      do iel = 1, ncel
        cvar_al(iel) = 1.d0
      enddo
    endif

 endif

elseif(iturb.eq.60) then

  call field_get_val_s(ivarfl(ik), cvar_k)
  call field_get_val_s(ivarfl(iomg), cvar_omg)

  if (uref.ge.0.d0) then

    do iel = 1, ncel
      cvar_k(iel) = 1.5d0*(0.02d0*uref)**2
      !     on utilise la formule classique eps=k**1.5/Cmu/ALMAX et omega=eps/Cmu/k
      cvar_omg(iel) = cvar_k(iel)**0.5d0/almax
    enddo
    !     pas la peine de clipper, les valeurs sont forcement positives

  else

    do iel = 1, ncel
      cvar_k(iel) = -grand
      cvar_omg(iel) = -grand
    enddo

  endif

elseif(iturb.eq.70) then

  call field_get_val_s(ivarfl(inusa), cvar_nusa)

  if (uref.ge.0.d0) then

    do iel = 1, ncel
      cvar_nusa(iel) = sqrt(1.5d0)*(0.02d0*uref)*almax
      !     on utilise la formule classique eps=k**1.5/Cmu/ALMAX
      !     et nusa=Cmu*k**2/eps
    enddo
    !     pas la peine de clipper, les valeurs sont forcement positives

  else

    do iel = 1, ncel
      cvar_nusa(iel) = -grand
    enddo

  endif

endif

!===============================================================================
! 6.  CLIPPING DES GRANDEURS SCALAIRES (SF K-EPS VOIR CI DESSUS)
!===============================================================================

if (nscal.gt.0) then

!    Clipping des scalaires non variance
  do iis = 1, nscal
    if(iscavr(iis).eq.0) then
      iscal = iis
      call clpsca(iscal)
      !==========
    endif
  enddo

!     Clipping des variances qui sont clippees sans recours au scalaire
!        associe
  do iis = 1, nscal
    if(iscavr(iis).ne.0.and.iclvfl(iis).ne.1) then
      iscal = iis
      call clpsca(iscal)
      !==========
    endif
  enddo

!     Clipping des variances qui sont clippees avec recours au scalaire
!        associe s'il est connu
  do iis = 1, nscal
    if (iscavr(iis).le.nscal.and.iscavr(iis).ge.1.and.iclvfl(iis).eq.1) then
      iscal = iis
      call clpsca(iscal)
      !==========
    endif
  enddo

endif

!===============================================================================
! 7.  INITIALISATION DE CONDITIONS AUX LIMITES ET FLUX DE MASSE
!      NOTER QUE LES CONDITIONS AUX LIMITES PEUVENT ETRE UTILISEES DANS
!      PHYVAR, PRECLI
!===============================================================================

! Conditions aux limites

if (ienerg.gt.0) then
  call field_get_coefbc_s(ivarfl(isca(ienerg)), cofbcp)
  do ifac = 1, nfabor
    cofbcp(ifac) = 0.d0
  enddo
endif

! Boundary conditions

do ifac = 1, nfabor
  itypfb(ifac) = 0
  itrifb(ifac) = 0
enddo

! Type symetrie : on en a besoin dans le cas du calcul des gradients
!     par moindres carres etendu avec extrapolation du gradient au bord
!     La valeur 0 permet de ne pas extrapoler le gradient sur les faces.
!     Habituellement, on evite l'extrapolation sur les faces de symetries
!     pour ne pas tomber sur une indetermination et une matrice 3*3 non
!     inversible dans les configurations 2D).
do ifac = 1, nfabor
  isympa(ifac) = 0
enddo

! Old mass flux. We try not to do the same operation multiple times
! (for shared mass fluxes), without doing too complex tests.

call field_get_n_fields(nfld)

ifmaip = -1
bfmaip = -1

do ii = 1, nfld

  iflid = ii - 1

  call field_get_key_int(iflid, kimasf, iflmas) ! interior mass flux
  call field_get_key_int(iflid, kbmasf, iflmab) ! boundary mass flux

  if (iflmas.ge.0 .and. iflmas.ne.ifmaip) then
    call field_current_to_previous(iflid)
    ifmaip = iflmas
  endif

  if (iflmab.ge.0 .and. iflmab.ne.bfmaip) then
    call field_current_to_previous(iflid)
    bfmaip = iflmab
  endif

enddo

!===============================================================================
! 8.  INITIALISATION CONSTANTE DE SMAGORINSKY EN MODELE DYNAMIQUE
!===============================================================================

if(iturb.eq.41) then
  do iel = 1, ncel
    propce(iel,ipproc(ismago)) = 0.d0
  enddo
endif

!===============================================================================
! 9.  INITIALISATION DU NUMERO DE LA FACE DE PAROI 5 LA PLUS PROCHE
!===============================================================================

!     Si IFAPAT existe,
!     on suppose qu'il faut le (re)calculer : on init le tab a -1.

if (ineedy.gt.0 .and. abs(icdpar).eq.2) then
  do iel = 1, ncel
    ifapat(iel) = -1
  enddo
endif

!===============================================================================
! 10.  INITIALISATION DE LA FORCE EXTERIEURE QUAND IPHYDR=1
!===============================================================================

if(iphydr.eq.1) then
  do iel = 1, ncel
    frcxt(1,iel) = 0.d0
    frcxt(2,iel) = 0.d0
    frcxt(3,iel) = 0.d0
  enddo
endif

!===============================================================================
! 11.  INITIALISATION DE LA PRESSION HYDROSTATIQUE QUAND IPHYDR=2
!===============================================================================

if(iphydr.eq.2) then
  do iel = 1, ncel
    prhyd(iel) = 0.d0
  enddo
endif

!===============================================================================
! 12.  INITIALISATIONS EN ALE OU MAILLAGE MOBILE
!===============================================================================

if (iale.eq.1) then
  do ii = 1, nnod
    impale(ii) = 0
  enddo
endif

if (iale.eq.1.or.imobil.eq.1) then
  do ii = 1, nnod
    do idim = 1, 3
      xyzno0(idim,ii) = xyznod(idim,ii)
    enddo
  enddo
endif

!----
! FIN
!----

return
end subroutine
