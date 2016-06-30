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

!===============================================================================
! Function:
! ---------

!> \file phyvar.f90
!>
!> \brief This subroutine fills physical properties which are variable in time
!> (mainly the eddy viscosity).
!>
!> Some user subroutines are called which allows the setting of \f$ \rho \f$,
!> \f$ \mu \f$, etc.
!>
!-------------------------------------------------------------------------------

!-------------------------------------------------------------------------------
! Arguments
!______________________________________________________________________________.
!  mode           name          role                                           !
!______________________________________________________________________________!
!> \param[in]     nvar          total number of variables
!> \param[in]     nscal         total number of scalars
!> \param[in]     dt            time step (per cell)
!> \param[in]     propce        physical properties at cell centers
!_______________________________________________________________________________


subroutine phyvar &
 ( nvar   , nscal  ,                                              &
   dt     , propce )

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
use pointe
use albase
use parall
use period
use ihmpre
use ppppar
use ppthch
use ppincl
use mesh
use field
use cavitation
use darcy_module

!===============================================================================

implicit none

! Arguments

integer          nvar   , nscal

double precision dt(ncelet)
double precision propce(ncelet,*)

! Local variables

character(len=80) :: chaine
integer          ivar  , iel   , ifac  , iscal
integer          ii    , iok   , iok1  , iok2  , iisct, idfm, iggafm
integer          nn
integer          mbrom , ipcvst, ifcvsl
integer          ipccp , ipcvis, ipcvma
integer          iclipc
Double precision xk, xe, xnu, xrom, vismax(nscamx), vismin(nscamx)
double precision nusa, xi3, fv1, cv13
double precision varmn(4), varmx(4), tt, ttmin, ttke, viscto
double precision xttkmg, xttdrb
double precision trrij,rottke
double precision, dimension(:), pointer :: brom, crom
double precision, dimension(:), pointer :: cvar_k, cvar_ep, cvar_phi, cvar_nusa
double precision, dimension(:), pointer :: cvar_r11, cvar_r22, cvar_r33
double precision, dimension(:), pointer :: cvar_r12, cvar_r13, cvar_r23
double precision, dimension(:), pointer :: sval
double precision, dimension(:,:), pointer :: visten, vistes
double precision, dimension(:), pointer :: viscl, visct, cpro_vis
double precision, dimension(:), pointer :: cvar_voidf

integer          ipass
data             ipass /0/
save             ipass

!===============================================================================

!===============================================================================
! 1. Initializations
!===============================================================================

ipass = ipass + 1

!===============================================================================
! 2. Preparing periodicity of rotation
!===============================================================================

if (iperot.gt.0 .and. itytur.eq.3) then

  call perinr &
  !==========
 ( imrgra , iwarni(ir11) , epsrgr(ir11) , extrag(ir11) )

endif


!===============================================================================
! 3. User settings
!===============================================================================

mbrom = 0

! First computation of physical properties for specific physics
! BEFORE the user
if (ippmod(iphpar).ge.1) then

  call cs_physical_properties1 &
 ( nvar   , nscal  ,                                              &
   mbrom  ,                                                       &
   dt     , propce )

endif


! - Interface Code_Saturne
!   ======================

if (iihmpr.eq.1) then
  call uiphyv &
  !===========
( ncel   , ncelet , icp    , irovar , ivivar ,                    &
  iviscv , itempk ,                                               &
  p0     , t0     , ro0    , cp0    , viscl0 , visls0 , viscv0 )

  if (ippmod(idarcy).ge.0) then
    call uidapp                                                           &
    !==========
    ( darcy_anisotropic_permeability,                                     &
      darcy_anisotropic_diffusion,                                        &
      darcy_gravity,                                                      &
      darcy_gravity_x, darcy_gravity_y, darcy_gravity_z)
  endif
endif


call usphyv &
!==========
( nvar   , nscal  ,                                              &
  mbrom  ,                                                       &
  dt     )


! Finalization of physical properties for specific physics
! AFTER the user
if (ippmod(iphpar).ge.1) then
  call cs_physical_properties2(propce)
endif

!  ROMB SUR LES BORDS : VALEUR PAR DEFAUT (CELLE DE LA CELLULE VOISINE)

if (mbrom.eq.0) then
  call field_get_val_s(icrom, crom)
  call field_get_val_s(ibrom, brom)
  do ifac = 1, nfabor
    iel = ifabor(ifac)
    brom(ifac) = crom(iel)
  enddo
endif

!  Au premier pas de temps du calcul
!     Si on a indique que rho (visc) etait constant
!       et qu'on l'a modifie dans usphyv, ca ne va pas
!     On se sert de irovar (ivivar) pour ecrire et lire
!       rho (visc) dans le fichier suite

if (ntcabs.eq.ntpabs+1 .and. icavit.lt.0) then

  ! Masse volumique aux cellules et aux faces de bord
  iok1 = 0
  if (irovar.eq.0) then
    call field_get_val_s(icrom, crom)
    call field_get_val_s(ibrom, brom)
    do iel = 1, ncel
      if ( abs(crom(iel)-ro0   ).gt.epzero) then
        iok1 = 1
      endif
    enddo
    do ifac = 1, nfabor
      if ( abs(brom(ifac)-ro0   ).gt.epzero) then
        iok1 = 1
      endif
    enddo
  endif
  if (iok1.ne.0) then
    write(nfecra,9001)
  endif

  ! Viscosite moleculaire aux cellules
  iok2 = 0
  if (ivivar.eq.0) then
    call field_get_val_s(iprpfl(iviscl), viscl)
    do iel = 1, ncel
      if ( abs(viscl(iel)-viscl0).gt.epzero) then
        iok2 = 1
      endif
    enddo
  endif
  if (iok2.ne.0) then
    if ( ippmod(icompf) .ge. 0 ) then
      write(nfecra,9003)
    else
      write(nfecra,9002)
    endif
  endif

  if (iok1.ne.0.or.iok2.ne.0) then
    call csexit(1)
  endif

endif

!===============================================================================
! 4. Compute the eddy viscosity
!===============================================================================

if     (iturb.eq. 0) then

! 4.1 Laminar
! ===========

  call field_get_val_s(iprpfl(ivisct), visct)

  do iel = 1, ncel
    visct(iel) = 0.d0
  enddo

elseif (iturb.eq.10) then

! 4.2 Mixing length model
! =======================

  call vislmg

elseif (itytur.eq.2) then

! 4.3 k-epsilon
! =============

  call field_get_val_s(iprpfl(ivisct), visct)
  call field_get_val_s(icrom, crom)
  call field_get_val_s(ivarfl(ik), cvar_k)
  call field_get_val_s(ivarfl(iep), cvar_ep)

  do iel = 1, ncel
    xk = cvar_k(iel)
    xe = cvar_ep(iel)
    visct(iel) = crom(iel)*cmu*xk**2/xe
  enddo

elseif (itytur.eq.3) then

! 4.4 Rij-epsilon
! ===============

  call field_get_val_s(iprpfl(ivisct), visct)
  call field_get_val_s(icrom, crom)
  call field_get_val_s(ivarfl(iep), cvar_ep)

  call field_get_val_s(ivarfl(ir11), cvar_r11)
  call field_get_val_s(ivarfl(ir22), cvar_r22)
  call field_get_val_s(ivarfl(ir33), cvar_r33)

  do iel = 1, ncel
    xk = 0.5d0*(cvar_r11(iel)+cvar_r22(iel)+cvar_r33(iel))
    xe = cvar_ep(iel)
    visct(iel) = crom(iel)*cmu*xk**2/xe
  enddo

elseif (iturb.eq.40) then

! 4.5 LES Smagorinsky
! ===================

  call vissma
  !==========

elseif (iturb.eq.41) then

! 4.6 LES dynamic
! ===============

  call visdyn &
  !==========
 ( nvar   , nscal  ,                                              &
   ncepdc , ncetsm ,                                              &
   icepdc , icetsm , itypsm ,                                     &
   dt     ,                                                       &
   ckupdc , smacel ,                                              &
   propce(1,ipproc(ismago)) )

elseif (iturb.eq.42) then

! 4.7 LES WALE
! ============

  call viswal
  !==========

elseif (itytur.eq.5) then

! 4.8 v2f (phi-model and BL-v2/k)
! ===============================

  if (iturb.eq.50) then

    call field_get_val_s(iprpfl(iviscl), viscl)
    call field_get_val_s(iprpfl(ivisct), visct)
    call field_get_val_s(icrom, crom)
    call field_get_val_s(ivarfl(ik), cvar_k)
    call field_get_val_s(ivarfl(iep), cvar_ep)
    call field_get_val_s(ivarfl(iphi), cvar_phi)

    do iel = 1, ncel
      xk = cvar_k(iel)
      xe = cvar_ep(iel)
      xrom = crom(iel)
      xnu = viscl(iel)/xrom
      ttke = xk / xe
      ttmin = cv2fct*sqrt(xnu/xe)
      tt = max(ttke,ttmin)
      visct(iel) = cv2fmu*xrom*tt*cvar_phi(iel)*cvar_k(iel)
    enddo

  else if (iturb.eq.51) then

    call visv2f
    !==========

  endif

elseif (iturb.eq.60) then

! 4.9 k-omega SST
! ===============

  call vissst
  !==========

elseif (iturb.eq.70) then

! 4.10 Spalart-Allmaras
! =====================

  cv13 = csav1**3

  call field_get_val_s(ivarfl(inusa), cvar_nusa)
  call field_get_val_s(iprpfl(ivisct), visct)
  call field_get_val_s(icrom, crom)
  call field_get_val_s(iprpfl(iviscl), viscl)

  do iel = 1, ncel
    xrom = crom(iel)
    nusa = cvar_nusa(iel)
    xi3  = (xrom*nusa/viscl(iel))**3
    fv1  = xi3/(xi3+cv13)
    visct(iel) = xrom*nusa*fv1
  enddo

endif

!===============================================================================
! 5. Anisotropic turbulent viscosity (symmetric)
!===============================================================================
idfm = 0
iggafm = 0

do iscal = 1, nscal
  if (ityturt(iscal).eq.3) idfm = 1
  ! GGDH or AFM on current scalar
  ! and if DFM, GGDH on the scalar variance
  if (ityturt(iscal).gt.0) iggafm = 1
enddo

if (idfm.eq.1 .or. itytur.eq.3 .and. idirsm.eq.1) then

  call field_get_val_v(ivsten, visten)

  if (itytur.eq.3) then

    call field_get_val_s(icrom, crom)
    call field_get_val_s(iprpfl(iviscl), viscl)

    call field_get_val_s(ivarfl(iep), cvar_ep)

    call field_get_val_s(ivarfl(ir11), cvar_r11)
    call field_get_val_s(ivarfl(ir22), cvar_r22)
    call field_get_val_s(ivarfl(ir33), cvar_r33)
    call field_get_val_s(ivarfl(ir12), cvar_r12)
    call field_get_val_s(ivarfl(ir13), cvar_r13)
    call field_get_val_s(ivarfl(ir23), cvar_r23)

    ! EBRSM
    if (iturb.eq.32) then
      do iel = 1, ncel
        trrij = 0.5d0*(cvar_r11(iel)+cvar_r22(iel)+cvar_r33(iel))
        ttke  = trrij/cvar_ep(iel)
        ! Durbin scale
        xttkmg = xct*sqrt(viscl(iel)/crom(iel)/cvar_ep(iel))
        xttdrb = max(ttke,xttkmg)
        rottke  = csrij * crom(iel) * xttdrb

        visten(1,iel) = rottke*cvar_r11(iel)
        visten(2,iel) = rottke*cvar_r22(iel)
        visten(3,iel) = rottke*cvar_r33(iel)
        visten(4,iel) = rottke*cvar_r12(iel)
        visten(5,iel) = rottke*cvar_r23(iel)
        visten(6,iel) = rottke*cvar_r13(iel)
      enddo

      if (iggafm.eq.1) then
        call field_get_val_v(ivstes, vistes)

        do iel = 1, ncel
          trrij = 0.5d0*(cvar_r11(iel)+cvar_r22(iel)+cvar_r33(iel))
          rottke  = csrij * crom(iel) * trrij / cvar_ep(iel)

          vistes(1,iel) = rottke*cvar_r11(iel)
          vistes(2,iel) = rottke*cvar_r22(iel)
          vistes(3,iel) = rottke*cvar_r33(iel)
          vistes(4,iel) = rottke*cvar_r12(iel)
          vistes(5,iel) = rottke*cvar_r23(iel)
          vistes(6,iel) = rottke*cvar_r13(iel)
        enddo
      endif

    ! LRR or SSG
    else
      do iel = 1, ncel
        trrij = 0.5d0*(cvar_r11(iel)+cvar_r22(iel)+cvar_r33(iel))
        rottke  = csrij * crom(iel) * trrij / cvar_ep(iel)

        visten(1,iel) = rottke*cvar_r11(iel)
        visten(2,iel) = rottke*cvar_r22(iel)
        visten(3,iel) = rottke*cvar_r33(iel)
        visten(4,iel) = rottke*cvar_r12(iel)
        visten(5,iel) = rottke*cvar_r23(iel)
        visten(6,iel) = rottke*cvar_r13(iel)
      enddo
    endif

  else

    do iel = 1, ncel
      visten(1,iel) = 0.d0
      visten(2,iel) = 0.d0
      visten(3,iel) = 0.d0
      visten(4,iel) = 0.d0
      visten(5,iel) = 0.d0
      visten(6,iel) = 0.d0
    enddo

  endif
endif

!===============================================================================
! 6. Eddy viscosity correction for cavitating flows
!===============================================================================

if (icavit.ge.0 .and. icvevm.eq.1) then
  if (itytur.eq.2 .or. itytur.eq.5 .or. iturb.eq.60 .or. iturb.eq.70) then

    ipcvst = ipproc(ivisct)
    call field_get_val_s(icrom, crom)
    call field_get_val_s(ivarfl(ivoidf), cvar_voidf)

    call cavitation_correct_visc_turb (crom, cvar_voidf, propce(:,ipcvst))
    !================================

  endif
endif

!===============================================================================
! 7. User modification of the turbulent viscosity and symmetric tensor
!    diffusivity
!===============================================================================

call usvist &
!==========
( nvar   , nscal  ,                                              &
  ncepdc , ncetsm ,                                              &
  icepdc , icetsm , itypsm ,                                     &
  dt     ,                                                       &
  ckupdc , smacel )

!===============================================================================
! 8. Clipping of the turbulent viscosity in dynamic LES
!===============================================================================

! Pour la LES en modele dynamique on clippe la viscosite turbulente de maniere
! a ce que mu+mu_t soit positif, .e. on autorise mu_t legerement negatif
! La diffusivite turbulente des scalaires (mu_t/sigma), elle, sera clippee a 0
! dans covofi

if (iturb.eq.41) then
  call field_get_val_s(iprpfl(iviscl), viscl)
  call field_get_val_s(iprpfl(ivisct), visct)
  iclipc = 0
  do iel = 1, ncel
    viscto = viscl(iel) + visct(iel)
    if (viscto.lt.0.d0) then
      visct(iel) = 0.d0
      iclipc = iclipc + 1
    endif
  enddo
  if (iwarni(iu).ge.1) then
    if (irangp.ge.0) then
      call parcpt(iclipc)
    endif
    write(nfecra,1000) iclipc
  endif
endif

!===============================================================================
! 9. User modification of the mesh viscosity in ALE
!===============================================================================

if (iale.eq.1.and.ntcabs.eq.0) then

  ! - Interface Code_Saturne
  !   ======================

  if (iihmpr.eq.1) then

    call uivima &
    !==========
  ( ncel,                             &
    propce(1,ipproc(ivisma(1))),      &
    propce(1,ipproc(ivisma(2))),      &
    propce(1,ipproc(ivisma(3))),      &
    xyzcen, dtref, ttcabs, ntcabs )

  endif

  call usvima &
  !==========
 ( nvar   , nscal  ,                                              &
   dt     ,                                                       &
   propce(1,ipproc(ivisma(1))) ,                                  &
   propce(1,ipproc(ivisma(2))) , propce(1,ipproc(ivisma(3))) )

endif

!===============================================================================
! 10. Checking of the user values
!===============================================================================

! ---> Calcul des bornes des variables et impressions

! Indicateur d'erreur
iok = 0

! Rang des variables dans PROPCE
call field_get_val_s(icrom, crom)
call field_get_val_s(iprpfl(iviscl), viscl)
ipcvis = ipproc(iviscl)
ipcvst = ipproc(ivisct)
if (icp.gt.0) then
  ipccp  = ipproc(icp   )
  nn     = 4
else
  ipccp = 0
  nn    = 3
endif


call field_get_val_s(ibrom, brom)

! Min et max sur les cellules
do ii = 1, nn
  ivar = 0
  if (ii.eq.1) then
    call field_get_val_s(icrom, sval)
    varmx(ii) = sval(1)
    varmn(ii) = sval(1)
    do iel = 2, ncel
      varmx(ii) = max(varmx(ii),sval(iel))
      varmn(ii) = min(varmn(ii),sval(iel))
    enddo
  else
    if (ii.eq.2) ivar = ipcvis
    if (ii.eq.3) ivar = ipcvst
    if (ii.eq.4) ivar = ipccp
    if (ivar.gt.0) then
      varmx(ii) = propce(1,ivar)
      varmn(ii) = propce(1,ivar)
      do iel = 2, ncel
        varmx(ii) = max(varmx(ii),propce(iel,ivar))
        varmn(ii) = min(varmn(ii),propce(iel,ivar))
      enddo
    endif
  endif
  if (ivar.gt.0) then
    if (irangp.ge.0) then
      call parmax (varmx(ii))
      call parmin (varmn(ii))
    endif
  endif
enddo

! Min et max sur les faces de bord (masse volumique uniquement)
ii   = 1
call field_get_val_s(ibrom, brom)
do ifac = 1, nfabor
  varmx(ii) = max(varmx(ii),brom(ifac) )
  varmn(ii) = min(varmn(ii),brom(ifac) )
enddo
if (irangp.ge.0) then
  call parmax (varmx(ii))
  call parmin (varmn(ii))
endif

! Writings
iok1 = 0
do ii = 1, nn
  if (ii.eq.1) call field_get_name(icrom, chaine)
  if (ii.eq.2) call field_get_name(iprpfl(iviscl), chaine)
  if (ii.eq.3) call field_get_name(iprpfl(ivisct), chaine)
  if (ii.eq.4) call field_get_name(iprpfl(icp), chaine)
  if (iwarni(iu).ge.1.or.ipass.eq.1.or.varmn(ii).lt.0.d0) then
    if (iok1.eq.0) then
      write(nfecra,3010)
      iok1 = 1
    endif
    if ((ii.ne.3).or.(iturb.ne.0))                          &
         write(nfecra,3011)chaine(1:16),varmn(ii),varmx(ii)
  endif
enddo
if (iok1.eq.1) write(nfecra,3012)

! Verifications de valeur physique

! Masse volumique definie
ii = 1
call field_get_name(icrom, chaine)
if (varmn(ii).lt.0.d0) then
  write(nfecra,9011)chaine(1:16),varmn(ii)
  iok = iok + 1
endif

! Viscosite moleculaire definie
ii = 2
call field_get_name(iprpfl(iviscl), chaine)
if (varmn(ii).lt.0.d0) then
  write(nfecra,9011)chaine(1:16),varmn(ii)
  iok = iok + 1
endif

! Viscosite turbulente definie
! on ne clippe pas mu_t en modele LES dynamique, car on a fait
! un clipping sur la viscosite totale
ii = 3
call field_get_name(iprpfl(ivisct), chaine)
if (varmn(ii).lt.0.d0.and.iturb.ne.41) then
  write(nfecra,9012)varmn(ii)
  iok = iok + 1
endif

! Chaleur specifique definie
if (icp.gt.0) then
  ii = 4
  call field_get_name(iprpfl(icp), chaine)
  if (varmn(ii).lt.0.d0) then
    iisct = 0
    if (itherm.ne.0) iisct = 1
    do iscal = 1, nscal
      if (iscacp(iscal).ne.0) then
        iisct = 1
      endif
    enddo
    if (iisct.eq.1) then
      write(nfecra,9011)chaine(1:16),varmn(ii)
      iok = iok + 1
    endif
  endif
endif

! ---> Calcul des bornes des scalaires et impressions

if (nscal.ge.1) then

  iok1 = 0
  do iscal = 1, nscal

    call field_get_key_int (ivarfl(isca(iscal)), kivisl, ifcvsl)
    if (ifcvsl.ge.0) then
      call field_get_val_s(ifcvsl, cpro_vis)
    endif

    vismax(iscal) = -grand
    vismin(iscal) =  grand
    if (ifcvsl.ge.0) then
      do iel = 1, ncel
        vismax(iscal) = max(vismax(iscal),cpro_vis(iel))
        vismin(iscal) = min(vismin(iscal),cpro_vis(iel))
      enddo
      if (irangp.ge.0) then
        call parmax (vismax(iscal))
        call parmin (vismin(iscal))
      endif
    else
      vismax(iscal) = visls0(iscal)
      vismin(iscal) = visls0(iscal)
    endif

    ivar = isca(iscal)
    if (iwarni(ivar).ge.1.or.ipass.eq.1.or.vismin(iscal).le.0.d0) then
      call field_get_label(ivarfl(ivar), chaine)
      if (iok1.eq.0) then
        write(nfecra,3110)
        iok1 = 1
      endif
      write(nfecra,3111) chaine(1:16),iscal,vismin(iscal),vismax(iscal)
    endif

  enddo
  if (iok1.eq.1) write(nfecra,3112)

  ! Verifications de valeur physique

  ! IOK a deja ete initialise

  do iscal = 1, nscal

    ivar = isca(iscal)

    if (vismin(iscal).lt.0.d0) then
      call field_get_label(ivarfl(ivar), chaine)
      write(nfecra,9111)chaine(1:16),iscal,vismin(iscal)
      iok = iok + 1
    endif

    if (iscal.eq.iscalt.and.irovar.eq.1.and.ityturt(iscal).eq.2) then
      iok1 = 0
      do iel = 1, ncel
        if (propce(iel,ipproc(ibeta)).le.0.d0) iok1 = 1
      enddo
      if (iok1.eq.1) write(nfecra,9013)
    endif
  enddo

endif

! ---> Calcul des bornes de viscosite de maillage en ALE

if (iale.eq.1.and.ntcabs.eq.0) then

  iok1 = 0
  nn = 1
  if (iortvm.eq.1) nn = 3
  do ii = 1, nn
    ipcvma = ipproc(ivisma(ii))

    ! Min et max sur les cellules
    varmx(1) = propce(1,ipcvma)
    varmn(1) = propce(1,ipcvma)
    do iel = 2, ncel
      varmx(1) = max(varmx(1),propce(iel,ipcvma))
      varmn(1) = min(varmn(1),propce(iel,ipcvma))
    enddo
    if (irangp.ge.0) then
      call parmax (varmx(1))
      call parmin (varmn(1))
    endif

    ! Writings
    call field_get_name(iprpfl(ipcvma), chaine)
    if (iwarni(iuma).ge.1.or.ipass.eq.1.or.varmn(1).lt.0.d0) then
      if (iok1.eq.0) then
        write(nfecra,3210)
        iok1 = 1
      endif
      write(nfecra,3211)chaine(1:16),varmn(1),varmx(1)
    endif

    ! Verifications de valeur physique

    ! Viscosite de maillage definie
    call field_get_name(iprpfl(ipcvma), chaine)
    if (varmn(1).le.0.d0) then
      write(nfecra,9211) varmn(1)
      iok = iok + 1
    endif

  enddo

  if (iok1.eq.1) write(nfecra,3212)

endif

! --->  arret eventuel

if (iok.ne.0) then
  write(nfecra,9999)iok
  call csexit (1)
endif

!===============================================================================
! 11. Parallelism and periodicity
!===============================================================================

! Pour navstv et visecv on a besoin de ROM dans le halo

call field_get_val_s(icrom, crom)

if (irangp.ge.0.or.iperio.eq.1) then
  call synsca(crom)
endif

!--------
! Formats
!--------

#if defined(_CS_LANG_FR)

 1000 format(                                                     &
' Nb de clippings de la viscosite totale (mu+mu_t>0) :',i10,/)
 3010 format(                                                     &
' -----------------------------------------',                   /,&
' Propriete          Valeur min  Valeur max',                   /,&
' -----------------------------------------                   '  )
 3011 format(                                                     &
 2x,    a16,      e12.4,      e12.4                              )
 3012 format(                                                     &
' -----------------------------------------',                   /)
 3110 format(                                                     &
' --- Diffusivite :',                                           /,&
' -----------------------------------------------',             /,&
' Scalaire         Numero  Valeur min  Valeur max',             /,&
' -----------------------------------------------'               )
 3111 format(                                                     &
 1x,    a16,   i7,      e12.4,      e12.4                        )
 3112 format(                                                     &
' ---------------------------------------',                     /)
 3210 format(                                                     &
' --- Viscosite de maillage (methode ALE)',                     /,&
' -----------------------------------------',                   /,&
' Propriete          Valeur min  Valeur max',                   /,&
' -----------------------------------------'                     )
 3211 format(                                                     &
 2x,    a16,      e12.4,      e12.4                              )
 3212 format(                                                     &
' -----------------------------------------',                   /)

 9001  format(                                                    &
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /,&
'@ @@ ATTENTION : ARRET LORS DU CALCUL DES GRANDEURS PHYSIQUES',/,&
'@    =========',                                               /,&
'@    INCOHERENCE ENTRE LES PARAMETRES ET LA MASSE VOLUMIQUE',  /,&
'@',                                                            /,&
'@  On a indique que la masse volumique etait',                 /,&
'@     constante (IROVAR=0) mais on a modifie ses',             /,&
'@     valeurs aux cellules ou aux faces de bord.',             /,&
'@',                                                            /,&
'@  Le calcul ne sera pas execute.',                            /,&
'@',                                                            /,&
'@  Verifier l''interface, cs_user_parameters.f90, et usphyv.', /,&
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /)
 9002  format(                                                    &
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /,&
'@ @@ ATTENTION : ARRET LORS DU CALCUL DES GRANDEURS PHYSIQUES',/,&
'@    =========',                                               /,&
'@    INCOHERENCE ENTRE LES PARAMETRES ET',                     /,&
'@                                    LA VISCOSITE MOLECULAIRE',/,&
'@',                                                            /,&
'@  On a indique que la viscosite moleculaire',                 /,&
'@     etait constante (IVIVAR=0) mais on a modifie ses',/,&
'@     valeurs aux cellules.',                                  /,&
'@',                                                            /,&
'@  Le calcul ne sera pas execute.',                            /,&
'@',                                                            /,&
'@  Verifier l''interface, cs_user_parameters.f90, et usphyv.', /,&
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /)
 9003  format(                                                    &
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /,&
'@ @@ ATTENTION : ARRET LORS DU CALCUL DES GRANDEURS PHYSIQUES',/,&
'@    =========',                                               /,&
'@    MODULE COMPRESSIBLE',                                     /,&
'@    INCOHERENCE ENTRE USCFPV ET USCFX2 POUR',                 /,&
'@                                    LA VISCOSITE MOLECULAIRE',/,&
'@',                                                            /,&
'@  En compressible la viscosite moleculaire est constante par',/,&
'@     defaut (IVIVAR=0) et la valeur de IVIVAR n''a',   /,&
'@     pas ete modifiee dans uscfx2. Pourtant, on a modifie',   /,&
'@     les valeurs de la viscosite moleculaire dans usphyv.',   /,&
'@',                                                            /,&
'@  Le calcul ne sera pas execute.',                            /,&
'@',                                                            /,&
'@  Verifier uscfx2 et usphyv.',                                /,&
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /)
 9011  format(                                                    &
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /,&
'@ @@ ATTENTION : ARRET LORS DU CALCUL DES GRANDEURS PHYSIQUES',/,&
'@    =========',                                               /,&
'@    LA PROPRIETE PHYSIQUE ', a16  ,' N A PAS ETE',            /,&
'@                                       CORRECTEMENT DEFINIE.',/,&
'@',                                                            /,&
'@  Le calcul ne sera pas execute.',                            /,&
'@',                                                            /,&
'@  La propriete physique identifiee ci-dessus est variable et',/,&
'@    le minimum atteint est', e12.4                           ,/,&
'@  Verifier que cette propriete a ete definie et',             /,&
'@    que la loi adoptee conduit a des valeurs correctes.',     /,&
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /)
 9012  format(                                                    &
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /,&
'@ @@ ATTENTION : ARRET LORS DU CALCUL DES GRANDEURS PHYSIQUES',/,&
'@    =========',                                               /,&
'@    LA VISCOSITE TURBULENTE',                                 /,&
'@                           N A PAS ETE CORRECTEMENT DEFINIE.',/,&
'@',                                                            /,&
'@  Le calcul ne sera pas execute.',                            /,&
'@',                                                            /,&
'@  Le minimum atteint est', e12.4                             ,/,&
'@  Verifier le cas echeant la definition de la masse',         /,&
'@    volumique et la modification de la viscosite turbulente', /,&
'@    dans usvist.',                                            /,&
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /)
 9013  format(                                                    &
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /,&
'@ @@ ATTENTION : ARRET LORS DU CALCUL DES GRANDEURS PHYSIQUES',/,&
'@    =========',                                               /,&
'@    INCOHERENCE ENTRE LES PARAMETRES ET LE COEFFICIENT'      ,/,&
'@    de dilatation volumique  Beta'                           ,/,&
'@',                                                            /,&
'@  On a indique que la masse volumique etait',                 /,&
'@     variable (IROVAR=1) mais on n a pas modifie ',           /,&
'@     la valeur de Beta dans l''interface ou dans usphyv',     /,&
'@',                                                            /,&
'@  Le calcul ne sera pas execute.',                            /,&
'@',                                                            /,&
'@  Verifier l''interface et usphyv.'                         , /,&
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /)

 9111  format(                                                    &
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /,&
'@ @@ ATTENTION : ARRET LORS DU CALCUL DES GRANDEURS PHYSIQUES',/,&
'@    =========',                                               /,&
'@    LA DIFFUSIVITE DU SCALAIRE ', a16                        ,/,&
'@       (SCALAIRE NUMERO', i10   ,') N A PAS ETE',             /,&
'@                                       CORRECTEMENT DEFINIE.',/,&
'@',                                                            /,&
'@  Le calcul ne sera pas execute.',                            /,&
'@',                                                            /,&
'@  La propriete physique identifiee ci-dessus est variable et',/,&
'@    le minimum atteint est', e12.4                           ,/,&
'@  Verifier que cette propriete a bien ete definie et',        /,&
'@    que la loi adoptee conduit a des valeurs correctes.',     /,&
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /)
 9211  format(                                                    &
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /,&
'@ @@ ATTENTION : ARRET LORS DU CALCUL DES GRANDEURS PHYSIQUES',/,&
'@    =========',                                               /,&
'@    LA VISCOSITE DE MAILLAGE N A PAS ETE',                    /,&
'@                                       CORRECTEMENT DEFINIE.',/,&
'@',                                                            /,&
'@  Le calcul ne sera pas execute.',                            /,&
'@',                                                            /,&
'@  Le minimum atteint est', e12.4                             ,/,&
'@  Verifier le cas echeant la modification de la viscosite',   /,&
'@    dans usvima ou dans l''interface graphique.',             /,&
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /)
 9999 format(                                                     &
'@',                                                            /,&
'@',                                                            /,&
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /,&
'@ @@ ATTENTION : ARRET LORS DU CALCUL DES GRANDEURS PHYSIQUES',/,&
'@    =========',                                               /,&
'@    DES GRANDEURS PHYSIQUES ONT DES VALEURS INCORRECTES',     /,&
'@',                                                            /,&
'@  Le calcul ne sera pas execute (',i10,' erreurs).',          /,&
'@',                                                            /,&
'@  Se reporter aux impressions precedentes pour plus de',      /,&
'@    renseignements.',                                         /,&
'@  Verifier les definitions et lois definies',                 /,&
'@    dans usphyv ou dans l''interface graphique.',             /,&
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /)

#else

 1000 format(                                                     &
' Nb of clippings for the effective viscosity (mu+mu_t>0):',i10,/)
 3010 format(                                                     &
' -----------------------------------------',                   /,&
' Property           Min. value  Max. value',                   /,&
' -----------------------------------------'                     )
 3011 format(                                                     &
 2x,    a16,      e12.4,      e12.4                              )
 3012 format(                                                     &
' -----------------------------------------',                   /)
 3110 format(                                                     &
' --- Diffusivity:',                                            /,&
' -----------------------------------------------',             /,&
' Scalar           Number  Min. value  Max. value',             /,&
' -----------------------------------------------'               )
 3111 format(                                                     &
 1x,    a16,   i7,      e12.4,      e12.4                        )
 3112 format(                                                     &
' -----------------------------------------------',             /)
 3210 format(                                                     &
' --- Mesh viscosity (ALE method)',                             /,&
' -----------------------------------------',                   /,&
' Property           Min. value  Max. value',                   /,&
' -----------------------------------------'                     )
 3211 format(                                                     &
 2x,    a16,      e12.4,      e12.4                              )
 3212 format(                                                     &
' -----------------------------------------',                   /)

 9001  format(                                                    &
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /,&
'@ @@ WARNING: ABORT IN THE PHYSICAL QUANTITIES COMPUTATION',   /,&
'@    ========',                                                /,&
'@    INCOHERENCY BETWEEN PARAMETERS FOR THE DENSITY.',         /,&
'@',                                                            /,&
'@  The density has been declared constant',                    /,&
'@     (IROVAR=0) but its value has been modified',             /,&
'@     in cells or at boundary faces.',                         /,&
'@',                                                            /,&
'@  The calculation will not be run.',                          /,&
'@',                                                            /,&
'@  Check the interface, cs_user_parameters.f90, and usphyv',   /,&
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /)
 9002  format(                                                    &
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /,&
'@ @@ WARNING: ABORT IN THE PHYSICAL QUANTITIES COMPUTATION',   /,&
'@    ========',                                                /,&
'@    INCOHERENCY BETWEEN PARAMETERS FOR',                      /,&
'@                                     THE MOLECULAR VISCOSITY',/,&
'@',                                                            /,&
'@  The molecular viscosity has been declared constant',        /,&
'@     (IVIVAR=0) but its value has been  modified in cells',   /,&
'@     or at boundary faces.',                                  /,&
'@',                                                            /,&
'@  The calculation will not be run.',                          /,&
'@',                                                            /,&
'@  Check the interface, cs_user_parameters.f90, and usphyv',   /,&
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /)
 9003  format(                                                    &
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /,&
'@ @@ WARNING: ABORT IN THE PHYSICAL QUANTITIES COMPUTATION',   /,&
'@    ========',                                                /,&
'@    INCOHERENCY BETWEEN USCFPV AND USCFX2 FOR',               /,&
'@                                     THE MOLECULAR VISCOSITY',/,&
'@',                                                            /,&
'@  In the compressible module, the molecular viscosity is',    /,&
'@     constant by default (IVIVAR=0) and the value',    /,&
'@     of IVIVAR  has not been modified in uscfx2. Yet, its',   /,&
'@     value has been modified in usphyv.',                     /,&
'@',                                                            /,&
'@  The calculation will not be run.',                          /,&
'@',                                                            /,&
'@  Verify uscfx2 and usphyv.',                                 /,&
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /)
 9011  format(                                                    &
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /,&
'@ @@ WARNING: ABORT IN THE PHYSICAL QUANTITIES COMPUTATION',   /,&
'@    ========',                                                /,&
'@    THE PHYSICAL PROPERTY ', a16  ,' HAS NOT BEEN',           /,&
'@                                          CORRECTLY DEFINED.',/,&
'@',                                                            /,&
'@  The calculation will not be run.',                          /,&
'@',                                                            /,&
'@  The physical property identified is variable and the',      /,&
'@    minimum reached is', e12.4                               ,/,&
'@  Verify that this property has been defined and',            /,&
'@    that the chosen law leads to correct values.',            /,&
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /)
 9012  format(                                                    &
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /,&
'@ @@ WARNING: ABORT IN THE PHYSICAL QUANTITIES COMPUTATION',   /,&
'@    ========',                                                /,&
'@    THE TURBULENT VISCOSITY HAS NOT BEEN CORRECTLY DEFINED.', /,&
'@',                                                            /,&
'@  The calculation will not be run.',                          /,&
'@',                                                            /,&
'@  The  minimum reached is', e12.4                            ,/,&
'@  Verify the density definition  and the turbulent viscosity',/,&
'@    modification in usvist (if any).',                        /,&
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /)
 9013  format( &
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /,&
'@ @@ WARNING : ABORT IN THE PHYSICAL QUANTITIES COMPUTATION',  /,&
'@    =========',                                               /,&
'@    INCOHERENCY BETWEEN PARAMETERS and the volumic thermal'  ,/,&
'@    expansion coefficient Beta'                              ,/,&
'@',                                                            /,&
'@  The density has been declared variable (IROVAR=1) but',     /,&
'@     the value of Beta has not been modified     ',           /,&
'@     in GUI or usphyv',                                       /,&
'@',                                                            /,&
'@  The calculation will not be run',                           /,&
'@',                                                            /,&
'@  Check the interface or usphyv.'                           , /,&
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@', /)


 9111  format(                                                    &
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /,&
'@ @@ WARNING: ABORT IN THE PHYSICAL QUANTITIES COMPUTATION',   /,&
'@    ========',                                                /,&
'@    THE DIFFUSIVITY OF THE SCALAR ', a16                     ,/,&
'@       (SCALAR NUMBER', i10   ,') HAS NOT BEEN',              /,&
'@                                          CORRECTLY DEFINED.',/,&
'@',                                                            /,&
'@  The calculation will not be run.',                          /,&
'@',                                                            /,&
'@  The physical property identified is variable and the',      /,&
'@    minimum reached is', e12.4                               ,/,&
'@  Verify that this property has been defined in usphyv and',  /,&
'@    that the chosen law leads to correct values.',            /,&
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /)
 9211  format(                                                    &
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /,&
'@ @@ WARNING: ABORT IN THE PHYSICAL QUANTITIES COMPUTATION',   /,&
'@    ========',                                                /,&
'@    THE MESH VISCOSITY HAS NOT BEEN CORRECTLY DEFINED.',      /,&
'@',                                                            /,&
'@  The calculation will not be run.',                          /,&
'@',                                                            /,&
'@  The  minimum reached is', e12.4                            ,/,&
'@  Verify that this property has been defined in usvima and',  /,&
'@    that the chosen law leads to correct values.',            /,&
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /)
 9999 format(                                                     &
'@',                                                            /,&
'@',                                                            /,&
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /,&
'@ @@ WARNING: ABORT IN THE PHYSICAL QUANTITIES COMPUTATION',   /,&
'@    ========',                                                /,&
'@    SOME PHYSICAL QUANTITIES HAVE INCORRECT VALUES',          /,&
'@',                                                            /,&
'@  The calculation will not be run (',i10,' errors).',         /,&
'@',                                                            /,&
'@  Refer to previous warnings for further information.',       /,&
'@  Verify usphyv.',                                            /,&
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /)

#endif

!----
! End
!----

return
end subroutine
