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

!> \file prehyd.f90
!>
!> \brief Compute an "a priori" hydrostatic pressure and its gradient associated
!> before the Navier Stokes equations
!> (prediction and correction steps \ref navstv.f90).
!>
!> This function computes a hydrostatic pressure \f$ P_{hydro} \f$ solving an
!> a priori simplified momentum equation:
!> \f[
!> \rho^n \dfrac{(\vect{u}^{hydro} - \vect{u}^n)}{\Delta t} =
!> \rho^n \vect{g}^n - \grad P_{hydro}
!> \f]
!> and using the mass equation as following:
!> \f[
!> \rho^n \divs \left( \delta \vect{u}_{hydro} \right) = 0
!> \f]
!> with: \f$ \delta \vect{u}_{hydro} = ( \vect{u}^{hydro} - \vect{u}^n) \f$
!>
!> finally, we resolve the simplified momentum equation below:
!> \f[
!> \divs \left( K \grad P_{hydro} \right) = \divs \left(\vect{g}\right)
!> \f]
!> with the diffusion coefficient (\f$ K \f$) defined as:
!> \f[
!>      K \equiv \dfrac{1}{\rho^n}
!> \f]
!> with a Neumann boundary condition on the hydrostatic pressure:
!> \f[
!>    D_\fib \left( K, \, P_{hydro} \right) =
!>    \vect{g} \cdot \vect{n}_\ib
!> \f]
!> (see the theory guide for more details on the boundary condition
!>  formulation).
!-------------------------------------------------------------------------------

!-------------------------------------------------------------------------------
!-------------------------------------------------------------------------------
! Arguments
!______________________________________________________________________________.
!  mode           name          role                                           !
!______________________________________________________________________________!
!> \param[in,out] prhyd         hydrostatic pressure predicted with
!>                              the a priori momentum equation reduced
!>                              \f$ P_{hydro} \f$
!> \param[out]    grdphd         the a priori hydrostatic pressure gradient
!>                              \f$ \partial _x (P_{hydro}) \f$
!_______________________________________________________________________________

subroutine prehyd &
 ( prhyd , grdphd  )

!===============================================================================

!===============================================================================
! Module files
!===============================================================================

use paramx
use numvar
use entsor
use cstphy
use cstnum
use optcal
use albase
use parall
use period
use lagpar
use lagran
use cplsat
use mesh
use field
use cs_c_bindings

!===============================================================================

implicit none

! Arguments

double precision prhyd(ncelet), grdphd(ncelet,ndim)

! Local variables

integer          iccocg, inc, isym  , isqrt
integer          iel   , ifac
integer          nswrgp, imligp, iwarnp
integer          iflmas, iflmab
integer          idiffp, iconvp, ndircp
integer          ibsize
integer          iescap, ircflp, ischcp, isstpp, ivar
integer          nswrsp
integer          imucpp, idftnp, iswdyp
integer          iharmo
integer          icvflb
integer          ivoid(1)

double precision thetap
double precision epsrgp, climgp, extrap, epsilp
double precision hint, qimp, epsrsp, blencp, relaxp

double precision rvoid(1)

double precision, allocatable, dimension(:) :: coefap, cofafp, coefbp, cofbfp

double precision, allocatable, dimension(:) :: viscf, viscb
double precision, allocatable, dimension(:) :: xinvro
double precision, allocatable, dimension(:) :: dpvar
double precision, allocatable, dimension(:) :: smbr, rovsdt
double precision, dimension(:), pointer :: imasfl, bmasfl
double precision, dimension(:), pointer :: crom
!===============================================================================

!===============================================================================
! 1. Initializations
!===============================================================================

! Allocate temporary arrays

! Boundary conditions for delta P
allocate(coefap(nfabor), cofafp(nfabor), coefbp(nfabor), cofbfp(nfabor))

! --- Physical properties
call field_get_val_s(icrom, crom)

call field_get_key_int(ivarfl(iu), kimasf, iflmas)
call field_get_key_int(ivarfl(iu), kbmasf, iflmab)
call field_get_val_s(iflmas, imasfl)
call field_get_val_s(iflmab, bmasfl)

! --- Resolution options
isym  = 1
if (iconv (ipr).gt.0) then
  isym  = 2
endif

! --- Matrix block size
ibsize = 1

isqrt = 1

!===============================================================================
! 2. Solving a diffusion equation with source term to obtain
!    the a priori hydrostatic pressure
!===============================================================================

! --- Allocate temporary arrays
allocate(dpvar(ncelet))
allocate(viscf(nfac), viscb(nfabor))
allocate(xinvro(ncelet))
allocate(smbr(ncelet), rovsdt(ncelet))

! --- Initialization of the variable to solve from the interior cells
do iel = 1, ncel
  xinvro(iel) = 1.d0/crom(iel)
  rovsdt(iel) = 0.d0
  smbr(iel)   = 0.d0
enddo

! --- Viscosity (k_t := 1/rho )
iharmo = 1
call viscfa (iharmo, xinvro, viscf, viscb)

! Neumann boundary condition for the pressure increment
!------------------------------------------------------

do ifac = 1, nfabor

  iel = ifabor(ifac)

  ! Prescribe the pressure gradient: kt.grd(Phyd)|_b = (g.n)|_b

  hint = 1.d0 /(crom(iel)*distb(ifac))
  qimp = - (gx*surfbo(1,ifac)                &
           +gy*surfbo(2,ifac)                &
           +gz*surfbo(3,ifac))/(surfbn(ifac))

  call set_neumann_scalar &
  !======================
  ( coefap(ifac), cofafp(ifac),             &
    coefbp(ifac), cofbfp(ifac),             &
    qimp        , hint )

enddo

! --- Solve the diffusion equation

!--------------------------------------------------------------------------
! We use a conjugate gradient to solve the diffusion equation

! By default, the hydrostatic pressure variable is resolved with 5 sweeps for
! the reconstruction gradient. Here we make the assumption that the mesh
! is orthogonal (any reconstruction gradient is done for the hydrostatic
! pressure variable)

! We do not yet use the multigrid to resolve the hydrostatic pressure
!--------------------------------------------------------------------------

!TODO later: define argument additionnal to pass to codits for work variable
! like prhyd to obtain the warning with namewv(ipwv) = 'Prhydo'

call sles_push(ivarfl(ipr), "Prhydro")

ivar   = ipr
iconvp = 0
idiffp = 1
ndircp = 0
nswrsp = 1           ! no reconstruction gradient
nswrgp = nswrgr(ivar)
imligp = imligr(ivar)
ircflp = ircflu(ivar)
ischcp = ischcv(ivar)
isstpp = isstpc(ivar)
iescap = 0
imucpp = 0
idftnp = 1
iswdyp = iswdyn(ivar)
iwarnp = iwarni(ivar)
blencp = blencv(ivar)
epsilp = epsilo(ivar)
epsrsp = epsrsm(ivar)
epsrgp = epsrgr(ivar)
climgp = climgr(ivar)
extrap = 0.d0
relaxp = relaxv(ivar)
thetap = thetav(ivar)
! all boundary convective flux with upwind
icvflb = 0

! --- Solve the diffusion equation

call codits &
!==========
( idtvar , ivar   , iconvp , idiffp , ndircp ,                   &
  imrgra , nswrsp , nswrgp , imligp , ircflp ,                   &
  ischcp , isstpp , iescap , imucpp , idftnp , iswdyp ,          &
  iwarnp ,                                                       &
  blencp , epsilp , epsrsp , epsrgp , climgp , extrap ,          &
  relaxp , thetap ,                                              &
  prhyd  , prhyd  ,                                              &
  coefap , coefbp ,                                              &
  cofafp , cofbfp ,                                              &
  imasfl , bmasfl ,                                              &
  viscf  , viscb  , rvoid  , viscf  , viscb  , rvoid  ,          &
  rvoid  , rvoid  ,                                              &
  icvflb , ivoid  ,                                              &
  rovsdt , smbr   , prhyd  , dpvar  ,                            &
  rvoid  , rvoid  )

call sles_pop(ivarfl(ipr))

! Free memory
deallocate(dpvar)

inc    = 1
iccocg = 1
nswrgp = 1
extrap = 0.d0

call grdpre &
!==========
 ( ivar   , imrgra , inc    , iccocg , nswrgp , imligp ,         &
   iwarnp , epsrgp , climgp , extrap ,                           &
   prhyd  , xinvro , coefap , coefbp ,                           &
   grdphd   )

!===============================================================================
! Free memory
!===============================================================================

deallocate(coefap, cofafp, coefbp, cofbfp)
deallocate(viscf, viscb)
deallocate(xinvro)
deallocate(smbr, rovsdt)

!--------
! Formats
!--------

!----
! End
!----

return

end subroutine
