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

!> \file divrit.f90
!>
!> \brief This subroutine perform  add the divergence of turbulent flux
!> to the transport equation of a scalar.
!-------------------------------------------------------------------------------

!-------------------------------------------------------------------------------
! Arguments
!______________________________________________________________________________.
!  mode           name          role                                           !
!______________________________________________________________________________!
!> \param[in]     nscal         total number of scalars
!> \param[in]     iscal         number of the scalar used
!> \param[in]     dt            time step (per cell)
!> \param[in]     xcpp          Cp
!> \param[out]    smbrs         Right hand side to update
!_______________________________________________________________________________

subroutine divrit &
 ( nscal  , iscal  ,                                              &
   dt     ,                                                       &
   xcpp   ,                                                       &
   smbrs )

!===============================================================================
! Module files
!===============================================================================

use paramx
use dimens, only: ndimfb
use numvar
use entsor
use optcal
use cstphy
use cstnum!
use pointe
use field
use field_operator
use mesh

!===============================================================================

implicit none

! Arguments

integer          nscal
integer          iscal
double precision dt(ncelet)
double precision xcpp(ncelet)
double precision smbrs(ncelet)

! Local variables

integer          ifac, init, inc, iprev
integer          iccocg,iflmb0
integer          nswrgp, imligp, iwarnp
integer          itypfl
integer          ivar , ivar0 , iel, ii, jj
integer          itt
integer          f_id, f_id0

double precision epsrgp, climgp, extrap
double precision xk, xe, xtt
double precision grav(3),xrij(3,3), temp(3)

character(len=80) :: fname

double precision, dimension(:), pointer :: coefap, coefbp
double precision, allocatable, dimension(:,:,:) :: gradv
double precision, allocatable, dimension(:,:) :: gradt
double precision, allocatable, dimension(:,:) :: coefat
double precision, allocatable, dimension(:,:,:) :: coefbt
double precision, allocatable, dimension(:) :: thflxf, thflxb
double precision, allocatable, dimension(:) :: divut
double precision, allocatable, dimension(:,:) :: w1

double precision, dimension(:,:), pointer :: cofarut
double precision, dimension(:,:,:), pointer :: cofbrut
double precision, dimension(:,:), pointer :: xut
double precision, dimension(:,:), pointer :: xuta
double precision, dimension(:), pointer :: brom, crom, cpro_beta
double precision, dimension(:), pointer :: cvara_ep
double precision, dimension(:), pointer :: cvara_r11, cvara_r22, cvara_r33
double precision, dimension(:), pointer :: cvara_r12, cvara_r13, cvara_r23
double precision, dimension(:), pointer :: cvara_scal, cvara_tt

!===============================================================================

!===============================================================================
! 1. Initialization
!===============================================================================

f_id0 = -1

! Initializations to avoid compiler warnings
xtt = 0.d0

! First component is for x,y,z  and the 2nd for u,v,w
allocate(gradv(3,3,ncelet))
allocate(gradt(ncelet,3), thflxf(nfac), thflxb(nfabor))

call field_get_val_s(icrom, crom)
call field_get_val_s(ibrom, brom)

if (ibeta.gt.0) then
  call field_get_val_s(iprpfl(ipproc(ibeta)), cpro_beta)
endif

! Compute scalar gradient
ivar = isca(iscal)
iccocg = 1
inc = 1
call field_get_val_prev_s(ivarfl(ivar), cvara_scal)

! Name of the scalar ivar
call field_get_name(ivarfl(ivar), fname)

! Index of the corresponding turbulent flux
call field_get_id(trim(fname)//'_turbulent_flux', f_id)

call field_get_val_v(f_id, xut)

nswrgp = nswrgr(ivar)
imligp = imligr(ivar)
iwarnp = iwarni(ivar)
epsrgp = epsrgr(ivar)
climgp = climgr(ivar)
extrap = extrag(ivar)

! Boundary condition pointers for gradients and advection
call field_get_coefa_s(ivarfl(ivar), coefap)
call field_get_coefb_s(ivarfl(ivar), coefbp)

ivar0 = 0

call grdcel &
!==========
 ( ivar0  , imrgra , inc    , iccocg , nswrgp , imligp ,         &
   iwarnp , nfecra , epsrgp , climgp , extrap ,                  &
   cvara_scal      , coefap , coefbp ,                           &
   gradt  )

! Compute velocity gradient
iprev  = 0
inc    = 1

! WARNING: gradv(xyz, uvw, iel)

call field_gradient_vector(ivarfl(iu), iprev, imrgra, inc,  &
                           gradv)

! Find the variance of the thermal scalar
itt = -1
if (((abs(gx)+abs(gy)+abs(gz)).gt.epzero).and.irovar.gt.0.and.         &
    ((ityturt(iscal).eq.2).or.(ityturt(iscal).eq.3))) then
  grav(1) = gx
  grav(2) = gy
  grav(3) = gz
  do ii = 1, nscal
    if (iscavr(ii).eq.iscalt) itt = ii
  enddo
  if (itt.le.0) then
    write(nfecra,9999)
    call csexit(1)
  endif
endif

!===============================================================================
! 2. Agebraic models AFM
!===============================================================================
if (ityturt(iscal).ne.3) then

  call field_get_val_prev_s(ivarfl(iep), cvara_ep)

  call field_get_val_prev_s(ivarfl(ir11), cvara_r11)
  call field_get_val_prev_s(ivarfl(ir22), cvara_r22)
  call field_get_val_prev_s(ivarfl(ir33), cvara_r33)
  call field_get_val_prev_s(ivarfl(ir12), cvara_r12)
  call field_get_val_prev_s(ivarfl(ir13), cvara_r13)
  call field_get_val_prev_s(ivarfl(ir23), cvara_r23)

  allocate(w1(3,ncelet))

  do ifac = 1, nfac
    thflxf(ifac) = 0.d0
  enddo
  do ifac = 1, nfabor
    thflxb(ifac) = 0.d0
  enddo

  if (itt.gt.0) call field_get_val_prev_s(ivarfl(isca(itt)), cvara_tt)

  do iel = 1, ncel
    !Rij
    xrij(1,1) = cvara_r11(iel)
    xrij(2,2) = cvara_r22(iel)
    xrij(3,3) = cvara_r33(iel)
    xrij(1,2) = cvara_r12(iel)
    xrij(1,3) = cvara_r13(iel)
    xrij(2,3) = cvara_r23(iel)
    xrij(2,1) = xrij(1,2)
    xrij(3,1) = xrij(1,3)
    xrij(3,2) = xrij(2,3)
    ! Epsilon
    xe = cvara_ep(iel)
    ! Kinetic turbulent energy
    xk = 0.5d0*(xrij(1,1)+xrij(2,2)+xrij(3,3))

    !  Turbulent time-scale (constant in AFM)
    if (iturt(iscal).eq.20) then
      xtt = xk/xe
    else
      xtt = xk/xe
    endif

    ! Compute thermal flux u'T'

    !FIXME compute u'T' for GGDH.
    do ii = 1, 3

      temp(ii) = 0.d0

      ! AFM and EB-AFM models
      !  "-C_theta*k/eps*( xi* uT'.Grad u + eta*beta*g_i*T'^2)"
      if (ityturt(iscal).eq.2.and.ibeta.gt.0) then
        if (itt.gt.0) then
          temp(ii) = temp(ii) - ctheta(iscal)*xtt*                            &
                       etaafm*cpro_beta(iel)*grav(ii)*cvara_tt(iel)
        endif

        do jj = 1, 3
          if (ii.ne.jj) then
            temp(ii) = temp(ii)                                               &
                     - ctheta(iscal)*xtt*xiafm*gradv(jj,ii,iel)*xut(jj,iel)
          endif
        enddo
      endif

      ! Partial implicitation of "-C_theta*k/eps*( xi* uT'.Grad u )"
      if (iturt(iscal).eq.20) then
        temp(ii) = temp(ii)/(1.d0+ctheta(iscal)*xtt*xiafm*gradv(ii,ii,iel))
      endif

    enddo

    ! Add the term in "grad T" which is implicited by the GGDH part in covofi.
    !  "-C_theta*k/eps* R.grad T"
    do ii = 1, 3
      xut(ii,iel) = temp(ii) - ctheta(iscal)*xtt*( xrij(ii,1)*gradt(iel,1)  &
                                                 + xrij(ii,2)*gradt(iel,2)  &
                                                 + xrij(ii,3)*gradt(iel,3))
      ! In the next step, we compute the divergence of:
      !  "-Cp*C_theta*k/eps*( xi* uT'.Grad u + eta*beta*g_i*T'^2)"
      !  The part "-C_theta*k/eps* R.Grad T" is computed by the GGDH part
      w1(ii,iel) = xcpp(iel)*temp(ii)
    enddo
  enddo

  itypfl = 1
  iflmb0 = 1
  init   = 1
  inc    = 1
  nswrgp = nswrgr(ivar)
  imligp = imligr(ivar)
  iwarnp = iwarni(ivar)
  epsrgp = epsrgr(ivar)
  climgp = climgr(ivar)
  extrap = extrag(ivar)

  ! Local gradient boundaray conditions: homogenous Neumann
  allocate(coefat(3,ndimfb))
  allocate(coefbt(3,3,ndimfb))
  do ifac = 1, nfabor
    do ii = 1, 3
    coefat(ii,ifac) = 0.d0
      do jj = 1, 3
        if (ii.eq.jj) then
          coefbt(ii,jj,ifac) = 1.d0
        else
          coefbt(ii,jj,ifac) = 0.d0
        endif
      enddo
    enddo
  enddo

  call inimav &
  !==========
  ( f_id0  , itypfl ,                                     &
    iflmb0 , init   , inc    , imrgra , nswrgp  , imligp, &
    iwarnp ,                                              &
    epsrgp , climgp ,                                     &
    crom   , brom   ,                                     &
    w1     ,                                              &
    coefat , coefbt ,                                     &
    thflxf , thflxb )

  deallocate(coefat)
  deallocate(coefbt)
  deallocate(w1)

!===============================================================================
! 3. Transport equation on turbulent thermal fluxes (DFM)
!===============================================================================
else

  call field_get_val_prev_v(f_id, xuta)

  call resrit &
  !==========
( nscal  ,                                               &
  iscal  , xcpp   , xut    , xuta   ,                    &
  dt     ,                                               &
  gradv  , gradt  )

  itypfl = 1
  iflmb0 = 1
  init   = 1
  inc    = 1
  nswrgp = nswrgr(ivar)
  imligp = imligr(ivar)
  iwarnp = iwarni(ivar)
  epsrgp = epsrgr(ivar)
  climgp = climgr(ivar)
  extrap = extrag(ivar)

  do iel = 1, ncelet
    xuta(1,iel) = xut(1,iel)
    xuta(2,iel) = xut(2,iel)
    xuta(3,iel) = xut(3,iel)
  enddo

  allocate(w1(3, ncelet))

  do iel = 1, ncelet
    w1(1,iel) = xcpp(iel)*xut(1,iel)
    w1(2,iel) = xcpp(iel)*xut(2,iel)
    w1(3,iel) = xcpp(iel)*xut(3,iel)
  enddo

  ! Boundary Conditions on T'u' for the divergence term of
  ! the thermal transport equation
  call field_get_coefad_v(f_id,cofarut)
  call field_get_coefbd_v(f_id,cofbrut)

  call inimav &
  !==========
  ( f_id0  , itypfl ,                                     &
    iflmb0 , init   , inc    , imrgra , nswrgp  , imligp, &
    iwarnp ,                                              &
    epsrgp , climgp ,                                     &
    crom   , brom   ,                                     &
    w1     ,                                              &
    cofarut, cofbrut,                                     &
    thflxf , thflxb )

  deallocate(w1)

endif

!===============================================================================
! 4. Add the divergence of the thermal flux to the thermal transport equation
!===============================================================================

if ((ityturt(iscal).eq.2.or.ityturt(iscal).eq.3)) then
  allocate(divut(ncelet))

  init = 1

  call divmas(init, thflxf, thflxb, divut)

  do iel = 1, ncel
    smbrs(iel) = smbrs(iel) - divut(iel)
  enddo

  ! Free memory
  deallocate(divut)

endif

! Free memory
deallocate(gradv)
deallocate(gradt)
deallocate(thflxf)
deallocate(thflxb)

!--------
! Formats
!--------

#if defined(_CS_LANG_FR)

 9999 format( &
'@'                                                            ,/,&
'@'                                                            ,/,&
'@'                                                            ,/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@'                                                            ,/,&
'@ @@ ATTENTION : ARRET A L''ENTREE DES DONNEES'               ,/,&
'@    ========='                                               ,/,&
'@    LES PARAMETRES DE CALCUL SONT INCOHERENTS OU INCOMPLETS' ,/,&
'@'                                                            ,/,&
'@  Le calcul ne sera pas execute'                             ,/,&
'@'                                                            ,/,&
'@  Le modele de flux thermique turbulent choisi        '      ,/,&
'@  necessite le calcul de la variance du scalaire thermique'  ,/,&
'@'                                                            ,/,&
'@  Verifier les donnees entrees dans l''interface'            ,/,&
'@    et dans les sous-programmes utilisateur.'                ,/,&
'@'                                                            ,/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@'                                                            ,/)

#else

 9999 format( &
'@'                                                            ,/,&
'@'                                                            ,/,&
'@'                                                            ,/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@'                                                            ,/,&
'@ @@ WARNING: ABORT IN THE DATA SPECIFICATION'                ,/,&
'@    ========'                                                ,/,&
'@    THE CALCULATION PARAMETERS ARE INCOHERENT OR INCOMPLET'  ,/,&
'@'                                                            ,/,&
'@  The calculation will not be run                  '         ,/,&
'@'                                                            ,/,&
'@  Turbulent heat flux model taken imposed that   '           ,/,&
'@  Thermal scalar variance has to be calculate.   '           ,/,&
'@'                                                            ,/,&
'@  Verify the provided data in the interface'                 ,/,&
'@    and in user subroutines.'                                ,/,&
'@'                                                            ,/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@'                                                            ,/)

#endif

end subroutine
