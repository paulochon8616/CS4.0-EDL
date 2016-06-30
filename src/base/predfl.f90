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

!> \file predfl.f90
!>
!> \brief Update the convective mass flux before the Navier Stokes equations
!> (prediction and correction steps).
!>
!> This function computes a potential \f$ \varia \f$ solving the equation:
!> \f[
!> D \left( \Delta t, \varia \right) = \divs \left( \rho \vect{u}^n\right)
!>                                   - \Gamma^n
!>                                   + \dfrac{\rho^n - \rho^{n-1}}{\Delta t}
!> \f]
!> This potential is then used to update the mass flux as follows:
!> \f[
!>  \dot{m}^{n+\frac{1}{2}}_\ij = \dot{m}^{n}_\ij
!>                               - \Delta t \grad_\fij \varia \cdot \vect{S}_\ij
!> \f]
!>
!-------------------------------------------------------------------------------

!-------------------------------------------------------------------------------
! Arguments
!______________________________________________________________________________.
!  mode           name          role                                           !
!______________________________________________________________________________!
!> \param[in]     nvar          total number of variables
!> \param[in]     ncesmp        number of cells with mass source term
!> \param[in]     icetsm        index of cells with mass source term
!> \param[in]     dt            time step (per cell)
!> \param[in]     smacel        variable value associated to the mass source
!>                               term (for ivar=ipr, smacel is the mass flux
!>                               \f$ \Gamma^n \f$)
!_______________________________________________________________________________

subroutine predfl &
 ( nvar   , ncesmp ,                                              &
   icetsm ,                                                       &
   dt     ,                                                       &
   smacel )

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

integer          nvar
integer          ncesmp

integer          icetsm(ncesmp)

double precision dt(ncelet)
double precision smacel(ncesmp,nvar)

! Local variables

character(len=80) :: chaine
integer          lchain
integer          iccocg, inc   , init  , isym  , isqrt
integer          ii, iel   , ifac
integer          nswmpr
integer          isweep, niterf
integer          nswrgp, imligp, iwarnp
integer          iflmas, iflmab
integer          idiffp, iconvp, ndircp
integer          iinvpe
integer          ibsize, iesize, iphydp
integer          imucpp, f_id0
double precision residu
double precision thetap
double precision epsrgp, climgp, extrap, epsilp
double precision drom  , tcrite, relaxp, rnorm, hint, qimp

double precision rvoid(1)

double precision, allocatable, dimension(:) :: dam, xam
double precision, allocatable, dimension(:) :: divu, pot, pota, dpot, rhs
double precision, allocatable, dimension(:) :: clapot, clbpot
double precision, allocatable, dimension(:) :: cfapot, cfbpot
double precision, allocatable, dimension(:) :: viscf, viscb
double precision, dimension(:), pointer :: imasfl, bmasfl
double precision, dimension(:), pointer :: brom, crom, croma

!===============================================================================

!===============================================================================
! 1.  Initializations
!===============================================================================

! Allocate temporary arrays
allocate(dam(ncelet), xam(nfac))
allocate(divu(ncelet))
allocate(clapot(nfabor), clbpot(nfabor))
allocate(cfapot(nfabor), cfbpot(nfabor))
allocate(viscf(nfac), viscb(nfabor))
allocate(pot(ncelet), pota(ncelet), dpot(ncelet), rhs(ncelet))

! --- Writing
chaine = 'potential       '
lchain = 16

! --- non field pointer
f_id0 = -1

! --- Physical quantities
call field_get_val_s(icrom, crom)
call field_get_val_s(ibrom, brom)
call field_get_val_prev_s(icrom, croma)

call field_get_key_int(ivarfl(iu), kimasf, iflmas)
call field_get_key_int(ivarfl(iu), kbmasf, iflmab)
call field_get_val_s(iflmas, imasfl)
call field_get_val_s(iflmab, bmasfl)

! --- Solving options
isym  = 1

! Matrix block size
ibsize = 1
iesize = 1

! Boundary conditions on the potential (homogenous Neumann)
do ifac = 1, nfabor

  iel = ifabor(ifac)

  ! Neumann Boundary Conditions
  !----------------------------

  hint = dt(iel)/distb(ifac)
  qimp = 0.d0

  call set_neumann_scalar &
       !==================
     ( clapot(ifac), cfapot(ifac),             &
       clbpot(ifac), cfbpot(ifac),             &
       qimp        , hint )

enddo

!===============================================================================
! 2.  Right Hand side
!===============================================================================

! --- Initial divergence of the mass
init = 1

call divmas(init, imasfl , bmasfl , divu)

! --- Mass source terms
if (ncesmp.gt.0) then
  do ii = 1, ncesmp
    iel = icetsm(ii)
    !FIXME It should be scmacel at time n-1
    divu(iel) = divu(iel) - volume(iel)*smacel(ii,ipr)
  enddo
endif

! --- Source term associated to the mass aggregation
do iel = 1, ncel
  drom = crom(iel) - croma(iel)
  divu(iel) = divu(iel) + drom*volume(iel)/dt(iel)

  ! The initial Right Hand Side is - div(u)
  rhs(iel) = - divu(iel)
enddo

!===============================================================================
! 3. Residual of the system if needed
!===============================================================================

isqrt = 1

call prodsc(ncel,isqrt,rhs,rhs,rnorm)

!===============================================================================
! 4. Building of the linear system to solve
!===============================================================================

! ---> Terme instationnaire

do iel = 1, ncel
  pot(iel) = 0.d0
enddo

! ---> Face diffusibility scalar

if (idiff(ipr).ge.1) then

    call viscfa &
  ( imvisf ,                                                       &
    dt     ,                                                       &
    viscf  , viscb  )

else

  do ifac = 1, nfac
    viscf(ifac) = 0.d0
  enddo
  do ifac = 1, nfabor
    viscb(ifac) = 0.d0
  enddo

endif

iconvp = iconv(ipr)
idiffp = idiff(ipr)
! Strengthen the diagonal
ndircp = 0

thetap = 1.d0
imucpp = 0

call matrix &
!==========
 ( iconvp , idiffp , ndircp , isym   ,                            &
   thetap , imucpp ,                                              &
   clbpot , cfbpot , pot    ,                                     &
   imasfl , bmasfl , viscf  , viscb  ,                            &
   rvoid  , dam    , xam    )

!===============================================================================
! 5. Solving (Loop over the non-orthogonalities)
!===============================================================================

! --- Number of sweeps
nswmpr = nswrsm(ipr)

! --- Variables are set to 0
!       pot     is the potential
!       dpot    is the increment of the potential between sweeps
!       divu    is the inital divergence of the mass flux
do iel = 1,ncel
  pot (iel) = 0.d0
  pota(iel) = 0.d0
  dpot(iel) = 0.d0
enddo

relaxp = relaxv(ipr)

! (Test to modify if needed: must be scticter than
! the test in the conjugate gradient)
tcrite = 10.d0*epsrsm(ipr)*rnorm

! Reconstruction loop (beginning)
!--------------------------------
isweep = 1
residu = rnorm

do while (isweep.le.nswmpr.and.residu.gt.tcrite)

  ! --- Solving on the increment dpot
  do iel = 1, ncel
    dpot(iel) = 0.d0
  enddo

  epsilp = epsilo(ipr)

  ! The potential is a scalar => no problem for the periodicity of rotation
  ! (iinvpe=1)
  iinvpe = 1

  call sles_solve_native(-1, chaine,                                &
                         isym, ibsize, iesize, dam, xam, iinvpe,    &
                         epsilp, rnorm, niterf, residu, rhs, dpot)

  ! Update the increment of potential
  if (idtvar.ge.0.and.isweep.le.nswmpr.and.residu.gt.tcrite) then
    do iel = 1, ncel
      pota(iel) = pot(iel)
      pot(iel)  = pota(iel) + relaxv(ipr)*dpot(iel)
    enddo
  ! If it is the last sweep, update with the total increment
  else
    do iel = 1, ncel
      pota(iel) = pot(iel)
      pot(iel)  = pota(iel) + dpot(iel)
    enddo
  endif

  isweep = isweep + 1

  ! --- Update the right hand side if needed:
  !      rhs^{k+1} = - div(rho u^n) - D(dt, pot^{k+1})

  if (isweep.le.nswmpr) then
    iccocg = 1
    init = 1
    inc  = 0
    nswrgp = nswrgr(ipr)
    imligp = imligr(ipr)
    iwarnp = iwarni(ipr)
    epsrgp = epsrgr(ipr)
    climgp = climgr(ipr)
    extrap = extrag(ipr)
    ! This option should be adapted to iphydr = 1
    iphydp = 0

    call itrgrp &
    !==========
   ( f_id0  , init   , inc    , imrgra , iccocg , nswrgp , imligp , iphydp ,   &
     iwarnp ,                                                                  &
     epsrgp , climgp , extrap ,                                                &
     rvoid  ,                                                                  &
     pot    ,                                                                  &
     clapot , clbpot ,                                                         &
     cfapot , cfbpot ,                                                         &
     viscf  , viscb  ,                                                         &
     dt     , dt     , dt     ,                                                &
     rhs   )

    do iel = 1, ncel
      rhs(iel) = - divu(iel) - rhs(iel)
    enddo

    ! --- Convergence test
    call prodsc(ncel, isqrt, rhs, rhs, residu)

    if (iwarni(ipr).ge.2) then
      if (rnorm.ge.epzero) then
        write(nfecra,1440) chaine(1:16),isweep,residu/rnorm, relaxp
      else
        write(nfecra,1440) chaine(1:16),isweep,residu, relaxp
      endif
    endif

  endif

enddo
! --- Reconstruction loop (end)

if (iwarni(ipr).ge.2) then
  if (isweep.gt.nswmpr) write(nfecra,1600) chaine(1:16), nswmpr
endif

! Update the mass flux
!---------------------

iccocg = 1
init = 0
inc  = 0
iphydp = 0
nswrgp = nswrgr(ipr)
imligp = imligr(ipr)
iwarnp = iwarni(ipr)
epsrgp = epsrgr(ipr)
climgp = climgr(ipr)
extrap = extrag(ipr)

call itrmas &
!==========
 ( f_id0  , init   , inc    , imrgra , iccocg , nswrgp , imligp , iphydp ,     &
   iwarnp ,                                                                    &
   epsrgp , climgp , extrap ,                                                  &
   rvoid  ,                                                                    &
   pota   ,                                                                    &
   clapot , clbpot ,                                                           &
   cfapot , cfbpot ,                                                           &
   viscf  , viscb  ,                                                           &
   dt     , dt     , dt     ,                                                  &
   imasfl , bmasfl )

! The last increment is not reconstructed to fullfill exactly the continuity
! equation (see theory guide)

iccocg = 0
nswrgp = 0
inc = 0

call itrmas &
!==========
 ( f_id0  , init   , inc    , imrgra , iccocg , nswrgp , imligp , iphydp ,     &
   iwarnp ,                                                                    &
   epsrgp , climgp , extrap ,                                                  &
   rvoid  ,                                                                    &
   dpot   ,                                                                    &
   clapot , clbpot ,                                                           &
   cfapot , cfbpot ,                                                           &
   viscf  , viscb  ,                                                           &
   dt     , dt     , dt     ,                                                  &
   imasfl , bmasfl )

!===============================================================================
! 6. Free solver setup
!===============================================================================

call sles_free_native(-1, chaine)

! Free memory
deallocate(dam, xam)
deallocate(divu, pot, pota, dpot, rhs)
deallocate(clapot, clbpot)
deallocate(cfapot, cfbpot)
deallocate(viscf, viscb)

!--------
! Formats
!--------

#if defined(_CS_LANG_FR)
 1440 format(1X,A16,' : sweep = ',I5,' norme second membre = ',E14.6,&
             ', relaxp = ',E14.6)
 1600 format(                                                     &
'@                                                            ',/,&
'@ @@ ATTENTION : ', A16,' Prediction du flux de masse        ',/,&
'@    =========                                               ',/,&
'@  Nombre d''iterations maximal ',I10   ,' atteint           ',/,&
'@                                                            '  )

#else

 1440 format(1X,A16,' : sweep = ',I5,' right hand side norm = ',E14.6,&
             ', relaxp = ',E14.6)
 1600 format(                                                     &
'@'                                                            ,/,&
'@ @@ WARNING: ', A16,' Mass flux prediction step             ',/,&
'@    ========                                                ',/,&
'@  Maximum number of iterations ',I10   ,' reached           ',/,&
'@'                                                              )

#endif

!----
! End
!----

return

end subroutine
