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

!> \file predvv.f90
!>
!> \brief This subroutine perform the velocity prediction step of the Navier
!> Stokes equations for incompressible or slightly compressible flows for
!> the coupled velocity components solver.
!>
!> - at the first call, the predicted velocities are computed and also
!>   an estimator on the predicted velocity is computed.
!>
!> - at the second call, a global estimator on Navier Stokes is computed.
!>   This second call is done after the correction step (\ref resopv).
!>
!-------------------------------------------------------------------------------

!-------------------------------------------------------------------------------
! Arguments
!______________________________________________________________________________.
!  mode           name          role                                           !
!______________________________________________________________________________!
!> \param[in]     iappel        call number (1 or 2)
!> \param[in]     nvar          total number of variables
!> \param[in]     nscal         total number of scalars
!> \param[in]     iterns        index of the iteration on Navier-Stokes
!> \param[in]     ncepdp        number of cells with head loss
!> \param[in]     ncesmp        number of cells with mass source term
!> \param[in]     nfbpcd        number of faces with condensation source terms
!> \param[in]     ncmast        number of cells with condensation source terms
!> \param[in]     icepdc        index of cells with head loss
!> \param[in]     icetsm        index of cells with mass source term
!> \param[in]     ifbpcd        index of faces with condensation source terms
!> \param[in]     ltmast        index of cells with condensation source terms
!> \param[in]     itypsm        type of mass source term for the variables
!> \param[in]     itypcd        type of condensation source terms for the variables
!> \param[in]     dt            time step (per cell)
!> \param[in]     vel           velocity
!> \param[in]     vela          velocity at the previous time step
!> \param[in]     propce        physical properties at cell centers
!> \param[in]     flumas        internal mass flux (depending on iappel)
!> \param[in]     flumab        boundary mass flux (depending on iappel)
!> \param[in]     tslagr        coupling term for the Lagrangian module
!> \param[in]     coefav        boundary condition array for the variable
!>                               (explicit part)
!> \param[in]     coefbv        boundary condition array for the variable
!>                               (implicit part)
!> \param[in]     cofafv        boundary condition array for the diffusion
!>                               of the variable (explicit part)
!> \param[in]     cofbfv        boundary condition array for the diffusion
!>                               of the variable (implicit part)
!> \param[in]     ckupdc        work array for the head loss
!> \param[in]     smacel        variable value associated to the mass source
!>                               term (for ivar=ipr, smacel is the mass flux
!>                               \f$ \Gamma^n \f$)
!> \param[in]     spcond        variable value associated to the condensation
!>                              source term (for ivar=ipr, spcond is the flow rate
!>                              \f$ \Gamma_{s, cond}^n \f$)
!> \param[in]     svcond        variable value associated to the condensation
!>                              source term (for ivar=ipr, svcond is the flow rate
!>                              \f$ \Gamma_{v, cond}^n \f$)
!> \param[in]     frcxt         external forces making hydrostatic pressure
!> \param[in]     trava         working array for the velocity-pressure coupling
!> \param[in]     ximpa         same
!> \param[in]     uvwk          same (stores the velocity at the previous iteration)
!> \param[in]     dfrcxt        variation of the external forces
!                               making the hydrostatic pressure
!> \param[in]     grdphd        hydrostatic pressure gradient to handle the
!>                              imbalance between the pressure gradient and
!>                              gravity source term
!> \param[in]     tpucou        non scalar time step in case of
!>                              velocity pressure coupling
!> \param[in]     trav          right hand side for the normalizing
!>                              the residual
!> \param[in]     viscf         visc*surface/dist aux faces internes
!> \param[in]     viscb         visc*surface/dist aux faces de bord
!> \param[in]     viscfi        same as viscf for increments
!> \param[in]     viscbi        same as viscb for increments
!> \param[in]     secvif        secondary viscosity at interior faces
!> \param[in]     secvib        secondary viscosity at boundary faces
!> \param[in]     w1            working array
!> \param[in]     w7            working array
!> \param[in]     w8            working array
!> \param[in]     w9            working array
!> \param[in]     xnormp        workig array for the norm of the pressure
!_______________________________________________________________________________

subroutine predvv &
 ( iappel ,                                                       &
   nvar   , nscal  , iterns ,                                     &
   ncepdp , ncesmp , nfbpcd , ncmast ,                            &
   icepdc , icetsm , ifbpcd , ltmast ,                            &
   itypsm , itypcd ,                                              &
   dt     , vel    , vela   ,                                     &
   propce ,                                                       &
   flumas , flumab ,                                              &
   tslagr , coefav , coefbv , cofafv , cofbfv ,                   &
   ckupdc , smacel , spcond , svcond , frcxt  , grdphd ,          &
   trava  , ximpa  , uvwk   , dfrcxt , tpucou , trav   ,          &
   viscf  , viscb  , viscfi , viscbi , secvif , secvib ,          &
   w1     , w7     , w8     , w9     , xnormp )

!===============================================================================

!===============================================================================
! Module files
!===============================================================================

use paramx
use dimens, only: ndimfb
use numvar
use entsor
use cstphy
use cstnum
use optcal
use parall
use period
use lagpar
use lagran
use ppppar
use ppthch
use ppincl
use cplsat
use ihmpre, only: iihmpr
use mesh
use rotation
use turbomachinery
use cs_f_interfaces
use cs_c_bindings
use cfpoin
use field
use field_operator
use pointe, only: gamcav
use cavitation
use cs_tagms, only:s_metal

!===============================================================================

implicit none

! Arguments

integer          iappel
integer          nvar   , nscal  , iterns
integer          ncepdp , ncesmp , nfbpcd , ncmast

integer          icepdc(ncepdp)
integer          icetsm(ncesmp), itypsm(ncesmp,nvar)
integer          ifbpcd(nfbpcd), itypcd(nfbpcd,nvar)
integer          ltmast(ncelet)

double precision dt(ncelet)
double precision propce(ncelet,*)
double precision flumas(nfac), flumab(nfabor)
double precision tslagr(ncelet,*)
double precision ckupdc(ncepdp,6), smacel(ncesmp,nvar)
double precision spcond(nfbpcd,nvar), svcond(ncelet,nvar)
double precision frcxt(3,ncelet), dfrcxt(3,ncelet)
double precision grdphd(ncelet,3)
double precision trava(ndim,ncelet)
double precision ximpa(ndim,ndim,ncelet),uvwk(ndim,ncelet)
double precision tpucou(6, ncelet)
double precision trav(3,ncelet)
double precision viscf(*), viscb(nfabor)
double precision viscfi(*), viscbi(nfabor)
double precision secvif(nfac), secvib(nfabor)
double precision w1(ncelet)
double precision w7(ncelet), w8(ncelet), w9(ncelet)
double precision xnormp(ncelet)
double precision coefav(3  ,ndimfb)
double precision cofafv(3  ,ndimfb)
double precision coefbv(3,3,ndimfb)
double precision cofbfv(3,3,ndimfb)

double precision vel   (3  ,ncelet)
double precision vela  (3  ,ncelet)

! Local variables

integer          f_id  , iel   , ielpdc, ifac  , isou  , itypfl
integer          iccocg, inc   , iprev , init  , ii    , jj    , isqrt
integer          nswrgp, imligp, iwarnp
integer          iswdyp, idftnp
integer          iconvp, idiffp, ndircp, nswrsp
integer          ircflp, ischcp, isstpp, iescap
integer          iflmb0, nswrp
integer          idtva0, icvflb
integer          jsou, ivisep
integer          ivoid(1)

double precision rnorm , vitnor
double precision romvom, drom  , rom
double precision epsrgp, climgp, extrap, relaxp, blencp, epsilp
double precision epsrsp
double precision vit1  , vit2  , vit3, xkb, pip, pfac, pfac1
double precision cpdc11, cpdc22, cpdc33, cpdc12, cpdc13, cpdc23
double precision d2s3  , thetap, thetp1, thets , dtsrom
double precision diipbx, diipby, diipbz
double precision ccorio
double precision dvol

double precision rvoid(1)

! Working arrays
double precision, allocatable, dimension(:,:) :: eswork
double precision, allocatable, dimension(:,:) :: grad, gradni
double precision, dimension(:,:), allocatable :: smbr
double precision, dimension(:,:,:), allocatable :: fimp
double precision, dimension(:,:), allocatable :: gavinj
double precision, dimension(:,:), allocatable :: tsexp
double precision, dimension(:,:,:), allocatable :: tsimp
double precision, allocatable, dimension(:,:) :: viscce
double precision, dimension(:,:), allocatable :: vect
double precision, dimension(:), allocatable :: xinvro
double precision, dimension(:), pointer :: brom, crom, croma, pcrom
double precision, dimension(:), pointer :: coefa_k, coefb_k
double precision, dimension(:), pointer :: coefa_p, coefb_p
double precision, dimension(:), pointer :: porosi
double precision, dimension(:), pointer :: volf
double precision, allocatable, dimension(:), target :: xvolf
double precision, dimension(:,:), allocatable :: rij
double precision, dimension(:), pointer :: coef1, coef2, coef3, coef4, coef5, coef6
double precision, dimension(:,:), allocatable :: coefat
double precision, dimension(:,:,:), allocatable :: coefbt
double precision, dimension(:,:), allocatable :: tflmas, tflmab
double precision, dimension(:,:), allocatable :: divt
double precision, dimension(:,:), pointer :: forbr, c_st_vel
double precision, dimension(:), pointer :: cvara_pr, cvara_k
double precision, dimension(:), pointer :: cvara_r11, cvara_r22, cvara_r33
double precision, dimension(:), pointer :: cvara_r12, cvara_r23, cvara_r13
double precision, dimension(:), pointer :: viscl, visct, c_estim

double precision, allocatable, dimension(:) :: surfbm

!===============================================================================

!===============================================================================
! 1. Initialization
!===============================================================================

! Allocate temporary arrays
allocate(smbr(3,ncelet))
allocate(fimp(3,3,ncelet))
allocate(tsexp(3,ncelet))
allocate(tsimp(3,3,ncelet))
if (idften(iu).eq.6) allocate(viscce(6,ncelet))

! Allocate a temporary array for the prediction-stage error estimator
if (iescal(iespre).gt.0) then
  allocate(eswork(3,ncelet))
endif

! Reperage de rho au bord
call field_get_val_s(ibrom, brom)
! Reperage de rho courant (ie en cas d'extrapolation rho^n+1/2)
call field_get_val_s(icrom, crom)
! Reperage de rho^n en cas d'extrapolation
if (iroext.gt.0.or.idilat.gt.1) then
  call field_get_val_prev_s(icrom, croma)
endif

if (iappel.eq.2) then
  if (ineedf.eq.1 .and. iterns.eq.1 .or. icavit.ge.0) then
    call field_get_val_s(ivarfl(ipr), cvara_pr)
  endif
  if(ineedf.eq.1 .and. iterns.eq.1                                          &
     .and. (itytur.eq.2 .or. itytur.eq.5 .or. iturb.eq.60) .and. igrhok.eq.1) then
    call field_get_val_s(ivarfl(ik), cvara_k)
  endif
  if (itytur.eq.3.and.iterns.eq.1) then
    call field_get_val_s(ivarfl(ir11), cvara_r11)
    call field_get_val_s(ivarfl(ir22), cvara_r22)
    call field_get_val_s(ivarfl(ir33), cvara_r33)
    call field_get_val_s(ivarfl(ir12), cvara_r12)
    call field_get_val_s(ivarfl(ir23), cvara_r23)
    call field_get_val_s(ivarfl(ir13), cvara_r13)
  endif
else
  if (ineedf.eq.1 .and. iterns.eq.1 .or. icavit.ge.0) then
    call field_get_val_prev_s(ivarfl(ipr), cvara_pr)
  endif
  if(ineedf.eq.1 .and. iterns.eq.1                                          &
     .and. (itytur.eq.2 .or. itytur.eq.5 .or. iturb.eq.60) .and. igrhok.eq.1) then
      call field_get_val_prev_s(ivarfl(ik), cvara_k)
  endif
  if (itytur.eq.3.and.iterns.eq.1) then
    call field_get_val_prev_s(ivarfl(ir11), cvara_r11)
    call field_get_val_prev_s(ivarfl(ir22), cvara_r22)
    call field_get_val_prev_s(ivarfl(ir33), cvara_r33)
    call field_get_val_prev_s(ivarfl(ir12), cvara_r12)
    call field_get_val_prev_s(ivarfl(ir23), cvara_r23)
    call field_get_val_prev_s(ivarfl(ir13), cvara_r13)
  endif
endif

! Compute the Volume of fluid (in case of porosity)
if (iporos.eq.0)  then
  volf => volume(:)

! With porosity
else

  call field_get_val_s(ipori, porosi)

  allocate(xvolf(ncelet))

  do iel = 1, ncel
    xvolf(iel) = volume(iel) * porosi(iel)
  enddo

  if (irangp.ge.0.or.iperio.eq.1) then
    call synsca(xvolf)
  endif

  volf => xvolf(:)

endif

if (ineedf.eq.1 .and. iterns.eq.1) call field_get_val_v(iforbr, forbr)

! Theta relatif aux termes sources explicites
thets  = thetsn
if (isno2t.gt.0) then
  call field_get_key_int(ivarfl(iu), kstprv, f_id)
  call field_get_val_v(f_id, c_st_vel)
else
  c_st_vel => null()
endif

! Coefficient of the "Coriolis-type" term
if (icorio.eq.1) then
  ! Relative velocity formulation
  ccorio = 2.d0
elseif (iturbo.eq.1) then
  ! Mixed relative/absolute velocity formulation
  ccorio = 1.d0
else
  ccorio = 0.d0
endif

!===============================================================================
! 2. Potential forces (pressure gradient and gravity)
!===============================================================================

!-------------------------------------------------------------------------------
! ---> Pressure gradient

! Allocate a work array for the gradient calculation
allocate(grad(3,ncelet))

iccocg = 1
inc    = 1

! For compressible flows, the new Pressure field is required
if (ippmod(icompf).ge.0) then
  iprev = 0
! For incompressible flows, keep the pressure at time n
! in case of PISO algorithm
else
  iprev = 1
endif

if (icavit.lt.0) then
  call field_gradient_potential(ivarfl(ipr), iprev, imrgra, inc,    &
                                iccocg, iphydr,                     &
                                frcxt, grad)

else

  ! Cavitating flows: consistency of the gradient with the diffusive flux scheme
  ! of the correction step

  call field_get_coefa_s (ivarfl(ipr), coefa_p)
  call field_get_coefb_s (ivarfl(ipr), coefb_p)

  allocate(gradni(ncelet,3))
  allocate(xinvro(ncelet))

  do iel = 1, ncel
    xinvro(iel) = 1.d0/crom(iel)
  enddo

  iccocg = 1
  inc    = 1
  nswrgp = nswrgr(ipr)
  imligp = imligr(ipr)
  iwarnp = iwarni(ipr)
  epsrgp = epsrgr(ipr)
  climgp = climgr(ipr)
  extrap = extrag(ipr)

  call grdpre (ipr, imrgra, inc, iccocg, nswrgp, imligp,  &
               iwarnp, epsrgp, climgp, extrap,            &
               cvara_pr, xinvro, coefa_p, coefb_p,        &
               gradni )

  do iel = 1, ncelet
    do isou = 1, 3
      grad(isou,iel) = gradni(iel,isou)
    enddo
  enddo

  deallocate(gradni)
  deallocate(xinvro)

endif


!    Calcul des efforts aux parois (partie 2/5), si demande
!    La pression a la face est calculee comme dans gradrc/gradmc
!    et on la transforme en pression totale
!    On se limite a la premiere iteration (pour faire simple par
!      rapport a la partie issue de condli, hors boucle)
if (ineedf.eq.1 .and. iterns.eq.1) then
  call field_get_coefa_s (ivarfl(ipr), coefa_p)
  call field_get_coefb_s (ivarfl(ipr), coefb_p)
  do ifac = 1, nfabor
    iel = ifabor(ifac)
    diipbx = diipb(1,ifac)
    diipby = diipb(2,ifac)
    diipbz = diipb(3,ifac)
    pip = cvara_pr(iel) &
        + diipbx*grad(1,iel) + diipby*grad(2,iel) + diipbz*grad(3,iel)
    pfac = coefa_p(ifac) +coefb_p(ifac)*pip
    pfac1= cvara_pr(iel)                                              &
         +(cdgfbo(1,ifac)-xyzcen(1,iel))*grad(1,iel)              &
         +(cdgfbo(2,ifac)-xyzcen(2,iel))*grad(2,iel)              &
         +(cdgfbo(3,ifac)-xyzcen(3,iel))*grad(3,iel)
    pfac = coefb_p(ifac)*(extrag(ipr)*pfac1                       &
         +(1.d0-extrag(ipr))*pfac)                                &
         +(1.d0-coefb_p(ifac))*pfac                               &
         + ro0*(gx*(cdgfbo(1,ifac)-xyzp0(1))                      &
         + gy*(cdgfbo(2,ifac)-xyzp0(2))                           &
         + gz*(cdgfbo(3,ifac)-xyzp0(3)) )                         &
         - pred0
! on ne rajoute pas P0, pour garder un maximum de precision
!     &         + P0
    do isou = 1, 3
      forbr(isou,ifac) = forbr(isou,ifac) + pfac*surfbo(isou,ifac)
    enddo
  enddo
endif

!-------------------------------------------------------------------------------
! ---> RESIDU DE NORMALISATION POUR RESOLP
!     Test d'un residu de normalisation de l'etape de pression
!       plus comprehensible = div(rho u* + dt gradP^(n))-Gamma
!       i.e. second membre du systeme en pression hormis la partie
!       pression (sinon a convergence, on tend vers 0)
!       Represente les termes que la pression doit equilibrer
!     On calcule ici div(rho dt/rho gradP^(n)) et on complete a la fin
!       avec  div(rho u*)
!     Pour grad P^(n) on suppose que des CL de Neumann homogenes
!       s'appliquent partout : on peut donc utiliser les CL de la
!       vitesse pour u*+dt/rho gradP^(n). Comme on calcule en deux fois,
!       on utilise les CL de vitesse homogenes pour dt/rho gradP^(n)
!       ci-dessous et les CL de vitesse completes pour u* a la fin.

if (iappel.eq.1.and.irnpnw.eq.1) then

!     Calcul de dt/rho*grad P
  do iel = 1, ncel
    dtsrom = dt(iel)/crom(iel)
    trav(1,iel) = grad(1,iel)*dtsrom
    trav(2,iel) = grad(2,iel)*dtsrom
    trav(3,iel) = grad(3,iel)*dtsrom
  enddo

  if (irangp.ge.0.or.iperio.eq.1) then
    call synvin(trav)
    !==========
  endif

!     Calcul de rho dt/rho*grad P.n aux faces
!       Pour gagner du temps, on ne reconstruit pas.
  itypfl = 1
  ! Cavitation algorithm: the pressure step corresponds to the
  ! correction of the volumetric flux, not the mass flux
  if (icavit.ge.0)  itypfl = 0
  init   = 1
  inc    = 0
  iflmb0 = 1
  nswrp  = 1
  imligp = imligr(iu )
  iwarnp = iwarni(ipr)
  epsrgp = epsrgr(iu )
  climgp = climgr(iu )

  call inimav                                                     &
  !==========
 ( ivarfl(iu)      , itypfl ,                                     &
   iflmb0 , init   , inc    , imrgra , nswrp  , imligp ,          &
   iwarnp ,                                                       &
   epsrgp , climgp ,                                              &
   crom   , brom   ,                                              &
   trav   ,                                                       &
   coefav , coefbv ,                                              &
   viscf  , viscb  )

!     Calcul de div(rho dt/rho*grad P)
  init = 1
  call divmas(init,viscf,viscb,xnormp)

!-- Volumic Gamma source term adding for volumic mass flow rate
  if (ncesmp.gt.0) then
    do ii = 1, ncesmp
      iel = icetsm(ii)
      xnormp(iel) = xnormp(iel) - volf(iel)*smacel(ii,ipr)
    enddo
  endif

!-- Surface Gamma source term adding for surface condensation modelling
  if (nfbpcd.gt.0) then
    do ii = 1, nfbpcd
      ifac= ifbpcd(ii)
      iel = ifabor(ifac)
      xnormp(iel) = xnormp(iel) - surfbn(ifac) * spcond(ii,ipr)
    enddo
  endif

! --- volume Gamma source term adding for volume condensation modelling
  if (icond.eq.1) then
    allocate(surfbm(ncelet))
    surfbm(:) = 0.d0

    do ii = 1, ncmast
      iel= ltmast(ii)
      surfbm(iel) = s_metal*volume(iel)/voltot
      xnormp(iel) = xnormp(iel)  - surfbm(iel)*svcond(iel,ipr)
    enddo

    deallocate(surfbm)
  endif

  ! Dilatable mass conservative algorithm
  if (idilat.eq.2) then
    do iel = 1, ncel
      drom = crom(iel) - croma(iel)
      xnormp(iel) = xnormp(iel) + drom*volf(iel)/dt(iel)
    enddo
  ! Semi-analytic weakly compressible algorithm add + 1/rho Drho/Dt
  else if (idilat.eq.4)then
    do iel = 1, ncel
      xnormp(iel) = xnormp(iel) + propce(iel,ipproc(iustdy(itsrho)))/crom(iel)
    enddo
  else if (idilat.eq.5) then
    do iel = 1, ncel
      xnormp(iel) = xnormp(iel) + propce(iel,ipproc(iustdy(itsrho)))
    enddo

  endif

  ! Cavitation source term
  if (icavit.gt.0) then
    do iel = 1, ncel
      xnormp(iel) = xnormp(iel) -volf(iel)*gamcav(iel)*(1.d0/rov - 1.d0/rol)
    enddo
  endif

!     On conserve XNORMP, on complete avec u* a la fin et
!       on le transfere a resopv

endif


!     Au premier appel, TRAV est construit directement ici.
!     Au second  appel (estimateurs), TRAV contient deja
!       l'increment temporel.
!     On pourrait fusionner en initialisant TRAV a zero
!       avant le premier appel, mais ca fait des operations en plus.

!     Remarques :
!       rho g sera a l'ordre 2 s'il est extrapole.
!       si on itere sur navsto, ca ne sert a rien de recalculer rho g a
!         chaque fois (ie on pourrait le passer dans trava) mais ce n'est
!         pas cher.
if (iappel.eq.1) then
  if (iphydr.eq.1) then
    do iel = 1, ncel
      trav(1,iel) = (frcxt(1 ,iel) - grad(1,iel)) * volf(iel)
      trav(2,iel) = (frcxt(2 ,iel) - grad(2,iel)) * volf(iel)
      trav(3,iel) = (frcxt(3 ,iel) - grad(3,iel)) * volf(iel)
    enddo
    elseif (iphydr.eq.2) then
    do iel = 1, ncel
      rom = crom(iel)
      trav(1,iel) = (rom*gx - grdphd(iel,1) - grad(1,iel)) * volf(iel)
      trav(2,iel) = (rom*gy - grdphd(iel,2) - grad(2,iel)) * volf(iel)
      trav(3,iel) = (rom*gz - grdphd(iel,3) - grad(3,iel)) * volf(iel)
    enddo
    elseif (ippmod(icompf).ge.0) then
    do iel = 1, ncel
      rom = crom(iel)
      trav(1,iel) = (rom*gx - grad(1,iel)) * volf(iel)
      trav(2,iel) = (rom*gy - grad(2,iel)) * volf(iel)
      trav(3,iel) = (rom*gz - grad(3,iel)) * volf(iel)
    enddo
  else
    do iel = 1, ncel
      drom = (crom(iel)-ro0)
      trav(1,iel) = (drom*gx - grad(1,iel) ) * volf(iel)
      trav(2,iel) = (drom*gy - grad(2,iel) ) * volf(iel)
      trav(3,iel) = (drom*gz - grad(3,iel) ) * volf(iel)
    enddo
  endif

else if(iappel.eq.2) then

  if (iphydr.eq.1) then
    do iel = 1, ncel
      trav(1,iel) = trav(1,iel) + (frcxt(1 ,iel) - grad(1,iel))*volf(iel)
      trav(2,iel) = trav(2,iel) + (frcxt(2 ,iel) - grad(2,iel))*volf(iel)
      trav(3,iel) = trav(3,iel) + (frcxt(3 ,iel) - grad(3,iel))*volf(iel)
    enddo
    elseif (iphydr.eq.2) then
    do iel = 1, ncel
      rom = crom(iel)
      trav(1,iel) = trav(1,iel) + (rom*gx - grdphd(iel,1) - grad(1,iel))*volf(iel)
      trav(2,iel) = trav(2,iel) + (rom*gy - grdphd(iel,2) - grad(2,iel))*volf(iel)
      trav(3,iel) = trav(3,iel) + (rom*gz - grdphd(iel,3) - grad(3,iel))*volf(iel)
    enddo
  else
    do iel = 1, ncel
      drom = (crom(iel)-ro0)
      trav(1,iel) = trav(1,iel) + (drom*gx - grad(1,iel))*volf(iel)
      trav(2,iel) = trav(2,iel) + (drom*gy - grad(2,iel))*volf(iel)
      trav(3,iel) = trav(3,iel) + (drom*gz - grad(3,iel))*volf(iel)
    enddo
  endif

endif

! Free memory
deallocate(grad)


!   Pour IAPPEL = 1 (ie appel standard sans les estimateurs)
!     TRAV rassemble les termes sources  qui seront recalcules
!       a toutes les iterations sur navsto
!     Si on n'itere pas sur navsto et qu'on n'extrapole pas les
!       termes sources, TRAV contient tous les termes sources
!       jusqu'au basculement dans SMBR
!     A ce niveau, TRAV contient -grad P et rho g
!       P est suppose pris a n+1/2
!       rho est eventuellement interpole a n+1/2


!-------------------------------------------------------------------------------
! ---> INITIALISATION DU TABLEAU TRAVA et propce AU PREMIER PASSAGE
!     (A LA PREMIERE ITER SUR NAVSTO)

!     TRAVA rassemble les termes sources qu'il suffit de calculer
!       a la premiere iteration sur navsto quand il y a plusieurs iter.
!     Quand il n'y a qu'une iter, on cumule directement dans TRAV
!       ce qui serait autrement alle dans TRAVA
!     PROPCE rassemble les termes sources explicites qui serviront
!       pour le pas de temps suivant en cas d'extrapolation (plusieurs
!       iter sur navsto ou pas)

!     A la premiere iter sur navsto
if (iterns.eq.1) then

  ! Si on   extrapole     les T.S. : -theta*valeur precedente
  if (isno2t.gt.0) then
    ! S'il n'y a qu'une    iter : TRAV  incremente
    if (nterup.eq.1) then
      do iel = 1, ncel
        do ii = 1, ndim
          trav (ii,iel) = trav (ii,iel) - thets*c_st_vel(ii,iel)
        enddo
      enddo
      ! S'il   y a plusieurs iter : TRAVA initialise
    else
      do iel = 1, ncel
        do ii = 1, ndim
          trava(ii,iel) = - thets*c_st_vel(ii,iel)
        enddo
      enddo
    endif
    ! Et on initialise le terme source pour le remplir ensuite
    do iel = 1, ncel
      do ii = 1, ndim
        c_st_vel(ii,iel) = 0.d0
      enddo
    enddo

  ! Si on n'extrapole pas les T.S. : pas de PROPCE
  else
    ! S'il   y a plusieurs iter : TRAVA initialise
    !  sinon TRAVA n'existe pas
    if(nterup.gt.1) then
      do ii = 1, ndim
        do iel = 1, ncel
          trava(ii,iel)  = 0.d0
        enddo
      enddo
    endif
  endif

endif

!-------------------------------------------------------------------------------
! Initialization of the implicit terms

if (iappel.eq.1) then

  ! Low Mach compressible Algos
  if (idilat.gt.1.or.ippmod(icompf).ge.0) then
    call field_get_val_prev_s(icrom, pcrom)

  ! Cavitation
  else if (icavit.ge.0) then
    call field_get_val_s(icroaa, pcrom)

  ! Standard algo
  else

    call field_get_val_s(icrom, pcrom)
  endif

  do iel = 1, ncel
    do isou = 1, 3
      fimp(isou,isou,iel) = istat(iu)*pcrom(iel)/dt(iel)*volf(iel)
      do jsou = 1, 3
        if(jsou.ne.isou) fimp(isou,jsou,iel) = 0.d0
      enddo
    enddo
  enddo

!     Le remplissage de FIMP est toujours indispensable,
!       meme si on peut se contenter de n'importe quoi pour IAPPEL=2.
else
  do iel = 1, ncel
    do isou = 1, 3
      do jsou = 1, 3
        fimp(isou,jsou,iel) = 0.d0
      enddo
    enddo
  enddo
endif

!-------------------------------------------------------------------------------
! ---> 2/3 RHO * GRADIENT DE K SI k-epsilon ou k-omega
!      NB : ON NE PREND PAS LE GRADIENT DE (RHO K), MAIS
!           CA COMPLIQUERAIT LA GESTION DES CL ...
!     On peut se demander si l'extrapolation en temps sert a
!       quelquechose

!     Ce terme explicite est calcule une seule fois,
!       a la premiere iter sur navsto : il va dans PROPCE si on
!       doit l'extrapoler en temps ; il va dans TRAVA si on n'extrapole
!       pas mais qu'on itere sur navsto. Il va dans TRAV si on
!       n'extrapole pas et qu'on n'itere pas sur navsto.
if(     (itytur.eq.2 .or. itytur.eq.5 .or. iturb.eq.60) &
   .and. igrhok.eq.1 .and. iterns.eq.1) then

  ! Allocate a work array for the gradient calculation
  allocate(grad(3,ncelet))

  iccocg = 1
  iprev  = 1
  inc    = 1

  call field_gradient_scalar(ivarfl(ik), iprev, imrgra, inc,      &
                             iccocg,                              &
                             grad)

  d2s3 = 2.d0/3.d0

  ! Si on extrapole les termes source en temps : PROPCE
  if (isno2t.gt.0) then
    ! Calcul de rho^n grad k^n      si rho non extrapole
    !           rho^n grad k^n      si rho     extrapole

    call field_get_val_s(icrom, crom)
    call field_get_val_prev_s(icrom, croma)
    do iel = 1, ncel
      romvom = -croma(iel)*volf(iel)*d2s3
      do isou = 1, 3
        c_st_vel(isou,iel) = c_st_vel(isou,iel)+grad(isou,iel)*romvom
      enddo
    enddo
  ! Si on n'extrapole pas les termes sources en temps : TRAV ou TRAVA
  else
    if(nterup.eq.1) then
      do iel = 1, ncel
        romvom = -crom(iel)*volf(iel)*d2s3
        do isou = 1, 3
          trav(isou,iel) = trav(isou,iel) + grad(isou,iel) * romvom
        enddo
      enddo
    else
      do iel = 1, ncel
        romvom = -crom(iel)*volf(iel)*d2s3
        do isou = 1, 3
          trava(isou,iel) = trava(isou,iel) + grad(isou,iel) * romvom
        enddo
      enddo
    endif
  endif

  ! Calcul des efforts aux parois (partie 3/5), si demande
  if (ineedf.eq.1) then
    call field_get_coefa_s (ivarfl(ik), coefa_k)
    call field_get_coefb_s (ivarfl(ik), coefb_k)
    do ifac = 1, nfabor
      iel = ifabor(ifac)
      diipbx = diipb(1,ifac)
      diipby = diipb(2,ifac)
      diipbz = diipb(3,ifac)
      xkb = cvara_k(iel) + diipbx*grad(1,iel)                      &
           + diipby*grad(2,iel) + diipbz*grad(3,iel)
      xkb = coefa_k(ifac)+coefb_k(ifac)*xkb
      xkb = d2s3*crom(iel)*xkb
      do isou = 1, 3
        forbr(isou,ifac) = forbr(isou,ifac) + xkb*surfbo(isou,ifac)
      enddo
    enddo
  endif

  ! Free memory
  deallocate(grad)

endif


!-------------------------------------------------------------------------------
! ---> Transpose of velocity gradient in the diffusion term

!     These terms are taken into account in bilscv.
!     We only compute here the secondary viscosity.

if (ivisse.eq.1) then

  call visecv(propce, secvif, secvib)

endif

!-------------------------------------------------------------------------------
! ---> Head losses
!      (if iphydr=1 this term has already been taken into account)

! ---> Explicit part
if ((ncepdp.gt.0).and.(iphydr.ne.1)) then

  ! Les termes diagonaux sont places dans TRAV ou TRAVA,
  !   La prise en compte de uvwk a partir de la seconde iteration
  !   est faite directement dans coditv.
  if (iterns.eq.1) then

    ! On utilise temporairement TRAV comme tableau de travail.
    ! Son contenu est stocke dans W7, W8 et W9 jusqu'apres tspdcv
    do iel = 1,ncel
      w7(iel) = trav(1,iel)
      w8(iel) = trav(2,iel)
      w9(iel) = trav(3,iel)
      trav(1,iel) = 0.d0
      trav(2,iel) = 0.d0
      trav(3,iel) = 0.d0
    enddo

    call tspdcv(ncepdp, icepdc, vela, ckupdc, trav)

    ! With porosity
    if (iporos.ge.1) then
      do iel = 1, ncel
        trav(1, iel) = trav(1, iel)*porosi(iel)
        trav(2, iel) = trav(2, iel)*porosi(iel)
        trav(3, iel) = trav(3, iel)*porosi(iel)
      enddo
    endif

    ! Si on itere sur navsto, on utilise TRAVA ; sinon TRAV
    if(nterup.gt.1) then
      do iel = 1, ncel
        trava(1,iel) = trava(1,iel) + trav(1,iel)
        trava(2,iel) = trava(2,iel) + trav(2,iel)
        trava(3,iel) = trava(3,iel) + trav(3,iel)
        trav(1,iel)  = w7(iel)
        trav(2,iel)  = w8(iel)
        trav(3,iel)  = w9(iel)
      enddo
    else
      do iel = 1, ncel
        trav(1,iel)  = w7(iel) + trav(1,iel)
        trav(2,iel)  = w8(iel) + trav(2,iel)
        trav(3,iel)  = w9(iel) + trav(3,iel)
      enddo
    endif
  endif

endif

! ---> Implicit part

!  At the second call, fimp is not needed anymore
if (iappel.eq.1) then
  if (ncepdp.gt.0) then
    ! The theta-scheme for the head loss is the same as the other terms
    thetap = thetav(iu)
    do ielpdc = 1, ncepdp
      iel = icepdc(ielpdc)
      romvom = crom(iel)*volf(iel)*thetap

      ! Diagonal part
      do isou = 1, 3
        fimp(isou,isou,iel) = fimp(isou,isou,iel) + romvom*ckupdc(ielpdc,isou)
      enddo
      ! Extra-diagonal part
      cpdc12 = ckupdc(ielpdc,4)
      cpdc23 = ckupdc(ielpdc,5)
      cpdc13 = ckupdc(ielpdc,6)

      fimp(1,2,iel) = fimp(1,2,iel) + romvom*cpdc12
      fimp(2,1,iel) = fimp(2,1,iel) + romvom*cpdc12
      fimp(1,3,iel) = fimp(1,3,iel) + romvom*cpdc13
      fimp(3,1,iel) = fimp(3,1,iel) + romvom*cpdc13
      fimp(2,3,iel) = fimp(2,3,iel) + romvom*cpdc23
      fimp(3,2,iel) = fimp(3,2,iel) + romvom*cpdc23
    enddo
  endif
endif


!-------------------------------------------------------------------------------
! ---> Coriolis force
!     (if iphydr=1 then this term is already taken into account)

! --->  Explicit part

if ((icorio.eq.1.or.iturbo.eq.1) .and. iphydr.ne.1) then

  ! A la premiere iter sur navsto, on ajoute la partie issue des
  ! termes explicites
  if (iterns.eq.1) then

    ! Si on n'itere pas sur navsto : TRAV
    if (nterup.eq.1) then

      call field_get_val_s(icrom, crom)

      do iel = 1, ncel
        romvom = -ccorio*crom(iel)*volf(iel)
        call add_coriolis_v(irotce(iel), romvom, vela(:,iel), trav(:,iel))
      enddo

    ! Si on itere sur navsto : TRAVA
    else

      do iel = 1, ncel
        romvom = -ccorio*crom(iel)*volf(iel)
        call add_coriolis_v(irotce(iel), romvom, vela(:,iel), trava(:,iel))
      enddo

    endif
  endif
endif

! --->  Implicit part

!  At the second call, fimp is not needed anymore
if(iappel.eq.1) then
  if (icorio.eq.1 .or. iturbo.eq.1) then
    ! The theta-scheme for the Coriolis term is the same as the other terms
    thetap = thetav(iu)

    do iel = 1, ncel
      romvom = -ccorio*crom(iel)*volf(iel)*thetap
      call add_coriolis_t(irotce(iel), romvom, fimp(:,:,iel))
    enddo

  endif
endif

!-------------------------------------------------------------------------------
! ---> - Divergence of tensor Rij

if(itytur.eq.3.and.iterns.eq.1) then

  allocate(rij(6,ncelet))
  do iel = 1, ncelet
    rij(1,iel) = cvara_r11(iel)
    rij(2,iel) = cvara_r22(iel)
    rij(3,iel) = cvara_r33(iel)
    rij(4,iel) = cvara_r12(iel)
    rij(5,iel) = cvara_r23(iel)
    rij(6,iel) = cvara_r13(iel)
  enddo

! --- Boundary conditions on the components of the tensor Rij

  allocate(coefat(6,nfabor))
  call field_get_coefad_s(ivarfl(ir11),coef1)
  call field_get_coefad_s(ivarfl(ir22),coef2)
  call field_get_coefad_s(ivarfl(ir33),coef3)
  call field_get_coefad_s(ivarfl(ir12),coef4)
  call field_get_coefad_s(ivarfl(ir23),coef5)
  call field_get_coefad_s(ivarfl(ir13),coef6)
  do ifac = 1, nfabor
    coefat(1,ifac) = coef1(ifac)
    coefat(2,ifac) = coef2(ifac)
    coefat(3,ifac) = coef3(ifac)
    coefat(4,ifac) = coef4(ifac)
    coefat(5,ifac) = coef5(ifac)
    coefat(6,ifac) = coef6(ifac)
  enddo

  allocate(coefbt(6,6,nfabor))
  do ifac = 1, nfabor
    do ii = 1, 6
      do jj = 1, 6
        coefbt(jj,ii,ifac) = 0.d0
      enddo
    enddo
  enddo
  call field_get_coefbd_s(ivarfl(ir11),coef1)
  call field_get_coefbd_s(ivarfl(ir22),coef2)
  call field_get_coefbd_s(ivarfl(ir33),coef3)
  call field_get_coefbd_s(ivarfl(ir12),coef4)
  call field_get_coefbd_s(ivarfl(ir23),coef5)
  call field_get_coefbd_s(ivarfl(ir13),coef6)
  do ifac = 1, nfabor
    coefbt(1,1,ifac) = coef1(ifac)
    coefbt(2,2,ifac) = coef2(ifac)
    coefbt(3,3,ifac) = coef3(ifac)
    coefbt(4,4,ifac) = coef4(ifac)
    coefbt(5,5,ifac) = coef5(ifac)
    coefbt(6,6,ifac) = coef6(ifac)
  enddo

  ! Flux computation options
  f_id = -1
  init = 1;
  inc  = 1;
  iflmb0 = 0;
  nswrgp = nswrgr(ir11);
  imligp = imligr(ir11);
  iwarnp = iwarni(ir11);
  epsrgp = epsrgr(ir11);
  climgp = climgr(ir11);
  itypfl = 1;

  allocate(tflmas(3,nfac))
  allocate(tflmab(3,nfabor))

  call divrij &
  !==========
 ( f_id   , itypfl ,                                              &
   iflmb0 , init   , inc    , imrgra , nswrgp , imligp ,          &
   iwarnp ,                                                       &
   epsrgp , climgp ,                                              &
   crom   , brom   ,                                              &
   rij    ,                                                       &
   coefat , coefbt ,                                              &
   tflmas , tflmab )

  deallocate(rij)
  deallocate(coefat, coefbt)

  !     Calcul des efforts aux bords (partie 5/5), si necessaire

  if (ineedf.eq.1) then
    do ifac = 1, nfabor
      do isou = 1, 3
        forbr(isou,ifac) = forbr(isou,ifac) + tflmab(isou,ifac)
      enddo
    enddo
  endif

  allocate(divt(3,ncelet))
  init = 1
  call divmat(init,tflmas,tflmab,divt)

  deallocate(tflmas, tflmab)

  ! (if iphydr=1 then this term is already taken into account)
  if (iphydr.ne.1.or.igprij.ne.1) then

    ! If extrapolation of source terms
    if (isno2t.gt.0) then
      do iel = 1, ncel
        do isou = 1, 3
          c_st_vel(isou,iel) = c_st_vel(isou,iel) - divt(isou,iel)
        enddo
      enddo

    ! No extrapolation of source terms
    else

      ! No PISO iteration
      if (nterup.eq.1) then
        do iel = 1, ncel
          do isou = 1, 3
            trav(isou,iel) = trav(isou,iel) - divt(isou,iel)
          enddo
        enddo
      ! PISO iterations
      else
        do iel = 1, ncel
          do isou = 1, 3
            trava(isou,iel) = trava(isou,iel) - divt(isou,iel)
          enddo
        enddo
      endif
    endif
  endif

endif


!-------------------------------------------------------------------------------
! ---> Face diffusivity for the velocity

if (idiff(iu).ge. 1) then

  call field_get_val_s(iprpfl(iviscl), viscl)
  call field_get_val_s(iprpfl(ivisct), visct)

  if (itytur.eq.3) then
    do iel = 1, ncel
      w1(iel) = viscl(iel)
    enddo
  else
    do iel = 1, ncel
      w1(iel) = viscl(iel) + idifft(iu)*visct(iel)
    enddo
  endif

  ! Scalar diffusivity (Default)
  if (idften(iu).eq.1) then

    call viscfa &
    !==========
   ( imvisf ,                                                       &
     w1     ,                                                       &
     viscf  , viscb  )

    ! When using Rij-epsilon model with the option irijnu=1, the face
    ! viscosity for the Matrix (viscfi and viscbi) is increased
    if(itytur.eq.3.and.irijnu.eq.1) then

      do iel = 1, ncel
        w1(iel) = viscl(iel) + idifft(iu)*visct(iel)
      enddo

      call viscfa &
      !==========
   ( imvisf ,                                                       &
     w1     ,                                                       &
     viscfi , viscbi )
    endif

  ! Tensorial diffusion of the velocity (in case of tensorial porosity)
  else if (idften(iu).eq.6) then

    do iel = 1, ncel
      do isou = 1, 3
        viscce(isou, iel) = w1(iel)
      enddo
      do isou = 4, 6
        viscce(isou, iel) = 0.d0
      enddo
    enddo

    call vistnv &
    !==========
     ( imvisf ,                                                       &
       viscce ,                                                       &
       viscf  , viscb  )

    ! When using Rij-epsilon model with the option irijnu=1, the face
    ! viscosity for the Matrix (viscfi and viscbi) is increased
    if(itytur.eq.3.and.irijnu.eq.1) then

      do iel = 1, ncel
        w1(iel) = viscl(iel) + idifft(iu)*visct(iel)
      enddo

      do iel = 1, ncel
        do isou = 1, 3
          viscce(isou, iel) = w1(iel)
        enddo
        do isou = 4, 6
          viscce(isou, iel) = 0.d0
        enddo
      enddo

      call vistnv &
      !==========
       ( imvisf ,                                                       &
         viscce ,                                                       &
         viscfi , viscbi )

    endif
  endif

! --- If no dissusion, viscosity is set to 0.
else

  do ifac = 1, nfac
    viscf(ifac) = 0.d0
  enddo
  do ifac = 1, nfabor
    viscb(ifac) = 0.d0
  enddo

  if(itytur.eq.3.and.irijnu.eq.1) then
    do ifac = 1, nfac
      viscfi(ifac) = 0.d0
    enddo
    do ifac = 1, nfabor
      viscbi(ifac) = 0.d0
    enddo
  endif

endif

!-------------------------------------------------------------------------------
! ---> Take external forces partially equilibrated with the pressure gradient
!      into account (only for the first call, the second one is dedicated
!      to error estimators)

if (iappel.eq.1.and.iphydr.eq.1.and.iterns.eq.1) then

! force ext au pas de temps precedent :
!     FRCXT a ete initialise a zero
!     (est deja utilise dans typecl, et est mis a jour a la fin
!     de navsto)

  do iel = 1, ncel

    ! External force variation between time step n and n+1
    ! (used in the correction step)
    drom = (crom(iel)-ro0)
    dfrcxt(1, iel) = drom*gx - frcxt(1, iel)
    dfrcxt(2, iel) = drom*gy - frcxt(2, iel)
    dfrcxt(3, iel) = drom*gz - frcxt(3, iel)
  enddo

  ! Add head losses
  if (ncepdp.gt.0) then
    do ielpdc = 1, ncepdp
      iel=icepdc(ielpdc)
      vit1   = vela(1,iel)
      vit2   = vela(2,iel)
      vit3   = vela(3,iel)
      cpdc11 = ckupdc(ielpdc,1)
      cpdc22 = ckupdc(ielpdc,2)
      cpdc33 = ckupdc(ielpdc,3)
      cpdc12 = ckupdc(ielpdc,4)
      cpdc23 = ckupdc(ielpdc,5)
      cpdc13 = ckupdc(ielpdc,6)
      dfrcxt(1 ,iel) = dfrcxt(1 ,iel) &
                    - crom(iel)*(cpdc11*vit1+cpdc12*vit2+cpdc13*vit3)
      dfrcxt(2 ,iel) = dfrcxt(2 ,iel) &
                    - crom(iel)*(cpdc12*vit1+cpdc22*vit2+cpdc23*vit3)
      dfrcxt(3 ,iel) = dfrcxt(3 ,iel) &
                    - crom(iel)*(cpdc13*vit1+cpdc23*vit2+cpdc33*vit3)
    enddo
  endif

  ! Add Coriolis force
  if (icorio.eq.1 .or. iturbo.eq.1) then
    do iel = 1, ncel
      rom = -ccorio*crom(iel)
      call add_coriolis_v(irotce(iel), rom, vela(:,iel), dfrcxt(:,iel))
    enddo
  endif

  ! Add -div( rho R) as external force
  if (itytur.eq.3.and.igprij.eq.1) then
    do iel = 1, ncel
      dvol = 1.d0/volf(iel)
      do isou = 1, 3
        dfrcxt(isou, iel) = dfrcxt(isou, iel) - divt(isou, iel)*dvol
      enddo
    enddo
  endif


  if (irangp.ge.0.or.iperio.eq.1) then
    call synvin(dfrcxt)
  endif

endif

!===============================================================================
! 3. Solving of the 3x3xNcel coupled system
!===============================================================================


! ---> AU PREMIER APPEL,
!      MISE A ZERO DE L'ESTIMATEUR POUR LA VITESSE PREDITE
!      S'IL DOIT ETRE CALCULE

if (iappel.eq.1) then
  if (iestim(iespre).ge.0) then
    call field_get_val_s(iestim(iespre), c_estim)
    do iel = 1, ncel
      c_estim(iel) =  0.d0
    enddo
  endif
endif

! ---> AU DEUXIEME APPEL,
!      MISE A ZERO DE L'ESTIMATEUR TOTAL POUR NAVIER-STOKES
!      (SI ON FAIT UN DEUXIEME APPEL, ALORS IL DOIT ETRE CALCULE)

if (iappel.eq.2) then
  call field_get_val_s(iestim(iestot), c_estim)
  do iel = 1, ncel
    c_estim(iel) =  0.d0
  enddo
endif

!-------------------------------------------------------------------------------
! ---> User source terms

do iel = 1, ncel
  do isou = 1, 3
    tsexp(isou,iel) = 0.d0
    do jsou = 1, 3
      tsimp(isou,jsou,iel) = 0.d0
    enddo
  enddo
enddo

! The computation of esplicit and implicit source terms is performed
! at the first iter only.
if (iterns.eq.1) then

  if (iihmpr.eq.1) then
    call uitsnv (vel, tsexp, tsimp)
  endif

  call ustsnv &
  !==========
 ( nvar   , nscal  , ncepdp , ncesmp ,                            &
   iu   ,                                                         &
   icepdc , icetsm , itypsm ,                                     &
   dt     ,                                                       &
   ckupdc , smacel , tsexp  , tsimp  )

  if (ibdtso(iu).gt.1.and.ntcabs.gt.ntinit &
      .and.(idtvar.eq.0.or.idtvar.eq.1)) then
    ! TODO: remove test on ntcabs and implemente a "proper" condition for
    ! initialization.
    f_id = ivarfl(iu)
    call cs_backward_differentiation_in_time(f_id, tsexp, tsimp)
  endif
  ! Skip first time step after restart if previous values have not been read.
  if (ibdtso(iu).lt.0) ibdtso(iu) = iabs(ibdtso(iu))

  ! Coupling between two Code_Saturne
  if (nbrcpl.gt.0) then
    !vectorial interleaved exchange
    call csccel(iu, vela, coefav, coefbv, tsexp)
    !==========
  endif

  if (iphydr.eq.1.and.igpust.eq.1) then

    do iel = 1, ncel
      !FIXME when using porosity
      dvol = 1.d0/volume(iel)
      do isou = 1, 3
        dfrcxt(isou, iel) = dfrcxt(isou, iel) + tsexp(isou, iel)*dvol
      enddo
    enddo

    if (irangp.ge.0.or.iperio.eq.1) then
      call synvin(dfrcxt)
    endif
  endif

  ! Porosity
  if (iporos.ge.1) then
    do iel = 1, ncel
      do isou = 1, 3
        tsexp(isou, iel) = porosi(iel)*tsexp(isou, iel)
      enddo
    enddo
  endif

endif

! if PISO sweeps are expected, implicit user sources terms are stored in ximpa
if (iterns.eq.1.and.nterup.gt.1) then
  do iel = 1, ncel
    do isou = 1, 3
      do jsou = 1, 3
        ximpa(isou,jsou,iel) = tsimp(isou,jsou,iel)
      enddo
    enddo
  enddo
endif

! ---> Explicit contribution due to implicit terms

! Without porosity
if (iporos.eq.0) then
  if (iterns.eq.1) then
    if (nterup.gt.1) then
      do iel = 1, ncel
        do isou = 1, 3
          do jsou = 1, 3
            trava(isou,iel) = trava(isou,iel)                                  &
                            + tsimp(isou,jsou,iel)*vela(jsou,iel)
          enddo
        enddo
      enddo
    else
      do iel = 1, ncel
        do isou = 1, 3
          do jsou = 1, 3
            trav(isou,iel) = trav(isou,iel)                                    &
                           + tsimp(isou,jsou,iel)*vela(jsou,iel)
          enddo
        enddo
      enddo
    endif
  endif

! With porosity
else
  if (iterns.eq.1) then
    if (nterup.gt.1) then
      do iel = 1, ncel
        do isou = 1, 3
          do jsou = 1, 3
            trava(isou,iel) = trava(isou,iel)                                  &
                            + tsimp(isou,jsou,iel)*vela(jsou,iel)*porosi(iel)
          enddo
        enddo
      enddo
    else
      do iel = 1, ncel
        do isou = 1, 3
          do jsou = 1, 3
            trav(isou,iel) = trav(isou,iel)                                    &
                           + tsimp(isou,jsou,iel)*vela(jsou,iel)*porosi(iel)
          enddo
        enddo
      enddo
    endif
  endif

endif

! At the first PISO iteration, explicit source terms are added
if (iterns.eq.1.and.(iphydr.ne.1.or.igpust.ne.1)) then
  ! If source terms are time-extrapolated, they are stored in propce
  if (isno2t.gt.0) then
    do iel = 1, ncel
      do isou = 1, 3
        c_st_vel(isou,iel) = c_st_vel(isou,iel) + tsexp(isou,iel)
      enddo
    enddo

  else
    ! If no PISO sweep
    if (nterup.eq.1) then
      do iel = 1, ncel
        do isou = 1, 3
          trav(isou,iel) = trav(isou,iel) + tsexp(isou,iel)
        enddo
      enddo
    ! If PISO sweeps
    else
      do iel = 1, ncel
        do isou = 1, 3
          trava(isou,iel) = trava(isou,iel) + tsexp(isou,iel)
        enddo
      enddo
    endif
  endif
endif

! ---> Implicit terms
if (iappel.eq.1) then
  ! If source terms are time-extrapolated
  if (isno2t.gt.0) then
    thetap = thetav(iu)
    if (iterns.gt.1) then
      do iel = 1, ncel
        do isou = 1, 3
          do jsou = 1, 3
            fimp(isou,jsou,iel) = fimp(isou,jsou,iel)                      &
                                - ximpa(isou,jsou,iel)*thetap
          enddo
        enddo
      enddo
    else
      do iel = 1, ncel
        do isou = 1, 3
          do jsou = 1, 3
            fimp(isou,jsou,iel) = fimp(isou,jsou,iel)                      &
                                - tsimp(isou,jsou,iel)*thetap
          enddo
        enddo
      enddo
    endif
  else
    if (iterns.gt.1) then
      do iel = 1, ncel
        do isou = 1, 3
          do jsou = 1, 3
            fimp(isou,jsou,iel) = fimp(isou,jsou,iel)                      &
                                + max(-ximpa(isou,jsou,iel),zero)
          enddo
        enddo
      enddo
    else
      do iel = 1, ncel
        do isou = 1, 3
          do jsou = 1, 3
            fimp(isou,jsou,iel) = fimp(isou,jsou,iel)                      &
                                + max(-tsimp(isou,jsou,iel),zero)
          enddo
        enddo
      enddo
    endif
  endif
endif

!-------------------------------------------------------------------------------
! --->  Mass source terms

if (ncesmp.gt.0) then

!     On calcule les termes Gamma (uinj - u)
!       -Gamma u a la premiere iteration est mis dans
!          TRAV ou TRAVA selon qu'on itere ou non sur navsto
!       Gamma uinj a la premiere iteration est placee dans W1
!       ROVSDT a chaque iteration recoit Gamma
  allocate(gavinj(3,ncelet))
  if (nterup.eq.1) then
    call catsmv &
    !==========
  ( ncelet , ncel , ncesmp , iterns , isno2t, thetav(iu),       &
    icetsm , itypsm(1,iu),                                      &
    volume , vela , smacel(1,iu) ,smacel(1,ipr) ,               &
    trav   , fimp , gavinj )
  else
    call catsmv &
    !==========
  ( ncelet , ncel , ncesmp , iterns , isno2t, thetav(iu),       &
    icetsm , itypsm(1,iu),                                      &
    volume , vela , smacel(1,iu) ,smacel(1,ipr) ,               &
    trava  , fimp  , gavinj )
  endif

  ! At the first PISO iteration, the explicit part "Gamma u^{in}" is added
  if (iterns.eq.1) then
    ! If source terms are extrapolated, stored in propce
    if(isno2t.gt.0) then
      do iel = 1, ncel
        do isou = 1, 3
          c_st_vel(isou,iel) = c_st_vel(isou,iel) + gavinj(isou,iel)
        enddo
      enddo

    else
      ! If no PISO iteration: in trav
      if (nterup.eq.1) then
        do iel = 1,ncel
          do isou = 1, 3
            trav(isou,iel)  = trav(isou,iel) + gavinj(isou,iel)
          enddo
        enddo
      ! Otherwise, in trava
      else
        do iel = 1,ncel
          do isou = 1, 3
            trava(isou,iel) = trava(isou,iel) + gavinj(isou,iel)
          enddo
        enddo
      endif
    endif
  endif

  deallocate(gavinj)

endif

! ---> Right Han Side initialization

! If source terms are extrapolated in time
if (isno2t.gt.0) then
  thetp1 = 1.d0 + thets
  ! If no PISO iteration: trav
  if (nterup.eq.1) then
    do iel = 1, ncel
      do isou = 1, 3
        smbr(isou,iel) = trav(isou,iel) + thetp1*c_st_vel(isou,iel)
      enddo
    enddo

  else
    do iel = 1, ncel
      do isou = 1, 3
        smbr(isou,iel) = trav(isou,iel) + trava(isou,iel)       &
                       + thetp1*c_st_vel(isou,iel)
      enddo
    enddo
  endif

! No time extrapolation
else
  ! No PISO iteration
  if (nterup.eq.1) then
    do iel = 1, ncel
      do isou = 1, 3
        smbr(isou,iel) = trav(isou,iel)
      enddo
    enddo
  ! PISO iterations
  else
    do iel = 1, ncel
      do isou = 1, 3
        smbr(isou,iel) = trav(isou,iel) + trava(isou,iel)
      enddo
    enddo
  endif
endif


! ---> LAGRANGIEN : COUPLAGE RETOUR

!     L'ordre 2 sur les termes issus du lagrangien necessiterait de
!       decomposer TSLAGR(IEL,ISOU) en partie implicite et
!       explicite, comme c'est fait dans ustsnv.
!     Pour le moment, on n'y touche pas.
if (iilagr.eq.2 .and. ltsdyn.eq.1)  then

  do iel = 1, ncel
    do isou = 1, 3
      smbr(isou,iel) = smbr(isou,iel) + tslagr(iel,itsvx+isou-1)
    enddo
  enddo
  ! At the second call, fimp is unused
  if(iappel.eq.1) then
    do iel = 1, ncel
      do isou = 1, 3
        fimp(isou,isou,iel) = fimp(isou,isou,iel) + max(-tslagr(iel,itsli),zero)
      enddo
    enddo
  endif

endif

! ---> Electric Arc (Laplace Force)
!      (No 2nd order in time yet)
if (ippmod(ielarc).ge.1) then
  do iel = 1, ncel
    do isou = 1, 3
      smbr(isou,iel) = smbr(isou,iel)                               &
                     + volf(iel)*propce(iel,ipproc(ilapla(isou)))
    enddo
  enddo
endif

! Solver parameters
iconvp = iconv (iu)
idiffp = idiff (iu)
ndircp = ndircl(iu)
nswrsp = nswrsm(iu)
nswrgp = nswrgr(iu)
imligp = imligr(iu)
ircflp = ircflu(iu)
ischcp = ischcv(iu)
isstpp = isstpc(iu)
idftnp = idften(iu)
iswdyp = iswdyn(iu)
iwarnp = iwarni(iu)
blencp = blencv(iu)
epsilp = epsilo(iu)
epsrsp = epsrsm(iu)
epsrgp = epsrgr(iu)
climgp = climgr(iu)
extrap = extrag(iu)
relaxp = relaxv(iu)
thetap = thetav(iu)

if (ippmod(icompf).ge.0) then
  ! impose boundary convective flux at some faces (face indicator icvfli)
  icvflb = 1
else
  ! all boundary convective flux with upwind
  icvflb = 0
endif

if (iappel.eq.1) then

  iescap = iescal(iespre)

  if (iterns.eq.1) then

    ! Warning: in case of convergence estimators, eswork give the estimator
    ! of the predicted velocity
    call coditv &
    !==========
 ( idtvar , iu     , iconvp , idiffp , ndircp ,                   &
   imrgra , nswrsp , nswrgp , imligp , ircflp , ivisse ,          &
   ischcp , isstpp , iescap , idftnp , iswdyp ,                   &
   iwarnp ,                                                       &
   blencp , epsilp , epsrsp , epsrgp , climgp ,                   &
   relaxp , thetap ,                                              &
   vela   , vela   ,                                              &
   coefav , coefbv , cofafv , cofbfv ,                            &
   flumas , flumab ,                                              &
   viscfi , viscbi , viscf  , viscb  , secvif , secvib ,          &
   icvflb , icvfli ,                                              &
   fimp   ,                                                       &
   smbr   ,                                                       &
   vel    ,                                                       &
   eswork )

  elseif(iterns.gt.1) then

    call coditv &
    !==========
 ( idtvar , iu     , iconvp , idiffp , ndircp ,                   &
   imrgra , nswrsp , nswrgp , imligp , ircflp , ivisse ,          &
   ischcp , isstpp , iescap , idftnp , iswdyp ,                   &
   iwarnp ,                                                       &
   blencp , epsilp , epsrsp , epsrgp , climgp ,                   &
   relaxp , thetap ,                                              &
   vela   , uvwk   ,                                              &
   coefav , coefbv , cofafv , cofbfv ,                            &
   flumas , flumab ,                                              &
   viscfi , viscbi , viscf  , viscb  , secvif , secvib ,          &
   icvflb , icvfli ,                                              &
   fimp   ,                                                       &
   smbr   ,                                                       &
   vel    ,                                                       &
   eswork )

  endif

  ! Velocity-pression coupling: compute the vector T, stored in tpucou,
  !  coditv is called, only one sweep is done, and tpucou is initialized
  !  by 0. so that the advection/diffusion added by bilscv is 0.
  !  nswrsp = -1 indicated that only one sweep is required and inc=0
  !  for boundary contitions on the weight matrix.
  if (ipucou.eq.1) then

    ! Allocate temporary arrays for the velocity-pressure resolution
    allocate(vect(3,ncelet))

    nswrsp = -1
    do iel = 1, ncel
      do isou = 1, 3
        smbr(isou,iel) = volf(iel)
      enddo
    enddo
    do iel = 1, ncelet
      do isou = 1, 3
        vect(isou,iel) = 0.d0
      enddo
    enddo
    iescap = 0

    ! We do not take into account transpose of grad
    ivisep = 0

    call coditv &
    !==========
 ( idtvar , iu     , iconvp , idiffp , ndircp ,                   &
   imrgra , nswrsp , nswrgp , imligp , ircflp , ivisep ,          &
   ischcp , isstpp , iescap , idftnp , iswdyp ,                   &
   iwarnp ,                                                       &
   blencp , epsilp , epsrsp , epsrgp , climgp ,                   &
   relaxp , thetap ,                                              &
   vect   , vect   ,                                              &
   coefav , coefbv , cofafv , cofbfv ,                            &
   flumas , flumab ,                                              &
   viscfi , viscbi , viscf  , viscb  , secvif , secvib ,          &
   icvflb , ivoid  ,                                              &
   fimp   ,                                                       &
   smbr   ,                                                       &
   vect   ,                                                       &
   rvoid  )

    do iel = 1, ncelet
      rom = crom(iel)
      do isou = 1, 3
        tpucou(isou,iel) = rom*vect(isou,iel)
      enddo
      do isou = 4, 6
        tpucou(isou,iel) = 0.d0
      enddo
    enddo

    ! Free memory
    deallocate(vect)

  endif

  ! ---> The estimator on the predicted velocity is summed up over the components
  if (iestim(iespre).ge.0) then
    call field_get_val_s(iestim(iespre), c_estim)
    do iel = 1, ncel
      do isou = 1, 3
        c_estim(iel) =  c_estim(iel) + eswork(isou,iel)
      enddo
    enddo
  endif


! ---> End of the construction of the total estimator:
!       RHS resiudal of (U^{n+1}, P^{n+1}) + rho*volume*(U^{n+1} - U^n)/dt
elseif (iappel.eq.2) then

  inc = 1
  ! Pas de relaxation en stationnaire
  idtva0 = 0

  call bilscv &
  !==========
 ( idtva0 , iu     , iconvp , idiffp , nswrgp , imligp , ircflp , &
   ischcp , isstpp , inc    , imrgra , ivisse ,                   &
   iwarnp , idftnp ,                                              &
   blencp , epsrgp , climgp , relaxp , thetap ,                   &
   vel    , vel    ,                                              &
   coefav , coefbv , cofafv , cofbfv ,                            &
   flumas , flumab , viscf  , viscb  , secvif , secvib ,          &
   icvflb , icvfli ,                                              &
   smbr   )

  call field_get_val_s(iestim(iestot), c_estim)
  do iel = 1, ncel
    do isou = 1, 3
      c_estim(iel) = c_estim(iel) + (smbr(isou,iel)/volume(iel))**2
    enddo
  enddo
endif

!===============================================================================
! 4. Finalize the norm of the pressure step (see resopv)
!===============================================================================

if (iappel.eq.1.and.irnpnw.eq.1) then

  ! Compute div(rho u*)

  if (irangp.ge.0.or.iperio.eq.1) then
    call synvin(vel)
  endif

  ! To save time, no space reconstruction
  itypfl = 1
  ! Cavitation algorithm: the pressure step corresponds to the
  ! correction of the volumetric flux, not the mass flux
  if (icavit.ge.0)  itypfl = 0
  init   = 1
  inc    = 1
  iflmb0 = 1
  nswrp  = 1
  imligp = imligr(iu )
  iwarnp = iwarni(ipr)
  epsrgp = epsrgr(iu )
  climgp = climgr(iu )

  call inimav &
  !==========
 ( ivarfl(iu)      , itypfl ,                                     &
   iflmb0 , init   , inc    , imrgra , nswrp  , imligp ,          &
   iwarnp ,                                                       &
   epsrgp , climgp ,                                              &
   crom   , brom   ,                                              &
   vel    ,                                                       &
   coefav , coefbv ,                                              &
   viscf  , viscb  )

  init = 0
  call divmas(init,viscf,viscb,xnormp)

  ! Compute the norm rnormp used in resopv
  isqrt = 1
  call prodsc(ncel,isqrt,xnormp,xnormp,rnormp)

endif

! ---> Finilaze estimators + Printings

if (iappel.eq.1) then

  ! ---> Estimator on the predicted velocity:
  !      square root (norm) or square root of the sum times the volume (L2 norm)
  if (iestim(iespre).ge.0) then
    call field_get_val_s(iestim(iespre), c_estim)
    if (iescal(iespre).eq.1) then
      do iel = 1, ncel
        c_estim(iel) = sqrt(c_estim(iel))
      enddo
    elseif (iescal(iespre).eq.2) then
      do iel = 1, ncel
        c_estim(iel) = sqrt(c_estim(iel)*volume(iel))
      enddo
    endif
  endif

  ! ---> Norm printings
  if (iwarni(iu).ge.2) then
    rnorm = -1.d0
    do iel = 1, ncel
      vitnor = sqrt(vel(1,iel)**2+vel(2,iel)**2+vel(3,iel)**2)
      rnorm = max(rnorm,vitnor)
    enddo

    if (irangp.ge.0) call parmax (rnorm)

    write(nfecra,1100) rnorm
  endif

! ---> Estimator on the whole Navier-Stokes:
!      square root (norm) or square root of the sum times the volume (L2 norm)
elseif (iappel.eq.2) then

  call field_get_val_s(iestim(iestot), c_estim)
  if (iescal(iestot).eq.1) then
    do iel = 1, ncel
      c_estim(iel) = sqrt(c_estim(iel))
    enddo
  elseif (iescal(iestot).eq.2) then
    do iel = 1, ncel
      c_estim(iel) = sqrt(c_estim(iel)*volume(iel))
    enddo
  endif

endif

! Free memory
!------------
deallocate(smbr)
deallocate(fimp)
deallocate(tsexp)
deallocate(tsimp)
if (allocated(viscce)) deallocate(viscce)
if (allocated(divt)) deallocate(divt)
if (allocated(xvolf)) deallocate(xvolf)

!--------
! Formats
!--------
#if defined(_CS_LANG_FR)

 1100 format(/,                                                   &
 1X,'Vitesse maximale apres prediction ',E12.4)

#else

 1100 format(/,                                                   &
 1X,'Maximum velocity after prediction ',E12.4)

#endif

!----
! End
!----

return

end subroutine
