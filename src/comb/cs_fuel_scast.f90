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
!> \file cs_fuel_scast.f90
!> \brief Specific physic routine: fuel oil flame.
!>   We indicate the source terms for a scalar PP
!>   on a step time
!>
!>
!> \warning   The treatment of source terms is different from
!>            the treatment in ustssc.f
!>
!> we solve \f$ rovsdt D(var) = smbrs \f$
!>
!> \f$ rovsdt \f$ and \f$ smbrs \f$ already contain eventual user source term.
!>  So they have to be incremented and be erased
!>
!> For stability reasons, we only add in rovsdt positive terms.
!>  There is no stress for smbrs.
!>
!> In the case of a source term in \f$ cexp + cimp \varia \f$ we must
!> write:
!>        \f[ smbrs  = smbrs  + cexp + cimp\cdot \varia\f]
!>        \f[ rovsdt = rovsdt + Max(-cimp,0)\f]
!>
!> We provide here rovsdt and smbrs (they contain rho*volume)
!>    smbrs in \f$kg\cdot [variable] \cdot s^{-1}\f$:
!>     ex : for velocity               \f$kg\cdot m \cdot s^{-2}\f$
!>          for temperatures           \f$kg \cdot [degres] \cdot s^{-1}\f$
!>          for enthalpies             \f$J \cdot s^{-1} \f$
!>    rovsdt in \f$kg \cdot s^{-1}\f$
!-------------------------------------------------------------------------------

!-------------------------------------------------------------------------------
!            ARGUMENTS
!______________________________________________________________________________.
!  mode           name          role
!______________________________________________________________________________!
!> \param[in]     iscal         scalar number
!> \param[in]     propce        physical properties at cell centers
!> \param[in,out] smbrs         second explicit member
!> \param[in,out] rovsdt        implicit diagonal part
!______________________________________________________________________________!

subroutine cs_fuel_scast &
 ( iscal  ,                                                       &
   propce ,                                                       &
   smbrs  , rovsdt )
!===============================================================================
! Module files
!===============================================================================

use paramx
use numvar
use entsor
use optcal
use cstphy
use cstnum
use parall
use period
use ppppar
use ppthch
use coincl
use cpincl
use cs_fuel_incl
use ppincl
use ppcpfu
use mesh
use pointe
use field

!===============================================================================

implicit none

! Arguments

integer          iscal

double precision propce(ncelet,*)
double precision smbrs(ncelet), rovsdt(ncelet)

! Local variables

character(len=80) :: chaine
integer          ivar , iel, icla , numcla
integer          iexp1 , iexp2 , iexp3
integer          ipcro2 , ipcte1 , ipcte2
integer          ipcdia
integer          imode  , iesp
integer          ipcgev , ipcght , ipchgl
integer          itermx,nbpauv,nbrich,nbepau,nberic
integer          nbarre,nbimax,nbpass
integer          iterch

double precision aux, rhovst
double precision rom
double precision hfov
double precision ho2,hco,xesp(ngazem),t2mt1
double precision gmech,gmvap,gmhet
double precision xxco,xxo2,xxco2,xxh2o
double precision xkp,xkm,t0p,t0m
double precision aux1 , aux2 , aux3 , w1
double precision anmr,tauchi,tautur
double precision sqh2o , x2 , wmhcn , wmno ,wmo2
double precision err1mx,err2mx
double precision errch,fn,qpr
double precision auxmax,auxmin
double precision ymoy
double precision fn0,fn1,fn2,anmr0,anmr1,anmr2
double precision lnk0p,l10k0e,lnk0m,t0e,xco2eq,xcoeq,xo2eq
double precision xcom,xo2m,xkcequ,xkpequ,xden
double precision, dimension(:), pointer :: crom
double precision, dimension(:), pointer :: cvara_k, cvara_ep
double precision, dimension(:), pointer :: cvar_yfolcl, cvara_yfolcl
double precision, dimension(:), pointer :: cvara_yno, cvara_yhcn
double precision, dimension(:), pointer :: cvara_var
type(pmapper_double_r1), dimension(:), allocatable :: cvara_yfol

!===============================================================================
! 1. Initialization
!===============================================================================

! --- Number of the scalar to treat: iscal

! --- Number of the variable associated to the scalar to treat iscal
ivar = isca(iscal)
call field_get_val_prev_s(ivarfl(isca(iscal)), cvara_var)

! --- Name of the variable associated to scalar to treat iscal
call field_get_label(ivarfl(ivar), chaine)

! --- Number of the physic bulks (Cf cs_user_boundary_conditions)
call field_get_val_s(icrom, crom)

! --- Gas phase temperature

ipcte1 = ipproc(itemp1)

!===============================================================================
! 2. Taking into account the source terms for the relative particles
!    in the particles classes
!===============================================================================

! --> Source term for the liquid enthalpy

if ( ivar .ge. isca(ih2(1))     .and.                            &
     ivar .le. isca(ih2(nclafu))      ) then

  if (iwarni(ivar).ge.1) then
    write(nfecra,1000) chaine(1:8)
  endif

  numcla = ivar-isca(ih2(1))+1

  call field_get_val_prev_s(ivarfl(isca(iyfol(numcla))), cvara_yfolcl)
  ipcro2 = ipproc(irom2 (numcla))
  ipcdia = ipproc(idiam2(numcla))
  ipcte2 = ipproc(itemp2(numcla))
  ipcgev = ipproc(igmeva(numcla))
  ipcght = ipproc(igmhtf(numcla))
  ipchgl = ipproc(ih1hlf(numcla))

  !       The variable is the liquid enthalpy for the mixture mass
  !       The interfacial flux contribute to the variation of the liquid
  !       enthalpy
  !       The vapor takes away its enthalpy
  !       flux = propce(iel,ipproc(igmeva))
  !       massic enthalpy reconstructed from ehgaze(ifov )
  !       at the drop temperature
  !       The heterogeneous oxidation contains an input flux of O2
  !       an output flux of CO
  !       The net flux is the carbon flux
  !       fluxIN  = 16/12 * propce(iel,ipproc(igmhtf))
  !       fluxOUT = 28/12 * propce(iel,ipproc(igmhtf))
  !       Input enthalpy reconstructed from ehgaze(IO2 )
  !       at the surrounding gas temperature
  !       Output enthalpy reconstructed from ehgaze(ico )
  !       at the grain temperature

  imode = -1
  do iel = 1, ncel

    if ( cvara_yfolcl(iel) .gt. epsifl ) then

      rom = crom(iel)

      do iesp = 1, ngazem
        xesp(iesp) = zero
      enddo

      xesp(ifov) = 1.d0
      call cs_fuel_htconvers1(imode,hfov,xesp,propce(iel,ipcte2))

      xesp(ifov) = zero
      xesp(io2)  = 1.d0
      call cs_fuel_htconvers1(imode,ho2 ,xesp,propce(iel,ipcte1))

      xesp(io2)  = zero
      xesp(ico)  = 1.d0
      call cs_fuel_htconvers1(imode,hco,xesp,propce(iel,ipcte2))

      t2mt1 = propce(iel,ipcte2)-propce(iel,ipcte1)

      gmech = -propce(iel,ipchgl)*t2mt1
      gmvap = propce(iel,ipcgev)*hfov*t2mt1
      gmhet = 16.d0/12.d0*propce(iel,ipcght)*ho2                    &
             -28.d0/12.d0*propce(iel,ipcght)*hco

      smbrs(iel) = smbrs(iel) +                                     &
           ( gmech+gmvap+gmhet )*rom*volume(iel)
      rhovst = ( propce(iel,ipchgl)                                 &
                -propce(iel,ipcgev)*hfov )/cp2fol                   &
              *rom*volume(iel)
      rovsdt(iel) = rovsdt(iel) +  max(zero,rhovst)

    endif

  enddo

! --> Source terme for the liquid mass

elseif ( ivar .ge. isca(iyfol(1))     .and.                       &
         ivar .le. isca(iyfol(nclafu))        ) then

  if (iwarni(ivar).ge.1) then
    write(nfecra,1000) chaine(1:8)
  endif

  numcla = ivar-isca(iyfol(1))+1

  ipcro2 = ipproc(irom2 (numcla))
  ipcdia = ipproc(idiam2(numcla))
  ipcte2 = ipproc(itemp2(numcla))
  ipcgev = ipproc(igmeva(numcla))
  ipcght = ipproc(igmhtf(numcla))
  ipchgl = ipproc(ih1hlf(numcla))

  do iel = 1, ncel

    t2mt1 =  propce(iel,ipcte2)-propce(iel,ipcte1)
    gmvap = -propce(iel,ipcgev)*t2mt1
    gmhet = -propce(iel,ipcght)

    smbrs(iel) = smbrs(iel)                                       &
         - crom(iel)*volume(iel)*(gmvap+gmhet)
    if ( cvara_var(iel).gt.epsifl ) then
      rhovst = crom(iel)*volume(iel)*(gmvap + gmhet)              &
              / cvara_var(iel)
    else
      rhovst = 0.d0
    endif
    rovsdt(iel) = rovsdt(iel) + max(zero,rhovst)

  enddo

! --> Source term for the vopor tracer

elseif ( ivar .eq. isca(ifvap) ) then

  if (iwarni(ivar).ge.1) then
    write(nfecra,1000) chaine(1:8)
  endif

  do icla = 1, nclafu

    call field_get_val_s(ivarfl(isca(iyfol(icla))), cvar_yfolcl)
    call field_get_val_prev_s(ivarfl(isca(iyfol(icla))), cvara_yfolcl)
    ipcte2 = ipproc(itemp2(icla))
    ipcgev = ipproc(igmeva(icla))

    do iel = 1, ncel

      t2mt1 = propce(iel,ipcte2)-propce(iel,ipcte1)
      if ( cvara_yfolcl(iel) .gt. epsifl ) then
        gmvap = -propce(iel,ipcgev)*t2mt1*cvar_yfolcl(iel)        &
                / cvara_yfolcl(iel)
      else
        gmvap = -propce(iel,ipcgev)*t2mt1
      endif

      smbrs(iel) = smbrs(iel)                                     &
                 + gmvap*crom(iel)*volume(iel)
    enddo

  enddo

! --> Source term for the C tracer ex heterogeneous reaction

elseif ( ivar .eq. isca(if7m) ) then

  if (iwarni(ivar).ge.1) then
    write(nfecra,1000) chaine(1:8)
  endif

  do icla = 1, nclafu

    call field_get_val_s(ivarfl(isca(iyfol(icla))), cvar_yfolcl)
    call field_get_val_prev_s(ivarfl(isca(iyfol(icla))), cvara_yfolcl)
    ipcght = ipproc(igmhtf(icla))

    do iel = 1, ncel
      if (cvara_yfolcl(iel) .gt. epsifl) then
        smbrs(iel) = smbrs(iel)                                        &
             -crom(iel)*propce(iel,ipcght)*volume(iel)                 &
                                *cvar_yfolcl(iel)                      &
                                /cvara_yfolcl(iel)
      else
        smbrs(iel) = smbrs(iel)                                        &
                    -crom(iel)*propce(iel,ipcght)*volume(iel)
      endif

    enddo

  enddo

endif

! --> Source term for the variance of the tracer 4 (Air)

if ( ivar.eq.isca(ifvp2m) ) then

  if (iwarni(ivar).ge.1) then
    write(nfecra,1000) chaine(1:8)
  endif

  ! ---- Calculation of the source the explicit and implicit source terms
  !      relative to interfacial exchanges between phases

  call cs_fuel_fp2st &
 !==================
 ( iscal  ,                                                        &
   propce ,                                                        &
   smbrs  , rovsdt )

endif


! --> Source term for CO2

if ( ieqco2 .ge. 1 ) then

  if ( ivar.eq.isca(iyco2) ) then

    if (iwarni(ivar).ge.1) then
      write(nfecra,1000) chaine(1:8)
    endif

    call field_get_val_prev_s(ivarfl(ik), cvara_k)
    call field_get_val_prev_s(ivarfl(iep), cvara_ep)

    ! Arrays of pointers containing the fields values for each class
    ! (loop on cells outside loop on classes)
    allocate(cvara_yfol(nclafu))
    do icla = 1, nclafu
      call field_get_val_prev_s(ivarfl(isca(iyfol(icla))), cvara_yfol(icla)%p)
    enddo

    ! ---- Contribution of the interfacial source term to the explicit and implicit balances

    ! Oxidation of CO
    ! ===============

    !  Dryer Glassman : XK0P in (mol/m3)**(-0.75) s-1
    !          XK0P = 1.26D10
    !          XK0P = 1.26D7 * (1.1)**(NTCABS)
    !          IF ( XK0P .GT. 1.26D10 ) XK0P=1.26D10
    !          T0P  = 4807.D0
    !  Howard : XK0P en [(moles/m3)**(-0.75) s-1]
    !          XK0P = 4.11D9
    !          T0P  = 15090.D0
    !  Westbrook & Dryer

    lnk0p = 23.256d0
    t0p  = 20096.d0

    !  Hawkin et Smith Purdue University Engeneering Bulletin, i
    !  Research series 108 vol 33, n 3n 1949
    !  Kp = 10**(4.6-14833/T)
    !  Equilibrum constant in partial pressure [atm           !]
    !  XKOE is the decimal log of the pre-exponential constant
    !  TOE  is NOT an activation temperature  ... it remains a lg(e)
    !  to go back in Kc and to use concentrations [moles/m3]
    !  Kc = (1/RT)**variation nb moles * Kp
    !  here Kc = sqrt(0.082*T)*Kp

    l10k0e = 4.6d0
    t0e  = 14833.d0
    ! Dissociation of CO2 (Trinh Minh Chinh)
    ! ===================
    !          XK0M = 5.D8
    !          T0M  = 4807.D0
    !          XK0M = 0.D0
    !  Westbrook & Dryer

    lnk0m = 20.03d0
    t0m  = 20096.d0

    err1mx = 0.d0
    err2mx = 0.d0

    ! Number of iterations
    itermx = 500
   ! Number of convergent points

   nbpauv = 0
   nbepau = 0
   nbrich = 0
   nberic = 0
   nbpass = 0
   nbarre = 0
   nbimax = 0
   ! Precision for convergence
   errch = 1.d-8

   do iel = 1, ncel

     xxco  = propce(iel,ipproc(iym1(ico  )))/wmole(ico)           &
            *propce(iel,ipproc(irom1))
     xxo2  = propce(iel,ipproc(iym1(io2  )))/wmole(io2)           &
            *propce(iel,ipproc(irom1))
     xxco2 = propce(iel,ipproc(iym1(ico2 )))/wmole(ico2)          &
            *propce(iel,ipproc(irom1))
     xxh2o = propce(iel,ipproc(iym1(ih2o )))/wmole(ih2o)          &
            *propce(iel,ipproc(irom1))

     xxco  = max(xxco ,zero)
     xxo2  = max(xxo2 ,zero)
     xxco2 = max(xxco2,zero)
     xxh2o = max(xxh2o,zero)
     sqh2o = sqrt(xxh2o)

     xkp = exp(lnk0p-t0p/propce(iel,ipproc(itemp1)))
     xkm = exp(lnk0m-t0m/propce(iel,ipproc(itemp1)))

     xkpequ = 10.d0**(l10k0e-t0e/propce(iel,ipproc(itemp1)))
     xkcequ = xkpequ                                              &
             /sqrt(8.32d0*propce(iel,ipproc(itemp1))/1.015d5)

     !        initialization per transported state

     anmr  = xxco2
     xcom  = xxco + xxco2
     xo2m  = xxo2 + 0.5d0*xxco2

     if ( propce(iel,ipproc(itemp1)) .gt. 1200.d0 ) then

     !           Search for the equilibrum state
     !           Iterative search with convergence control
     !            (to preserve parallelism on the meshes)
     !            on the number of reaction mols which separate
     !            the state before reaction (as calculated by Cpcym)
     !            of the equilibrum state
     !           anmr must be confined between 0 and Min(xcom,2.*xo2m)
     !           We look for the solution by dichotomy

       anmr0 = 0.d0
       anmr1 = min(xcom,2.d0*xo2m)
       iterch = 0
       fn2    = 1.d0
       fn0  = -0.5d0                           * anmr0**3         &
            + (     xcom    + xo2m - xkcequ**2) * anmr0**2        &
            - (.5d0*xcom    +2.d0*xo2m)*xcom   * anmr0            &
            +       xcom**2 * xo2m
       fn1  = -0.5d0                           * anmr1**3         &
            + (     xcom    + xo2m - xkcequ**2) * anmr1**2        &
            - (.5d0*xcom    +2.d0*xo2m)*xcom   * anmr1            &
            +       xcom**2 * xo2m

       if ( xo2m.gt.1.d-6) then
         do while ( iterch.lt.itermx .and. fn2.gt.errch )
           anmr2 = 0.5d0*(anmr0+anmr1)
           fn2  = -0.5d0                            * anmr2**3    &
                + (     xcom    + xo2m - xkcequ**2) * anmr2**2    &
                - (.5d0*xcom    +2.d0*xo2m)*xcom    * anmr2       &
                +       xcom**2 * xo2m
           if(fn0*fn2 .gt. 0.d0) then
             anmr0 = anmr2
             fn0 = fn2
           elseif(fn1*fn2 .gt. 0.d0) then
             anmr1 = anmr2
             fn1 = fn2
           elseif(fn0*fn1 .gt. 0.d0) then
             iterch = itermx
             anmr2 = min(xcom,2.d0*xo2m)
             nbarre = nbarre + 1
           endif
           iterch = iterch + 1
         enddo

         if ( iterch .ge. itermx) then
           nberic = nberic + 1
         else
           nbimax = max(nbimax,iterch)
         endif
         err1mx = max(err1mx,fn2)

         xco2eq = anmr2
         xcoeq  = xcom - anmr2
         xo2eq  = xo2m - 0.5d0 * anmr2
       else
         xo2eq  = 0.d0
         xcoeq  = xxco
         xco2eq = 0.d0
       endif

     else

       xco2eq = min(xcom,2.d0*xo2m)
       xo2eq  = xo2m - 0.5d0*xco2eq
       xcoeq  = xcom - xco2eq

     endif

     if ( xco2eq.gt.xxco2 ) then
       !           oxidation
       xden = xkp*sqh2o*(xxo2)**0.25d0
     else
       !           dissociation
       xden = xkm
     endif
     if ( xden .ne. 0.d0 ) then

       tauchi = 1.d0/xden
       tautur = cvara_k(iel)/cvara_ep(iel)

       x2 = 0.d0
       do icla = 1, nclafu
         x2 = x2 + cvara_yfol(icla)%p(iel)
       enddo

       !    We transport CO2

       smbrs(iel)  = smbrs(iel)                                   &
                    +wmole(ico2)/propce(iel,ipproc(irom1))        &
         * (xco2eq-xxco2)/(tauchi+tautur)                         &
         * (1.d0-x2)                                              &
         * volume(iel) * crom(iel)

       w1 = volume(iel)*crom(iel)/(tauchi+tautur)
       rovsdt(iel) = rovsdt(iel) +   max(w1,zero)

     else
       rovsdt(iel) = rovsdt(iel) + 0.d0
       smbrs(iel)  = smbrs(iel)  + 0.d0
     endif

   enddo

   deallocate(cvara_yfol)

   if(irangp.ge.0) then
     call parcpt(nberic)
     call parmax(err1mx)
     call parcpt(nbpass)
     call parcpt(nbarre)
     call parcpt(nbarre)
     call parcmx(nbimax)
   endif

   write(nfecra,*) ' Max Error = ', err1mx
   write(nfecra,*) ' no Points   ', nberic, nbarre, nbpass
   write(nfecra,*) ' Iter max number ', nbimax


  endif

endif


! --> Source term for HCN and NO: only from the second
!                                   iteration

if ( ieqnox .eq. 1 .and. ntcabs .gt. 1) then

  if ( ivar.eq.isca(iyhcn) .or. ivar.eq.isca(iyno) ) then

    iexp1  = ipproc(ighcn1)
    iexp2  = ipproc(ighcn2)
    iexp3  = ipproc(ignoth)

    ! QPR= %N released during the evaporation/average volatile materials
    !          rate

    qpr = 1.3d0

    ! YMOY = % output vapor

    ymoy = 0.7d0

    ! Azote in the fuel oil

    fn = 0.015

    ! Molar mass
    wmhcn = wmole(ihcn)
    wmno  = 0.030d0
    wmo2  = wmole(io2)

    if ( ivar.eq.isca(iyhcn) ) then

      !        Source term HCN

      if (iwarni(ivar).ge.1) then
        write(nfecra,1000) chaine(1:8)
      endif

      call field_get_val_prev_s(ivarfl(isca(iyno)), cvara_yno)

      auxmin = 1.d+20
      auxmax =-1.d+20

      do iel=1,ncel

        xxo2 = propce(iel,ipproc(iym1(io2)))                       &
              *propce(iel,ipproc(immel))/wmo2

        aux = volume(iel)*crom(iel)                                &
             *( propce(iel,iexp2)                                  &
               +propce(iel,iexp1)*cvara_yno(iel)                   &
                                 *propce(iel,ipproc(immel))/wmno )

        smbrs(iel)  = smbrs(iel)  - aux*cvara_var(iel)
        rovsdt(iel) = rovsdt(iel) + aux

        gmvap = 0.d0
        gmhet = 0.d0
        do icla=1,nclafu

          ipcgev = ipproc(igmeva(icla))
          ipcght = ipproc(igmhtf(icla))
          ipcte2 = ipproc(itemp2(icla))
          ipcte1 = ipproc(itemp1)

          gmvap = gmvap                                           &
                 + crom(iel)*propce(iel,ipcgev)                   &
                  *(propce(iel,ipcte2)-propce(iel,ipcte1))

          gmhet = gmhet                                           &
                 +crom(iel)*propce(iel,ipcght)

        enddo
        if ( xxo2 .gt. 0.03d0 ) then
          aux = -volume(iel)*fn*wmhcn/(wmole(in2)/2.d0)           &
                *( qpr*gmvap+(1.d0-qpr*ymoy)/(1.d0-ymoy)*gmhet )
        else
          aux = -volume(iel)*fn*wmhcn/(wmole(in2)/2.d0)           &
                            *(qpr*gmvap)
        endif
        smbrs(iel)  = smbrs(iel) + aux

      enddo

    endif

    if ( ivar.eq.isca(iyno) ) then

      !        Source term NO

      if (iwarni(ivar).ge.1) then
        write(nfecra,1000) chaine(1:8)
      endif

      call field_get_val_prev_s(ivarfl(isca(iyhcn)), cvara_yhcn)

      do iel=1,ncel

        aux1 = volume(iel)*crom(iel)                     &
              *propce(iel,iexp1)*cvara_yhcn(iel)         &
              *propce(iel,ipproc(immel))/wmhcn
        aux2 = volume(iel)*crom(iel)                     &
              *propce(iel,iexp2)*cvara_yhcn(iel)         &
              *wmno/wmhcn
        aux3 = volume(iel)*crom(iel)**1.5d0              &
              *propce(iel,iexp3)                         &
              *propce(iel,ipproc(iym1(in2)))

        smbrs(iel)  = smbrs(iel) - aux1*cvara_var(iel)   &
                               + aux2 + aux3
        rovsdt(iel) = rovsdt(iel) + aux1
      enddo

    endif

  endif

endif

!--------
! Formats
!--------

 1000 format(' Specific physic source term for the variable '  &
       ,a8,/)

!----
! End
!----

return

end subroutine
