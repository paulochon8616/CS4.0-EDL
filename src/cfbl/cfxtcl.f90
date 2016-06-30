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

!> \file cfxtcl.f90
!> \brief Handle boundary condition type code (\ref itypfb) when the
!> compressible model is enabled.
!>
!-------------------------------------------------------------------------------

!------------------------------------------------------------------------------
! Arguments
!------------------------------------------------------------------------------
!   mode          name          role
!------------------------------------------------------------------------------
!> \param[in]     nvar          total number of variables
!> \param[in,out] icodcl        face boundary condition code:
!>                               - 1 Dirichlet
!>                               - 2 Radiative outlet
!>                               - 3 Neumann
!>                               - 4 sliding and
!>                                 \f$ \vect{u} \cdot \vect{n} = 0 \f$
!>                               - 5 smooth wall and
!>                                 \f$ \vect{u} \cdot \vect{n} = 0 \f$
!>                               - 6 rough wall and
!>                                 \f$ \vect{u} \cdot \vect{n} = 0 \f$
!>                               - 9 free inlet/outlet
!>                                 (input mass flux blocked to 0)
!>                               - 13 Dirichlet for the advection operator and
!>                                    Neumann for the diffusion operator
!> \param[in]     itypfb        boundary face types
!> \param[in]     dt            time step (per cell)
!> \param[in,out] rcodcl        boundary condition values:
!>                               - rcodcl(1) value of the dirichlet
!>                               - rcodcl(2) value of the exterior exchange
!>                                 coefficient (infinite if no exchange)
!>                               - rcodcl(3) value flux density
!>                                 (negative if gain) in w/m2 or roughness
!>                                 in m if icodcl=6
!>                                 -# for the velocity \f$ (\mu+\mu_T)
!>                                    \gradv \vect{u} \cdot \vect{n}  \f$
!>                                 -# for the pressure \f$ \Delta t
!>                                    \grad P \cdot \vect{n}  \f$
!>                                 -# for a scalar \f$ cp \left( K +
!>                                     \dfrac{K_T}{\sigma_T} \right)
!>                                     \grad T \cdot \vect{n} \f$
!______________________________________________________________________________

subroutine cfxtcl &
 ( nvar   ,                                                       &
   icodcl , itypfb , dt     , rcodcl )

!===============================================================================
! Module files
!===============================================================================

use paramx
use numvar
use optcal
use cstphy
use cstnum
use entsor
use parall
use ppppar
use ppthch
use ppincl
use cfpoin
use mesh
use field

!===============================================================================

implicit none

! Arguments

integer          nvar

integer          icodcl(nfabor,nvarcl)
integer          itypfb(nfabor)

double precision dt(ncelet)
double precision rcodcl(nfabor,nvarcl,3)

! Local variables

integer          ivar  , ifac  , iel, l_size
integer          ii    , iii   , iccfth
integer          icalep, icalgm
integer          iflmab
integer          ien   , itk
integer          nvarcf

integer          nvcfmx
parameter       (nvcfmx=6)
integer          ivarcf(nvcfmx)

double precision hint  , gammag

double precision, allocatable, dimension(:) :: w1, w2
double precision, allocatable, dimension(:) :: w4, w5, w6
double precision, allocatable, dimension(:) :: w7
double precision, allocatable, dimension(:) :: wbfb
double precision, allocatable, dimension(:,:) :: bval

double precision, dimension(:), pointer :: bmasfl
double precision, dimension(:), pointer :: coefbp
double precision, dimension(:), pointer :: crom, brom, cpro_cv, cvar_en
double precision, dimension(:,:), pointer :: vel

!===============================================================================

! Map field arrays
call field_get_val_v(ivarfl(iu), vel)

!===============================================================================
! 1. Initializations
!===============================================================================

! Allocate temporary arrays
allocate(w1(ncelet), w2(ncelet))
allocate(w4(ncelet), w5(ncelet), w6(ncelet))

allocate(w7(nfabor), wbfb(nfabor))
allocate(bval(nfabor,nvar))

ien = isca(ienerg)
itk = isca(itempk)

call field_get_key_int(ivarfl(ien), kbmasf, iflmab)
call field_get_val_s(iflmab, bmasfl)

call field_get_val_s(icrom, crom)
call field_get_val_s(ibrom, brom)

call field_get_val_s(ivarfl(ien), cvar_en)

if (icv.gt.0) call field_get_val_s(iprpfl(icv), cpro_cv)

! list of the variables of the compressible model
ivarcf(1) = ipr
ivarcf(2) = iu
ivarcf(3) = iv
ivarcf(4) = iw
ivarcf(5) = ien
ivarcf(6) = itk
nvarcf    = 6

call field_get_coefb_s(ivarfl(ipr), coefbp)
do ifac = 1, nfabor
  wbfb(ifac) = coefbp(ifac)
enddo

! Computation of epsilon_sup = e - CvT
! Needed if walls with imposed temperature are set.

icalep = 0
do ifac = 1, nfabor
  if(icodcl(ifac,itk).eq.5) then
    icalep = 1
  endif
enddo
if(icalep.ne.0) then
  ! At cell centers
  call cf_thermo_eps_sup(w5, ncel)

  ! At boundary faces centers
  call cf_thermo_eps_sup(w7, nfabor)
endif

! Computation of gamma (can be constant or variable)
! Needed for to compute the Rusanov fluxes at imposed inlet.

icalgm = 0
do ifac = 1, nfabor
  if ( ( itypfb(ifac).eq.iesicf ) .or.                    &
       ( itypfb(ifac).eq.ieqhcf ) ) then
    icalgm = 1
  endif
enddo
if(icalgm.ne.0) then
  if(ieos.eq.1) then
    call cf_thermo_gamma(gammag)
  else
    ! TODO for thermodynamic with variable gamma
    ! Gamma is used in cfrusb. If non uniform (ieos different from 1),
    ! the cell values have to be passed and used as gammag(ifabor(ifac))
    ! in the Rusanov flux computation.
    ! For now, we stop here and an error message is printed out.
    write(nfecra,7000)
    call csexit (1)
  endif

endif

! Loop on all boundary faces and treatment of types of BCs given by itypfb

do ifac = 1, nfabor
  iel = ifabor(ifac)

!===============================================================================
! 2. Treatment of all wall boundary faces
!===============================================================================

  if ( itypfb(ifac).eq.iparoi) then

    ! rcodcl elements have been initialized at -RINFIN to allow to check wether
    ! they have been modified by the user. Here those that have not been
    ! modified by the user are set back to zero.
    ! At walls all variables are treated.
    do ivar = 1, nvar
      if(rcodcl(ifac,ivar,1).le.-rinfin*0.5d0) then
        rcodcl(ifac,ivar,1) = 0.d0
      endif
    enddo

    ! zero mass flux
    bmasfl(ifac) = 0.d0

    ! pressure :
    ! if the gravity is prevailing: hydrostatic pressure
    ! (warning: the density is here explicit and the term is an approximation)

    if(icfgrp.eq.1) then

      icodcl(ifac,ipr) = 3
      hint = dt(iel)/distb(ifac)
      rcodcl(ifac,ipr,3) = -hint                                  &
           * ( gx*(cdgfbo(1,ifac)-xyzcen(1,iel))                  &
           + gy*(cdgfbo(2,ifac)-xyzcen(2,iel))                    &
           + gz*(cdgfbo(3,ifac)-xyzcen(3,iel)) )                  &
           * crom(iel)

    else

      ! generally proportional to the bulk value
      ! (Pboundary = COEFB*Pi)
      ! If rarefaction is too strong : homogeneous Dirichlet

      call cf_thermo_wall_bc(wbfb, ifac)

      ! In addition, a pre-correction has to be applied to cancel the
      ! treatment done afterward in condli.
      ! TODO see if coefa, coefb could be directly set. In this case,
      ! a test on ippmod in condli would be necessary.

      !FIXME with the new cofaf
      icodcl(ifac,ipr) = 1
      if(wbfb(ifac).lt.rinfin*0.5d0.and.                  &
         wbfb(ifac).gt.0.d0  ) then
        hint = dt(iel)/distb(ifac)
        rcodcl(ifac,ipr,1) = 0.d0
        rcodcl(ifac,ipr,2) = hint*(1.d0/wbfb(ifac)-1.d0)
      else
        rcodcl(ifac,ipr,1) = 0.d0
      endif

    endif

    ! Velocity and turbulence are treated in a standard manner in condli.

    ! For thermal B.C., a pre-treatment has be done here since the solved
    ! variable is the total energy
    ! (internal energy + epsilon_sup + cinetic energy).
    ! Especially, when a temperature is imposed on a wall, clptur treatment
    ! has to be prepared. Except for the solved energy all the variables rho
    ! and s will take arbitrarily a zero flux B.C. (their B.C. are only used
    ! for the gradient reconstruction and imposing something else than zero
    ! flux could bring out spurious values near the boundary layer).

    ! adiabatic by default
    if(  icodcl(ifac,itk).eq.0.and.                          &
         icodcl(ifac,ien).eq.0) then
      icodcl(ifac,itk) = 3
      rcodcl(ifac,itk,3) = 0.d0
    endif

    ! imposed temperature
    if(icodcl(ifac,itk).eq.5) then

      ! The value of the energy that leads to the right flux is imposed.
      ! However it should be noted that it is the B.C. for the diffusion
      ! flux. For the gradient reconstruction, something else will be
      ! needed. For example, a zero flux or an other B.C. respecting a
      ! profile: it may be possible to treat the total energy as the
      ! temperature, keeping in mind that the total energy contains
      ! the cinetic energy, which could make the choice of the profile more
      ! difficult.

      icodcl(ifac,ien) = 5
      if(icv.eq.0) then
        rcodcl(ifac,ien,1) = cv0*rcodcl(ifac,itk,1)
      else
        rcodcl(ifac,ien,1) = cpro_cv(iel)*rcodcl(ifac,itk,1)
      endif
      rcodcl(ifac,ien,1) = rcodcl(ifac,ien,1)             &
           + 0.5d0*(vel(1,iel)**2+vel(2,iel)**2+vel(3,iel)**2)          &
           + w5(iel)
      ! w5 contains epsilon_sup

      ! fluxes in grad(epsilon_sup and cinetic energy) have to be zero
      ! since they are already accounted for in the energy diffusion term
      ifbet(ifac) = 1

      ! Dirichlet condition on the temperature for gradient reconstruction
      ! used only in post-processing (typically Nusselt computation)
      icodcl(ifac,itk) = 1

    ! imposed flux
    elseif(icodcl(ifac,itk).eq.3) then

      ! zero flux on energy
      icodcl(ifac,ien) = 3
      rcodcl(ifac,ien,3) = rcodcl(ifac,itk,3)

      ! fluxes in grad(epsilon_sup and cinetic energy) have to be zero
      ! since they are already accounted for in the energy diffusion term
      ifbet(ifac) = 1

      ! zero flux for the possible temperature reconstruction
      icodcl(ifac,itk) = 3
      rcodcl(ifac,itk,3) = 0.d0

    endif


!     Scalars : zero flux (by default in typecl for iparoi code)


!===============================================================================
! 3. Treatment of all symmetry boundary faces
!===============================================================================

  elseif ( itypfb(ifac).eq.isymet ) then

    ! rcodcl elements have been initialized at -RINFIN to allow to check wether
    ! they have been modified by the user. Here those that have not been
    ! modified by the user are set back to zero.
    ! At symmetry faces, all variables are treated.
    do ivar = 1, nvar
      if(rcodcl(ifac,ivar,1).le.-rinfin*0.5d0) then
        rcodcl(ifac,ivar,1) = 0.d0
      endif
    enddo

    ! zero mass flux
    bmasfl(ifac) = 0.d0

    ! Pressure condition:
    ! homogeneous Neumann condition, nothing to be done.
    icodcl(ifac,ipr) = 3
    rcodcl(ifac,ipr,1) = 0.d0
    rcodcl(ifac,ipr,2) = rinfin
    rcodcl(ifac,ipr,3) = 0.d0

    ! zero flux for all other variables (except for the normal velocity which is
    ! itself zero) : by default in typecl for isymet code.

!===============================================================================
! 4. Treatment of all inlet/outlet boundary faces and thermo step
!===============================================================================


!===============================================================================
! 4.1 Imposed Inlet/outlet (for example: supersonic inlet)
!===============================================================================

  elseif ( itypfb(ifac).eq.iesicf ) then

    ! we have
    !   - velocity,
    !   - 2 variables among P, rho, T, E (but not the couple (T,E)),
    !   - turbulence variables
    !   - scalars

    ! we look for the variable to be initialized
    ! (if a zero value has been given, it is not adapted, so it will
    ! be considered as not initialized and the computation will stop
    ! displaying an error message
    iccfth = 10000
    if(rcodcl(ifac,ipr,1).gt.0.d0) iccfth = 2*iccfth
    if(brom(ifac).gt.0.d0)         iccfth = 3*iccfth
    if(rcodcl(ifac,itk,1).gt.0.d0) iccfth = 5*iccfth
    if(rcodcl(ifac,ien,1).gt.0.d0) iccfth = 7*iccfth
    if((iccfth.le.70000.and.iccfth.ne.60000).or.                &
         (iccfth.eq.350000)) then
      write(nfecra,1000)iccfth
      call csexit (1)
    endif
    iccfth = iccfth + 900

    ! rcodcl elements have been initialized at -RINFIN to allow to check wether
    ! they have been modified by the user. Here those that have not been
    ! modified by the user are set back to zero.
    ! Firstly variables other than turbulent ones and passive scalars are
    ! handled, the others are handled further below.
    do iii = 1, nvarcf
      ivar = ivarcf(iii)
      if(rcodcl(ifac,ivar,1).le.-rinfin*0.5d0) then
        rcodcl(ifac,ivar,1) = 0.d0
      endif
    enddo

    ! missing thermo variables among P,rho,T,E are computed
    do ivar = 1, nvar
      bval(ifac,ivar) = rcodcl(ifac,ivar,1)
    enddo

    call cfther &
    !==========
 ( nvar   ,               &
   iccfth , ifac   ,      &
   w1     , w2     , bval )


    ! Rusanov fluxes, mass flux and boundary conditions types (icodcl) are
    ! dealt with further below

!===============================================================================
! 4.2 Supersonic outlet
!===============================================================================

  elseif ( itypfb(ifac).eq.isspcf ) then

    ! A Dirichlet value equal to the bulk value is imposed for the velocity
    ! and the energy (for the other variables a deduced Dirichlet value is
    ! imposed). The computation of a convection flux is not needed here.
    ! Reconstruction of those bulk cell values would be necessary by using their
    ! cell gradient: for now only cell center values are used (not consistant on
    ! non orthogonal meshes but potentially more stable).
    ! Another solution may be to impose zero fluxes which would avoid
    ! reconstruction (to be tested).
    ! rcodcl elements have been initialized at -RINFIN to allow to check wether
    ! they have been modified by the user. Here those that have not been
    ! modified by the user are set back to zero.
    ! Firstly variables other than turbulent ones and passive scalars are
    ! handled, the others are handled further below.
    do iii = 1, nvarcf
      ivar = ivarcf(iii)
      if(rcodcl(ifac,ivar,1).le.-rinfin*0.5d0) then
        rcodcl(ifac,ivar,1) = 0.d0
      endif
    enddo

    ! density, velocity and total energy values
    brom(ifac) = crom(iel) ! TODO: test without (already done in phyvar)
    rcodcl(ifac,iu ,1) = vel(1,iel)
    rcodcl(ifac,iv ,1) = vel(2,iel)
    rcodcl(ifac,iw ,1) = vel(3,iel)
    rcodcl(ifac,ien,1) = cvar_en(iel)

    do ivar = 1, nvar
      bval(ifac,ivar) = rcodcl(ifac,ivar,1)
    enddo

    l_size = 1
    call cf_thermo_pt_from_de_ni(brom(ifac:ifac), bval(ifac,ien), bval(ifac,ipr),  &
                                 bval(ifac,itk), bval(ifac,iu), bval(ifac,iv),     &
                                 bval(ifac,iw), l_size)

    ! mass fluxes and boundary conditions codes, see further below.

!===============================================================================
! 4.3 Outlet with imposed pressure
!===============================================================================

  elseif ( itypfb(ifac).eq.isopcf ) then

    ! If no value was given for P or if its value is negative, the computation
    ! stops (a negative value could be possible, but in most cases it would be
    ! an error).
    if(rcodcl(ifac,ipr,1).lt.-rinfin*0.5d0) then
      write(nfecra,1100)
      call csexit (1)
    endif

    ! rcodcl elements have been initialized at -RINFIN to allow to check wether
    ! they have been modified by the user. Here those that have not been
    ! modified by the user are set back to zero.
    ! Firstly variables other than turbulent ones and passive scalars are
    ! handled, the others are handled further below.
    do iii = 1, nvarcf
      ivar = ivarcf(iii)
      if(rcodcl(ifac,ivar,1).le.-rinfin*0.5d0) then
        rcodcl(ifac,ivar,1) = 0.d0
      endif
    enddo

    ! values of the density, the velocity and the total energy
    do ivar = 1, nvar
      bval(ifac,ivar) = rcodcl(ifac,ivar,1)
    enddo

    call cf_thermo_subsonic_outlet_bc(bval, ifac)
    !==============================

    ! mass fluxes and boundary conditions codes, see further below.

!===============================================================================
! 4.4 Inlet with Ptot, Htot imposed (reservoir boundary conditions)
!===============================================================================

  elseif ( itypfb(ifac).eq.iephcf ) then

    ! If values for Ptot and Htot were not given, the computation stops.

    ! rcodcl(ifac,isca(ienerg),1) contains the boundary total enthalpy values
    ! prescribed by the user

    if(rcodcl(ifac,ipr ,1).lt.-rinfin*0.5d0.or.               &
         rcodcl(ifac,isca(ienerg) ,1).lt.-rinfin*0.5d0) then
      write(nfecra,1200)
      call csexit (1)
    endif

    ! rcodcl elements have been initialized at -RINFIN to allow to check wether
    ! they have been modified by the user. Here those that have not been
    ! modified by the user are set back to zero.
    ! Firstly variables other than turbulent ones and passive scalars are
    ! handled, the others are handled further below.
    do iii = 1, nvarcf
      ivar = ivarcf(iii)
      if(rcodcl(ifac,ivar,1).le.-rinfin*0.5d0) then
        rcodcl(ifac,ivar,1) = 0.d0
      endif
    enddo

    do ivar = 1, nvar
      bval(ifac,ivar) = rcodcl(ifac,ivar,1)
    enddo

    call cf_thermo_ph_inlet_bc(bval, ifac)
    !=======================

    ! mass fluxes and boundary conditions codes, see further below.

!===============================================================================
! 4.5 Inlet with imposed rho*U and rho*U*H
!===============================================================================

  elseif ( itypfb(ifac).eq.ieqhcf ) then

    ! TODO to be implemented
    write(nfecra,1301)
    call csexit (1)

    !     On utilise un scenario dans lequel on a un 2-contact et une
    !       3-d�tente entrant dans le domaine. On d�termine les conditions
    !       sur l'interface selon la thermo et on passe dans Rusanov
    !       ensuite pour lisser.

    !     Si rho et u ne sont pas donn�s, erreur
    if(rcodcl(ifac,irunh,1).lt.-rinfin*0.5d0) then
      write(nfecra,1300)
      call csexit (1)
    endif

    ! rcodcl elements have been initialized at -RINFIN to allow to check wether
    ! they have been modified by the user. Here those that have not been
    ! modified by the user are set back to zero.
    ! Firstly variables other than turbulent ones and passive scalars are
    ! handled, the others are handled further below.
    do iii = 1, nvarcf
      ivar = ivarcf(iii)
      if(rcodcl(ifac,ivar,1).le.-rinfin*0.5d0) then
          rcodcl(ifac,ivar,1) = 0.d0
      endif
    enddo

!     IRUNH = ISCA(IENER)
!     (aliases pour simplifier uscfcl)

!===============================================================================
! 5. Unexpected boundary condition type
!===============================================================================

  else

    ! The computation stops.
    write(nfecra,1400)
    call csexit (1)


  endif ! end of test on boundary condition types


!===============================================================================
! 6. Complete the treatment for inlets and outlets:
!    - mass fluxes computation
!    - boundary convective fluxes computation (analytical or Rusanov) if needed
!    - B.C. code (Dirichlet or Neumann)
!===============================================================================

  if ( ( itypfb(ifac).eq.iesicf ) .or.                    &
       ( itypfb(ifac).eq.isspcf ) .or.                    &
       ( itypfb(ifac).eq.iephcf ) .or.                    &
       ( itypfb(ifac).eq.isopcf ) .or.                    &
       ( itypfb(ifac).eq.ieqhcf ) ) then

!===============================================================================
! 6.1 Mass fluxes computation and
!     boundary convective fluxes computation (analytical or Rusanov) if needed
!     (gamma should already have been computed if Rusanov fluxes are computed)
!===============================================================================

    ! Supersonic outlet
    if ( itypfb(ifac).eq.isspcf ) then

      ! only the mass flux is computed
      bmasfl(ifac) = brom(ifac) *                                              &
                     ( bval(ifac,iu)*surfbo(1,ifac)                            &
                     + bval(ifac,iv)*surfbo(2,ifac)                            &
                     + bval(ifac,iw)*surfbo(3,ifac) )

    ! other inlets/outlets
    else

      ! Rusanov fluxes are computed only for the imposed inlet for stability
      ! reasons (the mass flux computation is concluded)
      if ( itypfb(ifac).eq.iesicf ) then

        call cfrusb(nvar, ifac, gammag, bval)
        !==========

      ! For the other types of inlets/outlets (subsonic outlet, QH inlet,
      ! PH inlet), analytical fluxes are computed
      else

        ! the pressure part of the boundary analytical flux is not added here,
        ! but set through the pressure gradient boundary conditions (Dirichlet)
        call cffana(nvar, ifac, bval)
        !==========

      endif

    endif

!===============================================================================
! 6.2 Copy of boundary values into the Dirichlet values array
!===============================================================================

    do ivar = 1, nvar
      rcodcl(ifac,ivar,1) = bval(ifac,ivar)
    enddo

!===============================================================================
! 6.3 Boundary conditions codes (Dirichlet or Neumann)
!===============================================================================

!     P               : Dirichlet except for iesicf : Neumann (arbitrary choice)
!     rho, U, E, T    : Dirichlet
!     k, R, eps, scal : Dirichlet/Neumann depending on the flux mass value

! For the pressure, a Neumann B.C. seems to be less worth for gradient
! reconstruction if the value of P provided by the user is very different from
! the internal value. The choice is however arbitrary.

! At this point, the following values are assumed to be in the array rcodcl
! rcodcl(IFAC,ivar,1) = user or computed above
! rcodcl(IFAC,ivar,2) = RINFIN
! rcodcl(IFAC,ivar,3) = 0.D0
! and if icodcl(IFAC,ivar) = 3, only rcodcl(IFAC,ivar,3) is used


!-------------------------------------------------------------------------------
! Pressure : - Dirichlet for the gradient computation, allowing to have the
!            pressure part of the convective flux at the boundary
!            - Homogeneous Neumann for the diffusion
!-------------------------------------------------------------------------------

    icodcl(ifac,ipr)   = 13

!-------------------------------------------------------------------------------
! U E T : Dirichlet
!-------------------------------------------------------------------------------

    ! velocity
    icodcl(ifac,iu)    = 1
    icodcl(ifac,iv)    = 1
    icodcl(ifac,iw)    = 1
    ! total energy
    icodcl(ifac,ien)   = 1
    ! temperature
    icodcl(ifac,itk)   = 1

!-------------------------------------------------------------------------------
! Turbulence and passive scalars: Dirichlet / Neumann depending on the mass flux
!-------------------------------------------------------------------------------

    ! Dirichlet or homogeneous Neumann
    ! A Dirichlet is chosen if the mass flux is ingoing and if the user provided
    ! a value in rcodcl(ifac,ivar,1)

    if (bmasfl(ifac).ge.0.d0) then
      if(itytur.eq.2) then
        icodcl(ifac,ik ) = 3
        icodcl(ifac,iep) = 3
      elseif(itytur.eq.3) then
        icodcl(ifac,ir11) = 3
        icodcl(ifac,ir22) = 3
        icodcl(ifac,ir33) = 3
        icodcl(ifac,ir12) = 3
        icodcl(ifac,ir13) = 3
        icodcl(ifac,ir23) = 3
        icodcl(ifac,iep ) = 3
      elseif(iturb.eq.50) then
        icodcl(ifac,ik  ) = 3
        icodcl(ifac,iep ) = 3
        icodcl(ifac,iphi) = 3
        icodcl(ifac,ifb ) = 3
      elseif(iturb.eq.60) then
        icodcl(ifac,ik  ) = 3
        icodcl(ifac,iomg) = 3
      elseif(iturb.eq.70) then
        icodcl(ifac,inusa) = 3
      endif
      if(nscaus.gt.0) then
        do ii = 1, nscaus
          icodcl(ifac,isca(ii)) = 3
        enddo
      endif
    else
      if(itytur.eq.2) then
        if(rcodcl(ifac,ik ,1).gt.0.d0.and.               &
             rcodcl(ifac,iep,1).gt.0.d0) then
          icodcl(ifac,ik ) = 1
          icodcl(ifac,iep) = 1
        else
          icodcl(ifac,ik ) = 3
          icodcl(ifac,iep) = 3
        endif
      elseif(itytur.eq.3) then
        if(rcodcl(ifac,ir11,1).gt.0.d0.and.              &
             rcodcl(ifac,ir22,1).gt.0.d0.and.              &
             rcodcl(ifac,ir33,1).gt.0.d0.and.              &
             rcodcl(ifac,ir12,1).gt.-rinfin*0.5d0.and.     &
             rcodcl(ifac,ir13,1).gt.-rinfin*0.5d0.and.     &
             rcodcl(ifac,ir23,1).gt.-rinfin*0.5d0.and.     &
             rcodcl(ifac,iep ,1).gt.0.d0) then
          icodcl(ifac,ir11) = 1
          icodcl(ifac,ir22) = 1
          icodcl(ifac,ir33) = 1
          icodcl(ifac,ir12) = 1
          icodcl(ifac,ir13) = 1
          icodcl(ifac,ir23) = 1
          icodcl(ifac,iep ) = 1
        else
          icodcl(ifac,ir11) = 3
          icodcl(ifac,ir22) = 3
          icodcl(ifac,ir33) = 3
          icodcl(ifac,ir12) = 3
          icodcl(ifac,ir13) = 3
          icodcl(ifac,ir23) = 3
          icodcl(ifac,iep ) = 3
        endif
      elseif(iturb.eq.50) then
        if(rcodcl(ifac,ik  ,1).gt.0.d0.and.              &
             rcodcl(ifac,iep ,1).gt.0.d0.and.              &
             rcodcl(ifac,iphi,1).gt.0.d0.and.              &
             rcodcl(ifac,ifb ,1).gt.-rinfin*0.5d0 ) then
          icodcl(ifac,ik  ) = 1
          icodcl(ifac,iep ) = 1
          icodcl(ifac,iphi) = 1
          icodcl(ifac,ifb ) = 1
        else
          icodcl(ifac,ik  ) = 3
          icodcl(ifac,iep ) = 3
          icodcl(ifac,iphi) = 3
          icodcl(ifac,ifb ) = 3
        endif
      elseif(iturb.eq.60) then
         if(rcodcl(ifac,ik  ,1).gt.0.d0.and.               &
              rcodcl(ifac,iomg,1).gt.0.d0 ) then
           icodcl(ifac,ik  ) = 1
           icodcl(ifac,iomg) = 1
         else
           icodcl(ifac,ik  ) = 3
           icodcl(ifac,iomg) = 3
         endif
       elseif(iturb.eq.70) then
         if(rcodcl(ifac,inusa,1).gt.0.d0) then
           icodcl(ifac,inusa) = 1
         else
           icodcl(ifac,inusa) = 3
         endif
       endif
       if(nscaus.gt.0) then
         do ii = 1, nscaus
           if(rcodcl(ifac,isca(ii),1).gt.-rinfin*0.5d0) then
             icodcl(ifac,isca(ii)) = 1
           else
             icodcl(ifac,isca(ii)) = 3
           endif
         enddo
       endif
     endif

     ! rcodcl elements have been initialized at -RINFIN to allow to check wether
     ! they have been modified by the user. Here those that have not been
     ! modified by the user are set back to zero.
     ! Turbulence and passive scalars are treated so here (to simplify the loop,
     ! all variables are treated, hence compressible variables are treated again
     ! here).
     do ivar = 1, nvar
       if(rcodcl(ifac,ivar,1).le.-rinfin*0.5d0) then
         rcodcl(ifac,ivar,1) = 0.d0
       endif
     enddo

   endif ! end of test on inlet/outlet faces

 enddo ! end of loop on boundary faces

! Free memory
deallocate(w1, w2)
deallocate(w4, w5, w6)
deallocate(w7)
deallocate(bval)

!----
! FORMATS
!----

 1000 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ WARNING : Error during execution,                       ',/,&
'@    =========                                               ',/,&
'@    two and only two independant variables among            ',/,&
'@    P, rho, T and E have to be imposed at boundaries of type',/,&
'@    iesicf in uscfcl (iccfth = ',I10,').                  ',/,&
'@                                                            ',/,&
'@    The computation will stop.                              ',/,&
'@                                                            ',/,&
'@    Check the boundary conditions in                        ',/,&
'@    cs_user_boundary_conditions                             ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 1100 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ WARNING : Error during execution,                       ',/,&
'@    =========                                               ',/,&
'@    The pressure was not provided at outlet with pressure   ',/,&
'@    imposed.                                                ',/,&
'@                                                            ',/,&
'@    The computation will stop.                              ',/,&
'@                                                            ',/,&
'@    Check the boundary conditions in                        ',/,&
'@    cs_user_boundary_conditions                             ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 1200 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ WARNING : Error during execution,                       ',/,&
'@    =========                                               ',/,&
'@    The total pressure or total enthalpy were not provided  ',/,&
'@    at inlet with total pressure and total enthalpy imposed.',/,&
'@                                                            ',/,&
'@    The computation will stop.                              ',/,&
'@                                                            ',/,&
'@    Check the boundary conditions in                        ',/,&
'@    cs_user_boundary_conditions                             ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 1300 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ WARNING : Error during execution,                       ',/,&
'@    =========                                               ',/,&
'@    The mass or enthalpy flow rate were not provided        ',/,&
'@    at inlet with mass and enthalpy flow rate imposed.      ',/,&
'@                                                            ',/,&
'@    The computation will stop.                              ',/,&
'@                                                            ',/,&
'@    Check the boundary conditions in                        ',/,&
'@    cs_user_boundary_conditions                             ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 1301 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ WARNING : Error during execution,                       ',/,&
'@    =========                                               ',/,&
'@    Inlet with mass and enthalpy flow rate not provided.    ',/,&
'@                                                            ',/,&
'@    The computation will stop.                              ',/,&
'@                                                            ',/,&
'@    Check the boundary conditions in                        ',/,&
'@    cs_user_boundary_conditions                             ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 1400 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ WARNING : Error during execution,                       ',/,&
'@    =========                                               ',/,&
'@    Unexpected type of predefined compressible boundary     ',/,&
'@      conditions.                                           ',/,&
'@                                                            ',/,&
'@    The computation will stop.                              ',/,&
'@                                                            ',/,&
'@    Check the boundary conditions in                        ',/,&
'@    cs_user_boundary_conditions                             ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 7000 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ WARNING : Error during execution,                       ',/,&
'@    =========                                               ',/,&
'@    cfxtcl should be modified to take into account a state  ',/,&
'@    law with a variable gamma. Only ieos = 1 is available   ',/,&
'@    for now.                                                ',/,&
'@                                                            ',/,&
'@  The computation will stop.                                ',/,&
'@                                                            ',/,&
'@  Check ieos in routine uscfx1.                             ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
!----
! END
!----

return
end subroutine
