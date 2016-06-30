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

!> \file typecl.f90
!> \brief Handle boundary condition type code (\ref itypfb).
!>
!------------------------------------------------------------------------------

!------------------------------------------------------------------------------
! Arguments
!------------------------------------------------------------------------------
!   mode          name          role
!------------------------------------------------------------------------------
!> \param[in]     nvar          total number of variables
!> \param[in]     nscal         total number of scalars
!> \param[in,out] itypfb        boundary face types
!> \param[out]    itrifb        tab d'indirection pour tri des faces
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
!> \param[out]    isostd        standard output indicator
!>                              + reference face number
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
!> \param[in]     frcxt         external force generating hydrostatic pressure
!______________________________________________________________________________

subroutine typecl &
 ( nvar   , nscal  ,                                              &
   itypfb , itrifb , icodcl , isostd ,                            &
   rcodcl , frcxt  )

!===============================================================================
! Module files
!===============================================================================

use paramx
use numvar
use optcal
use cstnum
use cstphy
use dimens, only: ndimfb
use pointe, only: b_head_loss
use entsor
use parall
use ppppar
use ppthch
use ppincl
use cplsat
use mesh
use field

!===============================================================================

implicit none

! Arguments

integer          nvar   , nscal

integer          icodcl(ndimfb,nvarcl)
integer          itypfb(ndimfb) , itrifb(ndimfb)
integer          isostd(ndimfb+1)

double precision rcodcl(ndimfb,nvarcl,3)
double precision frcxt(3,ncelet)

! Local variables

integer          ifac, ivar, iel
integer          iok, inc, iccocg, ideb, ifin, inb, isum, iwrnp
integer          ifrslb, itbslb
integer          ityp, ii, jj, iwaru, iflmab
integer          nswrgp, imligp, iwarnp
integer          irangd
integer          ifadir
integer          iut  , ivt   , iwt, iscal
double precision pref, epsrgp, climgp, extrap, pipb
double precision diipbx, diipby, diipbz
double precision flumbf, flumty(ntypmx)
double precision xxp0, xyp0, xzp0, d0, d0min
double precision xyzref(4) ! xyzref(3) + PI' for broadcast

double precision, allocatable, dimension(:) :: pripb
double precision, allocatable, dimension(:,:) :: grad
double precision, dimension(:), pointer :: bmasfl
double precision, dimension(:), pointer :: coefap, coefbp

double precision, dimension(:), pointer :: cvara_pr
double precision, dimension(:), pointer :: cpro_prtot

integer          ipass
data             ipass /0/
save             ipass

!===============================================================================

!===============================================================================
! 1.  Initialization
!===============================================================================

! Allocate temporary arrays
allocate(pripb(ndimfb))

! Initialize variables to avoid compiler warnings

pipb = 0.d0
pref = 0.d0

call field_get_key_int(ivarfl(iu), kbmasf, iflmab)
call field_get_val_s(iflmab, bmasfl)

call field_get_val_prev_s(ivarfl(ipr), cvara_pr)

!===============================================================================
! 2.  Check consistency of types given in cs_user_boundary_conditions
!===============================================================================

iok = 0

do ifac = 1, nfabor
  ityp = itypfb(ifac)
  if(ityp.le.0.or.ityp.gt.ntypmx) then
    itypfb(ifac) = 0
    iok = iok + 1
  endif
enddo

if (irangp.ge.0) call parcmx(iok)
if(iok.ne.0) then
  call bcderr(itypfb)
endif

!===============================================================================
! 3.  Sort boundary faces
!===============================================================================


! Count faces of each type (temporarily in ifinty)

do ii = 1, ntypmx
  ifinty(ii) = 0
enddo

do ifac = 1, nfabor
  ityp = itypfb(ifac)
  ifinty(ityp) = ifinty(ityp) + 1
enddo


! Set start of each group of faces in itrifb (sorted by type): idebty

do ii = 1, ntypmx
  idebty(ii) = 1
enddo

do ii = 1, ntypmx-1
  do jj = ii+1, ntypmx
    idebty(jj) = idebty(jj) + ifinty(ii)
  enddo
enddo

! Sort faces in itrifb and use the opportunity to correctly set ifinty

do ii = 1, ntypmx
  ifinty(ii) = idebty(ii)-1
enddo

do ifac = 1, nfabor
  ityp = itypfb(ifac)
  ifin = ifinty(ityp)+1
  itrifb(ifin) = ifac
  ifinty(ityp) = ifin
enddo

! Basic check

iok = 0
do ii = 1, ntypmx-1
  if(ifinty(ii).ge.idebty(ii+1)) then
    if (iok.eq.0) iok = ii
  endif
enddo
if (irangp.ge.0) call parcmx(iok)
if (iok.gt.0) then
  ii = iok
  if(ifinty(ii).ge.idebty(ii+1)) then
    write(nfecra,2020) (ifinty(jj),jj=1,ntypmx)
    write(nfecra,2030) (idebty(jj),jj=1,ntypmx)
    write(nfecra,2040) (itypfb(jj),jj=1,nfabor)
    write(nfecra,2098) ii,ifinty(ii),ii+1,idebty(ii+1)
  else
    write(nfecra,2099) ii,ii+1
  endif
  call csexit (1)
endif

iok = 0
isum = 0
do ii = 1, ntypmx
  isum = isum + ifinty(ii) - idebty(ii) + 1
enddo
if (irangp.ge.0) call parcpt (isum)
if(isum.ne.nfbrgb) then
  write(nfecra,3099) isum, nfbrgb
  iok = iok + 1
endif
if (iok.ne.0) then
  call csexit (1)
  !==========
endif


! ---> On ecrit les types de faces avec la borne inf et sup et le nb
!       pour chaque type de face trouve (tjrs pour les types par defaut)

if(ipass.eq.0.or.iwarni(iu).ge.2) then

  ipass = 1

  write(nfecra,6010)

  write(nfecra,6011)

  if ( ippmod(icompf).lt.0 ) then

    ii = ientre
    inb = ifinty(ii)-idebty(ii)+1
    if (irangp.ge.0) call parcpt (inb)
#if defined(_CS_LANG_FR)
    write(nfecra,6020) 'Entree           ', ii, inb
#else
    write(nfecra,6020) 'Inlet            ', ii, inb
#endif
    ii = iparoi
    inb = ifinty(ii)-idebty(ii)+1
    if (irangp.ge.0) call parcpt (inb)
#if defined(_CS_LANG_FR)
    write(nfecra,6020) 'Paroi lisse      ', ii, inb
#else
    write(nfecra,6020) 'Smooth wall      ', ii, inb
#endif
    ii = iparug
    inb = ifinty(ii)-idebty(ii)+1
    if (irangp.ge.0) call parcpt (inb)
#if defined(_CS_LANG_FR)
    write(nfecra,6020) 'Paroi rugueuse   ', ii, inb
#else
    write(nfecra,6020) 'Rough wall       ', ii, inb
#endif
    ii = isymet
    inb = ifinty(ii)-idebty(ii)+1
    if (irangp.ge.0) call parcpt (inb)
#if defined(_CS_LANG_FR)
    write(nfecra,6020) 'Symetrie         ', ii, inb
#else
    write(nfecra,6020) 'Symmetry         ', ii, inb
#endif
    ii = isolib
    inb = ifinty(ii)-idebty(ii)+1
    if (irangp.ge.0) call parcpt (inb)
#if defined(_CS_LANG_FR)
    write(nfecra,6020) 'Sortie libre     ', ii, inb
#else
    write(nfecra,6020) 'Free outlet      ', ii, inb
#endif
    ii = ifrent
    inb = ifinty(ii)-idebty(ii)+1
    if (irangp.ge.0) call parcpt (inb)
#if defined(_CS_LANG_FR)
    write(nfecra,6020) 'Entree libre     ', ii, inb
#else
    write(nfecra,6020) 'Free inlet       ', ii, inb
#endif

    ! Presence of free entrance face(s)
    if (inb.gt.0) then
      iifren = 1
      if (.not.(allocated(b_head_loss))) allocate(b_head_loss(ndimfb))
    else
      iifren = 0
    endif

    ii = i_convective_inlet
    inb = ifinty(ii)-idebty(ii)+1
    if (irangp.ge.0) call parcpt (inb)
#if defined(_CS_LANG_FR)
    write(nfecra,6020) 'Entree convective', ii, inb
#else
    write(nfecra,6020) 'Convective inlet ', ii, inb
#endif

    if (nbrcpl.ge.1) then
      ii = icscpl
      inb = ifinty(ii)-idebty(ii)+1
      if (irangp.ge.0) call parcpt (inb)
#if defined(_CS_LANG_FR)
      write(nfecra,6020) 'Couplage sat/sat ', ii, inb
#else
      write(nfecra,6020) 'Sat/Sat coupling ', ii, inb
#endif
    endif

    ii = ifresf
    inb = ifinty(ii)-idebty(ii)+1
    if (irangp.ge.0) call parcpt (inb)
#if defined(_CS_LANG_FR)
    write(nfecra,6020) 'Surface libre    ', ii, inb
#else
    write(nfecra,6020) 'Free surface     ', ii, inb
#endif

    ii = iindef
    inb = ifinty(ii)-idebty(ii)+1
    if (irangp.ge.0) call parcpt (inb)
#if defined(_CS_LANG_FR)
    write(nfecra,6020) 'Indefini         ', ii, inb
#else
    write(nfecra,6020) 'Undefined        ', ii, inb
#endif

    do ii = 1, ntypmx
      if (ii.ne.ientre  .and. &
          ii.ne.i_convective_inlet .and. &
          ii.ne.iparoi  .and. &
          ii.ne.iparug  .and. &
          ii.ne.isymet  .and. &
          ii.ne.isolib  .and. &
          ii.ne.ifrent  .and. &
          ii.ne.ifresf  .and. &
          ii.ne.icscpl  .and. &
          ii.ne.iindef ) then
        inb = ifinty(ii)-idebty(ii)+1
        if (irangp.ge.0) call parcpt (inb)
        if(inb.gt.0) then
#if defined(_CS_LANG_FR)
          write(nfecra,6020) 'Type utilisateur ', ii, inb
#else
          write(nfecra,6020) 'User type        ', ii, inb
#endif
        endif
      endif
    enddo

  else

    ii = ieqhcf
    inb = ifinty(ii)-idebty(ii)+1
    if (irangp.ge.0) call parcpt (inb)
#if defined(_CS_LANG_FR)
    write(nfecra,6020) 'Entree sub. enth.', ii, inb
#else
    write(nfecra,6020) 'Sub. enth. inlet ', ii, inb
#endif

    ii = iephcf
    inb = ifinty(ii)-idebty(ii)+1
    if (irangp.ge.0) call parcpt (inb)
#if defined(_CS_LANG_FR)
    write(nfecra,6020) 'Ptot, Htot       ', ii, inb
#else
    write(nfecra,6020) 'Ptot, Htot       ', ii, inb
#endif

    ii = iesicf
    inb = ifinty(ii)-idebty(ii)+1
    if (irangp.ge.0) call parcpt (inb)
#if defined(_CS_LANG_FR)
    write(nfecra,6020) 'Entree/Sortie imp', ii, inb
#else
    write(nfecra,6020) 'Imp inlet/outlet ', ii, inb
#endif

    ii = isopcf
    inb = ifinty(ii)-idebty(ii)+1
    if (irangp.ge.0) call parcpt (inb)
#if defined(_CS_LANG_FR)
    write(nfecra,6020) 'Sortie subsonique', ii, inb
#else
    write(nfecra,6020) 'Subsonic outlet  ', ii, inb
#endif

    ii = isspcf
    inb = ifinty(ii)-idebty(ii)+1
    if (irangp.ge.0) call parcpt (inb)
#if defined(_CS_LANG_FR)
    write(nfecra,6020) 'Sortie supersoniq', ii, inb
#else
    write(nfecra,6020) 'Supersonic outlet', ii, inb
#endif

    ii = iparoi
    inb = ifinty(ii)-idebty(ii)+1
    if (irangp.ge.0) call parcpt (inb)
#if defined(_CS_LANG_FR)
    write(nfecra,6020) 'Paroi lisse      ', ii, inb
#else
    write(nfecra,6020) 'Smooth wall      ', ii, inb
#endif

    ii = iparug
    inb = ifinty(ii)-idebty(ii)+1
    if (irangp.ge.0) call parcpt (inb)
#if defined(_CS_LANG_FR)
    write(nfecra,6020) 'Paroi rugueuse   ', ii, inb
#else
    write(nfecra,6020) 'Rough wall       ', ii, inb
#endif

    ii = isymet
    inb = ifinty(ii)-idebty(ii)+1
    if (irangp.ge.0) call parcpt (inb)
#if defined(_CS_LANG_FR)
    write(nfecra,6020) 'Symetrie         ', ii, inb
#else
    write(nfecra,6020) 'Symmetry         ', ii, inb
#endif

    ii = iindef
    inb = ifinty(ii)-idebty(ii)+1
    if (irangp.ge.0) call parcpt (inb)
#if defined(_CS_LANG_FR)
    write(nfecra,6020) 'Indefini         ', ii, inb
#else
    write(nfecra,6020) 'Undefined        ', ii, inb
#endif

    do ii = 1, ntypmx
      if (ii.ne.iesicf .and. &
           ii.ne.isspcf .and. &
           ii.ne.ieqhcf .and. &
           ii.ne.iephcf .and. &
           ii.ne.isopcf .and. &
           ii.ne.iparoi .and. &
           ii.ne.iparug .and. &
           ii.ne.isymet .and. &
           ii.ne.iindef ) then
        inb = ifinty(ii)-idebty(ii)+1
        if (irangp.ge.0) call parcpt (inb)
        if(inb.gt.0) then
#if defined(_CS_LANG_FR)
          write(nfecra,6020) 'Type utilisateur ',ii, inb
#else
          write(nfecra,6020) 'User type        ',ii, inb
#endif
        endif
      endif
    enddo

  endif

  write(nfecra,6030)

endif

!================================================================================
! 4.  rcodcl(.,    .,1) has been initialized as rinfin so as to check what
!     the user has modified. Those not modified are reset to zero here.
!     isolib, ifrent and ientre are handled later.
!================================================================================

do ivar = 1, nvar
  do ifac = 1, nfabor
    if ((itypfb(ifac) .ne. isolib)            .and. &
        (itypfb(ifac) .ne. ifrent)            .and. &
        (itypfb(ifac) .ne. ifresf)            .and. &
        (itypfb(ifac) .ne. i_convective_inlet).and. &
        (itypfb(ifac) .ne. ientre)            .and. &
        (rcodcl(ifac,ivar,1) .gt. rinfin*0.5d0)) then
      rcodcl(ifac,ivar,1) = 0.d0
    endif
  enddo
enddo

do iscal = 1, nscal
  if (ityturt(iscal).eq.3) then
    ! Set pointer values of turbulent fluxes in icodcl
    iut = nvar + 3*(ifltur(iscal) - 1) + 1
    ivt = nvar + 3*(ifltur(iscal) - 1) + 2
    iwt = nvar + 3*(ifltur(iscal) - 1) + 3

    do ifac = 1, nfabor
      if ((itypfb(ifac) .ne. isolib)             .and. &
          (itypfb(ifac) .ne. ifrent)             .and. &
          (itypfb(ifac) .ne. ifresf)             .and. &
          (itypfb(ifac) .ne. i_convective_inlet) .and. &
          (itypfb(ifac) .ne. ientre)             .and. &
          (rcodcl(ifac,iut,1) .gt. rinfin*0.5d0)) then
        rcodcl(ifac,iut,1) = 0.d0
      endif
      if ((itypfb(ifac) .ne. isolib)             .and. &
          (itypfb(ifac) .ne. ifrent)             .and. &
          (itypfb(ifac) .ne. ifresf)             .and. &
          (itypfb(ifac) .ne. i_convective_inlet) .and. &
          (itypfb(ifac) .ne. ientre)             .and. &
          (rcodcl(ifac,ivt,1) .gt. rinfin*0.5d0)) then
        rcodcl(ifac,ivt,1) = 0.d0
      endif
      if ((itypfb(ifac) .ne. isolib)             .and. &
          (itypfb(ifac) .ne. ifrent)             .and. &
          (itypfb(ifac) .ne. ifresf)             .and. &
          (itypfb(ifac) .ne. i_convective_inlet) .and. &
          (itypfb(ifac) .ne. ientre)             .and. &
          (rcodcl(ifac,iwt,1) .gt. rinfin*0.5d0)) then
        rcodcl(ifac,iwt,1) = 0.d0
      endif
    enddo
  endif
enddo

!===============================================================================
! 5.  Compute pressure at boundary (in pripb(*))
!     (if we need it, that is if there are outlet boudary faces).
!===============================================================================

xxp0   = xyzp0(1)
xyp0   = xyzp0(2)
xzp0   = xyzp0(3)

! ifrslb = closest free standard outlet face to xyzp0 (icodcl not modified)
!          (or closest free inlet)
! itbslb = max of ifrslb on all ranks, standard outlet face presence indicator

! Even when the user has not chosen xyzp0 (and it is thus at the
! origin), we choose the face whose center is closest to it, so
! as to be mesh numbering (and partitioning) independent.

d0min = rinfin

ifrslb = 0

ideb = idebty(isolib)
ifin = ifinty(isolib)

do ii = ideb, ifin
  ifac = itrifb(ii)
  if (icodcl(ifac,ipr).eq.0) then
    d0 =   (cdgfbo(1,ifac)-xxp0)**2  &
         + (cdgfbo(2,ifac)-xyp0)**2  &
         + (cdgfbo(3,ifac)-xzp0)**2
    if (d0.lt.d0min) then
      ifrslb = ifac
      d0min = d0
    endif
  endif
enddo


ideb = idebty(ifrent)
ifin = ifinty(ifrent)

do ii = ideb, ifin
  ifac = itrifb(ii)
  if (icodcl(ifac,ipr).eq.0) then
    d0 =   (cdgfbo(1,ifac)-xxp0)**2  &
         + (cdgfbo(2,ifac)-xyp0)**2  &
         + (cdgfbo(3,ifac)-xzp0)**2
    if (d0.lt.d0min) then
      ifrslb = ifac
      d0min = d0
    endif
  endif
enddo

! If we have free outlet faces, irangd and itbslb will
! contain respectively the rank having the boundary face whose
! center is closest to xyzp0, and the local number of that face
! on that rank (also equal to ifrslb on that rank).
! If we do not have free outlet faces, than itbslb = 0
! (as it was initialized that way on all ranks).

itbslb = ifrslb
irangd = irangp
if (irangp.ge.0) then
  call parfpt(itbslb, irangd, d0min)
endif

if (itbslb.gt.0) then

  ! Allocate a work array for the gradient calculation
  allocate(grad(ncelet,3))

  inc = 1
  iccocg = 1
  nswrgp = nswrgr(ipr)
  imligp = imligr(ipr)
  iwarnp = iwarni(ipr)
  epsrgp = epsrgr(ipr)
  climgp = climgr(ipr)
  extrap = extrag(ipr)

  call field_get_coefa_s(ivarfl(ipr), coefap)
  call field_get_coefb_s(ivarfl(ipr), coefbp)

  call grdpot &
  !==========
     ( ipr , imrgra , inc    , iccocg , nswrgp , imligp , iphydr ,    &
       iwarnp , epsrgp , climgp , extrap ,                            &
       frcxt  ,                                                       &
       cvara_pr   , coefap , coefbp ,                                     &
       grad   )


  !  Put in pripb the value at I' or F (depending on iphydr) of the
  !  total pressure, computed from P*

  if ((iphydr.eq.0.or.iphydr.eq.2).and.iifren.eq.0) then
    do ifac = 1, nfabor
      ii = ifabor(ifac)
      diipbx = diipb(1,ifac)
      diipby = diipb(2,ifac)
      diipbz = diipb(3,ifac)
      pripb(ifac) = cvara_pr(ii)                                          &
           + diipbx*grad(ii,1)+ diipby*grad(ii,2) + diipbz*grad(ii,3) &
           + ro0*( gx*(cdgfbo(1,ifac)-xxp0)                           &
           + gy*(cdgfbo(2,ifac)-xyp0)                                 &
           + gz*(cdgfbo(3,ifac)-xzp0))                                &
           + p0 - pred0
    enddo
  else
    do ifac = 1, nfabor
      ii = ifabor(ifac)
      pripb(ifac) = cvara_pr(ii)                                    &
           + (cdgfbo(1,ifac)-xyzcen(1,ii))*grad(ii,1)           &
           + (cdgfbo(2,ifac)-xyzcen(2,ii))*grad(ii,2)           &
           + (cdgfbo(3,ifac)-xyzcen(3,ii))*grad(ii,3)           &
           + ro0*(  gx*(cdgfbo(1,ifac)-xxp0)                    &
           + gy*(cdgfbo(2,ifac)-xyp0)                           &
           + gz*(cdgfbo(3,ifac)-xzp0))                          &
           + p0 - pred0
    enddo
  endif

  ! Free memory
  deallocate(grad)

endif

!===============================================================================
! 6.  Convert to rcodcl and icodcl
!     (if this has not already been set by the user)

!     First, process variables for which a specific treatement is done
!     (pressure, velocity, ...)
!===============================================================================

! 6.1.1 Inlet
! ===========

! ---> La pression a un traitement Neumann, le reste Dirichlet
!                                           sera traite plus tard.

ideb = idebty(ientre)
ifin = ifinty(ientre)

do ivar = 1, nvar
  if (ivar.eq.ipr) then
    do ii = ideb, ifin
      ifac = itrifb(ii)
      if(icodcl(ifac,ivar).eq.0) then
        icodcl(ifac,ivar)   = 3
        rcodcl(ifac,ivar,1) = 0.d0
        rcodcl(ifac,ivar,2) = rinfin
        rcodcl(ifac,ivar,3) = 0.d0
      endif
    enddo
  endif
enddo

! 6.1.2 Convective Inlet
! ======================

! ---> La pression a un traitement Neumann, le reste Dirichlet
!                                           sera traite plus tard.

ideb = idebty(i_convective_inlet)
ifin = ifinty(i_convective_inlet)

do ivar = 1, nvar
  if (ivar.eq.ipr) then
    do ii = ideb, ifin
      ifac = itrifb(ii)
      if(icodcl(ifac,ivar).eq.0) then
        icodcl(ifac,ivar)   = 3
        rcodcl(ifac,ivar,1) = 0.d0
        rcodcl(ifac,ivar,2) = rinfin
        rcodcl(ifac,ivar,3) = 0.d0
      endif
    enddo
  endif
enddo


! 6.2 SORTIE (entree-sortie libre) (ISOLIB)
! ===================

! ---> La pression a un traitement Dirichlet, les vitesses 9
!        (le reste Neumann, ou Dirichlet si donnee utilisateur,
!        sera traite plus tard)

if (iphydr.eq.1.or.iifren.eq.1) then

!     En cas de prise en compte de la pression hydrostatique,
!     on remplit le tableau ISOSTD
!     0 -> pas une face de sortie standard (i.e. pas sortie ou sortie avec CL
!                                                de pression modifiee)
!     1 -> face de sortie libre avec CL de pression automatique.
!     le numero de la face de reference est stocke dans ISOSTD(NFABOR+1)
!     qui est d'abord initialise a -1 (i.e. pas de face de sortie std)
  isostd(nfabor+1) = -1
  do ifac = 1,nfabor
    isostd(ifac) = 0
    if ((itypfb(ifac).eq.isolib.or.itypfb(ifac).eq.ifrent).and.    &
        (icodcl(ifac,ipr).eq.0)) then
      isostd(ifac) = 1
    endif
  enddo
endif

! ---> Reference pressure (unique, even if there are multiple outlets)
!     In case we account for the hydrostatic pressure, we search for the
!     reference face.

!   Determine a unique P I' pressure in parallel
!     if there are free outlet faces, we have determined that the rank
!     with the outlet face closest to xyzp0 is irangd.

!     We also retrieve the coordinates of the reference point, so as to
!     calculate pref later on.

if (itbslb.gt.0) then

  ! If irangd is the local rank, we assign PI' to xyzref(4)
  ! (this is always the case in serial mode)

  if (irangp.eq.irangd) then
    xyzref(1) = cdgfbo(1,ifrslb)
    xyzref(2) = cdgfbo(2,ifrslb)
    xyzref(3) = cdgfbo(3,ifrslb)
    xyzref(4) = pripb(ifrslb)
    if (iphydr.eq.1.or.iifren.eq.1) isostd(nfabor+1) = ifrslb
  endif

  ! Broadcast PI' and pressure reference
  ! from irangd to all other ranks.
  if (irangp.ge.0) then
    inb = 4
    call parbcr(irangd, inb, xyzref)
  endif

  pipb = xyzref(4)
  xyzref(4) = 0.d0

  ! If the user has not specified anything, we set ixyzp0 to 2 so as
  ! to update the reference point.

  if (ixyzp0.eq.-1) ixyzp0 = 2

elseif (ixyzp0.lt.0) then

  ! If there are no outlet faces, we search for possible Dirichlets
  ! specified by the user so as to locate the reference point.
  ! As before, we chose the face closest to xyzp0 so as to
  ! be mesh numbering (and partitioning) independent.

  d0min = rinfin

  ifadir = -1
  do ifac = 1, nfabor
    if (icodcl(ifac,ipr).eq.1) then
      d0 =   (cdgfbo(1,ifac)-xxp0)**2  &
           + (cdgfbo(2,ifac)-xyp0)**2  &
           + (cdgfbo(3,ifac)-xzp0)**2
      if (d0.lt.d0min) then
        ifadir = ifac
        d0min = d0
      endif
    endif
  enddo

  irangd = irangp
  if (irangp.ge.0) call parfpt(ifadir, irangd, d0min)

  if (ifadir.gt.0) then

    ! on met ixyzp0 a 2 pour mettre a jour le point de reference
    ixyzp0 = 2

    if (irangp.eq.irangd) then
      xyzref(1) = cdgfbo(1,ifadir)
      xyzref(2) = cdgfbo(2,ifadir)
      xyzref(3) = cdgfbo(3,ifadir)
    endif

    ! Broadcast xyzref from irangd to all other ranks.
    if (irangp.ge.0) then
      inb = 3
      call parbcr(irangd, inb, xyzref)
    endif

  endif

endif


!   Si le point de reference n'a pas ete specifie par l'utilisateur
!   on le change et on decale alors COEFU s'il y a des sorties.
!   La pression totale dans PROPCE est aussi decalee (c'est a priori
!   inutile sauf si l'utilisateur l'utilise dans ustsnv par exemple)

if (ixyzp0.eq.2) then
  ixyzp0 = 1
  xxp0 = xyzref(1) - xyzp0(1)
  xyp0 = xyzref(2) - xyzp0(2)
  xzp0 = xyzref(3) - xyzp0(3)
  xyzp0(1) = xyzref(1)
  xyzp0(2) = xyzref(2)
  xyzp0(3) = xyzref(3)
  if (ippmod(icompf).lt.0) then
    call field_get_val_s(iprpfl(iprtot), cpro_prtot)
    do iel = 1, ncelet
      cpro_prtot(iel) = cpro_prtot(iel) - ro0*( gx*xxp0 + gy*xyp0 + gz*xzp0 )
    enddo
  endif
  if (itbslb.gt.0) then
    write(nfecra,8000)xxp0,xyp0,xzp0
    do ifac = 1, nfabor
      pripb(ifac) = pripb(ifac) - ro0*( gx*xxp0 + gy*xyp0 + gz*xzp0 )
    enddo
    pipb = pipb - ro0*( gx*xxp0 + gy*xyp0 + gz*xzp0 )
  else
    write(nfecra,8001)xxp0,xyp0,xzp0
  endif
elseif (ixyzp0.eq.-1) then
  !     Il n'y a pas de sorties ni de Dirichlet et l'utilisateur n'a
  !     rien specifie -> on met IXYZP0 a 0 pour ne plus y toucher, tout
  !     en differenciant du cas =1 qui necessitera une ecriture en suite
  ixyzp0 = 0
endif

!     La pression totale doit etre recalee en Xref a la valeur
!     Po + rho_0*g.(Xref-X0)
if (itbslb.gt.0) then
  xxp0 = xyzp0(1)
  xyp0 = xyzp0(2)
  xzp0 = xyzp0(3)
  pref = p0                                            &
       + ro0*( gx*(xyzref(1)-xxp0)                     &
       + gy*(xyzref(2)-xyp0)                           &
       + gz*(xyzref(3)-xzp0) )                         &
       - pipb
endif


! ---> Entree/Sortie libre

ideb = idebty(isolib)
ifin = ifinty(isolib)

do ivar = 1, nvar
  if (ivar.eq.ipr) then
    do ii = ideb, ifin
      ifac = itrifb(ii)
      if(icodcl(ifac,ivar).eq.0) then
        icodcl(ifac,ivar)   = 1
        rcodcl(ifac,ivar,1) = pripb(ifac) + pref
        rcodcl(ifac,ivar,2) = rinfin
        rcodcl(ifac,ivar,3) = 0.d0
      endif
    enddo
  elseif(ivar.eq.iu.or.ivar.eq.iv.or.ivar.eq.iw) then
    do ii = ideb, ifin
      ifac = itrifb(ii)
      if(icodcl(ifac,ivar).eq.0) then
        icodcl(ifac,ivar)   = 9
        rcodcl(ifac,ivar,1) = 0.d0
        rcodcl(ifac,ivar,2) = rinfin
        rcodcl(ifac,ivar,3) = 0.d0
      endif
    enddo
  endif
enddo

! ---> Free entrance (Bernoulli relation), std free outlet
!      (a specific treatment si performed on the increment of pressure)

ideb = idebty(ifrent)
ifin = ifinty(ifrent)

do ivar = 1, nvar
  if (ivar.eq.ipr) then
    do ii = ideb, ifin
      ifac = itrifb(ii)
      iel  = ifabor(ifac)
      if (icodcl(ifac,ivar).eq.0) then

        ! If the user has given a value of boundary head loss
        if (rcodcl(ifac,ivar,2).le.0.5d0*rinfin) then
          b_head_loss(ifac) = rcodcl(ifac,ivar,2)
        else
          b_head_loss(ifac) = 0.d0
        endif

        ! Std outlet
        icodcl(ifac,ivar)   = 1
        rcodcl(ifac,ivar,1) = pripb(ifac) + pref
        rcodcl(ifac,ivar,2) = rinfin
        rcodcl(ifac,ivar,3) = 0.d0

      endif
    enddo
  elseif(ivar.eq.iu.or.ivar.eq.iv.or.ivar.eq.iw) then
    do ii = ideb, ifin
      ifac = itrifb(ii)
      ! Homogeneous Neumann
      if(icodcl(ifac,ivar).eq.0) then
        icodcl(ifac,ivar)   = 3
        rcodcl(ifac,ivar,1) = 0.d0
        rcodcl(ifac,ivar,2) = rinfin
        rcodcl(ifac,ivar,3) = 0.d0
      endif
    enddo
  endif
enddo


! ---> Free surface: Dirichlet on the pressure

ideb = idebty(ifresf)
ifin = ifinty(ifresf)

do ivar = 1, nvar
  if (ivar.eq.ipr) then
    do ii = ideb, ifin
      ifac = itrifb(ii)
      if(icodcl(ifac,ivar).eq.0) then
        icodcl(ifac,ivar)   = 1
        rcodcl(ifac,ivar,1) = p0
        rcodcl(ifac,ivar,2) = rinfin
        rcodcl(ifac,ivar,3) = 0.d0
      endif
    enddo
  elseif(ivar.eq.iu.or.ivar.eq.iv.or.ivar.eq.iw) then
    do ii = ideb, ifin
      ifac = itrifb(ii)
      ! Homogeneous Neumann
      if(icodcl(ifac,ivar).eq.0) then
        icodcl(ifac,ivar)   = 3
        rcodcl(ifac,ivar,1) = 0.d0
        rcodcl(ifac,ivar,2) = rinfin
        rcodcl(ifac,ivar,3) = 0.d0
      endif
    enddo
  endif
enddo


! Free memory
deallocate(pripb)


! 6.3 SYMETRIE
! =============

! ---> Les vecteurs et tenseurs ont un traitement particulier
!        le reste Neumann sera traite plus tard

ideb = idebty(isymet)
ifin = ifinty(isymet)

do ivar = 1, nvar
  if (ivar.eq.iu.or.ivar.eq.iv.or.ivar.eq.iw                     &
     .or.(itytur.eq.3                                            &
         .and.(ivar.eq.ir11.or.ivar.eq.ir22.or.ivar.eq.ir33.or.  &
               ivar.eq.ir12.or.ivar.eq.ir13.or.ivar.eq.ir23))) then
    do ii = ideb, ifin
      ifac = itrifb(ii)
      if(icodcl(ifac,ivar).eq.0) then
        icodcl(ifac,ivar)   = 4
        !         rcodcl(ifac,ivar,1) = Modifie eventuellement par l'ALE
        rcodcl(ifac,ivar,2) = rinfin
        rcodcl(ifac,ivar,3) = 0.d0
      endif
    enddo
  elseif(ivar.eq.ipr) then
    do ii = ideb, ifin
      ifac = itrifb(ii)
      if(icodcl(ifac,ivar).eq.0) then
        icodcl(ifac,ivar)   = 3
        rcodcl(ifac,ivar,1) = 0.d0
        rcodcl(ifac,ivar,2) = rinfin
        rcodcl(ifac,ivar,3) = 0.d0
      endif
    enddo
  endif
enddo

! 6.4 PAROI LISSE
! ===============

! ---> La vitesse et les grandeurs turbulentes ont le code 5
!        le reste Neumann sera traite plus tard

ideb = idebty(iparoi)
ifin = ifinty(iparoi)

do ivar = 1, nvar
  if (ivar.eq.iu.or.ivar.eq.iv.or.ivar.eq.iw) then
    do ii = ideb, ifin
      ifac = itrifb(ii)
      if (icodcl(ifac,ivar).eq.0) then
        icodcl(ifac,ivar)   = 5
        ! rcodcl(ifac,ivar,1) = Utilisateur
        rcodcl(ifac,ivar,2) = rinfin
        rcodcl(ifac,ivar,3) = 0.d0
      endif
    enddo
  elseif ((itytur.eq.2                                             &
          .and.(ivar.eq.ik.or.ivar.eq.iep))                        &
      .or.(itytur.eq.3                                             &
          .and.(ivar.eq.ir11.or.ivar.eq.ir22.or.ivar.eq.ir33.or.   &
                ivar.eq.ir12.or.ivar.eq.ir13.or.ivar.eq.ir23.or.   &
                ivar.eq.iep.or.ivar.eq.ial))                       &
      .or.(iturb.eq.50                                             &
          .and.(ivar.eq.ik.or.ivar.eq.iep.or.ivar.eq.iphi.or.      &
                ivar.eq.ifb))                                      &
      .or.(iturb.eq.51                                             &
          .and.(ivar.eq.ik.or.ivar.eq.iep.or.ivar.eq.iphi.or.      &
                ivar.eq.ial))                                      &
      .or.(iturb.eq.60                                             &
          .and.(ivar.eq.ik.or.ivar.eq.iomg))                       &
      .or.(iturb.eq.70                                             &
          .and.(ivar.eq.inusa))) then
    do ii = ideb, ifin
      ifac = itrifb(ii)
      if(icodcl(ifac,ivar).eq.0) then
        icodcl(ifac,ivar)   = 5
        rcodcl(ifac,ivar,1) = 0.d0
        rcodcl(ifac,ivar,2) = rinfin
        rcodcl(ifac,ivar,3) = 0.d0
      endif
    enddo

  ! Homogeneous Neumann on the pressure
  elseif(ivar.eq.ipr) then
    do ii = ideb, ifin
      ifac = itrifb(ii)
      if(icodcl(ifac,ivar).eq.0) then
        icodcl(ifac,ivar)   = 3
        rcodcl(ifac,ivar,1) = 0.d0
        rcodcl(ifac,ivar,2) = rinfin
        rcodcl(ifac,ivar,3) = 0.d0
      endif
    enddo
  endif
enddo

! 6.5 PAROI RUGUEUSE
! ==================

! ---> La vitesse et les grandeurs turbulentes ont le code 6
!      la rugosite est stockee dans rcodcl(..,..,3)
!      le reste Neumann sera traite plus tard (idem paroi lisse)

ideb = idebty(iparug)
ifin = ifinty(iparug)

do ivar = 1, nvar
  if ( ivar.eq.iu.or.ivar.eq.iv.or.ivar.eq.iw) then
    do ii = ideb, ifin
      ifac = itrifb(ii)
      if(icodcl(ifac,ivar).eq.0) then
        icodcl(ifac,ivar)   = 6
        ! rcodcl(ifac,ivar,1) = Utilisateur
        rcodcl(ifac,ivar,2) = rinfin
        ! rcodcl(ifac,ivar,3) = Utilisateur
      endif
    enddo
  elseif ((itytur.eq.2                                              &
          .and.(ivar.eq.ik.or.ivar.eq.iep))                         &
      .or.(itytur.eq.3                                              &
          .and.(ivar.eq.ir11.or.ivar.eq.ir22.or.ivar.eq.ir33.or.    &
                ivar.eq.ir12.or.ivar.eq.ir13.or.ivar.eq.ir23.or.    &
                ivar.eq.iep.or.ivar.eq.ial))                        &
      .or.(iturb.eq.50                                              &
          .and.(ivar.eq.ik.or.ivar.eq.iep.or.ivar.eq.iphi.or.       &
                ivar.eq.ifb))                                       &
      .or.(iturb.eq.51                                              &
          .and.(ivar.eq.ik.or.ivar.eq.iep.or.ivar.eq.iphi.or.       &
                ivar.eq.ial))                                       &
      .or.(iturb.eq.60                                              &
          .and.(ivar.eq.ik.or.ivar.eq.iomg))                        &
      .or.(iturb.eq.70                                              &
          .and.(ivar.eq.inusa))) then
    do ii = ideb, ifin
      ifac = itrifb(ii)
      if(icodcl(ifac,ivar).eq.0) then
        icodcl(ifac,ivar)   = 6
        rcodcl(ifac,ivar,1) = 0.d0
        rcodcl(ifac,ivar,2) = rinfin
        rcodcl(ifac,ivar,3) = 0.d0
      endif
    enddo
  elseif(ivar.eq.ipr) then
    do ii = ideb, ifin
      ifac = itrifb(ii)
      if(icodcl(ifac,ivar).eq.0) then
        icodcl(ifac,ivar)   = 3
        rcodcl(ifac,ivar,1) = 0.d0
        rcodcl(ifac,ivar,2) = rinfin
        rcodcl(ifac,ivar,3) = 0.d0
      endif
    enddo
  endif
enddo

!===============================================================================
! 6.bis  CONVERSION EN RCODCL ICODCL
!   (SI CE DERNIER N'A PAS DEJA ETE RENSEIGNE PAR L'UTILISATEUR)

!     MAINTENANT LES VARIABLES POUR LESQUELLES IL N'EXISTE PAS DE
!    TRAITEMENT PARTICULIER (HORS PRESSION, VITESSE ...)
!===============================================================================

! 6.1.1 Inlet bis
! ===============

! ---> Pressure is already treated (with a Neumann BC)
!      Dirichlet BC for the velocity.
!      Dirichlet BC for scalars if the user give a value, otherwise homogeneous
!      Neumann if the mass flux is outgoing.

ideb = idebty(ientre)
ifin = ifinty(ientre)

iok = 0
do ivar = 1, nvar
  do ii = ideb, ifin
    ifac = itrifb(ii)
    if(icodcl(ifac,ivar).eq.0) then

      if (ivar.eq.iu.or.ivar.eq.iv.or.ivar.eq.iw)      &
           then
        if (rcodcl(ifac,ivar,1).gt.rinfin*0.5d0) then
          itypfb(ifac) = - abs(itypfb(ifac))
          if (iok.eq.0.or.iok.eq.2) iok = iok + 1
        else
          icodcl(ifac,ivar) = 1
          !           rcodcl(ifac,ivar,1) = Utilisateur
          rcodcl(ifac,ivar,2) = rinfin
          rcodcl(ifac,ivar,3) = 0.d0
        endif

      elseif (rcodcl(ifac,ivar,1).gt.rinfin*0.5d0) then

        flumbf = bmasfl(ifac)
        if( flumbf.ge.-epzero) then
          icodcl(ifac,ivar)   = 3
          rcodcl(ifac,ivar,1) = 0.d0
          rcodcl(ifac,ivar,2) = rinfin
          rcodcl(ifac,ivar,3) = 0.d0
        else
          itypfb(ifac) = - abs(itypfb(ifac))
          if (iok.lt.2) iok = iok + 2
        endif
      else
        icodcl(ifac,ivar) = 1
        !         rcodcl(ifac,ivar,1) = Utilisateur
        rcodcl(ifac,ivar,2) = rinfin
        rcodcl(ifac,ivar,3) = 0.d0
      endif

    endif
  enddo
enddo

if (irangp.ge.0) call parcmx(iok)
if (iok.gt.0) then
  if (iok.eq.1 .or. iok.eq.3) write(nfecra,6060)
  if (iok.eq.2 .or. iok.eq.3) write(nfecra,6070)
  call bcderr(itypfb)
endif

! 6.1.1 Convective Inlet bis
! ==========================

! ---> Pressure is already treated (with a Neumann BC)
!      Dirichlet BC for the velocity.
!      Dirichlet BC for scalars if the user give a value, otherwise homogeneous
!      Neumann if the mass flux is outgoing.

ideb = idebty(i_convective_inlet)
ifin = ifinty(i_convective_inlet)

iok = 0
do ivar = 1, nvar
  do ii = ideb, ifin
    ifac = itrifb(ii)
    if(icodcl(ifac,ivar).eq.0) then

      if (ivar.eq.iu.or.ivar.eq.iv.or.ivar.eq.iw) then
        if (rcodcl(ifac,ivar,1).gt.rinfin*0.5d0) then
          itypfb(ifac) = - abs(itypfb(ifac))
          if (iok.eq.0.or.iok.eq.2) iok = iok + 1
        else
          icodcl(ifac,ivar) = 13
          ! rcodcl(ifac,ivar,1) = User
          rcodcl(ifac,ivar,2) = rinfin
          rcodcl(ifac,ivar,3) = 0.d0
        endif

      elseif (rcodcl(ifac,ivar,1).gt.rinfin*0.5d0) then

        flumbf = bmasfl(ifac)
        if( flumbf.ge.-epzero) then
          icodcl(ifac,ivar)   = 3
          rcodcl(ifac,ivar,1) = 0.d0
          rcodcl(ifac,ivar,2) = rinfin
          rcodcl(ifac,ivar,3) = 0.d0
        else
          itypfb(ifac) = - abs(itypfb(ifac))
          if (iok.lt.2) iok = iok + 2
        endif
      else
        icodcl(ifac,ivar) = 13
        ! rcodcl(ifac,ivar,1) = User
        rcodcl(ifac,ivar,2) = rinfin
        rcodcl(ifac,ivar,3) = 0.d0
      endif

    endif
  enddo
enddo

if (irangp.ge.0) call parcmx(iok)
if (iok.gt.0) then
  if (iok.eq.1 .or. iok.eq.3) write(nfecra,6060)
  if (iok.eq.2 .or. iok.eq.3) write(nfecra,6070)
  call bcderr(itypfb)
endif


! 6.2.a SORTIE (entree sortie libre)
! ==================================

! ---> La pression a un traitement Dirichlet, les vitesses 9 ont ete
!        traites plus haut.
!      Le reste Dirichlet si l'utilisateur fournit une donnee
!        (flux de masse entrant ou sortant).
!      S'il n'y a pas de donnee utilisateur, on utilise un Neumann homogene
!        (flux entrant et sortant)


! ---> Sortie ISOLIB

ideb = idebty(isolib)
ifin = ifinty(isolib)

do ivar = 1, nvar
  do ii = ideb, ifin
    ifac = itrifb(ii)
    if(icodcl(ifac,ivar).eq.0) then

      if (rcodcl(ifac,ivar,1).gt.rinfin*0.5d0) then
        icodcl(ifac,ivar) = 3
        rcodcl(ifac,ivar,1) = 0.d0
        rcodcl(ifac,ivar,2) = rinfin
        rcodcl(ifac,ivar,3) = 0.d0
      else
        icodcl(ifac,ivar) = 1
        !             rcodcl(ifac,ivar,1) = Utilisateur
        rcodcl(ifac,ivar,2) = rinfin
        rcodcl(ifac,ivar,3) = 0.d0
      endif
    endif
  enddo
enddo

! 6.2.b Free inlet (outlet) Bernoulli
! ===================================

! ---> Free entrance (Bernoulli, a dirichlet is needed on the other variables
!      than velocity and pressure, already treated) Free outlet (homogeneous
!      Neumann)

ideb = idebty(ifrent)
ifin = ifinty(ifrent)

do ivar = 1, nvar
  do ii = ideb, ifin
    ifac = itrifb(ii)
    if(icodcl(ifac,ivar).eq.0) then

      if (rcodcl(ifac,ivar,1).gt.rinfin*0.5d0) then
        icodcl(ifac,ivar) = 3
        rcodcl(ifac,ivar,1) = 0.d0
        rcodcl(ifac,ivar,2) = rinfin
        rcodcl(ifac,ivar,3) = 0.d0
      else
        icodcl(ifac,ivar) = 1
        ! rcodcl(ifac,ivar,1) is given by the user
        rcodcl(ifac,ivar,2) = rinfin
        rcodcl(ifac,ivar,3) = 0.d0
      endif
    endif
  enddo
enddo

! 6.2.c Free surface
! ===================================

! ---> Free surface

ideb = idebty(ifresf)
ifin = ifinty(ifresf)

do ivar = 1, nvar
  do ii = ideb, ifin
    ifac = itrifb(ii)
    if(icodcl(ifac,ivar).eq.0) then

      if (rcodcl(ifac,ivar,1).gt.rinfin*0.5d0) then
        icodcl(ifac,ivar) = 3
        rcodcl(ifac,ivar,1) = 0.d0
        rcodcl(ifac,ivar,2) = rinfin
        rcodcl(ifac,ivar,3) = 0.d0
      else
        icodcl(ifac,ivar) = 1
        ! rcodcl(ifac,ivar,1) is given by the user
        rcodcl(ifac,ivar,2) = rinfin
        rcodcl(ifac,ivar,3) = 0.d0
      endif
    endif
  enddo
enddo

! 6.3 SYMETRIE bis
! =============

! ---> Les vecteurs et tenseurs ont un traitement particulier
!        traite plus haut
!        le reste Neumann

ideb = idebty(isymet)
ifin = ifinty(isymet)

do ivar = 1, nvar
  do ii = ideb, ifin
    ifac = itrifb(ii)
    if(icodcl(ifac,ivar).eq.0) then
      icodcl(ifac,ivar)   = 3
      rcodcl(ifac,ivar,1) = 0.d0
      rcodcl(ifac,ivar,2) = rinfin
      rcodcl(ifac,ivar,3) = 0.d0
    endif
  enddo
enddo

! 6.4 PAROI LISSE bis
! ===============

! ---> La vitesse et les grandeurs turbulentes ont le code 5
!        traite plus haut
!        le reste Neumann

ideb = idebty(iparoi)
ifin = ifinty(iparoi)

do ivar = 1, nvar
  do ii = ideb, ifin
    ifac = itrifb(ii)
    if(icodcl(ifac,ivar).eq.0) then
      icodcl(ifac,ivar)   = 3
      rcodcl(ifac,ivar,1) = 0.d0
      rcodcl(ifac,ivar,2) = rinfin
      rcodcl(ifac,ivar,3) = 0.d0
    endif
  enddo
enddo

! 6.5 PAROI RUGUEUSE bis
! ==================

! ---> La vitesse et les grandeurs turbulentes ont le code 6
!        traite plus haut
!        le reste Neumann

ideb = idebty(iparug)
ifin = ifinty(iparug)

do ivar = 1, nvar
  do ii = ideb, ifin
    ifac = itrifb(ii)
    if(icodcl(ifac,ivar).eq.0) then
      icodcl(ifac,ivar)   = 3
      rcodcl(ifac,ivar,1) = 0.d0
      rcodcl(ifac,ivar,2) = rinfin
      rcodcl(ifac,ivar,3) = 0.d0
    endif
  enddo
enddo

!===============================================================================
! 7.  RENFORCEMENT DIAGONALE DE LA MATRICE SI AUCUN POINTS DIRICHLET
!===============================================================================
! On renforce si ISTAT=0 et si l'option est activee (IDIRCL=1)
! Si une de ces conditions est fausse, on force NDIRCL a valoir
! au moins 1 pour ne pas decaler la diagonale.

do ivar = 1, nvar
  ndircl(ivar) = 0
  if ( istat(ivar).gt.0 .or. idircl(ivar).eq.0 ) ndircl(ivar) = 1
enddo

do ivar = 1, nvar
  do ifac = 1, nfabor
    if( icodcl(ifac,ivar).eq.1 .or. icodcl(ifac,ivar).eq.5 ) then
      ndircl(ivar) = ndircl(ivar) +1
    endif
  enddo
  if (irangp.ge.0) call parcpt (ndircl(ivar))
enddo

!===============================================================================
! 8.  ON CALCULE LE FLUX DE MASSE AUX DIFFERENTS TYPES DE FACES
!       ET ON IMPRIME.

!     Ca serait utile de faire l'impression dans ECRLIS, mais attention,
!       on imprime le flux de masse du pas de temps precedent
!       or dans ECRLIS, on imprime a la fin du pas de temps
!       d'ou une petite incoherence possible.
!     D'autre part, ca serait utile de sortir d'autres grandeurs
!       (flux de chaleur par exemple, bilan de scalaires ...)

!===============================================================================

iwaru = -1
iwaru = max(iwarni(iu),iwaru)
if (irangp.ge.0) call parcmx(iwaru)

if(iwaru.ge.1 .or. mod(ntcabs,ntlist).eq.0                        &
       .or.(ntcabs.le.ntpabs+2).or.(ntcabs.ge.ntmabs-1)) then
  write(nfecra,7010)
endif

iwrnp = iwarni(iu)
if (irangp.ge.0) call parcmx (iwrnp)
!==========

!     On ecrit le flux de masse si IWARNI>0, a la periodicite NTLIST
!     et au deux premiers et deux derniers pas de temps.
if(iwrnp.ge.1 .or. mod(ntcabs,ntlist).eq.0                      &
     .or.(ntcabs.le.ntpabs+2).or.(ntcabs.ge.ntmabs-1)) then

  do ii = 1, ntypmx
    flumty(ii) = 0.d0
  enddo

  do ii = 1, ntypmx
    ideb = idebty(ii)
    ifin = ifinty(ii)
    do jj = ideb, ifin
      ifac = itrifb(jj)
      flumty(ii) = flumty(ii) + bmasfl(ifac)
    enddo
  enddo


  write(nfecra,7011)

  if (ippmod(icompf).lt.0 ) then

    ii = ientre
    inb = ifinty(ii)-idebty(ii)+1
    if (irangp.ge.0) then
      call parcpt (inb)
      call parsom (flumty(ii))
    endif
#if defined(_CS_LANG_FR)
    write(nfecra,7020) 'Entree           ',ii,inb,flumty(ii)
#else
    write(nfecra,7020) 'Inlet            ',ii,inb,flumty(ii)
#endif
    ii = iparoi
    inb = ifinty(ii)-idebty(ii)+1
    if (irangp.ge.0) then
      call parcpt (inb)
      call parsom (flumty(ii))
    endif
#if defined(_CS_LANG_FR)
    write(nfecra,7020) 'Paroi lisse      ',ii,inb,flumty(ii)
#else
    write(nfecra,7020) 'Smooth wall      ',ii,inb,flumty(ii)
#endif
    ii = iparug
    inb = ifinty(ii)-idebty(ii)+1
    if (irangp.ge.0) then
      call parcpt (inb)
      call parsom (flumty(ii))
    endif
#if defined(_CS_LANG_FR)
    write(nfecra,7020) 'Paroi rugueuse   ',ii,inb,flumty(ii)
#else
    write(nfecra,7020) 'Rough wall       ',ii,inb,flumty(ii)
#endif
    ii = isymet
    inb = ifinty(ii)-idebty(ii)+1
    if (irangp.ge.0) then
      call parcpt (inb)
      call parsom (flumty(ii))
    endif
#if defined(_CS_LANG_FR)
    write(nfecra,7020) 'Symetrie         ',ii,inb,flumty(ii)
#else
    write(nfecra,7020) 'Symmetry         ',ii,inb,flumty(ii)
#endif

    ii = isolib
    inb = ifinty(ii)-idebty(ii)+1
    if (irangp.ge.0) then
      call parcpt (inb)
      call parsom (flumty(ii))
    endif
#if defined(_CS_LANG_FR)
    write(nfecra,7020) 'Sortie libre     ',ii,inb,flumty(ii)
#else
    write(nfecra,7020) 'Free outlet      ',ii,inb,flumty(ii)
#endif

    ii = ifrent
    inb = ifinty(ii)-idebty(ii)+1
    if (irangp.ge.0) then
      call parcpt (inb)
      call parsom (flumty(ii))
    endif
#if defined(_CS_LANG_FR)
    write(nfecra,7020) 'Entree libre     ',ii,inb,flumty(ii)
#else
    write(nfecra,7020) 'Free inlet       ',ii,inb,flumty(ii)
#endif
    ii = i_convective_inlet
    inb = ifinty(ii)-idebty(ii)+1
    if (irangp.ge.0) then
      call parcpt (inb)
      call parsom (flumty(ii))
    endif
#if defined(_CS_LANG_FR)
    write(nfecra,7020) 'Entree convective',ii,inb,flumty(ii)
#else
    write(nfecra,7020) 'Convective inlet ',ii,inb,flumty(ii)
#endif

    ii = ifresf
    inb = ifinty(ii)-idebty(ii)+1
    if (irangp.ge.0) then
      call parcpt (inb)
      call parsom (flumty(ii))
    endif
#if defined(_CS_LANG_FR)
    write(nfecra,7020) 'Surface libre    ',ii,inb,flumty(ii)
#else
    write(nfecra,7020) 'Free surface     ',ii,inb,flumty(ii)
#endif

    if (nbrcpl.ge.1) then
      ii = icscpl
      inb = ifinty(ii)-idebty(ii)+1
      if (irangp.ge.0) then
        call parcpt (inb)
        call parsom (flumty(ii))
      endif
#if defined(_CS_LANG_FR)
      write(nfecra,7020) 'Couplage sat/sat ',ii,inb,flumty(ii)
#else
      write(nfecra,7020) 'Sat/Sat coupling ',ii,inb,flumty(ii)
#endif
    endif

    ii = iindef
    inb = ifinty(ii)-idebty(ii)+1
    if (irangp.ge.0) then
      call parcpt (inb)
      call parsom (flumty(ii))
    endif
#if defined(_CS_LANG_FR)
    write(nfecra,7020) 'Indefini         ',ii,inb,flumty(ii)
#else
    write(nfecra,7020) 'Undefined        ',ii,inb,flumty(ii)
#endif

    do ii = 1, ntypmx
      if ( ii.ne.ientre  .and.                                    &
           ii.ne.i_convective_inlet .and.                         &
           ii.ne.iparoi  .and.                                    &
           ii.ne.iparug  .and.                                    &
           ii.ne.isymet  .and.                                    &
           ii.ne.isolib  .and.                                    &
           ii.ne.ifrent  .and.                                    &
           ii.ne.ifresf  .and.                                    &
           ii.ne.icscpl  .and.                                    &
           ii.ne.iindef ) then
        inb = ifinty(ii)-idebty(ii)+1
        if (irangp.ge.0) then
          call parcpt (inb)
          call parsom (flumty(ii))
        endif
        if(inb.gt.0) then
#if defined(_CS_LANG_FR)
          write(nfecra,7020) 'Type utilisateur ',ii,inb,flumty(ii)
#else
          write(nfecra,7020) 'User type        ',ii,inb,flumty(ii)
#endif
        endif
      endif
    enddo

  else

    ii = ieqhcf
    inb = ifinty(ii)-idebty(ii)+1
    if (irangp.ge.0) then
      call parcpt (inb)
      call parsom (flumty(ii))
    endif
#if defined(_CS_LANG_FR)
    write(nfecra,7020) 'Entree sub. enth.',ii,inb,flumty(ii)
#else
    write(nfecra,7020) 'Sub. enth. inlet ',ii,inb,flumty(ii)
#endif

    ii = iephcf
    inb = ifinty(ii)-idebty(ii)+1
    if (irangp.ge.0) then
      call parcpt (inb)
      call parsom (flumty(ii))
    endif
#if defined(_CS_LANG_FR)
    write(nfecra,7020) 'Ptot, Htot       ',ii,inb,flumty(ii)
#else
    write(nfecra,7020) 'Ptot, Htot       ',ii,inb,flumty(ii)
#endif

    ii = iesicf
    inb = ifinty(ii)-idebty(ii)+1
    if (irangp.ge.0) then
      call parcpt (inb)
      call parsom (flumty(ii))
    endif
#if defined(_CS_LANG_FR)
    write(nfecra,7020) 'Entree/Sortie imp',ii,inb,flumty(ii)
#else
    write(nfecra,7020) 'Imp inlet/outlet ',ii,inb,flumty(ii)
#endif

    ii = isopcf
    inb = ifinty(ii)-idebty(ii)+1
    if (irangp.ge.0) then
      call parcpt (inb)
      call parsom (flumty(ii))
    endif
#if defined(_CS_LANG_FR)
    write(nfecra,7020) 'Sortie subsonique',ii,inb,flumty(ii)
#else
    write(nfecra,7020) 'Subsonic outlet  ',ii,inb,flumty(ii)
#endif

    ii = isspcf
    inb = ifinty(ii)-idebty(ii)+1
    if (irangp.ge.0) then
      call parcpt (inb)
      call parsom (flumty(ii))
    endif
#if defined(_CS_LANG_FR)
    write(nfecra,7020) 'Sortie supersoniq',ii,inb,flumty(ii)
#else
    write(nfecra,7020) 'Supersonic outlet',ii,inb,flumty(ii)
#endif

    ii = iparoi
    inb = ifinty(ii)-idebty(ii)+1
    if (irangp.ge.0) then
      call parcpt (inb)
      call parsom (flumty(ii))
    endif
#if defined(_CS_LANG_FR)
    write(nfecra,7020) 'Paroi            ',ii,inb,flumty(ii)
#else
    write(nfecra,7020) 'Wall             ',ii,inb,flumty(ii)
#endif

    ii = isymet
    inb = ifinty(ii)-idebty(ii)+1
    if (irangp.ge.0) then
      call parcpt (inb)
      call parsom (flumty(ii))
    endif
#if defined(_CS_LANG_FR)
    write(nfecra,7020) 'Symetrie         ',ii,inb,flumty(ii)
#else
    write(nfecra,7020) 'Symmetry         ',ii,inb,flumty(ii)
#endif

    ii = iindef
    inb = ifinty(ii)-idebty(ii)+1
    if (irangp.ge.0) then
      call parcpt (inb)
      call parsom (flumty(ii))
    endif
#if defined(_CS_LANG_FR)
    write(nfecra,7020) 'Indefini         ',ii,inb,flumty(ii)
#else
    write(nfecra,7020) 'Undefined        ',ii,inb,flumty(ii)
#endif

    do ii = 1, ntypmx
      if (ii.ne.iesicf .and. &
           ii.ne.isspcf .and. &
           ii.ne.ieqhcf .and. &
           ii.ne.iephcf .and. &
           ii.ne.isopcf .and. &
           ii.ne.iparoi .and. &
           ii.ne.isymet .and. &
           ii.ne.iindef) then
        inb = ifinty(ii)-idebty(ii)+1
        if (irangp.ge.0) then
          call parcpt (inb)
          call parsom (flumty(ii))
        endif
        if(inb.gt.0) then
#if defined(_CS_LANG_FR)
          write(nfecra,7020) 'Type utilisateur ',ii,inb,flumty(ii)
#else
          write(nfecra,7020) 'User type        ',ii,inb,flumty(ii)
#endif
        endif
      endif
    enddo

  endif

  write(nfecra,7030)

endif

!===============================================================================
! FORMATS
!===============================================================================

#if defined(_CS_LANG_FR)

 2020 format(/,'   IFINTY : ',I10)
 2030 format(/,'   IDEBTY : ',I10)
 2040 format(/,'   ITYPFB : ',I10)
 2098 format(/,                                                   &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET LORS DE LA VERIFICATION DES COND. LIM.',/,&
'@    =========                                               ',/,&
'@    PROBLEME DE TRI DES FACES DE BORD                       ',/,&
'@                                                            ',/,&
'@    IFINTY(',I10   ,') = ',I10                               ,/,&
'@      est superieur a                                       ',/,&
'@    IDEBTY(',I10   ,') = ',I10                               ,/,&
'@                                                            ',/,&
'@    Le calcul ne sera pas execute.                          ',/,&
'@                                                            ',/,&
'@    Contacter l''assistance.                                ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 2099 format(/,                                                   &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET LORS DE LA VERIFICATION DES COND. LIM.',/,&
'@    =========                                               ',/,&
'@    PROBLEME DE TRI DES FACES DE BORD SUR UN RANG DISTANT   ',/,&
'@                                                            ',/,&
'@    IFINTY(',I10   ,')                                      ',/,&
'@      est superieur a                                       ',/,&
'@    IDEBTY(',I10   ,')                                      ',/,&
'@                                                            ',/,&
'@    Le calcul ne sera pas execute.                          ',/,&
'@                                                            ',/,&
'@    Contacter l''assistance.                                ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

 3099 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET LORS DE LA VERIFICATION DES COND. LIM.',/,&
'@    =========                                               ',/,&
'@    PROBLEME DE TRI DES FACES DE BORD                       ',/,&
'@                                                            ',/,&
'@      nombre de faces classees par type = ',I10              ,/,&
'@      nombre de faces de bord  NFABOR   = ',I10              ,/,&
'@                                                            ',/,&
'@    Le calcul ne sera pas execute.                          ',/,&
'@                                                            ',/,&
'@    Contacter l''assistance.                                ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)


 6010 format ( /,/,                                               &
 '   ** INFORMATIONS SUR LE TYPE DE FACES DE BORD',/,             &
 '      -----------------------------------------',/)
 6011 format (                                                    &
'---------------------------------------------------------------',&
'----------',                                                     &
                                                                /,&
'Type de bord           Code    Nb faces',                        &
                                                                /,&
'---------------------------------------------------------------',&
'----------')
 6020 format (                                                    &
 a17,i10,i12)
 6030 format(                                                     &
'---------------------------------------------------------------',&
'----------'/)

 6060 format(                                                     &
'@                                                            ',/,&
'@                                                            ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET LORS DE LA VERIFICATION DES COND. LIM.',/,&
'@    =========                                               ',/,&
'@    CONDITIONS AUX LIMITES INCORRECTES OU INCOMPLETES       ',/,&
'@                                                            ',/,&
'@    Au moins une face de bord declaree en entree            ',/,&
'@      (ou sortie) a vitesse imposee pour laquelle la valeur ',/,&
'@      de la vitesse n''a pas ete fournie pour toutes les    ',/,&
'@      composantes.                                          ',/,&
'@    Le calcul ne sera pas execute.                          ',/,&
'@                                                            ',/,&
'@    Verifier les conditions aux limites dans l''Interface   ',/,&
'@    ou dans le sous-programme utilisateur correspondant.    ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

 6070 format(                                                           &
'@                                                            ',/,&
'@                                                            ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET LORS DE LA VERIFICATION DES COND. LIM.',/,&
'@    =========                                               ',/,&
'@    CONDITIONS AUX LIMITES INCORRECTES OU INCOMPLETES       ',/,&
'@                                                            ',/,&
'@    Au moins une face de bord declaree en entree            ',/,&
'@      (ou sortie) a vitesse imposee avec un flux rentrant   ',/,&
'@      pour laquelle la valeur d''une variable n''a pas ete  ',/,&
'@      specifiee (condition de Dirichlet).                   ',/,&
'@    Le calcul ne sera pas execute                           ',/,&
'@                                                            ',/,&
'@    Verifier les conditions aux limites dans l''Interface   ',/,&
'@    ou dans le sous-programme utilisateur correspondant.    ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)


 7010 format ( /,/,                                               &
 '   ** INFORMATIONS SUR LE FLUX DE MASSE AU BORD',/,             &
 '      -----------------------------------------',/)
 7011 format (                                                    &
'---------------------------------------------------------------',&
                                                                /,&
'Type de bord           Code    Nb faces           Flux de masse',&
                                                                /,&
'---------------------------------------------------------------')
 7020 format (                                                    &
 a17,i10,i12,6x,e18.9)
 7030 format(                                                     &
'---------------------------------------------------------------',&
                                                                /)

 8000 format(/,                                                   &
'Faces de bord d''entree/sortie libre detectees               ',/,&
'Mise a jour du point de reference pour la pression totale    ',/,&
' XYZP0 = ',E14.5,E14.5,E14.5                  ,/)
 8001 format(/,                                                   &
'Faces de bord a Dirichlet de pression impose detectees       ',/,&
'Mise a jour du point de reference pour la pression totale    ',/,&
' XYZP0 = ',E14.5,E14.5,E14.5                  ,/)

!-------------------------------------------------------------------------------

#else

 2020 format(/,'   IFINTY : ',I10)
 2030 format(/,'   IDEBTY : ',I10)
 2040 format(/,'   ITYPFB : ',I10)
 2098 format(/,                                                   &
'@'                                                            ,/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@'                                                            ,/,&
'@ @@ WARNING: ABORT BY BOUNDARY CONDITION CHECK'              ,/,&
'@    ========'                                                ,/,&
'@    PROBLEM WITH ORDERING OF BOUNDARY FACES'                 ,/,&
'@'                                                            ,/,&
'@    IFINTY(',I10   ,') = ',I10                               ,/,&
'@      is greater than'                                       ,/,&
'@    IDEBTY(',I10   ,') = ',I10                               ,/,&
'@'                                                            ,/,&
'@    The calculation will not be run.'                        ,/,&
'@'                                                            ,/,&
'@    Contact support.'                                        ,/,&
'@'                                                            ,/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 2099 format(/,                                                   &
'@'                                                            ,/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@'                                                            ,/,&
'@ @@ WARNING: ABORT BY BOUNDARY CONDITION CHECK'              ,/,&
'@    ========'                                                ,/,&
'@    PROBLEM WITH ORDERING OF BOUNDARY FACES'                 ,/,&
'@    ON A DISTANT RANK.'                                      ,/,&
'@'                                                            ,/,&
'@    IFINTY(',I10   ,')                                      ',/,&
'@      is greater than'                                       ,/,&
'@    IDEBTY(',I10   ,')                                      ',/,&
'@'                                                            ,/,&
'@    The calculation will not be run.'                        ,/,&
'@'                                                            ,/,&
'@    Contact support.'                                        ,/,&
'@'                                                            ,/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

 3099 format(                                                     &
'@'                                                            ,/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@'                                                            ,/,&
'@ @@ WARNING: ABORT BY BOUNDARY CONDITION CHECK'              ,/,&
'@    ========'                                                ,/,&
'@    PROBLEM WITH ORDERING OF BOUNDARY FACES'                 ,/,&
'@'                                                            ,/,&
'@      number of faces classified by type = ',I10             ,/,&
'@      number of boundary faces (NFABOR)  = ',I10             ,/,&
'@'                                                            ,/,&
'@    The calculation will not be run.'                        ,/,&
'@'                                                            ,/,&
'@    Contact support.'                                        ,/,&
'@'                                                            ,/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)


 6010 format ( /,/,                                               &
 '   ** INFORMATION ON BOUNDARY FACES TYPE',/,                    &
 '      ----------------------------------',/)
 6011 format (                                                    &
'---------------------------------------------------------------',&
'----------',                                                     &
                                                                /,&
'Boundary type          Code    Nb faces',                        &
                                                                /,&
'---------------------------------------------------------------',&
'----------')
 6020 format (                                                    &
 a17,i10,i12)
 6030 format(                                                     &
'---------------------------------------------------------------',&
'----------'/)

 6060 format(                                                     &
'@'                                                            ,/,&
'@'                                                            ,/,&
'@'                                                            ,/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@'                                                            ,/,&
'@ @@ WARNING: ABORT BY BOUNDARY CONDITION CHECK'              ,/,&
'@    ========'                                                ,/,&
'@    INCORRECT OR INCOMPLETE BOUNDARY CONDITIONS'             ,/,&
'@'                                                            ,/,&
'@    At least one boundary face declared as inlet (or'        ,/,&
'@      outlet) with prescribed velocity for which the'        ,/,&
'@      velocity value has not been assigned for all'          ,/,&
'@      components.'                                           ,/,&
'@    The calculation will not be run.                        ',/,&
'@'                                                            ,/,&
'@    Verify the boundary condition definitions in the GUI'    ,/,&
'@    or in the appropriate user subroutine.'                  ,/,&
'@'                                                            ,/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

 6070 format(                                                     &
'@'                                                            ,/,&
'@'                                                            ,/,&
'@'                                                            ,/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@'                                                            ,/,&
'@ @@ WARNING: ABORT BY BOUNDARY CONDITION CHECK'              ,/,&
'@    ========'                                                ,/,&
'@    INCORRECT OR INCOMPLETE BOUNDARY CONDITIONS'             ,/,&
'@'                                                            ,/,&
'@    At least one boundary face declared as inlet (or'        ,/,&
'@      outlet) with prescribed velocity with an entering'     ,/,&
'@      flow for which the value of a variable has not been'   ,/,&
'@      specified (Dirichlet condition).'                      ,/,&
'@    The calculation will not be run.                        ',/,&
'@'                                                            ,/,&
'@    Verify the boundary condition definitions in the GUI'    ,/,&
'@    or in the appropriate user subroutine.'                  ,/,&
'@'                                                            ,/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)


 7010 format ( /,/,                                               &
 '   ** BOUNDARY MASS FLOW INFORMATION',/,                        &
 '      ------------------------------',/)
 7011 format (                                                    &
'---------------------------------------------------------------',&
                                                                /,&
'Boundary type          Code    Nb faces           Mass flow'   , &
                                                                /,&
'---------------------------------------------------------------')
 7020 format (                                                    &
 a17,i10,i12,6x,e18.9)
 7030 format(                                                     &
'---------------------------------------------------------------',&
                                                                /)

 8000 format(/,                                                   &
'Boundary faces with free inlet/outlet detected'               ,/,&
'Update of reference point for total pressure'                 ,/,&
' XYZP0 = ',E14.5,E14.5,E14.5                  ,/)
 8001 format(/,                                                   &
'Boundary faces with pressure Dirichlet condition detected'    ,/,&
'Update of reference point for total pressure'                 ,/,&
' XYZP0 = ',E14.5,E14.5,E14.5                  ,/)

#endif


return
end subroutine
