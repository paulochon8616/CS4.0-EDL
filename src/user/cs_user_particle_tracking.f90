!-------------------------------------------------------------------------------

!VERS

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

subroutine uslaed &
!================

 ( ntersl , nvlsta , nvisbr ,                                     &
   dt     ,                                                       &
   taup   , tlag   , tempct )

!===============================================================================
! Purpose :
! ----------

!   Subroutine of the Lagrangian particle-tracking module :
!   -------------------------------------

!     User subroutine (non-mandatory intervention)

!     Integration of the sde for the user-defined variables.
!     The variables are constant by default.


!                                         d T       T - PIP
!     The sde must be of the form:       ----- = - ---------
!                                         d t         Tca


!     T : IIIIeme user-defined variable, given for the ip particle by
!            T = EPTP(JVLS(IIII),IP)
!            T = EPTPA(JVLS(IIII),IP)

!     Tca : Characteristic time for the sde
!           to be prescribed in the array auxl1

!     PIP : Coefficient of the sde (pseudo right member)
!           to be prescribed in the array auxl2
!
!           If the chosen scheme is first order (nordre=1)
!           then, at the first and only passage pip is expressed
!           as a function of the quantities of the previous time step contained
!           in eptpa
!
!           If the chosen scheme is second order (nordre=2)
!           then, at the first passage (nor=1) pip is expressed as
!           a function of the quantities of the previous time step contained in eptpa,
!           and at the second passage (nor=2) pip is expressed as
!           a function of the quantities of the current time step contained in eptp

!-------------------------------------------------------------------------------
! Arguments
!__________________.____._____.________________________________________________.
! name             !type!mode ! role                                           !
!__________________!____!_____!________________________________________________!
! ntersl           ! i  ! <-- ! number of source terms of return coupling      !
! nvlsta           ! i  ! <-- ! nb of Lagrangian statistical variables         !
! nvisbr           ! i  ! <-- ! number of boundary statistics                  !
! dt(ncelet)       ! ra ! <-- ! time step (per cell)                           !
! taup(nbpart)     ! ra ! <-- ! particle relaxation time                       !
! tlag(nbpart)     ! ra ! <-- ! relaxation time for the flow                   !
! tempct           ! ra ! <-- ! characteristic thermal time and                !
!  (nbpart,2)      !    !     ! implicit source term of return coupling        !
!__________________!____!_____!________________________________________________!

!     Type: i (integer), r (real), s (string), a (array), l (logical),
!           and composite types (ex: ra real array)
!     mode: <-- input, --> output, <-> modifies data, --- work array

!===============================================================================

!===============================================================================
! Module files
!===============================================================================

use paramx
use numvar
use cstphy
use cstnum
use optcal
use entsor
use lagpar
use lagran
use mesh

!===============================================================================

implicit none

! Arguments

integer          ntersl , nvlsta , nvisbr

double precision dt(ncelet)
double precision taup(nbpart) , tlag(nbpart,3) , tempct(nbpart,2)

! Local variables

integer          npt , iel , iiii , ipl
double precision, allocatable, dimension(:) :: tcarac, pip

!===============================================================================


! TEST_TO_REMOVE_FOR_USE_OF_SUBROUTINE_START
!===============================================================================
! 0.  This test allows the user to ensure that the version of this subroutine
!       used is that from his case definition, and not that from the library.
!     If a file from the GUI is used, this subroutine may not be mandatory,
!       thus the default (library reference) version returns immediately.
!===============================================================================

! We enter this subroutine only if additional variables have been defined in
! uslag1; we must then necessarily define how they are solved.


if(1.eq.1) then
  write(nfecra,9000)
  call csexit (1)
endif

 9000 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ CAUTION: STOP IN THE LAGRANGIAN MODULE                  ',/,&
'@    =========                                               ',/,&
'@     THE USER SUBROUTINE uslaed MUST BE FILLED              ',/,&
'@                                                            ',/,&
'@  The calculation will not be run                           ',/,&
'@                                                            ',/,&
'@  Additional variables have been declared in                ',/,&
'@    uslag1 (NVLS=)                                          ',/,&
'@  The subroutine uslaed must be filled to precise           ',/, &
'@    the stochastic differential equation to be solved       ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)


! FIXME : TODO write a user example


! TEST_TO_REMOVE_FOR_USE_OF_SUBROUTINE_END

!===============================================================================
! 1.  Initializations
!===============================================================================

allocate (tcarac(nbpart), pip(nbpart))

!===============================================================================
! 2. Characteristic time of the current sde
!===============================================================================

! Loop on the additional variables

do iiii = 1,nvls

  ! Number of the treated variable in eptp

  ipl = jvls(iiii)

  do npt = 1,nbpart

    if ( ipepa(jisor,npt).gt.0 ) then

      iel = ipepa(jisor,npt)

!     Characteristic time tca of the differential equation
!     This example must be adapted to the case

      tcarac(npt) = 1.d0

!     Prediction at the first substep
!     This example must be adapted to the case

      if (nor.eq.1) then
        pip(npt) = eptpa(ipl,npt)
      else

!     Correction at the second substep
!     This example must be adapted to the case

        pip(npt) = eptp(ipl,npt)
      endif

    endif
  enddo

!===============================================================================
! 3. Integration of the variable ipl
!===============================================================================

  call lagitg                                                     &
  !==========
   ( ipl    ,                                                     &
     tcarac  , pip  )

enddo

!===============================================================================

deallocate (tcarac, pip)

!----
! End
!----

end subroutine uslaed


!===============================================================================


subroutine uslafe &
!================

 ( nvar   , nscal  ,                                              &
   ntersl , nvlsta , nvisbr ,                                     &
   dt     ,                                                       &
   statis , stativ ,                                              &
   taup   , tlag   , piil   ,                                     &
   tsuf   , tsup   , bx     , tsfext ,                            &
   vagaus , gradpr , gradvf ,                                     &
   romp   , fextla )

!===============================================================================
! Purpose:
! ----------

!   Subroutine of the Lagrangian particle-tracking module:
!   -------------------------------------

!    User subroutine (non-mandatory intervention)

!    Management of an external force field acting on the particles
!    It must be prescribed in every cell and be homogeneous to gravity (m/s^2)
!
!    By default gravity and drag force are the only forces acting on the particles
!    (the gravity components gx gy gz are assigned in the GUI or in usipsu)
!

!-------------------------------------------------------------------------------
! Arguments
!__________________.____._____.________________________________________________.
! name             !type!mode ! role                                           !
!__________________!____!_____!________________________________________________!
! nvar             ! i  ! <-- ! total number of variables                      !
! nscal            ! i  ! <-- ! total number of scalars                        !
! ntersl           ! i  ! <-- ! number of source terms of return coupling      !
! nvlsta           ! i  ! <-- ! nb of Lagrangian statistical variables         !
! nvisbr           ! i  ! <-- ! number of boundary statistics                  !
! dt(ncelet)       ! ra ! <-- ! time step (per cell)                           !
! statis           ! ra ! <-- ! cumul for the averages of the volume stats.    !
!  (ncelet,nvlsta) !    !     !                                                !
! stativ           ! ra ! <-- ! cumulation for the variance of the volume      !
!  (ncelet,        !    !     ! statistics                                     !
!   nvlsta-1)      !    !     !                                                !
! taup(nbpart)     ! ra ! <-- ! particle relaxation time                       !
! tlag(nbpart)     ! ra ! <-- ! relaxation time for the flow                   !
! piil(nbpart,3)   ! ra ! <-- ! term in the integration of the sde             !
! tsup(nbpart,3)   ! ra ! <-- ! prediction 1st substep for                     !
!                  !    !     ! the velocity of the particles                  !
! tsuf(nbpart,3)   ! ra ! <-- ! prediction 1st substep for                     !
!                  !    !     ! the velocity of the flow seen                  !
! bx(nbpart,3,2)   ! ra ! <-- ! characteristics of the turbulence              !
! tsfext(nbpart)   ! ra ! <-- ! infos for the return coupling                  !
! vagaus           ! ra ! <-- ! Gaussian random variables                      !
!  (nbpart,nvgaus) !    !     !                                                !
! gradpr(3,ncel)   ! ra ! <-- ! pressure gradient                              !
! gradvf(3,3,ncel) ! ra ! <-- ! gradient of the flow velocity                  !
! romp             ! ra ! --- ! particle density                               !
! fextla(ncelet,3) ! ra ! --> ! user external force field (m/s^2)              !
!__________________!____!_____!________________________________________________!

!     Type: i (integer), r (real), s (string), a (array), l (logical),
!           and composite types (ex: ra real array)
!     mode: <-- input, --> output, <-> modifies data, --- work array
!===============================================================================

!===============================================================================
! Module files
!===============================================================================

use paramx
use numvar
use cstnum
use cstphy
use optcal
use entsor
use lagpar
use lagran
use ppppar
use ppthch
use ppincl
use cpincl
use mesh

!===============================================================================

implicit none

! Arguments

integer          nvar   , nscal
integer          ntersl , nvlsta , nvisbr

double precision dt(ncelet)
double precision statis(ncelet,*),stativ(ncelet,*)
double precision taup(nbpart) , tlag(nbpart,3)
double precision piil(nbpart,3) , bx(nbpart,3,2)
double precision tsuf(nbpart,3) , tsup(nbpart,3)
double precision tsfext(nbpart)
double precision vagaus(nbpart,*)
double precision gradpr(3,ncelet) , gradvf(3,3,ncelet)
double precision romp(nbpart)
double precision fextla(nbpart,3)

! Local variables

integer          ip

!===============================================================================

! TEST_TO_REMOVE_FOR_USE_OF_SUBROUTINE_START
!===============================================================================

if(1.eq.1) return

!===============================================================================
! 0.  This test allows the user to ensure that the version of this subroutine
!       used is that from his case definition, and not that from the library.
!     If a file from the GUI is used, this subroutine may not be mandatory,
!       thus the default (library reference) version returns immediately.
!===============================================================================
!===============================================================================
! TEST_TO_REMOVE_FOR_USE_OF_SUBROUTINE_END

!===============================================================================
! 0. Memory management
!===============================================================================


!===============================================================================
! 1. Example
!===============================================================================

!   This example is unactivated

if (1.eq.0) then


  do ip = 1,nbpart

    fextla(ip,1) = 0.d0
    fextla(ip,2) = 0.d0
    fextla(ip,3) = 0.d0

  enddo


endif

!==============================================================================

!--------
! Formats
!--------


!----
! End
!----

end subroutine uslafe


!===============================================================================


subroutine uslain &
!================

 ( nvar   , nscal  ,                                              &
   ntersl , nvlsta , nvisbr ,                                     &
   nptnew , iprev  ,                                              &
   itypfb , itrifb , ifrlag , injfac ,                            &
   dt     ,                                                       &
   icocel , lndnod , itycel , dlgeo,                              &
   ncmax  , nzmax  , iusloc )

!===============================================================================
! Purpose:
! --------
!
! User subroutine of the Lagrangian particle-tracking module:
! -----------------------------------------
!
! User subroutine (non-mandatory intervention)

! User subroutine for the boundary conditions for the particles
! (inlet and treatment for the other boundaries)
!
! This routine is called after the initialization of the
! eptp, pepa and ipepa arrays for the new particles in order to modify them
! to inject new particle profiles.
!

!-------------------------------------------------------------------------------
! Arguments
!__________________.____._____.________________________________________________.
! name             !type!mode ! role                                           !
!__________________!____!_____!________________________________________________!
! nvar             ! i  ! <-- ! total number of variables                      !
! nscal            ! i  ! <-- ! total number of scalars                        !
! ntersl           ! i  ! <-- ! number of source terms of return coupling      !
! nvlsta           ! i  ! <-- ! nb of Lagrangian statistical variables         !
! nvisbr           ! i  ! <-- ! number of boundary statistics                  !
! nptnew           ! i  ! <-- ! total number of new particles for all the      !
!                  !    !     ! injection zones                                !
! iprev            ! i  ! <-- ! time step indicator for fields                 !
!                  !    !     !   0: use fields at current time step           !
!                  !    !     !   1: use fields at previous time step          !
! itrifb(nfabor)   ! ia ! <-- ! indirection for the sorting of the boundary    !
! itypfb(nfabor)   ! ia ! <-- ! type of the boundary faces                     !
! ifrlag(nfabor)   ! ia ! --> ! type of the Lagrangian boundary faces          !
! injfac(npbmax)   ! ia ! <-- ! number of the injection boundary face          !
! dt(ncelet)       ! ra ! <-- ! time step (per cell)                           !
! icocel           ! ia ! <-- ! connectivity cells -> faces                    !
!   (lndnod)       !    !     !    boundary cell if the number is negative     !
! lndnod           ! i  ! <-- ! dim. connectivity cells -> faces               !
!  itycel          ! ia ! <-- ! connectivity cells -> faces                    !
! (ncelet+1)       !    !     !    pointer of the icocel array                 !
!  dlgeo           ! ra ! <-- ! array of the geometrical quantities            !
!(nfabor,ngeol)    !    !     ! related to the boundary faces                  !
! ncmax            ! i  ! <-- ! number of class                                !
! nzmax            ! i  ! <-- ! number of zones                                !
! iusloc           ! ia ! <-- ! local equivalent of the iuslag array           !
!__________________!____!_____!________________________________________________!

!     Type: i (integer), r (real), s (string), a (array), l (logical),
!           and composite types (ex: ra real array)
!     mode: <-- input, --> output, <-> modifies data, --- work array

!===============================================================================

!===============================================================================
! Module files
!===============================================================================

use paramx
use numvar
use optcal
use cstnum
use cstphy
use entsor
use lagpar
use lagran
use ppppar
use ppthch
use cpincl
use mesh

!===============================================================================

implicit none

! Arguments

integer          nvar   , nscal
integer          ntersl , nvlsta , nvisbr
integer          nptnew
integer          iprev
integer          lndnod

integer          itypfb(nfabor) , itrifb(nfabor)
integer          ifrlag(nfabor)
integer          injfac(nbpart+nptnew)

double precision dt(ncelet)
integer          icocel(lndnod) ,  itycel(ncelet+1)
double precision dlgeo(nfabor,ngeol)

integer ncmax, nzmax
integer iusloc(ncmax, nzmax, ndlaim)

! Local variables

integer          iclas , izone , ifac
integer          ii , ip , npt , npar1 , npar2, ipnorm

! User-defined local variables
! (the dimension of vgauss is 3, but 2 would be sufficient here)

double precision vgauss(3)

!===============================================================================


! TEST_TO_REMOVE_FOR_USE_OF_SUBROUTINE_START
!===============================================================================

!     By default, we do not modify them

if(1.eq.1) return

!===============================================================================
! TEST_TO_REMOVE_FOR_USE_OF_SUBROUTINE_END

if (nbpnew.eq.0) return

!===============================================================================
! 1. Memory management
!===============================================================================


!===============================================================================
! 2. Initializations
!===============================================================================


!===============================================================================
! 3. Modification of properties of the new particles (injection profiles,
!    position of the injection point, statistical
!    weights, correction of the diameter if the standard-deviation option
!    is activated.)
!===============================================================================

!    These modifications occur after all the initializations related to
!    the particle injection, but before the treatment of the continuous
!    injection: it is thus possible to impose an injection profile with
!    the continous-injection option.
!
if (.false.) then

  ! reinitialization of the counter of the new particles
  npt = nbpart

  ! for each boundary zone:
  do ii = 1,nfrlag
    izone = ilflag(ii)

    ! for each class:
    do iclas = 1, iusncl(izone)

      ! if new particles must enter the domain:
      if (mod(ntcabs,iusloc(iclas,izone,ijfre)).eq.0) then

        do ip = npt+1 , npt+iusloc(iclas,izone,ijnbp)

          ! number of the original boundary face of injection

          ifac = injfac(ip)

!-----------------------------------------------------------
!        EXAMPLE OF MODIFICATION OF THE INJECTION VELOCITY
!        WITH RESPECT TO THE INJECTION POSITION
!-----------------------------------------------------------
!    For instance, the user can call his own subroutine that provides
!    the three components of the instantaneous velocities eptp(jup,ip)
!    eptp(jvp,ip) and  eptp(jwp,ip) with respect to  eptp(jzp,ip)
!    (through interpolation for instance). More simply, the user can provide
!    the three components of the instantaneous velocities, under the form
!    of a mean value (taken arbitrarily here equal to (2,0,0) m/s) added
!    to a fluctuating value (equal here to 0,2 m/s for the 1st and 3rd components)

          ipnorm = 2
          call normalen(ipnorm,vgauss)
          eptp(jup,ip) = 2.d0 + vgauss(1) * 0.2d0
          eptp(jvp,ip) = 0.d0
          eptp(jwp,ip) = 0.d0 + vgauss(2) * 0.2d0

        enddo

        npt = npt + iusloc(iclas,izone,ijnbp)

      endif

    enddo
  enddo

endif

!===============================================================================
! 4. SIMULATION OF THE INSTANTANEOUS TURBULENT FLUID FLOW VELOCITIES SEEN
!    BY THE SOLID PARTICLES ALONG THEIR TRAJECTORIES.
!===============================================================================
!
! Entering this subroutine, the eptp(juf,ip) eptp(jvf,ip) and eptp(jwf,ip) arrays
! are filled with the components of the instantaneous velocity (fluctuation + mean value)
! seen by the particles
!
! When the velocity of the flow is modified just above, most of the time
! the user knows only the mean value. In some flow configurations and some
! injection conditions, it may be necessary to reconstruct the fluctuating part.
! That is why the following routine is called.
!
! Caution: this turbulent component must be reconstructed only on the modified
! velocities of the flow seen.
!
! The reconstruction is unactivated here and must be adapted to the case.
!

if (.false.) then

  npar1 = nbpart+1
  npar2 = nbpart+nbpnew

  call lagipn(npar1, npar2, iprev)
  !==========

endif

!===============================================================================

!--------
! Formats
!--------

!----
! End
!----

return

end subroutine uslain


!===============================================================================


subroutine uslapr &
!================

 ( idvar  , iepart , ifpart , izone  , iclass ,                   &
   nvar   , nscal  ,                                              &
   ntersl , nvlsta , nvisbr ,                                     &
   itypfb , itrifb , ifrlag ,                                     &
   xxpart , yypart , zzpart ,                                     &
   swpart , uupart , vvpart , wwpart , ddpart , ttpart  ,         &
   dt     )

!===============================================================================
! Purpose:
! ----------

!   Subroutine of the Lagrangian particle-tracking module:
!   -------------------------------------

!   User subroutine for the boundary conditions associated to
!   the particles (inlet and treatment of the other boundaries)
!
!   It allows to impose the values of the velocity, the diameter,
!   the temperature, and the statistical weight for the treated particle.
!
!   if idvar = 1 ==> the 3 components of the velocity are retrieved
!   if idvar = 2 ==> the diameter is retrieved
!   if idvar = 3 ==> the temperature is retrieved
!   if idvar = 4 ==> the statistical weight is retrieved

!-------------------------------------------------------------------------------
! Arguments
!__________________.____._____.________________________________________________.
! name             !type!mode ! role                                           !
!__________________!____!_____!________________________________________________!
! idvar            ! i  ! <-- ! type of the value(s) ta calculate              !
! iepart           ! i  ! <-- ! number of the particle cell                    !
! ifpart           ! i  ! <-- ! number of the particle inlet boundary face     !
! izone            ! i  ! <-- ! number of the particle zone                    !
! iclass           ! i  ! <-- ! number of the particle class                   !
! nvar             ! i  ! <-- ! total number of variables                      !
! nscal            ! i  ! <-- ! total number of scalars                        !
! ntersl           ! i  ! <-- ! number of source terms of return coupling      !
! nvlsta           ! i  ! <-- ! nb of Lagrangian statistical variables         !
! nvisbr           ! i  ! <-- ! number of boundary statistics                  !
! itrifb(nfabor)   ! ia ! <-- ! indirection for the sorting of the             !
! itypfb(nfabor)   ! ia ! <-- ! type of the boundary faces                     !
! ifrlag(nfabor)   ! ia ! --> ! type of the Lagrangian boundary faces          !
! xxpart           !  r ! <-- ! x-coordinate of the particle                   !
! yypart           !  r ! <-- ! y-coordinate of the particle                   !
! zzpart           !  r ! <-- ! z-coordinate of the particle                   !
! swpart           !  r ! <-- ! value of the statistical weight                !
! uupart           !  r ! <-- ! x-component of particle velocity               !
! vvpart           !  r ! <-- ! y-component of particle velocity               !
! wwpart           !  r ! <-- ! z-component of particle velocity               !
! ddpart           !  r ! <-- ! particle diameter                              !
! ttpart           !  r ! <-- ! particle temperature                           !
! dt(ncelet)       ! ra ! <-- ! time step (per cell)                           !
!__________________!____!_____!________________________________________________!

!     Type: i (integer), r (real), s (string), a (array), l (logical),
!           and composite types (ex: ra real array)
!     mode: <-- input, --> output, <-> modifies data, --- work array

!===============================================================================

!===============================================================================
! Module files
!===============================================================================

use paramx
use numvar
use optcal
use cstnum
use cstphy
use entsor
use lagpar
use lagran
use ppppar
use ppthch
use cpincl
use mesh

!===============================================================================

implicit none

! Arguments


integer          idvar  , iepart , ifpart , izone  , iclass

integer          nvar   , nscal
integer          ntersl , nvlsta , nvisbr

integer          itypfb(nfabor) , itrifb(nfabor)
integer          ifrlag(nfabor)

double precision xxpart , yypart , zzpart
double precision swpart , uupart , vvpart , wwpart
double precision ddpart , ttpart

double precision dt(ncelet)

! Local variables

double precision pis6

!===============================================================================

! TEST_TO_REMOVE_FOR_USE_OF_SUBROUTINE_START

!===============================================================================
! 0.  This test allows the user to ensure that the version of this subroutine
!       used is that from his case definition, and not that from the library.
!     If a file from the GUI is used, this subroutine may not be mandatory,
!       thus the default (library reference) version returns immediately.
!===============================================================================

if(1.eq.1) then
  write(nfecra,9000)
  call csexit (1)
  !==========
endif

 9000 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET LORS DE L''ENTREE DES COND. LIM.      ',/,&
'@    =========                                               ',/,&
'@     MODULE LAGRANGIEN :                                    ',/,&
'@     LE SOUS-PROGRAMME UTILISATEUR uslapr DOIT ETRE COMPLETE',/,&
'@                                                            ',/,&
'@  Le calcul ne sera pas execute.                            ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

! TEST_TO_REMOVE_FOR_USE_OF_SUBROUTINE_END

!===============================================================================
! Initialization
!===============================================================================

pis6 = pi / 6.d0

!===============================================================================
! Velocity profile
!===============================================================================

if (idvar .eq. 1) then

  uupart = 1.d0
  vvpart = 0.d0
  wwpart = 0.d0

endif

!===============================================================================
! Diameter profile
!===============================================================================

if (idvar .eq. 2) then

  ddpart = 50.d-6

endif

!===============================================================================
! Temperature profile
!===============================================================================

if (idvar .eq. 3) then

  ttpart = 20.d0

endif

!===============================================================================
! Statistical weight profile
!===============================================================================

if (idvar .eq. 4) then

  swpart = 0.01

endif

!===============================================================================

!--------
! Formats
!--------

!----
! End
!----

return

end subroutine uslapr


!===============================================================================


subroutine uslaru &
!================

 ( nvar   , nscal  ,                                              &
   ntersl , nvlsta , nvisbr ,                                     &
   itypfb , itrifb ,                                              &
   dt     ,                                                       &
   croule ,                                                       &
   distpa , distyp )

!===============================================================================
! Purpose:
! --------
!
! User subroutine of the Lagrangian particle-tracking module:
! -----------------------------------------
!
! User subroutine (non-mandatory intervention)

! Calculation of the function of significance for the Russian roulette


!-------------------------------------------------------------------------------
! Arguments
!__________________.____._____.________________________________________________.
! name             !type!mode ! role                                           !
!__________________!____!_____!________________________________________________!
! nvar             ! i  ! <-- ! total number of variables                      !
! nscal            ! i  ! <-- ! total number of scalars                        !
! ntersl           ! i  ! <-- ! number of source terms of return coupling      !
! nvlsta           ! i  ! <-- ! nb of Lagrangian statistical variables         !
! nvisbr           ! i  ! <-- ! number of boundary statistics                  !
! itypfb(nfabor)   ! ia ! <-- ! type of the boundary faces                     !
! itrifb(nfabor)   ! ia ! --> ! indirection for the sorting of the             !
! dt(ncelet)       ! ra ! <-- ! time step (per cell)                           !
! croule(ncelet    ! ra ! --> ! function of significance for                   !
!                  !    !     ! the Russian roulette                           !
! distpa(ncelet    ! ra ! <-- ! wall-normal distance arrays                    !
! disty(ncelet)    ! ra ! <-- ! y+ distance                                    !
!__________________!____!_____!________________________________________________!

!     Type: i (integer), r (real), s (string), a (array), l (logical),
!           and composite types (ex: ra real array)
!     mode: <-- input, --> output, <-> modifies data, --- work array

!===============================================================================

!===============================================================================
! Module files
!===============================================================================

use paramx
use numvar
use optcal
use entsor
use cstphy
use parall
use period
use lagpar
use lagran
use mesh

!===============================================================================

implicit none

! Arguments

integer          nvar   , nscal
integer          ntersl , nvlsta , nvisbr

integer          itypfb(nfabor) , itrifb(nfabor)

double precision dt(ncelet)
double precision croule(ncelet)
double precision distpa(ncelet) , distyp(ncelet)

! Local variables

integer          iel
double precision zref

!===============================================================================

!===============================================================================
! 1. Default initialization
!---------------------------

!     Caution : the croule parameter is only initialized in this subroutine.
!               Make sure that it is prescribed for every cell.

!===============================================================================

do iel = 1,ncel
  croule(iel) = 1.d0
enddo

! TEST_TO_REMOVE_FOR_USE_OF_SUBROUTINE_START
!===============================================================================
! -1.  If the user does not intervene, croule = 1 everywhere
!===============================================================================

if(1.eq.1) then
  return
endif

! TEST_TO_REMOVE_FOR_USE_OF_SUBROUTINE_END

!===============================================================================
! 2. Calculation of a user-defined function of significance
!===============================================================================

!   CAUTION:   the croule array must be filled with positive
!   ^^^^^^^^^  real numbers enabling to weight the importance
!              of some zones with respect to others.
!
!              (the greater croule, the more important the zone)

!              For instance, we can decide that the zone is as important
!              as it is close to a position z=zref; with an importance equal
!              to 1.e-3 near zref, and with an importance equal to 1.e-6
!              far from zref.


zref = 0

do iel = 1,ncel
  croule(iel) = 1.d0/(max( abs(xyzcen(3,iel)-zref),1.d-3 ))
enddo

do iel = 1,ncel
  croule(iel) = max(croule(iel),1.d-6 )
enddo

!===============================================================================

!----
! End
!----

end subroutine uslaru


!===============================================================================


subroutine uslast &
!================

 ( nvar   , nscal  ,                                              &
   ntersl , nvlsta , nvisbr ,                                     &
   dt     )

!===============================================================================
! Purpose:
! --------
!
! User subroutine of the Lagrangian particle-tracking module:
! -----------------------------------------
!
! User subroutine (non-mandatory intervention)

! User-defined modifications on the variables at the end of the
! Lagrangian iteration and calculation of user-defined
! additional statistics on the particles.
!
! About the user-defined additional statistics, we recall that:
!

!   isttio = 0 : unsteady Lagrangian calculation
!          = 1 : steady Lagrangian calculation

!   istala : calculation of the statistics if >= 1, else no stats

!   isuist : Restart of statistics calculation if >= 1, else no stats

!   idstnt : Number of the time step for the start of the statistics calculation

!   nstist : Number of the Lagrangian iteration of the start of the steady computation

!   npst   : Number of iterations of the computation of the steady statistics

!   npstt  : Total number of iterations of the statistics calculation since the
!            beginning of the calculation, including the unsteady part

!   tstat  : Physical time of the recording of the steady volume statistics
!            (for the unsteady part, tstat = dtp the Lagrangian time step)
!

!-------------------------------------------------------------------------------
! Arguments
!__________________.____._____.________________________________________________.
! name             !type!mode ! role                                           !
!__________________!____!_____!________________________________________________!
! nvar             ! i  ! <-- ! total number of variables                      !
! nscal            ! i  ! <-- ! total number of scalars                        !
! ntersl           ! i  ! <-- ! number of source terms of return coupling      !
! nvlsta           ! i  ! <-- ! nb of Lagrangian statistical variables         !
! nvisbr           ! i  ! <-- ! number of boundary statistics                  !
! dt(ncelet)       ! ra ! <-- ! time step (per cell)                           !
!__________________!____!_____!________________________________________________!

!     Type: i (integer), r (real), s (string), a (array), l (logical),
!           and composite types (ex: ra real array)
!     mode: <-- input, --> output, <-> modifies data, --- work array
!===============================================================================

!===============================================================================
! Module files
!===============================================================================

use paramx
use numvar
use cstnum
use optcal
use pointe
use entsor
use lagpar
use lagran
use cstphy
use ppppar
use ppthch
use cpincl
use mesh

!===============================================================================

implicit none

! Arguments

integer          nvar   , nscal
integer          ntersl , nvlsta , nvisbr

double precision dt(ncelet)

! Local variables

integer          npt ,  iel

integer          ivf , ivff , iflu , icla

! User-defined local variables

integer          nxlist
parameter       (nxlist=100)

integer          iplan
integer          ii, ind, il
integer          inoeud, irang0, indic
integer          ist(6)

integer, allocatable, dimension(:) :: node_mask

double precision zz(4), zzz(8), xlist(nxlist,8), xyzpt(3)

double precision, allocatable, dimension(:) :: tabvr

character        name(8)*4

double precision debm(4)
save             debm

!===============================================================================


! TEST_TO_REMOVE_FOR_USE_OF_SUBROUTINE_START

if(istala.eq.1 .and. iplas.ge.idstnt .and. nvlsts.gt.0) then

!
! if needed, the user must fill and adapt the following example
!

  if(1.eq.1) then
    write(nfecra,9000)nvlsts
    call csexit (1)
  endif

 9000 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ CAUTION: STOP IN THE LAGRANGIAN MODULE                  ',/,&
'@    =========                                               ',/,&
'@    THE USER SUBROUTINER uslast MUST BE MODIFIED            ',/,&
'@                                                            ',/,&
'@  The calculation will not be run                           ',/,&
'@                                                            ',/,&
'@  Additional statistics variables have been asked           ',/,&
'@   in uslag1 (nvlsts =',   I10,')                           ',/,&
'@  The subroutine uslast must be adapted to                  ',/, &
'@  precise the computation of their cumulation.              ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

else

! During a Lagrangian calculation, we always enter this subroutine
! if we wish to do nothing, we exit immediately
!
  return

endif

! TEST_TO_REMOVE_FOR_USE_OF_SUBROUTINE_END


!===============================================================================
! 0.  Memory management
!===============================================================================


!===============================================================================
! 1. Initialization
!===============================================================================

!===============================================================================
! 2 - Computation of user-defined particle statistics
!===============================================================================

!   From a general point of view, we carry out in this subroutine the cumulations of
!   the variables about which we wish to perform statistics. The mean and the
!   variance are calculated in the routine uslaen. This computation is most often
!   carried out by dividing the cumulations by either the steady cumulation time
!   in the variable tstat, either by the number of particles in statistical weight.
!   This division is applied in each writing in the listing and in
!   the post-processing files.

if (.false.) then

 if(istala.eq.1 .and. iplas.ge.idstnt .and. nvlsts.gt.0) then

  do npt = 1,nbpart

    if( ipepa(jisor,npt).gt.0 ) then

      iel = ipepa(jisor,npt)

! -------------------------------------------------
! EXAMPLE 1: Cumulation for mass concentration
! -------------------------------------------------

      statis(iel,ilvu(1)) = statis(iel,ilvu(1))                   &
        + pepa(jrpoi,npt) *eptp(jmp,npt)

      stativ(iel,ilvu(1)) = stativ(iel,ilvu(1))                   &
        + pepa(jrpoi,npt) *eptp(jmp,npt) *eptp(jmp,npt)

    endif

  enddo

 endif

endif

!===============================================================================
! 3 - User-defined computation of the particle mass flow rate on 4 plans
!===============================================================================

!  This example is unactivated and must be adapted to the case

if (.false.) then

  zz(1) = 0.1d0
  zz(2) = 0.15d0
  zz(3) = 0.20d0
  zz(4) = 0.25d0

! If we are in an unsteady case, or if the beginning of the steady stats
! is not reached yet, all statistics are reset to zero at each time step before entering
! this subroutine.

  if(isttio.eq.0 .or. npstt.le.nstist) then
    do iplan = 1,4
      debm(iplan) = 0.d0
    enddo
  endif

  do iplan = 1,4

    do npt = 1,nbpart

      if(ipepa(jisor,npt).gt.0) then

        iel = ipepa(jisor,npt)

        if( eptp(jxp,npt).gt.zz(iplan) .and.                      &
            eptpa(jxp,npt).le.zz(iplan)      ) then
          debm(iplan) = debm(iplan) +pepa(jrpoi,npt)*eptp(jmp,npt)
        endif

      endif

    enddo
  enddo

  do iplan = 1,4
    write(nfecra,1001)iplan,debm(iplan)/tstat
  enddo

 1001   format(' Debit massique particulaire en Z(',I10,') : ',E14.5)

endif


!===============================================================================
! 4 - Extraction of volume statistics at the end of the calculation
!===============================================================================

!  This example is unactivated and must be adapted to the case

if (.false.) then

  if(ntcabs.eq.ntmabs) then

    zzz(1) = 0.005d0
    zzz(2) = 0.025d0
    zzz(3) = 0.050d0
    zzz(4) = 0.075d0
    zzz(5) = 0.100d0
    zzz(6) = 0.150d0
    zzz(7) = 0.200d0
    zzz(8) = 0.250d0

    NAME(1) = 'XB01'
    NAME(2) = 'XB05'
    NAME(3) = 'XB10'
    NAME(4) = 'XB15'
    NAME(5) = 'XB20'
    NAME(6) = 'XB30'
    NAME(7) = 'XB40'
    NAME(8) = 'XB50'

    ist(1) = ilvx
    ist(2) = ilvz
    ist(3) = ilfv
    ist(4) = ilpd

    npts = nxlist

    ! Allocate work arrays
    allocate(tabvr(ncelet))
    allocate(node_mask(nnod))
    node_mask(:) = 0

    do iplan = 1,8

      !  Concerning the following file:
      !  the user will check if he has not let the unit
      !  impusr(1) opened in another user subroutine.

      open(file=name(iplan),unit=impusr(1),form='formatted')

      xyzpt(1) = zzz(iplan)

      do ivf = 1,4

        ivff = ist(ivf)
        icla = 0
        iflu = 0

        call uslaen(nvlsta, ivff, ivff, ivff, iflu, ilpd, icla, tabvr)
        !==========

        ind = 0
        do ii = 1, npts

          xyzpt(2) = 0.d0
          xyzpt(3) = float(ii-1)/float(npts-1)*150.d-3

          call findpt                                             &
          !==========
          (ncelet, ncel, xyzcen,                                  &
           xyzpt(1), xyzpt(2), xyzpt(3), inoeud, irang0)

          indic = node_mask(inoeud)
          node_mask(inoeud) = 1
          if (indic.eq.1) then
            ind = ind +1
            xlist(ind,1) = xyzcen(1,inoeud)
            xlist(ind,2) = xyzcen(3,inoeud) * (1.d3 / 5.d0)
            xlist(ind,ivf+2) = tabvr(inoeud)
          endif
        enddo
      enddo

      do il = 1, ind
        WRITE (IMPUSR(1),'(8E13.5)') (XLIST(IL,II), II=1,6)
      enddo

      close(impusr(1))

    enddo

    ! Free memory
    deallocate(node_mask)
    deallocate(tabvr)

  endif

endif

!===============================================================================

!====
! End
!====

return

end subroutine uslast

!===============================================================================


subroutine uslatc &
!================

 ( nvar   , nscal  ,                                              &
   numpt  ,                                                       &
   rep    , uvwr   , romf   , romp   , xnul   ,                   &
   xcp    , xrkl   , tauc   ,                                     &
   dt     )

!===============================================================================
! Purpose:
! --------
!
! User subroutine of the Lagrangian particle-tracking module:
! -----------------------------------------
!
! User subroutine (non-mandatory intervention)
!
! Modification of the computation of the thermal relaxation time
! of the particles with respect to the chosen formulation of the
! Nusselt number.

! This subroutine being called in a loop on the particle number,
! be careful not to "load" it to heavily..
!
!

!               m   Cp
!                p    p
!      Tau = ---------------
!         c          2
!               PI d    h
!                   p    e

!     Tau  : Thermal relaxation time (value to be computed)
!        c

!     m    : Particle mass
!      p

!     Cp   : Particle specific heat
!       p

!     d    : Particle diameter
!      p

!     h    : Coefficient of thermal exchange
!      e

!  The coefficient of thermal exchange is calculated from a Nusselt number,
!  itself evaluated by a correlation (Ranz-Marshall by default)
!
!

!            h  d
!             e  p
!     Nu = --------  = 2 + 0.55 Re **(0.5) Prt**(0.33)
!           Lambda                p

!     Lambda : Thermal conductivity of the carrier field

!     Re     : Particle Reynolds number
!       p

!     Prt    : Prandtl number

!

!-------------------------------------------------------------------------------
! Arguments
!__________________.____._____.________________________________________________.
! name             !type!mode ! role                                           !
!__________________!____!_____!________________________________________________!
! nvar             ! i  ! <-- ! total number of variables                      !
! nscal            ! i  ! <-- ! total number of scalars                        !
! numpt            ! i  ! <-- !                                                !
! rep              ! r  ! <-- ! particle Reynolds number                       !
!                  !    !     ! rep = uvwr * eptp(jdp,numpt) / xnul            !
! uvwr             ! r  ! <-- ! relative velocity of the particle              !
!                  !    !     ! uvwr = |flow-seen velocity - part. velocity |  !
! romf             ! r  ! <-- ! fluid density at  particle position            !
!                  !    !     !                                                !
! romp             ! r  ! <-- ! particle density                               !
! xnul             ! r  ! <-- ! kinematic viscosity of the fluid at            !
!                  !    !     ! particle position                              !
! xcp              ! r  ! <-- ! specific heat of the fluid at particle         !
!                  !    !     ! position                                       !
! xrkl             ! r  ! <-- ! diffusion coefficient of the fluid at particle !
!                  !    !     ! position                                       !
! tauc             ! r  ! --> ! thermal relaxation time                        !
! dt(ncelet)       ! ra ! <-- ! time step (per cell)                           !
!__________________!____!_____!________________________________________________!

!     Type: i (integer), r (real), s (string), a (array), l (logical),
!           and composite types (ex: ra real array)
!     mode: <-- input, --> output, <-> modifies data, --- work array

!===============================================================================

!===============================================================================
! Module files
!===============================================================================

use paramx
use numvar
use cstnum
use cstphy
use optcal
use entsor
use lagpar
use lagran
use ppppar
use ppthch
use ppincl
use cpincl
use mesh

!===============================================================================

implicit none

! Arguments

integer          nvar   , nscal
integer          numpt

double precision rep    , uvwr   , romf   , romp   , xnul
double precision xcp    , xrkl   , tauc

double precision dt(ncelet)

! Local variables

integer          ip

! User-defined local variables

double precision prt, fnus

!===============================================================================

! TEST_TO_REMOVE_FOR_USE_OF_SUBROUTINE_START
!===============================================================================

if(1.eq.1) return

!===============================================================================
! TEST_TO_REMOVE_FOR_USE_OF_SUBROUTINE_END

!===============================================================================
! 0. Memory management
!===============================================================================


!===============================================================================
! 1. Initializations
!===============================================================================

ip = numpt

!===============================================================================
! 2. Standard thermal relaxation time
!===============================================================================

!   This example is unactivated, it gives the standard thermal relaxation time
!   as an indication.


if (.false.) then

  prt  = xnul / xrkl

  fnus = 2.d0 + 0.55d0 * rep**0.5d0 * prt**(1.d0/3.d0)

  tauc = eptp(jdp,ip) *eptp(jdp,ip) * romp * eptp(jcp,ip)         &
           / ( fnus * 6.d0 * romf * xcp * xrkl )

endif

!==============================================================================

!--------
! Formats
!--------


!----
! End
!----

end subroutine uslatc


!===============================================================================


subroutine uslatp &
!================

 ( nvar   , nscal  ,                                              &
   numpt  ,                                                       &
   rep    , uvwr   , romf   , romp   , xnul   , taup   ,          &
   dt     )

!===============================================================================
! Purpose:
! --------
!
! User subroutine of the Lagrangian particle-tracking module:
! -----------------------------------------
!
! User subroutine (non-mandatory intervention)
!
! Modification of the calculation of the particle relaxation time
! with respect to the chosen formulation for the drag coefficient

! This subroutine being called in a loop on the particle number,
! be careful not to "load" it too heavily..
!
!            rho             4 d
!               p               p
!      Tau = ---- --------------------------------
!         p
!            rho   3 C     | U [X (t),t] - V (t) |
!               f     drag    f  p          p

!     Tau  : Particle relaxation time
!        p

!     rho  : Particle density
!        p

!     rho  : Fluid density
!        f

!     C    : Drag coefficient
!      drag

!     d    : Particle diameter
!      p

!     U [X (t),t] : Instantaneous velocity of the flow seen
!      f  p

!     V (t) : Particle velocity
!      p

!
!

!-------------------------------------------------------------------------------
! Arguments
!__________________.____._____.________________________________________________.
! name             !type!mode ! role                                           !
!__________________!____!_____!________________________________________________!
! nvar             ! i  ! <-- ! total number of variables                      !
! nscal            ! i  ! <-- ! total number of scalars                        !
! numpt            ! i  ! <-- !                                                !
! rep              ! r  ! <-- ! particle Reynolds number                       !
!                  !    !     ! rep = uvwr * eptp(jdp,numpt) / xnul            !
! uvwr             ! r  ! <-- ! particle relative velocity                     !
!                  !    !     ! uvwr= |flow-seen velocity - part. velocity|    !
! romf             ! r  ! <-- ! fluid density at  particle position            !
!                  !    !     !                                                !
! romp             ! r  ! <-- ! particle density                               !
! xnul             ! r  ! <-- ! kinematic viscosity of the fluid at            !
!                  !    !     ! particle position                              !
! taup             ! r  ! --> ! particle relaxation time                       !
! dt(ncelet)       ! ra ! <-- ! time step (per cell)                           !
!__________________!____!_____!________________________________________________!

!     Type: i (integer), r (real), s (string), a (array), l (logical),
!           and composite types (ex: ra real array)
!     mode: <-- input, --> output, <-> modifies data, --- work array

!===============================================================================

!===============================================================================
! Module files
!===============================================================================

use paramx
use numvar
use cstnum
use cstphy
use optcal
use entsor
use lagpar
use lagran
use ppppar
use ppthch
use ppincl
use cpincl
use mesh

!===============================================================================

implicit none

! Arguments

integer          nvar   , nscal
integer          numpt

double precision rep    , uvwr   , romf   , romp   , xnul  , taup

double precision dt(ncelet)

! Local variables

integer          ip
double precision fdr

! User-defined local variables

double precision cd1 , cd2 , dd2
double precision rec1, rec2, rec3, rec4

!===============================================================================

! TEST_TO_REMOVE_FOR_USE_OF_SUBROUTINE_START
!===============================================================================

if(1.eq.1) return

!===============================================================================
! TEST_TO_REMOVE_FOR_USE_OF_SUBROUTINE_END

!===============================================================================
! 0.  Memory management
!===============================================================================


!===============================================================================
! 1. Initializations
!===============================================================================

ip = numpt

!===============================================================================
! 2. Relaxation time with the standard (Wen-Yu) formulation of the drag coefficient
!===============================================================================

! This example is unactivated, it gives the standard relaxation time
! as an indication:

if (.false.) then

  cd1  = 0.15d0
  cd2  = 0.687d0

  if (rep.le.1000) then
      dd2 = eptp(jdp,ip) * eptp(jdp,ip)
      fdr = 18.d0 * xnul * (1.d0 + cd1 * rep**cd2) / dd2
  else
      fdr = (0.44d0 * 3.d0 / 4.d0) * uvwr / eptp(jdp,ip)
  endif

  taup = romp / romf / fdr

endif

!===============================================================================
! 3. Computation of the relaxation time with the drag coefficient of
!    S.A. Morsi and A.J. Alexander, J. of Fluid Mech., Vol.55, pp 193-208 (1972)
!===============================================================================

rec1 =  0.1d0
rec2 =  1.0d0
rec3 =  10.d0
rec4 = 200.d0

dd2 = eptp(jdp,ip) * eptp(jdp,ip)

if ( rep.le.rec1 ) then
  fdr = 18.d0 * xnul / dd2

else if ( rep.le.rec2 ) then
  fdr = 3.d0/4.d0 * xnul / dd2                                     &
      * (22.73d0 + 0.0903d0/rep + 3.69d0*rep )

else if ( rep.le.rec3 ) then
  fdr = 3.d0/4.d0 * xnul / dd2                                     &
      * (29.1667d0 - 3.8889d0/rep + 1.222d0*rep)

else if ( rep.le.rec4 ) then
    fdr = 18.d0*xnul/dd2 *(1.d0 + 0.15d0*rep**0.687d0)

else
   fdr = (0.44d0 * 3.d0 / 4.d0) * uvwr / eptp(jdp,ip)
endif

taup = romp / romf / fdr


!==============================================================================

!--------
! Formats
!--------


!----
! End
!----

end subroutine uslatp
