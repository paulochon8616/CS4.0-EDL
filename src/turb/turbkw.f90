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

!> \file turbkw.f90
!>
!> \brief Solving the \f$ k - \omega \f$ SST for incompressible flows
!> or slightly compressible flows for one time step.
!-------------------------------------------------------------------------------

!-------------------------------------------------------------------------------
! Arguments
!______________________________________________________________________________.
!  mode           name          role
!______________________________________________________________________________!
!> \param[in]     nvar          total number of variables
!> \param[in]     nscal         total number of scalars
!> \param[in]     ncepdp        number of cells with head loss
!> \param[in]     ncesmp        number of cells with mass source term
!> \param[in]     icepdc        index of the ncepdp cells with head loss
!> \param[in]     icetsm        index of cells with mass source term
!> \param[in]     itypsm        mass source type for the variables (cf. cs_user_mass_source_terms)
!> \param[in]     dt            time step (per cell)
!> \param[in]     tslagr        coupling term of the lagangian module
!> \param[in]     ckupdc        work array for the head loss
!> \param[in]     smacel        values of the variables associated to the
!>                               mass source
!>                               (for ivar=ipr, smacel is the mass flux)
!_______________________________________________________________________________

subroutine turbkw &
 ( nvar   , nscal  , ncepdp , ncesmp ,                            &
   icepdc , icetsm , itypsm ,                                     &
   dt     ,                                                       &
   tslagr , ckupdc , smacel )

!===============================================================================

!===============================================================================
! Module files
!===============================================================================

use paramx
use numvar
use entsor
use cstnum
use cstphy
use optcal
use lagran
use pointe, only: s2kw, divukw, ifapat, dispar
use parall
use mesh
use field
use field_operator
use cs_c_bindings

!===============================================================================

implicit none

! Arguments

integer          nvar   , nscal
integer          ncepdp , ncesmp

integer          icepdc(ncepdp)
integer          icetsm(ncesmp), itypsm(ncesmp,nvar)

double precision dt(ncelet)
double precision tslagr(ncelet,*)
double precision ckupdc(ncepdp,6), smacel(ncesmp,nvar)

! Local variables

character(len=80) :: chaine
integer          iel   , ifac  , inc   , iprev,  iccocg, ivar
integer          ii, iivar , iiun  , ifacpt
integer          iclipk, iclipw, isqrt
integer          nswrgp, imligp
integer          iconvp, idiffp, ndircp
integer          nswrsp, ircflp, ischcp, isstpp, iescap
integer          iflmas, iflmab
integer          iwarnp
integer          istprv
integer          imucpp, idftnp, iswdyp

integer          icvflb
integer          ivoid(1)

double precision rnorm , d2s3, divp23, epz2
double precision deltk , deltw, a11, a12, a22, a21
double precision unsdet, romvsd
double precision prdtur, xk, xw, xeps, xnu
double precision visct , rho, visclc, visctc, hint
double precision blencp, epsilp, epsrgp, climgp, extrap, relaxp
double precision thetp1, thetak, thetaw, thets, thetap, epsrsp
double precision tuexpk, tuexpw
double precision cdkw, xarg1, xxf1, xgamma, xbeta, sigma, produc
double precision var, vrmin(2), vrmax(2)

double precision rvoid(1)

double precision, allocatable, dimension(:) :: viscf, viscb
double precision, allocatable, dimension(:) :: smbrk, smbrw
double precision, allocatable, dimension(:) :: tinstk, tinstw, xf1
double precision, allocatable, dimension(:,:) :: gradk, grado, grad
double precision, allocatable, dimension(:) :: w1, w2
double precision, allocatable, dimension(:) :: gdkgdw
double precision, allocatable, dimension(:) :: w5, w6
double precision, allocatable, dimension(:) :: prodk, prodw
double precision, allocatable, dimension(:) :: gamk, gamw
double precision, allocatable, dimension(:) :: usimpk, usimpw
double precision, allocatable, dimension(:) :: w7
double precision, allocatable, dimension(:) :: dpvar
double precision, allocatable, dimension(:) :: rotfct
double precision, dimension(:), pointer :: imasfl, bmasfl
double precision, dimension(:), pointer :: brom, crom
double precision, dimension(:), pointer :: bromo, cromo
double precision, dimension(:), pointer :: coefa_k, coefb_k, coefaf_k, coefbf_k
double precision, dimension(:), pointer :: coefa_o, coefb_o, coefaf_o, coefbf_o
double precision, dimension(:), pointer :: cvar_k, cvara_k, cvar_omg, cvara_omg
double precision, dimension(:), pointer :: cvar_var
double precision, dimension(:), pointer :: cpro_pcvto, cpro_pcvlo
double precision, dimension(:), pointer :: viscl, cvisct
double precision, dimension(:), pointer :: c_st_k_p, c_st_omg_p

!===============================================================================

!===============================================================================
! 1.Initialization
!===============================================================================

! Allocate temporary arrays for the turbulence resolution
allocate(viscf(nfac), viscb(nfabor))
allocate(smbrk(ncelet), smbrw(ncelet))
allocate(tinstk(ncelet), tinstw(ncelet), xf1(ncelet))

! Allocate work arrays
allocate(w1(ncelet), w2(ncelet))
allocate(dpvar(ncelet))
allocate(gdkgdw(ncelet))
allocate(prodk(ncelet), prodw(ncelet))

epz2 = epzero**2

call field_get_val_s(iprpfl(ivisct), cvisct)
call field_get_val_s(iprpfl(iviscl), viscl)

call field_get_key_int(ivarfl(ik), kimasf, iflmas)
call field_get_key_int(ivarfl(ik), kbmasf, iflmab)
call field_get_val_s(iflmas, imasfl)
call field_get_val_s(iflmab, bmasfl)

call field_get_val_s(icrom, crom)
call field_get_val_s(ibrom, brom)
call field_get_val_s(icrom, cromo)
call field_get_val_s(ibrom, bromo)

call field_get_val_s(iprpfl(ivisct), cpro_pcvto)
call field_get_val_s(iprpfl(iviscl), cpro_pcvlo)

call field_get_val_s(ivarfl(ik), cvar_k)
call field_get_val_prev_s(ivarfl(ik), cvara_k)
call field_get_val_s(ivarfl(iomg), cvar_omg)
call field_get_val_prev_s(ivarfl(iomg), cvara_omg)

call field_get_coefa_s(ivarfl(ik), coefa_k)
call field_get_coefb_s(ivarfl(ik), coefb_k)
call field_get_coefaf_s(ivarfl(ik), coefaf_k)
call field_get_coefbf_s(ivarfl(ik), coefbf_k)

call field_get_coefa_s(ivarfl(iomg), coefa_o)
call field_get_coefb_s(ivarfl(iomg), coefb_o)
call field_get_coefaf_s(ivarfl(iomg), coefaf_o)
call field_get_coefbf_s(ivarfl(iomg), coefbf_o)

thets  = thetst

call field_get_key_int(ivarfl(ik), kstprv, istprv)
if (istprv.ge.0) then
  call field_get_val_s(istprv, c_st_k_p)
  call field_get_key_int(ivarfl(iep), kstprv, istprv)
  if (istprv.ge.0) then
    call field_get_val_s(istprv, c_st_omg_p)
  endif
  if (istprv.ge.0) istprv = 1
endif

if (istprv.ge.0) then
  if (iroext.gt.0) then
    call field_get_val_prev_s(icrom, cromo)
    call field_get_val_prev_s(ibrom, bromo)
  endif
  if (iviext.gt.0) then
    call field_get_val_s(iprpfl(ivista), cpro_pcvto)
    call field_get_val_s(iprpfl(ivisla), cpro_pcvlo)
  endif
endif

if (iwarni(ik).ge.1) then
  write(nfecra,1000)
endif

d2s3 = 2.d0/3.d0

!===============================================================================
! 2.1 Compute dk/dxj.dw/dxj
!     stored in gdkgdw
!===============================================================================

! Allocate temporary arrays for gradients calculation
allocate(gradk(3,ncelet), grado(3,ncelet))

iccocg = 1
inc = 1
iprev = 1

call field_gradient_scalar(ivarfl(ik), iprev, imrgra, inc,          &
                           iccocg,                                  &
                           gradk)

call field_gradient_scalar(ivarfl(iomg), iprev, imrgra, inc,        &
                           iccocg,                                  &
                           grado)

do iel = 1, ncel
  gdkgdw(iel) = gradk(1,iel)*grado(1,iel) &
              + gradk(2,iel)*grado(2,iel) &
              + gradk(3,iel)*grado(3,iel)
enddo

! Free memory
deallocate(gradk, grado)

!===============================================================================
! 2.2. Compute the weight f1 (stored in xf1)
!===============================================================================

if (abs(icdpar).eq.2) then
  do iel = 1, ncel
    ifacpt = ifapat(iel)
    w2(iel) = (cdgfbo(1,ifacpt)-xyzcen(1,iel))**2 &
            + (cdgfbo(2,ifacpt)-xyzcen(2,iel))**2 &
            + (cdgfbo(3,ifacpt)-xyzcen(3,iel))**2
    w2(iel) = sqrt(w2(iel))
  enddo
else
  do iel = 1, ncel
    w2(iel) = max(dispar(iel),epzero)
  enddo
endif

! En cas d'ordre 2 on utilise les valeurs en n car le terme en (1-f1)*gdkgdw
! sera dans PROPCE. Du coup, on aura quand meme certaines "constantes"
! intervenant dans des termes en n+1/2 (ex sigma_k pour la diffusion) calcules
! a partir de f1 en n -> mais l'effet sur les "constantes" est faible
! -> a garder en tete si on fait vraiment de l'ordre 2 en temps en k-omega
do iel = 1, ncel
  rho = cromo(iel)
  xnu = cpro_pcvlo(iel)/rho
  xk = cvara_k(iel)
  xw  = cvara_omg(iel)
  cdkw = 2*rho/ckwsw2/xw*gdkgdw(iel)
  cdkw = max(cdkw,1.d-20)
  xarg1 = max(sqrt(xk)/cmu/xw/w2(iel), 500.d0*xnu/xw/w2(iel)**2)
  xarg1 = min(xarg1, 4.d0*rho*xk/ckwsw2/cdkw/w2(iel)**2)
  xf1(iel) = tanh(xarg1**4)
enddo

!===============================================================================
! 3. Unsteady terms (stored in tinstk and tinstw)
!===============================================================================

do iel = 1, ncel
  rho = crom(iel)
  romvsd = rho*volume(iel)/dt(iel)
  tinstk(iel) = istat(ik)*romvsd
  tinstw(iel) = istat(iomg)*romvsd
enddo

!===============================================================================
! 4. Compute production terms
!     stored in: prodk,prodw
!      En sortie de l'etape on conserve gdkgdw,xf1,prodk,tinstW
!===============================================================================

do iel = 1, ncel
  xk   = cvara_k(iel)
  xw   = cvara_omg(iel)
  xeps = cmu*xw*xk
  visct = cpro_pcvto(iel)
  rho = cromo(iel)
  prodw(iel) = visct*s2kw(iel)                    &
             - d2s3*rho*xk*divukw(iel)

  ! The negative part is implicited
  xxf1   = xf1(iel)
  xgamma = xxf1*ckwgm1 + (1.d0-xxf1)*ckwgm2
  tinstw(iel) = tinstw(iel)                                         &
              + max( d2s3*rho*volume(iel)                           &
                   *(rho*xgamma*xk/(visct*xw))*divukw(iel), 0.d0)

  ! Take the min between prodw and the low Reynold one
  if (prodw(iel).gt.ckwc1*rho*xeps) then
    prodk(iel) = ckwc1*rho*xeps
  else
    prodk(iel) = prodw(iel)
    tinstk(iel) = tinstk(iel) + max(d2s3*volume(iel)*rho*divukw(iel), 0.d0)
  endif
enddo

!===============================================================================
! 5. Take into account rotation/curvature correction, if necessary
!===============================================================================

! Spalart-Shur correction: the production terms are multiplied by a
! 'rotation function'

if (irccor.eq.1) then

  ! Allocate an array for the rotation function
  allocate(rotfct(ncel))

  ! Compute the rotation function (gdkgdw array not used)
  call rotcor(dt, rotfct, gdkgdw)
  !==========

  do iel = 1, ncel
    prodk(iel) = prodk(iel)*rotfct(iel)
    prodw(iel) = prodw(iel)*rotfct(iel)
  enddo

  ! rotfct array is used later in case of renforced coupling (ikecou = 1).
  ! The array is deallocated at the end of the subroutine.

endif

!===============================================================================
! 6. Compute buoyancy terms
!     stored in: prodk, prodw, w2
!===============================================================================

if (igrake.eq.1) then

  ! Allocate a temporary array for the gradient calculation
  allocate(grad(ncelet,3))

  ! --- Buoyant term:     G = Beta*g*GRAD(T)/PrT/rho
  !     Here is computed: G =-g*GRAD(rho)/PrT/rho

  iccocg = 1
  inc = 1

  nswrgp = nswrgr(ik)
  epsrgp = epsrgr(ik)
  imligp = imligr(ik)
  iwarnp = iwarni(ik)
  climgp = climgr(ik)
  extrap = extrag(ik)

  ! BCs on rho: Dirichlet ROMB
  !  NB: viscb is used as COEFB

  do ifac = 1, nfabor
    viscb(ifac) = 0.d0
  enddo

  iivar = 0

  call grdcel &
  !==========
 ( iivar  , imrgra , inc    , iccocg , nswrgp , imligp ,          &
   iwarnp , nfecra , epsrgp , climgp , extrap ,                   &
   cromo  , bromo  , viscb  ,                                     &
   grad   )


  ! Buoyancy production
  !   prodk=min(P,c1*eps)+G
  !   prodw=P+(1-ce3)*G
  if (iscalt.gt.0.and.nscal.ge.iscalt) then
    prdtur = sigmas(iscalt)
  else
    prdtur = 1.d0
  endif

  do iel = 1, ncel
    rho = cromo(iel)
    visct = cpro_pcvto(iel)

    w2(iel) = -(grad(iel,1)*gx + grad(iel,2)*gy + grad(iel,3)*gz) / &
               (rho*prdtur)

    prodw(iel) = prodw(iel)+visct*max(w2(iel),zero)
    prodk(iel) = prodk(iel)+visct*w2(iel)

    ! Implicit Buoyant terms when negativ
    tinstk(iel) = tinstk(iel)                                        &
                + max(-volume(iel)*visct/cvara_k(iel)*w2(iel), 0.d0)
  enddo

  ! Free memory
  deallocate(grad)

endif

!===============================================================================
! 7. Take user source terms into account
!     explicit parts stored in: smbrk, smbrw
!     implicit parts stored in: usimpk, usimpw
!===============================================================================

allocate(usimpk(ncelet), usimpw(ncelet))

do iel = 1, ncel
  smbrk(iel) = 0.d0
  smbrw(iel) = 0.d0
  usimpk(iel) = 0.d0
  usimpw(iel) = 0.d0
enddo

call cs_user_turbulence_source_terms &
!===================================
 ( nvar   , nscal  , ncepdp , ncesmp ,                            &
   ivarfl(ik)      ,                                              &
   icepdc , icetsm , itypsm ,                                     &
   ckupdc , smacel ,                                              &
   smbrk  , usimpk )

call cs_user_turbulence_source_terms &
!===================================
 ( nvar   , nscal  , ncepdp , ncesmp ,                            &
   ivarfl(iomg)    ,                                              &
   icepdc , icetsm , itypsm ,                                     &
   ckupdc , smacel ,                                              &
   smbrw  , usimpw )

! If source terms are extrapolated over time
if (istprv.ge.0) then

  thetak = thetav(ik)
  thetaw = thetav(iomg)

  do iel = 1, ncel

    ! Recover the value at time (n-1)
    tuexpk = c_st_k_p(iel)
    tuexpw = c_st_omg_p(iel)

    ! Save the values for the next time-step
    c_st_k_p(iel) = smbrk(iel)
    c_st_omg_p(iel) = smbrw(iel)

    ! Explicit Part
    smbrk(iel) = - thets*tuexpk
    smbrw(iel) = - thets*tuexpw
    ! It is assumed that (-usimpk > 0) and though this term is implicit
    smbrk(iel) = usimpk(iel)*cvara_k(iel) + smbrk(iel)
    smbrw(iel) = usimpw(iel)*cvara_omg(iel) + smbrw(iel)

    ! Implicit part
    tinstk(iel) = tinstk(iel) -usimpk(iel)*thetak
    tinstw(iel) = tinstw(iel) -usimpw(iel)*thetaw
  enddo

! If no extrapolation over time
else
  do iel = 1, ncel
    ! Explicit Part
    smbrk(iel) = smbrk(iel) + usimpk(iel)*cvara_k(iel)
    smbrw(iel) = smbrw(iel) + usimpw(iel)*cvara_omg(iel)

    ! Implicit part
    tinstk(iel) = tinstk(iel) + max(-usimpk(iel),zero)
    tinstw(iel) = tinstw(iel) + max(-usimpw(iel),zero)
  enddo
endif


!===============================================================================
! 8. Finalization of explicit and implicit source terms

!      Les termes sont stockes dans     smbrk, smbrw
!      En sortie de l'etape on conserve smbrk,smbrw,gdkgdw
!===============================================================================

do iel = 1, ncel

  visct  = cpro_pcvto(iel)
  rho    = cromo(iel)
  xk     = cvara_k(iel)
  xw     = cvara_omg(iel)
  xxf1   = xf1(iel)
  xgamma = xxf1*ckwgm1 + (1.d0-xxf1)*ckwgm2
  xbeta  = xxf1*ckwbt1 + (1.d0-xxf1)*ckwbt2

  smbrk(iel) = smbrk(iel) + volume(iel)*(                         &
                                          prodk(iel)              &
                                        - cmu*rho*xw*xk )

  smbrw(iel) = smbrw(iel)                                                &
             + volume(iel)*(                                             &
                             rho*xgamma/visct*prodw(iel)                 &
                           - xbeta*rho*xw**2                             &
                           + 2.d0*rho/xw*(1.d0-xxf1)/ckwsw2*gdkgdw(iel)  &
                           )

  tinstw(iel) = tinstw(iel) + volume(iel)*max(-2.d0*rho/xw**2*(1.d0-xxf1) &
                                              /ckwsw2*gdkgdw(iel), 0.d0)
enddo

! If the solving of k-omega is uncoupled, negative source terms are implicited
if (ikecou.eq.0) then
  do iel=1,ncel
    xw    = cvara_omg(iel)
    xxf1  = xf1(iel)
    xbeta = xxf1*ckwbt1 + (1.d0-xxf1)*ckwbt2
    rho = crom(iel)
    tinstk(iel) = tinstk(iel) + volume(iel)*cmu*rho*xw
    tinstw(iel) = tinstw(iel) + 2.d0*volume(iel)*xbeta*rho*xw
  enddo
endif

! Free memory
deallocate(gdkgdw)

!===============================================================================
! 9 Prise en compte des termes sources lagrangien
!   couplage retour
!===============================================================================

!     Ordre 2 non pris en compte
if (iilagr.eq.2 .and. ltsdyn.eq.1) then

  do iel = 1, ncel

    ! Termes sources explicte et implicte sur k
    smbrk(iel)  = smbrk(iel) + tslagr(iel,itske)

    ! Termes sources explicte sur omega : on reprend la constante CE4 directement
    !    du k-eps sans justification ... a creuser si necessaire
    smbrw(iel)  = smbrw(iel)                                      &
                + ce4 *tslagr(iel,itske) * cromo(iel)             &
                /cpro_pcvto(iel)

    ! Termes sources implicite sur k
    tinstk(iel) = tinstk(iel) + max(-tslagr(iel,itsli),zero)

    ! Termes sources implicte sur omega
    tinstw(iel) = tinstw(iel)                                     &
                + max( (-ce4*tslagr(iel,itske)/cvara_k(iel)) , zero)
  enddo

endif

!===============================================================================
! 10. Mass source terms (Implicit and explicit parts)

!===============================================================================

if (ncesmp.gt.0) then

  allocate(gamk(ncelet), gamw(ncelet))

  ! Entier egal a 1 (pour navsto : nb de sur-iter)
  iiun = 1

  ! On incremente SMBRS par -Gamma.var_prev et ROVSDT par Gamma (*theta)
  ivar = ik

  call catsma &
  !==========
 ( ncelet , ncel   , ncesmp , iiun   ,                            &
   isto2t , thetav(ivar) ,                                        &
   icetsm , itypsm(1,ivar) ,                                      &
   volume , cvara_k      , smacel(1,ivar) , smacel(1,ipr) ,       &
   smbrk  , tinstk , gamk )

  ivar = iomg

  call catsma &
  !==========
 ( ncelet , ncel   , ncesmp , iiun   ,                            &
   isto2t , thetav(ivar) ,                                        &
   icetsm , itypsm(1,ivar) ,                                      &
   volume , cvara_omg    , smacel(1,ivar) , smacel(1,ipr) ,       &
   smbrw  , tinstw , gamw )

  ! Si on extrapole les TS on met Gamma Pinj dans PROPCE
  if (istprv.ge.0) then
    do iel = 1, ncel
      c_st_k_p(iel) = c_st_k_p(iel) + gamk(iel)
      c_st_omg_p(iel) = c_st_omg_p(iel) + gamw(iel)
    enddo
  !  Sinon on le met directement dans SMBR
  else
    do iel = 1, ncel
      smbrk(iel) = smbrk(iel) + gamk(iel)
      smbrw(iel) = smbrw(iel) + gamw(iel)
    enddo
  endif

  !Free memory
  deallocate(gamk, gamw)

endif

! Finalisation des termes sources
if (istprv.ge.0) then
  thetp1 = 1.d0 + thets
  do iel = 1, ncel
    smbrk(iel) = smbrk(iel) + thetp1 * c_st_k_p(iel)
    smbrw(iel) = smbrw(iel) + thetp1 * c_st_omg_p(iel)
  enddo
endif


!===============================================================================
! 11.1 Re-set Boundary conditions flux coefficient for k and omega

!     The definition of cofaf requires hint=(mu+muT/sigma)/distb where sigma
!     is not constant in the k-omega model (and not directly accessible)
!===============================================================================

do ifac = 1, nfabor

  iel = ifabor(ifac)

  ! --- Physical Propreties
  visclc = viscl(iel)
  visctc = cvisct(iel)

  xxf1 = xf1(iel)

  ! k
  sigma = xxf1*ckwsk1 + (1.d0-xxf1)*ckwsk2
  hint = (visclc+visctc/sigma)/distb(ifac)

  ! Translate coefa into cofaf and coefb into cofbf
  coefaf_k(ifac) = -hint*coefa_k(ifac)
  coefbf_k(ifac) = hint*(1.d0-coefb_k(ifac))

  ! Omega
  sigma = xxf1*ckwsw1 + (1.d0-xxf1)*ckwsw2
  hint = (visclc+visctc/sigma)/distb(ifac)

  ! Translate coefa into cofaf and coefb into cofbf
  coefaf_o(ifac) = -hint*coefa_o(ifac)
  coefbf_o(ifac) = hint*(1.d0-coefb_o(ifac))

enddo

!===============================================================================
! 11.2 Prise en compte des termes de conv/diff dans le second membre pour le
!      couplage renforcé k-omega (ikecou == 1)

!      Tableaux de travail              w7
!      Les termes sont stockes dans     w5 ET w6, PUIS AJOUTES A smbrk, smbrw
!      En sortie de l'etape on conserve w2-6,smbrk,smbrw,usimpk
!===============================================================================

if (ikecou.eq.1) then

  allocate(w5(ncelet), w6(ncelet))
  allocate(w7(ncelet))

  do iel = 1, ncel
    w5 (iel) = 0.d0
    w6 (iel) = 0.d0
  enddo

  ! ---> Traitement de k
  ivar   = ik

  call field_get_label(ivarfl(ivar), chaine)

  if (idiff(ivar).ge. 1) then

    do iel = 1, ncel
      xxf1 = xf1(iel)
      sigma = xxf1*ckwsk1 + (1.d0-xxf1)*ckwsk2
      w7(iel) = viscl(iel)                                        &
              + idifft(ivar)*cvisct(iel)/sigma
    enddo
    call viscfa &
    !==========
 ( imvisf ,                                                       &
   w7     ,                                                       &
   viscf  , viscb  )

  else

    do ifac = 1, nfac
      viscf(ifac) = 0.d0
    enddo
    do ifac = 1, nfabor
      viscb(ifac) = 0.d0
    enddo

  endif

  iccocg = 1
  inc    = 1
  imucpp = 0
  idftnp = 1 ! no tensorial diffusivity
  iconvp = iconv (ivar)
  idiffp = idiff (ivar)
  nswrgp = nswrgr(ivar)
  imligp = imligr(ivar)
  ircflp = ircflu(ivar)
  ischcp = ischcv(ivar)
  isstpp = isstpc(ivar)
  iwarnp = iwarni(ivar)
  blencp = blencv(ivar)
  epsrgp = epsrgr(ivar)
  climgp = climgr(ivar)
  extrap = extrag(ivar)
  relaxp = relaxv(ivar)
  thetap = thetav(ivar)
  ! all boundary convective flux with upwind
  icvflb = 0

  call bilsca &
  !==========
 ( idtvar , ivar   , iconvp , idiffp , nswrgp , imligp , ircflp , &
   ischcp , isstpp , inc    , imrgra , iccocg ,                   &
   iwarnp , imucpp , idftnp ,                                     &
   blencp , epsrgp , climgp , extrap , relaxp , thetap ,          &
   cvara_k         , cvara_k         ,                            &
   coefa_k , coefb_k , coefaf_k , coefbf_k ,                      &
   imasfl , bmasfl ,                                              &
   viscf  , viscb  , rvoid  , rvoid  ,                            &
   rvoid  , rvoid  ,                                              &
   icvflb , ivoid  ,                                              &
   w5     )

  if (iwarni(ivar).ge.2) then
    isqrt = 1
    call prodsc(ncel,isqrt,smbrk,smbrk,rnorm)
    write(nfecra,1100) chaine(1:8) ,rnorm
  endif

  ! ---> Traitement de omega
  ivar   = iomg

  call field_get_label(ivarfl(ivar), chaine)

  if (idiff(ivar).ge. 1) then
    do iel = 1, ncel
      xxf1 = xf1(iel)
      sigma = xxf1*ckwsw1 + (1.d0-xxf1)*ckwsw2
      w7(iel) = viscl(iel)                                        &
              + idifft(ivar)*cvisct(iel)/sigma
    enddo
    call viscfa &
    !==========
 ( imvisf ,                                                       &
   w7     ,                                                       &
   viscf  , viscb  )

  else

    do ifac = 1, nfac
      viscf(ifac) = 0.d0
    enddo
    do ifac = 1, nfabor
      viscb(ifac) = 0.d0
    enddo

  endif

  iccocg = 1
  inc    = 1
  imucpp = 0
  idftnp = 1 ! no tensorial diffusivity
  iconvp = iconv (ivar)
  idiffp = idiff (ivar)
  nswrgp = nswrgr(ivar)
  imligp = imligr(ivar)
  ircflp = ircflu(ivar)
  ischcp = ischcv(ivar)
  isstpp = isstpc(ivar)
  iwarnp = iwarni(ivar)
  blencp = blencv(ivar)
  epsrgp = epsrgr(ivar)
  climgp = climgr(ivar)
  extrap = extrag(ivar)
  relaxp = relaxv(ivar)
  thetap = thetav(ivar)
  ! all boundary convective flux with upwind
  icvflb = 0

  call bilsca &
  !==========
 ( idtvar , ivar   , iconvp , idiffp , nswrgp , imligp , ircflp , &
   ischcp , isstpp , inc    , imrgra , iccocg ,                   &
   iwarnp , imucpp , idftnp ,                                     &
   blencp , epsrgp , climgp , extrap , relaxp , thetap ,          &
   cvara_omg       , cvara_omg       ,                            &
   coefa_o , coefb_o , coefaf_o , coefbf_o ,                      &
   imasfl , bmasfl ,                                              &
   viscf  , viscb  , rvoid  , rvoid  ,                            &
   rvoid  , rvoid  ,                                              &
   icvflb , ivoid  ,                                              &
   w6     )

  if (iwarni(ivar).ge.2) then
    isqrt = 1
    call prodsc(ncel,isqrt,smbrw,smbrw,rnorm)
    write(nfecra,1100) chaine(1:8) ,rnorm
  endif

  do iel = 1,ncel
    smbrk(iel) = smbrk(iel) + w5(iel)
    smbrw(iel) = smbrw(iel) + w6(iel)
  enddo

endif

!===============================================================================
! 11.3 k-omega coupling (ikecou == 1)

!===============================================================================

!  Ordre 2 non pris en compte
if (ikecou.eq.1) then

  ! Take into account, if necessary, the Spalart-Shur rotation/curvature
  ! correction of the production term
  if (irccor.eq.2) then
    do iel = 1, ncel
      w1(iel) = rotfct(iel)
    enddo
  else
    do iel = 1, ncel
      w1(iel) = 1.d0
    enddo
  endif

  do iel = 1, ncel

    rho = crom(iel)

    ! RESOLUTION COUPLEE

    romvsd     = 1.d0/(rho*volume(iel))
    smbrk(iel) = smbrk(iel)*romvsd
    smbrw(iel) = smbrw(iel)*romvsd
    divp23     = d2s3*max(divukw(iel),zero)
    produc     = w1(iel)*s2kw(iel)+w2(iel)
    xk         = cvara_k(iel)
    xw         = cvara_omg(iel)
    xxf1       = xf1(iel)
    xgamma     = xxf1*ckwgm1 + (1.d0-xxf1)*ckwgm2
    xbeta      = xxf1*ckwbt1 + (1.d0-xxf1)*ckwbt2

    a11 = 1.d0/dt(iel)                                            &
         - 1.d0/xw*min(produc,zero)+divp23+cmu*xw
    a12 = cmu*xk
    a21 = 0.d0
    a22 = 1.d0/dt(iel)+xgamma*divp23+2.d0*xbeta*xw

    unsdet = 1.d0/(a11*a22 -a12*a21)

    deltk = ( a22*smbrk(iel) -a12*smbrw(iel) )*unsdet
    deltw = (-a21*smbrk(iel) +a11*smbrw(iel) )*unsdet

    ! NOUVEAU TERME SOURCE POUR CODITS

    romvsd = rho*volume(iel)/dt(iel)

    smbrk(iel) = romvsd*deltk
    smbrw(iel) = romvsd*deltw

  enddo


  ! on enleve la convection/diffusion au temps n a SMBRK et SMBRW
  ! s'ils ont ete calcules
  do iel = 1, ncel
    smbrk(iel) = smbrk(iel) - w5(iel)
    smbrw(iel) = smbrw(iel) - w6(iel)
  enddo

  ! Free memory
  deallocate(w5, w6)
  deallocate(w7)

endif

!===============================================================================
! 14. Solving
!===============================================================================

! ---> turbulent kinetic (k) energy treatment
ivar = ik

! Face viscosity
if (idiff(ivar).ge. 1) then

  do iel = 1, ncel
    xxf1 = xf1(iel)
    sigma = xxf1*ckwsk1 + (1.d0-xxf1)*ckwsk2
    w1(iel) = viscl(iel)                                          &
             + idifft(ivar)*cvisct(iel)/sigma
  enddo
  call viscfa &
  !==========
 ( imvisf ,                                                       &
   w1     ,                                                       &
   viscf  , viscb  )

else

  do ifac = 1, nfac
    viscf(ifac) = 0.d0
  enddo
  do ifac = 1, nfabor
    viscb(ifac) = 0.d0
  enddo

endif

! Solving k
iconvp = iconv (ivar)
idiffp = idiff (ivar)
ndircp = ndircl(ivar)
nswrsp = nswrsm(ivar)
nswrgp = nswrgr(ivar)
imligp = imligr(ivar)
ircflp = ircflu(ivar)
ischcp = ischcv(ivar)
isstpp = isstpc(ivar)
iescap = 0
imucpp = 0
idftnp = 1 ! no tensorial diffusivity
iswdyp = iswdyn(ivar)
iwarnp = iwarni(ivar)
blencp = blencv(ivar)
epsilp = epsilo(ivar)
epsrsp = epsrsm(ivar)
epsrgp = epsrgr(ivar)
climgp = climgr(ivar)
extrap = extrag(ivar)
relaxp = relaxv(ivar)
thetap = thetav(ivar)
! all boundary convective flux with upwind
icvflb = 0

call codits &
!==========
 ( idtvar , ivar   , iconvp , idiffp , ndircp ,                   &
   imrgra , nswrsp , nswrgp , imligp , ircflp ,                   &
   ischcp , isstpp , iescap , imucpp , idftnp , iswdyp ,          &
   iwarnp ,                                                       &
   blencp , epsilp , epsrsp , epsrgp , climgp , extrap ,          &
   relaxp , thetap ,                                              &
   cvara_k         , cvara_k         ,                            &
   coefa_k , coefb_k , coefaf_k , coefbf_k ,                      &
   imasfl , bmasfl ,                                              &
   viscf  , viscb  , rvoid  , viscf  , viscb  , rvoid  ,          &
   rvoid  , rvoid  ,                                              &
   icvflb , ivoid  ,                                              &
   tinstk , smbrk  , cvar_k          , dpvar  ,                   &
   rvoid  , rvoid  )

! ---> Omega treatment
ivar = iomg

! Face viscosity
if (idiff(ivar).ge. 1) then
  do iel = 1, ncel
    xxf1 = xf1(iel)
    sigma = xxf1*ckwsw1 + (1.d0-xxf1)*ckwsw2
    w1(iel) = viscl(iel)                                          &
                        + idifft(ivar)*cvisct(iel)/sigma
  enddo
  call viscfa &
  !==========
 ( imvisf ,                                                       &
   w1     ,                                                       &
   viscf  , viscb  )

else

  do ifac = 1, nfac
    viscf(ifac) = 0.d0
  enddo
  do ifac = 1, nfabor
    viscb(ifac) = 0.d0
  enddo

endif

! Solving omega
iconvp = iconv (ivar)
idiffp = idiff (ivar)
ndircp = ndircl(ivar)
nswrsp = nswrsm(ivar)
nswrgp = nswrgr(ivar)
imligp = imligr(ivar)
ircflp = ircflu(ivar)
ischcp = ischcv(ivar)
isstpp = isstpc(ivar)
iescap = 0
imucpp = 0
idftnp = 1 ! no tensorial diffusivity
iswdyp = iswdyn(ivar)
iwarnp = iwarni(ivar)
blencp = blencv(ivar)
epsilp = epsilo(ivar)
epsrsp = epsrsm(ivar)
epsrgp = epsrgr(ivar)
climgp = climgr(ivar)
extrap = extrag(ivar)
relaxp = relaxv(ivar)
thetap = thetav(ivar)
! all boundary convective flux with upwind
icvflb = 0

call codits &
!==========
 ( idtvar , ivar   , iconvp , idiffp , ndircp ,                   &
   imrgra , nswrsp , nswrgp , imligp , ircflp ,                   &
   ischcp , isstpp , iescap , imucpp , idftnp , iswdyp ,          &
   iwarnp ,                                                       &
   blencp , epsilp , epsrsp , epsrgp , climgp , extrap ,          &
   relaxp , thetap ,                                              &
   cvara_omg       , cvara_omg       ,                            &
   coefa_o , coefb_o , coefaf_o , coefbf_o ,                      &
   imasfl , bmasfl ,                                              &
   viscf  , viscb  , rvoid  , viscf  , viscb  , rvoid  ,          &
   rvoid  , rvoid  ,                                              &
   icvflb , ivoid  ,                                              &
   tinstw , smbrw  , cvar_omg        , dpvar  ,                   &
   rvoid  , rvoid  )

!===============================================================================
! 15. Clipping
!===============================================================================

! Calcul des Min/Max avant clipping, pour affichage
do ii = 1, 2
  if (ii.eq.1) then
    cvar_var => cvar_k
  elseif (ii.eq.2) then
    cvar_var => cvar_omg
  endif

  vrmin(ii) =  grand
  vrmax(ii) = -grand
  do iel = 1, ncel
    var = cvar_var(iel)
    vrmin(ii) = min(vrmin(ii),var)
    vrmax(ii) = max(vrmax(ii),var)
  enddo
enddo

! On clippe simplement k et omega par valeur absolue
iclipk = 0
iclipw = 0
do iel = 1, ncel
  xk = cvar_k(iel)
  xw = cvar_omg(iel)
  if (abs(xk).le.epz2) then
    iclipk = iclipk + 1
    cvar_k(iel) = max(cvar_k(iel),epz2)
  elseif (xk.le.0.d0) then
    iclipk = iclipk + 1
    cvar_k(iel) = -xk
  endif
  if (abs(xw).le.epz2) then
    iclipw = iclipw + 1
    cvar_omg(iel) = max(cvar_omg(iel),epz2)
  elseif (xw.le.0.d0) then
    iclipw = iclipw + 1
    cvar_omg(iel) = -xw
  endif
enddo

! ---  Stockage nb de clippings pour listing

call log_iteration_clipping_field(ivarfl(ik), iclipk, 0,    &
                                  vrmin(1:1), vrmax(1:1))
call log_iteration_clipping_field(ivarfl(iomg), iclipw, 0,  &
                                  vrmin(2:2), vrmax(2:2))

! Free memory
deallocate(viscf, viscb)
deallocate(smbrk, smbrw)
deallocate(tinstk, tinstw, xf1)
deallocate(w1, w2, usimpk, usimpw)
deallocate(dpvar)
deallocate(prodk, prodw)

if (allocated(rotfct))  deallocate(rotfct)

!--------
! Formats
!--------

#if defined(_CS_LANG_FR)

 1000 format(/, &
'   ** RESOLUTION DU K-OMEGA'                     ,/,&
'      ---------------------'                     ,/)
 1100 format(1X,A8,' : BILAN EXPLICITE = ',E14.5)

#else

 1000 format(/, &
'   ** SOLVING K-OMEGA'                           ,/,&
'      ---------------'                           ,/)
 1100 format(1X,A8,' : EXPLICIT BALANCE = ',E14.5)

#endif

!----
! End
!----

return

end subroutine
