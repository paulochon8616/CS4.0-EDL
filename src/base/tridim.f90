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

!> \file tridim.f90
!> \brief Resolution of incompressible Navier Stokes and scalar transport
!> equations for a time step.
!>
!------------------------------------------------------------------------------

!------------------------------------------------------------------------------
! Arguments
!------------------------------------------------------------------------------
!   mode          name          role
!------------------------------------------------------------------------------
!> \param[in]     itrale        ALE iteration number
!> \param[in]     nvar          total number of variables
!> \param[in]     nscal         total number of scalars
!> \param[in]     isostd        standard output indicator
!>                              + reference face number
!> \param[in]     dt            time step (per cell)
!> \param[in,out] propce        physical properties at cell centers
!> \param[in]     frcxt         external force generating hydrostatic pressure
!> \param[in]     prhyd         predicted hydrostatic pressure
!______________________________________________________________________________

subroutine tridim &
 ( itrale ,                                                       &
   nvar   , nscal  ,                                              &
   isostd ,                                                       &
   dt     , propce ,                                              &
   frcxt  , prhyd  )

!===============================================================================
! Module files
!===============================================================================

use paramx
use numvar
use optcal
use entsor
use cstphy
use cstnum
use pointe
use albase
use alstru
use alaste
use parall
use period
use ppppar
use ppthch
use ppincl
use cpincl
use coincl
use atincl
use atsoil
use lagpar
use lagdim
use lagran
use vorinc
use ihmpre
use radiat
use cplsat
use ppcpfu
use elincl
use mesh
use field
use rotation
use darcy_module
use cs_f_interfaces
use cs_tagmr, only:rob, condb,cpb,hext,text,tpar0
use cs_tagms, only: t_metal, tmet0
use cs_nz_tagmr
use cs_nz_condensation
use turbomachinery

! les " use pp* " ne servent que pour recuperer le pointeur IIZFPP

!===============================================================================

implicit none

! Arguments

integer          itrale
integer          nvar   , nscal

integer          isostd(nfabor+1)

double precision, pointer, dimension(:)   :: dt
double precision, pointer, dimension(:,:) :: propce
double precision, pointer, dimension(:,:) :: frcxt
double precision, pointer, dimension(:) :: prhyd

! Local variables

logical          interleaved

integer          iel   , ifac  , inod  , ivar  , iscal , iappel
integer          ncv   , iok   , ifld  , nfld  , f_id  , f_dim  , f_type
integer          nbccou
integer          ntrela
integer          icmst

integer          isvhb, iz
integer          ii    , ientha, ippcv
integer          iterns, inslst, icvrge
integer          italim, itrfin, itrfup, ineefl
integer          nbzfmx, nozfmx
integer          ielpdc

double precision tditot, tdist2, tdist1, cvcst
double precision xxp0, xyp0, xzp0
double precision relaxk, relaxe, relaxw, relaxn
double precision hdls(6)
double precision, save :: tpar, tmet

integer          ipass
data             ipass /0/
save             ipass

integer          infpar
save             infpar

integer, allocatable, dimension(:,:) :: icodcl
integer, allocatable, dimension(:) :: ilzfbr

double precision, allocatable, dimension(:) :: flmalf, flmalb, xprale
double precision, allocatable, dimension(:,:) :: cofale
double precision, pointer, dimension(:,:) :: dttens
double precision, allocatable, dimension(:) :: qcalc
double precision, allocatable, dimension(:,:,:) :: rcodcl
double precision, allocatable, dimension(:) :: hbord, theipb
double precision, allocatable, dimension(:) :: visvdr
double precision, allocatable, dimension(:) :: prdv2f
double precision, dimension(:), pointer :: crom, crom_prev, crom_prev2

double precision, pointer, dimension(:,:) :: uvwk
double precision, pointer, dimension(:,:) :: trava
double precision, pointer, dimension(:,:,:) :: ximpav
double precision, dimension(:,:), pointer :: disale
double precision, dimension(:,:), pointer :: vel
double precision, dimension(:,:), pointer :: cvar_vec
double precision, dimension(:), pointer :: cvar_sca
double precision, dimension(:), pointer :: cvar_pr, cvara_pr
double precision, dimension(:), pointer :: cvar_k, cvara_k, cvar_ep, cvara_ep
double precision, dimension(:), pointer :: cvar_omg, cvara_omg
double precision, dimension(:), pointer :: cvar_nusa, cvara_nusa
double precision, dimension(:), pointer :: cvar_r11, cvar_r22, cvar_r33
double precision, dimension(:), pointer :: cvar_r12, cvar_r13, cvar_r23
double precision, dimension(:), pointer :: cpro_prtot
double precision, dimension(:), pointer :: cvar_scalt, cvar_totwt

! Darcy
integer mbrom
integer, allocatable, dimension(:) :: delay_id
double precision, dimension(:), pointer :: cpro_delay, cpro_capacity, cpro_sat
double precision, dimension(:), pointer :: cproa_delay, cproa_capacity
double precision, dimension(:), pointer :: cproa_sat
character*80     fname

double precision, dimension(:), pointer :: coefap, cofafp, cofbfp

!===============================================================================
! Interfaces
!===============================================================================

interface

  subroutine navstv &
  !================

  ( nvar   , nscal  , iterns , icvrge , itrale ,                   &
    isostd ,                                                       &
    dt     , propce ,                                              &
    frcxt  , prhyd  ,                                              &
    trava  , ximpa  , uvwk   )

    use dimens, only: ndimfb
    use mesh, only: nfabor

    implicit none

    integer          nvar   , nscal  , iterns , icvrge , itrale

    integer          isostd(nfabor+1)

    double precision, pointer, dimension(:)   :: dt
    double precision, pointer, dimension(:,:) :: propce
    double precision, pointer, dimension(:,:) :: frcxt
    double precision, pointer, dimension(:) :: prhyd
    double precision, pointer, dimension(:,:) :: trava, uvwk
    double precision, pointer, dimension(:,:,:) :: ximpa

  end subroutine navstv

  subroutine richards &
  !================

 (icvrge, dt)

    use dimens, only: ndimfb
    use mesh, only: nfabor

    implicit none

    integer  icvrge
    double precision, pointer, dimension(:)   :: dt

  end subroutine richards

end interface

!===============================================================================

! Map field arrays
call field_get_val_v(ivarfl(iu), vel)

! Number of fields
call field_get_n_fields(nfld)

!===============================================================================
! 1.  INITIALISATION
!===============================================================================

if (iwarni(iu).ge.1) then
  write(nfecra,1000)
endif

ipass = ipass + 1

! --- Indicateur de stockage d'un scalaire et de son coef
!     d'echange associe.
!     Pour le moment, on stocke uniquement dans le cas couplage SYRTHES.
!     ISVHB donne le numero du scalaire (on suppose qu'il n'y en a qu'un).
!     Dans le cas ou on a un couplage avec le module thermique 1D en paroi,
!     on utilise le meme scalaire que celui qui sert a Syrthes (s'il y a
!     couplage Syrthes), sinon on stocke le scalaire thermique de la phase 1.

call nbcsyr (nbccou)
!==========
isvhb = 0
if (nbccou .ge. 1) then
  do iscal = 1, nscal
    if(icpsyr(iscal).eq.1) then
      isvhb = iscal
    endif
  enddo
endif

if ((nfpt1t.gt.0).and.(nbccou.le.0)) then
  isvhb = iscalt
endif

!     Si la distance a la paroi doit etre mise a jour, on l'initialise a GRAND
!     des maintenant (pour le premier passage dans phyvar en k-omega)
if(ipass.eq.1.and.ineedy.eq.1.and.abs(icdpar).eq.1.and.           &
                                  imajdy.eq.0) then
  do iel = 1, ncel
    dispar(iel) = grand
  enddo
endif

call field_get_val_s(ivarfl(ipr), cvar_pr)
call field_get_val_prev_s(ivarfl(ipr), cvara_pr)

!===============================================================================
! 2.  AU DEBUT DU CALCUL ON REINITIALISE LA PRESSION
!===============================================================================

if (ippmod(idarcy).eq.-1) then

! On le fait sur ntinit pas de temps, car souvent, le champ de flux de masse
!   initial n'est pas a divergence nulle (CL incluses) et l'obtention
!   d'un flux a divergence nulle coherent avec la contrainte stationnaire
!   peut prendre quelques pas de temps.
! Remarquer que la pression est rattrapee dans l'etape de stokes.
! On ne le fait pas dans le cas de la prise en compte de la pression
!   hydrostatique, ni dans le cas du compressible

  if( ntcabs.le.ntinit .and. isuite.eq.0 .and. (iphydr.eq.0.or.iphydr.eq.2)    &
                  .and. ippmod(icompf).lt.0                               &
                  .and. idilat .le.1                 ) then

    if(iwarni(ipr).ge.2) then
      write(nfecra,2000) ntcabs
    endif
    call field_get_val_s(iprpfl(iprtot), cpro_prtot)
    xxp0   = xyzp0(1)
    xyp0   = xyzp0(2)
    xzp0   = xyzp0(3)
    do iel = 1, ncel
      cvar_pr(iel) = pred0
      cpro_prtot(iel) = p0                                   &
           + ro0*( gx*(xyzcen(1,iel)-xxp0)                   &
           +       gy*(xyzcen(2,iel)-xyp0)                   &
           +       gz*(xyzcen(3,iel)-xzp0) )
    enddo
  endif

endif

 2000 format(                                                           &
  ' REINITIALISATION DE LA PRESSION A L''ITERATION ',I10)

!===============================================================================
! 3.  COMMUNICATIONS
!===============================================================================

! ---> On echange ici les variables RTP en debut de pas de temps.
!         Ce n'est pas fait dans caltri pour faciliter la lecture
!         (manipulation des tableaux)
!      Ceci a l'avantage d'echanger egalement ce qui provient de
!         inivar et lecamo (et par rapport a une solution d'echange
!         en fin de pas de temps, on evite une communication)
!      L'inconvenient est que l'on ne dispose pas des halos sitot les
!         RTP calcules (fin de navstv, turbke, turrij, boucle dans scalai)
!      On pourrait penser a echanger aussi les PROPCE et le DT
!         Pour le moment ca ne s'impose pas : on a besoin d'avoir
!         echange RHO dans navstv pour un affichage et les viscosites
!         dans visecv. On fera les transferts localement quand necessaire.
!      Par principe, on suppose que
!         c'est a la charge de celui qui utilise des valeurs voisines de
!           s'assurer qu'elles existent (ss pgm utilisateurs en
!           particulier)
!         seules les RTPA sont echangees de maniere systematique
!           (eviter donc d'utiliser RTP)
!         le calcul du gradient fournit aussi les valeurs sur le halo
!           (utile pour les reconstructions)
!         les seules boucles sur NCELET sont des boucles d'initialisation
!           (on n'a pas a faire de calcul sur les cellules halo, elles
!            elles sont remplies par les routines de communication et
!            on y preleve seulement de l'information)

! ---> Halo synchronization

if (irangp.ge.0 .or. iperio.eq.1) then

  do f_id = 0, nfld-1

    call field_get_dim(f_id, f_dim, interleaved)
    call field_get_type(f_id, f_type)

    ! Is the field of type FIELD_VARIABLE?
    if (iand(f_type, FIELD_VARIABLE).eq.FIELD_VARIABLE) then
      if (f_dim.eq.1) then

        call field_get_val_s(f_id, cvar_sca)
        call synsce (cvar_sca)

      else if (f_dim.eq.3) then

        call field_get_val_v(f_id, cvar_vec)
        call synvie(cvar_vec)

      else
        call csexit(1)
      endif

    endif
  enddo

endif

! ---> Periodicity of rotation

if (iperio.eq.1) then

  !  -- Reynolds stress tensor

  if (itytur.eq.3) then

    call field_get_val_s(ivarfl(ir11), cvar_r11)
    call field_get_val_s(ivarfl(ir22), cvar_r22)
    call field_get_val_s(ivarfl(ir33), cvar_r33)
    call field_get_val_s(ivarfl(ir12), cvar_r12)
    call field_get_val_s(ivarfl(ir13), cvar_r13)
    call field_get_val_s(ivarfl(ir23), cvar_r23)

    call perrte &
    !==========
  ( cvar_r11, cvar_r12, cvar_r13,           &
    cvar_r12, cvar_r22, cvar_r23,           &
    cvar_r13, cvar_r23, cvar_r33 )
  endif

  !  -- Note for v2f:
  !     v2 (thus phi) is oriented locally, and is handled as a scalar
  !     regarding periodicity of rotation

endif

!===============================================================================
! 4.  POUR IPHYDR ON DOIT COMMUNIQUER FRCXT AU PREMIER PASSAGE
!     (FRCXT SERT DANS TYPECL)
!     If icalhy=1, rho must be synchronized before copying to previous values
!===============================================================================

if (ipass.eq.1) then

! --- Communication de FRCXT
  if (iphydr.eq.1) then

    if (irangp.ge.0 .or. iperio.eq.1) then
      call synvin (frcxt)
    endif

  endif

! --- Communication de RHO
  if (icalhy.eq.1 .or. idilat.eq.3) then

    call field_get_val_s(icrom, crom)
    if (irangp.ge.0 .or. iperio.eq.1) then
      call synsce (crom)
      !==========
    endif

  endif

! --- Communication de prhyd
  if (iphydr.eq.2) then

    if (irangp.ge.0 .or. iperio.eq.1) then
      call synsce (prhyd(1))
      !==========
    endif

  endif

endif

!===============================================================================
! 5.  LES VALEURS COURANTES ECRASENT LES VALEURS ANTERIEURES
!===============================================================================

! --- Noter que exceptionnellement, on fait un calcul avec NCELET,
!       pour eviter une nouvelle communication sur RTPA et les autres
!       tableaux du pas de temps precedent

ifld = -1
do ivar = 1, nvar
  if (ivarfl(ivar) .ne. ifld) then
    ifld = ivarfl(ivar)
    call field_current_to_previous(ifld)
  endif
enddo

! If required, the density at time step n-2 is updated
if (icavit.ge.0.or.idilat.gt.1) then
  call field_get_val_prev_s(icrom, crom_prev)
  call field_get_val_s(icroaa, crom_prev2)
  do iel = 1, ncelet
    crom_prev2(iel) = crom_prev(iel)
  enddo
endif

! If required, the density at time step n-1 is updated
if (icalhy.eq.1.or.idilat.gt.1.or.icavit.ge.0) then
  call field_get_val_s(icrom, crom)
  call field_get_val_prev_s(icrom, crom_prev)
  do iel = 1, ncelet
    crom_prev(iel) = crom(iel)
  enddo
endif

!===============================================================================
! 6. DANS LE CAS  "zero pas de temps" EN "SUITE" DE CALCUL
!      ON SORT ICI
!===============================================================================
!  on sort avant SCHTMP car sinon a l'ordre 2 en temps la valeur du
!  flux de masse au pas de temps precedent est ecrasee par la valeur
!  au pas de temps actuel et la valeur au pas de temps actuel est
!  remplacee par une extrapolation qui n'a pas lieu d'etre puisque
!  NTCABS n'est pas incremente. Dans le cas INPDT0=1 sans suite, il
!  n'y a pas de probleme puisque tous les flux de masse sont a 0           !
!  Si ITRALE=0, on est a l'iteration d'initialisation de l'ALE,
!  on ne touche pas au flux de masse non plus


if(inpdt0.eq.1.and.isuite.eq.1) goto 200

if (itrale.gt.0) then
  iappel = 1
  call schtmp(nscal, iappel, propce)
  !==========
endif


!===============================================================================
! 6.  MISE A JOUR DU MAILLAGE POUR UN COUPLAGE ROTOR/STATOR
!===============================================================================

if (imobil.eq.1) then

  ! En turbomachine on connait la valeur exacte de la vitesse de maillage
  ! on modifie la geometrie en fonction de la geometrie initiale

  do inod = 1, nnod
    do ii = 1, 3
      xyznod(ii,inod) = xyzno0(ii,inod)
    enddo
  enddo

  call rotation_update_coords(nnod, ttcmob, xyznod)

  call algrma(volmin, volmax, voltot)
  !==========

  ! Abort at the end of the current time-step if there is a negative volume
  if (volmin.le.0.d0) ntmabs = ntcabs

endif

!===============================================================================
! 6.  MISE A JOUR DE LA LOCALISATION DES INTERFACES DE COUPLAGE CS/CS
!===============================================================================

! Localisation des interfaces de couplage via la librairie FVM

! On fait cette mise a jour des interfaces de localisation juste apres
! les changements de geometries dus :
!   - soit a la methode ALE (en fin de pas de temps precedent)
!   - soit a un deplacement impose (cf ci-dessus)

if (nbrcpl.gt.0) call cscloc
                 !==========

!===============================================================================
! 7.  CALCUL DES PROPRIETES PHYSIQUES VARIABLES
!      SOIT VARIABLES AU COURS DU TEMPS
!      SOIT VARIABLES LORS D'UNE REPRISE DE CALCUL
!        (VISCOSITES ET MASSE VOLUMIQUE)
!===============================================================================

if (iwarni(iu).ge.1) then
  write(nfecra,1010)
endif

call phyvar(nvar, nscal, dt, propce)
!==========

if (itrale.gt.0) then
  iappel = 2
  call schtmp(nscal, iappel, propce)
  !==========
endif


! REMPLISSAGE DES COEFS DE PDC
!    ON Y PASSE MEME S'IL N'Y A PAS DE PDC SUR LE PROC COURANT AU CAS OU
!    UN UTILISATEUR DECIDERAIT D'AVOIR UN COEFF DE PDC DEPENDANT DE
!    LA VITESSE MOYENNE OU MAX.


if (ncpdct.gt.0) then

  iappel = 3

  if (iihmpr.eq.1) then
    call uikpdc &
    !==========
  ( iappel, ncelet, ncepdc,             &
    icepdc, ckupdc)
  endif

  call cs_user_head_losses &
( ncepdc , iappel ,                                              &
  icepdc , izcpdc ,                                              &
  dt     ,                                                       &
  ckupdc )

endif

! REMPLISSAGE DES COEFS DE TERME SOURCE DE MASSE

!    ON Y PASSE MEME S'IL N'Y A PAS DE TSM SUR LE PROC COURANT AU CAS OU
!    UN UTILISATEUR DECIDERAIT D'AVOIR UN TSM DEPENDANT DE
!    VALEURS GLOBALES OU MAX.
if(nctsmt.gt.0) then

  !     Mise a zero du tableau de type de TS masse et source
  do ii = 1, ncetsm
    do ivar = 1, nvar
      itypsm(ii,ivar) = 0
      smacel(ii,ivar) = 0.d0
    enddo
  enddo

  iappel = 3
  call  cs_user_mass_source_terms &
( nvar   , nscal  , ncepdc ,                                     &
  ncetsm , iappel ,                                              &
  icepdc ,                                                       &
  icetsm , itypsm , izctsm ,                                     &
  dt     ,                                                       &
  ckupdc , smacel )

endif

!------------------------------------------------------------------------
!-- Fill the condensation arrays spcond for the sink term of condensation
!-- and hpcond the thermal exchange coefficient associated to the phase
!-- change (gas phase to liquid phase)
!------------------------------------------------------------------------

if (nftcdt.gt.0) then

  iappel = 3

  ! Condensation source terms arrays initialized
  do ii = 1, nfbpcd
    do ivar = 1, nvar
      itypcd(ii,ivar) = 0
      spcond(ii,ivar) = 0.d0
      hpcond(ii)      = 0.d0
    enddo
  enddo

  call cs_user_boundary_mass_source_terms &
  !======================================
( nvar   , nscal  ,                                              &
  nfbpcd , iappel ,                                              &
  ifbpcd , itypcd , izftcd ,                                     &
  spcond , tpar)

  if (nzones.eq.1) then
    do ii = 1, nfbpcd
      iz = izzftcd(ii)
      zrob  (iz) = rob
      zcondb(iz) = condb
      zcpb  (iz) = cpb
      zhext (iz) = hext
      ztext (iz) = text
      ztpar (iz) = tpar
    enddo
  endif

  ! Empiric laws used by COPAIN condensation model to
  ! the computation of the condensation source term and
  ! exchange coefficient of the heat transfer imposed
  ! as boundary condition.

  call condensation_copain_model &
  !=============================
( nvar   , nfbpcd , ifbpcd , izzftcd ,                           &
  tpar   ,                                                       &
  spcond , hpcond )

endif

!----------------------------------------------------------
!-- Fill the condensation arrays (svcond) for the sink term
!-- of condensation and source term type (itypst) of each
!-- variable solved associated to the metal structures
!-- condensation modelling.
!----------------------------------------------------------

if (icond.eq.1) then

  !-- Condensation source terms arrays initialized
  do iel = 1, ncelet
    ltmast(iel) = 0
    itypst(iel, ivar) = 0
    svcond(iel, ivar) = 0.d0
    flxmst(iel) = 0.d0
  enddo

  call cs_user_metal_structures_source_terms &
  !=========================================
( nvar   , nscal  ,                                              &
  ncmast , ltmast,                                               &
  itypst , izmast ,                                              &
  svcond , tmet)

  ! Condensation model to compute the sink source term
  ! (svcond) and the  heat transfer flux (flxmst) imposed
  ! in the cells associated to the metal  structures
  ! volume where this phenomenon occurs.

  call metal_structures_copain_model &
  !=================================
( ncmast , ltmast ,                                          &
  tmet   ,                                                   &
  svcond(:, ipr)  , flxmst )

  ! array initialization if the metal structures
  ! condensation model is coupled with
  ! a 0-D thermal model
  ! FIXME add restart file later
  if (itagms.eq.1) then
    do icmst = 1, ncmast
      iel = ltmast(icmst)
      t_metal(iel,1) = tmet0
      t_metal(iel,2) = tmet0
    enddo
  endif

endif

if (ippmod(idarcy).eq.1) then

  if (nscal.gt.0) then
    allocate(delay_id(nscal))
  endif

  do ii = 1, nscal

    call field_get_name(ivarfl(isca(ii)), fname)
    call field_get_id(trim(fname)//'_delay', delay_id(ii))

  enddo

  ! Index of the corresponding field
  call field_get_val_prev_s_by_name('capacity', cproa_capacity)
  call field_get_val_prev_s_by_name('saturation', cproa_sat)
  call field_get_val_s_by_name('capacity', cpro_capacity)
  call field_get_val_s_by_name('saturation', cpro_sat)

  do iel = 1, ncel
    cproa_capacity(iel) = cpro_capacity(iel)
    cproa_sat(iel) = cpro_sat(iel)
  enddo

  do ii = 1, nscal
    call field_get_val_prev_s(delay_id(ii), cproa_delay)
    call field_get_val_s(delay_id(ii), cpro_delay)
    do iel = 1, ncel
      cproa_delay(iel) = cpro_delay(iel)
    enddo
  enddo

endif

!===============================================================================
! 8.  CALCUL DU NOMBRE DE COURANT ET DE FOURIER
!     CALCUL DU PAS DE TEMPS SI VARIABLE
!===============================================================================

if(iwarni(iu).ge.1) then
  write(nfecra,1020)
endif

call dttvar &
!==========
 ( nvar   , nscal  , ncepdc , ncetsm ,                            &
   iwarni(iu)   ,                                                 &
   icepdc , icetsm , itypsm ,                                     &
   dt     , propce ,                                              &
   ckupdc , smacel )

if (nbaste.gt.0.and.itrale.gt.nalinf) then
  ntrela = ntcabs - ntpabs
  call astpdt(dt, ncelet, ntrela)
  !==========
endif

! Compute the pseudo tensorial time step if needed for the pressure solving

if ((idften(ipr).eq.6).and.(ippmod(idarcy).eq.-1)) then

  call field_get_val_v(idtten, dttens)

  do iel = 1, ncel
    dttens(1, iel) = dt(iel)
    dttens(2, iel) = dt(iel)
    dttens(3, iel) = dt(iel)
    dttens(4, iel) = 0.d0
    dttens(5, iel) = 0.d0
    dttens(6, iel) = 0.d0
  enddo

  do ielpdc = 1, ncepdc
    iel = icepdc(ielpdc)

    ! dttens = (1/dt + Kpdc)^-1
    hdls(1) = ckupdc(ielpdc, 1) + 1.d0/dt(iel)
    hdls(2) = ckupdc(ielpdc, 2) + 1.d0/dt(iel)
    hdls(3) = ckupdc(ielpdc, 3) + 1.d0/dt(iel)
    hdls(4) = ckupdc(ielpdc, 4)
    hdls(5) = ckupdc(ielpdc, 5)
    hdls(6) = ckupdc(ielpdc, 6)

    call symmetric_matrix_inverse(hdls, dttens(:, iel))
  enddo

endif

!===============================================================================
!     RECALAGE DE LA PRESSION Pth ET MASSE VOLUMIQUE rho
!     POUR L'ALGORITHME A MASSE VOLUMIQUE VARIABLE.
!===============================================================================

if (idilat.eq.3) then
  call pthrbm &
  !==========
 ( nvar   , ncetsm , nfbpcd , ncmast,                             &
   dt     , smacel , spcond , svcond )

endif

!===============================================================================
! 9.  CHARGEMENT ET TRADUCTION DES CONDITIONS AUX LIMITES
!===============================================================================

if(iwarni(iu).ge.1) then
  write(nfecra,1030)
endif

!  -- Methode des vortex en LES :
!     Definition ou modification eventuelle des parametres
!     Mise a jour des vortex

if (ivrtex.eq.1) then

  iappel = 2
  call usvort &
  !==========
 ( nvar   , nscal  ,                                              &
   iappel ,                                                       &
   dt     )

!     Verification des donnees entrees par l'utilisateur
!       (au premier passage seulement)
  if (ipass.eq.1) then
    call vorver ( nfabor , iappel )
    !==========
  endif

  if(irangp.le.0) then
    call vortex
    !==========
  endif

! -- Fin de zone Methode des vortex

endif

! --- Methode ALE : debut de boucle d'implicitation du deplacement des
!       structures. ITRFIN=0 indique qu'on a besoin de refaire une iteration
!       pour Syrthes, T1D ou rayonnement.
italim = 1
itrfin = 1
ineefl = 0
if (iale.eq.1 .and. nalimx.gt.1 .and. itrale.gt.nalinf) then
!     On reserve certains tableaux pour permettre le retour a l'etat
!       initial en fin d'iteration ALE
!       - flux de masse
!       - conditions aux limites de gradient de P et U (car on a un appel
!         a GDRCEL pour les non orthogonalites pour calculer les CL reelles)
!         -> n'est peut-etre pas reellement necessaire
!       - la pression initiale (car RTPA est aussi ecrase dans le cas
!         ou NTERUP>1) -> on pourrait optimiser en ne reservant que si
!         necessaire ...
!       Pas la peine de tester les depassements car on passe dans
!       memcli juste apres.
  allocate(flmalf(nfac))
  allocate(flmalb(nfabor))
  allocate(cofale(nfabor,11))
  allocate(xprale(ncelet))
  ineefl = 1

  if (nbccou.gt.0 .or. nfpt1t.gt.0 .or. iirayo.gt.0) itrfin = 0

endif

300 continue


! --- Boucle sur navstv pour couplage vitesse/pression
!     on s'arrete a NTERUP ou quand TOUTES les phases on converge
!     ITRFUP=0 indique qu'on a besoin de refaire une iteration
!     pour Syrthes, T1D ou rayonnement.
itrfup = 1

if (nterup.gt.1.or.isno2t.gt.0) then

  allocate(ximpav(ndim,ndim,ncelet))
  allocate(uvwk(ndim,ncelet))
  allocate(trava(ndim,ncelet))

  if (nbccou.gt.0 .or. nfpt1t.gt.0 .or. iirayo.gt.0) itrfup = 0

else

  uvwk => rvoid2
  trava => rvoid2
  ximpav => rvoid3

endif
! Compute the number of variable plus the number of turbulent fluxes
nvarcl = nvar
do iscal = 1, nscal
  if (ityturt(iscal).eq.3) nvarcl = nvarcl + 3
enddo

! Allocate temporary arrays for boundary conditions
if (italim .eq. 1) then
  allocate(icodcl(nfabor,nvarcl))
  allocate(rcodcl(nfabor,nvarcl,3))
endif
if (isvhb.gt.0) then
  allocate(hbord(nfabor))
endif
! Boundary value of the thermal scalar in I'
if (iscalt.gt.0) then
  allocate(theipb(nfabor))
endif
if (itytur.eq.4 .and. idries.eq.1) then
  allocate(visvdr(ncelet))
endif

icvrge = 0
inslst = 0
iterns = 1

! Darcy : in case of a steady flow, we resolve Richards only once,
! at the first time step.
if (ippmod(idarcy).eq.1) then
  if ((darcy_unsteady.eq.0).and.(ntcabs.gt.1)) goto 100
endif

do while (iterns.le.nterup)

  call precli(nvar, nscal, icodcl, rcodcl)
  !==========

  !     - Interface Code_Saturne
  !       ======================

  if (iihmpr.eq.1) then

  ! N.B. Zones de face de bord : on utilise provisoirement les zones des
  !    physiques particulieres, meme sans physique particuliere
  !    -> sera modifie lors de la restructuration des zones de bord

    call uiclim &
    !==========
  ( ntcabs, nfabor, ippmod(idarcy),                                &
    darcy_gravity, darcy_gravity_x, darcy_gravity_y,               &
    darcy_gravity_z,                                               &
    nozppm, ncharm, ncharb, nclpch,                                &
    iindef, ientre, iesicf, isspcf, iephcf,                        &
    isopcf, iparoi, iparug, isymet, isolib, ifrent, ifresf,        &
    iqimp,  icalke, ientat, ientcp, inmoxy, ientox,                &
    ientfu, ientgb, ientgf, iprofm,                                &
    coejou, dpot,   ielcor, ipoti,                                 &
    itypfb, izfppp, icodcl,                                        &
    dtref,  ttcabs, surfbo, cdgfbo,                                &
    qimp,   qimpat, qimpcp, dh,     xintur,                        &
    timpat, timpcp, tkent ,  fment, distch, nvarcl, rcodcl)

    if (ippmod(iphpar).eq.0) then

    ! ON NE FAIT PAS DE LA PHYSIQUE PARTICULIERE

      nbzfmx = nbzppm
      nozfmx = nozppm
      allocate(ilzfbr(nbzfmx))
      allocate(qcalc(nozfmx))

      call stdtcl &
      !==========
    ( nbzfmx , nozfmx ,                                              &
      iqimp  , icalke , qimp   , dh , xintur,                        &
      itypfb , izfppp , ilzfbr ,                                     &
      rcodcl , qcalc  )

      ! Free memory
      deallocate(ilzfbr)
      deallocate(qcalc)

    endif

  endif

  !     - Sous-programme utilisateur
  !       ==========================

  call cs_user_boundary_conditions &
  !===============================
  ( nvar   , nscal  ,                                              &
    icodcl , itrifb , itypfb , izfppp ,                            &
    dt     ,                                                       &
    rcodcl )

  !     - Interface Code_Saturne
  !       ======================

  if(iihmpr.eq.1) then

    call uiclve &
    !==========
  ( nfabor, nozppm,                                                &
    iindef, ientre, iesicf, iephcf, isspcf, isopcf,                &
    iparoi, iparug, isymet, isolib, ifrent, ifresf, iale  ,        &
    itypfb, izfppp )

  endif

  ! -- Methode des vortex en L.E.S. :
  !    (Transfert des vortex dans les tableaux RCODCL)

  if (ivrtex.eq.1) then
    call vor2cl(itypfb, rcodcl)
    !==========
  endif

  ! --- Couplage code/code entre deux instances (ou plus) de Code_Saturne
  !       On s'occupe ici du couplage via les faces de bord, et de la
  !       transformation de l'information recue en condition limite.

  if (nbrcpl.gt.0) then

    call cscfbr &
    !==========
  ( nscal  ,                                                       &
    icodcl , itypfb ,                                              &
    dt     ,                                                       &
    rcodcl )

  endif

! -- Synthetic Eddy Method en L.E.S. :
!    (Transfert des structures dans les tableaux rcodcl)

    call synthe &
    !==========
  ( nvar   , nscal  ,                                              &
    iu     , iv     , iw     ,                                     &
    ttcabs , dt     ,                                              &
    rcodcl )

  ! -- Methode ALE (CL de vitesse de maillage et deplacement aux noeuds)

  if (iale.eq.1) then

    call field_get_val_v(fdiale, disale)

    do ii = 1, nnod
      impale(ii) = 0
    enddo

    ! - Interface Code_Saturne
    !   ======================

    if (iihmpr.eq.1) then

      call uialcl &
      !==========
    ( nozppm,                            &
      ibfixe, igliss, ivimpo, ifresf,    &
      ialtyb,                            &
      impale,                            &
      disale,                            &
      dtref, ttcabs, ntcabs,             &
      iuma, ivma, iwma,                  &
      rcodcl)

    endif

    call usalcl &
    !==========
  ( itrale ,                                                       &
    nvar   , nscal  ,                                              &
    icodcl , itypfb , ialtyb ,                                     &
    impale ,                                                       &
    dt     ,                                                       &
    rcodcl , xyzno0 , disale )

    !     Au cas ou l'utilisateur aurait touche DEPALE sans mettre IMPALE=1, on
    !       remet le deplacement initial
    do ii  = 1, nnod
      if (impale(ii).eq.0) then
        disale(1,ii) = xyznod(1,ii)-xyzno0(1,ii)
        disale(2,ii) = xyznod(2,ii)-xyzno0(2,ii)
        disale(3,ii) = xyznod(3,ii)-xyzno0(3,ii)
      endif
    enddo

    !     En cas de couplage de structures, on calcule un deplacement predit
    if (nbstru.gt.0.or.nbaste.gt.0) then

      call strpre &
      !==========
    ( itrale , italim , ineefl ,                                     &
      impale ,                                                       &
      flmalf , flmalb , xprale , cofale )

    endif

  endif

  !     UNE FOIS CERTAINS CODES DE CONDITIONS LIMITES INITIALISES PAR
  !     L'UTILISATEUR, ON PEUT COMPLETER CES CODES PAR LES COUPLAGES
  !     AUX BORDS (TYPE SYRTHES), SAUF SI ON DOIT Y REPASSER ENSUITE
  !     POUR CENTRALISER CE QUI EST RELATIF AU COUPLAGE AVEC SYRTHES
  !     ON POSITIONNE ICI L'APPEL AU COUPLAGE VOLUMIQUE SYRTHES
  !     UTILE POUR BENIFICER DE LA DERNIERE VITESSE CALCULEE SI ON
  !     BOUCLE SUR U/P.
  !     LE COUPLAGE VOLUMIQUE DOIT ETRE APPELE AVANT LE SURFACIQUE
  !     POUR RESPECTER LE SCHEMA DE COMMUNICATION

  if (itrfin.eq.1 .and. itrfup.eq.1) then

    call cpvosy(iscalt, dt)
    !==========

    call coupbi(nfabor, nscal, icodcl, rcodcl)
    !==========

    if (nfpt1t.gt.0) then
      call cou1di(nfabor, iscalt, icodcl, rcodcl)
      !==========
    endif

    ! coupling 1D thermal model with condensation modelling
    ! to take into account the solid temperature evolution over time
    if (nftcdt.gt.0) then
      call cs_tagmri(nfabor, iscalt, icodcl, rcodcl)
      !=============
    endif

  endif


  if (iirayo.gt.0 .and. itrfin.eq.1 .and. itrfup.eq.1) then

    call raycli &
    !==========
  ( nvar   , nscal  ,                                              &
    icodcl , itypfb ,                                              &
    izfrad ,                                                       &
    dt     , propce , rcodcl )

  endif

  !     ON CALCULE LES COEFFICIENTS ASSOCIES AUX CONDITIONS LIMITES

  call condli &
  !==========
( nvar   , nscal  , iterns ,                                     &
  isvhb  ,                                                       &
  icodcl , isostd ,                                              &
  dt     ,                                                       &
  rcodcl ,                                                       &
  visvdr , hbord  , theipb ,                                     &
  frcxt  )

  if (nftcdt.gt.0) then
    ! Coefficient exchange of the enthalpy scalar
    ivar = isca(iscalt)
    call field_get_coefa_s(ivarfl(ivar) , coefap)
    call field_get_coefaf_s(ivarfl(ivar), cofafp)
    call field_get_coefbf_s(ivarfl(ivar), cofbfp)

    ! Pass the heat transfer computed by the Empiric laws
    ! of the COPAIN condensation to impose the heat transfer
    ! at the wall due to condensation for the enthalpy scalar.
    do ii = 1, nfbpcd

      ifac= ifbpcd(ii)
      iel = ifabor(ifac)

      ! Enthalpy Boundary condition associated
      ! to the heat transfer due to condensation.
      cofafp(ifac) = -hpcond(ii)*coefap(ifac)
      cofbfp(ifac) =  hpcond(ii)

    enddo

  endif

!     ==============================================
!     Appel de l'interface sol-atmosphere
!     ==============================================

  if (ippmod(iatmos).eq.2.and.iatsoil.eq.1.and.nfmodsol.gt.0) then
    call field_get_val_s(icrom, crom)
    call field_get_val_s(ivarfl(isca(iscalt)), cvar_scalt)
    call field_get_val_s(ivarfl(isca(itotwt)), cvar_totwt)
    call solvar(cvar_scalt , cvar_totwt ,                &
                crom   , dt ,                            &
                rcodcl )
  endif

  !     UNE FOIS LES COEFFICIENTS CALCULES, ON PEUT EN DEDUIRE PLUS
  !     FACILEMENT (I.E. SANS RECALCULS INUTILES) LES TERMES A
  !     ENVOYER POUR LES COUPLAGES AUX BORDS (TYPE SYRTHES)


  ! On indique si la variable couplee est l'enthalpie
  ientha = 0
  if(iscalt.gt.0) then
    if(itherm.eq.2) then
      ientha = 1
    endif
  endif

  ! Compressible : on indique si la variable couple est l'energie

  if (ippmod(icompf).ge.0) then
    if(iscalt.gt.0) then
      if(itherm.eq.3) then
        ientha = 2
      endif
    endif
  endif

  ! En compressible et si on couple ave l'energie
  ! on recupere le Cv de la phase couplee

  if ( ippmod(icompf).ge.0 .and. ientha .eq. 2 ) then

    if(icv.gt.0) then
      ippcv = ipproc(icv)
      ncv   = ncelet
      cvcst = 0.d0
    else
      ippcv = 1
      ncv   = 1
      cvcst = cv0
    endif
  else
    ippcv = 1
    ncv   = 1
    cvcst = 0.d0
  endif

  ! On envoie le tout vers SYRTHES, en distinguant CP
  !  constant ou variable
  if (itrfin.eq.1 .and. itrfup.eq.1) then

    call coupbo &
    !==========
  ( ncv    , ientha ,                                              &
    cvcst  , propce(:,ippcv),                                      &
    hbord  , theipb )

    if (nfpt1t.gt.0) then
      call cou1do &
      !==========
    ( nvar   , nscal  , nfpt1d ,                                   &
      ientha , ifpt1d , iclt1d ,                                   &
      tppt1d , tept1d , hept1d , fept1d ,                          &
      xlmbt1 , rcpt1d , dtpt1d , dt     ,                          &
      hbord  , theipb )
    endif

    ! 1-D thermal model coupling with condensation
    ! on a surface region
    if (nftcdt.gt.0.and.nztag1d.eq.1) then
      call cs_tagmro &
      !=============
     ( nfbpcd , ifbpcd , izzftcd ,                  &
       dt     )
    endif

     ! 0-D thermal model coupling with condensation
     ! on a volume region associated to metal structures
    if (icond.eq.1.and.itagms.eq.1) then
      call cs_metal_structures_tag &
      !===========================
     ( ncmast , ltmast ,                          &
       dt     )
    endif

  endif

  !     ON N'A PLUS BESOIN DE ISVHB OU ISVHT (POUR HBORD ET TBORD)
  !     A PARTIR D'ICI



  !     CALCUL DE LA DISTANCE A LA PAROI
  !       (Nouvel algorithme. L'ancien est dans condli)
  !     En ALE on ne fait ce calcul qu'a la premiere des
  !       sous-iterations d'implicitation ITALIM, car le maillage
  !       n'est pas modifie dans les sous-iterations suivantes

  if (italim.eq.1) then

    if(ineedy.eq.1.and.iwarny.ge.1) then
      call dmtmps(tdist1)
    endif


    ! On ne fait le calcul que s'il y a des parois, 'dispar'  est reserve
    ! et initialise a GRAND avant. S'il n'y a pas de paroi, il restera = GRAND)

    ! Pour le moment, on suppose que l'on peut se contenter de faire
    !  cela au premier passage, sauf avec les maillages mobiles. Attention donc
    !  aux conditions aux limites variables (faces qui deviennent des parois ou
    !  parois qui deviennent autre chose)

    ! Nombre de faces de paroi
    if(ipass.eq.1) then
      if(ineedy.eq.1) then
        infpar = 0
        do ifac = 1, nfabor
          if (itypfb(ifac).eq.iparoi .or. itypfb(ifac).eq.iparug) then
            infpar = infpar+1
          endif
        enddo
        if(irangp.ge.0) then
          call parcpt(infpar)
        endif
      endif
    endif


    !     On calcule la distance a la paroi
    !          si elle doit etre mise a jour
    !       et si on en a besoin,
    !       et si on a choisi ce mode de calcul,
    if( imajdy.eq.0.and.ineedy.eq.1.and.abs(icdpar).eq.1) then

      !     S'il n'y a pas de paroi, on garde l'initialisation a GRAND
      if(infpar.eq.0) then
        imajdy = 1

        !     S'il y a des parois, il faut calculer
      else


        !     On doit conserver la memoire de memcli a cause de 'uetbor'
        !       dans DISTYP (uniquement en LES avec van Driest mais tant pis)

        call distpr(itypfb, dispar)
        !==========

        !     La distance n'a plus a etre mise a jour sauf en ALE
        if (iale.eq.0) imajdy = 1

      endif
    endif

  endif


  !     CALCUL DE L'AMORTISSEMENT DE VAN DRIEST
  !     OU CALCUL DE Y+ POUR LE LAGRANGIEN


  !     On calcule y+ si on en a besoin

  if( (itytur.eq.4.and.idries.eq.1)                 &
       .or. (iilagr.ge.1 .and. iroule.eq.2) ) then

    !       On calcule si on a demande ce mode de calcul
    !               et s'il y a des parois (si pas de paroi, pas de y+)
    if(abs(icdpar).eq.1.and.infpar.gt.0) then

      !     On doit conserver la memoire de memcli a cause de 'uetbor'
      !       dans DISTYP

      call distyp(itypfb, dispar, yplpar)
      !==========

    endif

  endif

  if (itytur.eq.4 .and. idries.eq.1) then

    !     Pas d'amortissement si pas de paroi
    if (infpar.gt.0) then
      call vandri(itypfb, ifapat, visvdr, yplpar)
    endif

  endif

  if(ineedy.eq.1.and.iwarny.ge.1) then
    call dmtmps(tdist2)
    tditot = tdist2-tdist1
    write(nfecra,4010)tditot
  endif

!===============================================================================
! 10. DANS LE CAS  "zero pas de temps" EN "NON SUITE" DE CALCUL
!      ON SORT ICI
!===============================================================================

  if (inpdt0.eq.1.and.isuite.eq.0) goto 200

  if (iilagr.eq.3) goto 200

!===============================================================================
! 11. RESOLUTION DE LA VITESSE DE MAILLAGE EN ALE
!===============================================================================

  if (iale.eq.1) then

    ! otherwise it is done in navstv.f90
    if (itrale.eq.0) then

      call alelav(propce)
      goto 200

    endif

  endif

!===============================================================================
! 11. CALCUL A CHAMP DE VITESSE NON FIGE :
!      ON RESOUT VITESSE ET TURBULENCE
!    ON SUPPOSE QUE TOUTES LES PHASES SONT FIGEES OU AUCUNE
!===============================================================================

  ! En cas de champ de vitesse fige, on ne boucle pas sur U/P
  if (iccvfg.eq.0) then
  !===============

!===============================================================================
! 12. RESOLUTION QUANTITE DE MOUVEMENT ET MASSE
!===============================================================================

    if (iwarni(iu).ge.1) then
      write(nfecra,1040)
    endif

    ! Coupled solving of the velocity components

    if (ippmod(idarcy).eq.-1) then

      call navstv &
      !==========
      ( nvar   , nscal  , iterns , icvrge , itrale ,                   &
        isostd ,                                                       &
        dt     , propce ,                                              &
        frcxt  , prhyd  ,                                              &
        trava  , ximpav , uvwk   )

      ! Update local pointer arrays for transient turbomachinery computations
      if (iturbo.eq.2) then
        call field_get_val_s(ivarfl(ipr), cvar_pr)
        call field_get_val_prev_s(ivarfl(ipr), cvara_pr)
      endif

    else

      call richards (icvrge, dt)

      if (iihmpr.eq.1) then
        call uidapp                                                    &
        !==========
         ( darcy_anisotropic_permeability,                             &
           darcy_anisotropic_diffusion,                                &
           darcy_gravity,                                              &
           darcy_gravity_x, darcy_gravity_y, darcy_gravity_z)
      endif

      ! Darcy : update data specific to underground flow
      mbrom = 0
      call usphyv(nvar, nscal, mbrom, dt)

      if (darcy_unsteady.eq.0) then

        do iel = 1, ncel
          cproa_capacity(iel) = cpro_capacity(iel)
          cproa_sat(iel) = cpro_sat(iel)
        enddo

        do ii = 1, nscal
          call field_get_val_prev_s(delay_id(ii), cproa_delay)
          call field_get_val_s(delay_id(ii), cpro_delay)
          do iel = 1, ncel
            cproa_delay(iel) = cpro_delay(iel)
          enddo
        enddo

      endif

    endif

    !     Mise a jour de la pression si on utilise un couplage vitesse/pression
    !       par point fixe
    !     En parallele, l'echange est fait au debut de navstv.
    if (nterup.gt.1) then
      do iel = 1, ncel
        cvara_pr(iel) = cvar_pr(iel)
      enddo
    endif

    !     Si c'est la derniere iteration : INSLST = 1
    if ((icvrge.eq.1).or.(iterns.eq.nterup)) then

      ! Si on a besoin de refaire une nouvelle iteration pour SYRTHES,
      ! rayonnement, paroi thermique 1D...
      ! ET que l'on est a la derniere iteration en ALE !

      ! ...alors, on remet a zero les indicateurs de convergence
      if (itrfup.eq.0.and.itrfin.eq.1) then
        itrfup = 1
        icvrge = 0
        iterns = iterns - 1

        ! ...sinon, on termine
      else
        inslst = 1
      endif

      !     On teste le flux de masse
      if ((istmpf.eq.0.and.inslst.eq.0) .or. istmpf.ne.0) then
        iappel = 3
        call schtmp(nscal, iappel, propce)
        !==========
      endif

      if (inslst.eq.1) goto 100

    endif

  endif ! Fin si calcul sur champ de vitesse figee

  iterns = iterns + 1

enddo

100 continue

! DARCY : the hydraulic head, identified with the pressure,
! has been updated by the call to Richards.
! As diffusion of scalars depends on hydraulic head in the
! general case, in order to compute the exact
! values of the boundary faces coefficients, we have to
! call boundary conditions routine again.
! Moreover, we need an update of the boundary
! conditions in the cases where they vary in time.

if (ippmod(idarcy).eq.1) then

  call precli(nvar, nscal, icodcl, rcodcl)
  !==========

  if (iihmpr.eq.1) then

  ! N.B. Zones de face de bord : on utilise provisoirement les zones des
  !    physiques particulieres, meme sans physique particuliere
  !    -> sera modifie lors de la restructuration des zones de bord

    call uiclim &
    !==========
  ( ntcabs, nfabor, ippmod(idarcy),                                &
    darcy_gravity, darcy_gravity_x, darcy_gravity_y,               &
    darcy_gravity_z,                                               &
    nozppm, ncharm, ncharb, nclpch,                                &
    iindef, ientre, iesicf, isspcf, iephcf,                        &
    isopcf, iparoi, iparug, isymet, isolib, ifrent, ifresf,        &
    iqimp,  icalke, ientat, ientcp, inmoxy, ientox,                &
    ientfu, ientgb, ientgf, iprofm,                                &
    coejou, dpot,   ielcor, ipoti,                                 &
    itypfb, izfppp, icodcl,                                        &
    dtref,  ttcabs, surfbo, cdgfbo,                                &
    qimp,   qimpat, qimpcp, dh,     xintur,                        &
    timpat, timpcp, tkent ,  fment, distch, nvarcl, rcodcl)

    if (ippmod(iphpar).eq.0) then

    ! ON NE FAIT PAS DE LA PHYSIQUE PARTICULIERE

      nbzfmx = nbzppm
      nozfmx = nozppm
      allocate(ilzfbr(nbzfmx))
      allocate(qcalc(nozfmx))

      call stdtcl &
      !==========
    ( nbzfmx , nozfmx ,                                              &
      iqimp  , icalke , qimp   , dh , xintur,                        &
      itypfb , izfppp , ilzfbr ,                                     &
      rcodcl , qcalc  )

      ! Free memory
      deallocate(ilzfbr)
      deallocate(qcalc)

    endif

  endif

  call cs_user_boundary_conditions &
  !===============================
  ( nvar   , nscal  ,                                              &
    icodcl , itrifb , itypfb , izfppp ,                            &
    dt     ,                                                       &
    rcodcl )

  call condli &
   ( nvar   , nscal  , iterns ,                                    &
     isvhb  ,                                                      &
     icodcl , isostd ,                                             &
     dt     , rcodcl ,                                             &
     visvdr , hbord  , theipb , frcxt  )

endif

! Free memory
if (allocated(hbord)) deallocate(hbord)
if (allocated(theipb)) deallocate(theipb)
if (allocated(visvdr)) deallocate(visvdr)

if (nterup.gt.1.or.isno2t.gt.0) then
  deallocate(uvwk, trava)
  deallocate(ximpav)
endif

! Calcul sur champ de vitesse fige SUITE (a cause de la boucle U/P)
if (iccvfg.eq.0) then
!===============

!===============================================================================
! 13.  DEPLACEMENT DES STRUCTURES EN ALE ET TEST DE BOUCLAGE IMPLICITE
!===============================================================================

  if (nbstru.gt.0.or.nbaste.gt.0) then

    call strdep &
    !==========
  ( itrale , italim , itrfin ,                                     &
    nvar   ,                                                       &
    dt     ,                                                       &
    flmalf , flmalb , cofale , xprale )

    !     On boucle eventuellement sur de deplacement des structures
    if (itrfin.ne.-1) then
      italim = italim + 1
      goto 300
    endif

    ! Free memory
    if (allocated(flmalf)) then
      deallocate(flmalf, flmalb)
      deallocate(cofale)
      deallocate(xprale)
    endif

  endif

  !     On ne passe dans SCHTMP que si ISTMPF.EQ.0 (explicite)
  !     On teste le flux de masse de la phase 1 (toutes les phases sont
  !     necessairement traitees de la meme facon, cf. VERINI)
  !     pour conserver
  if (istmpf.eq.0) then
    iappel = 4
    call schtmp(nscal, iappel, propce)
    !==========
  endif

!===============================================================================
! 14. RESOLUTION TURBULENCE
!===============================================================================

  iok = 0
  if(iwarni(iu).ge.1) then
    if( itytur.eq.2 .or. itytur.eq.3              &
         .or. itytur.eq.5 .or. iturb.eq.60 ) then
      iok = 1
    endif
    if(iok.eq.1) then
      write(nfecra,1050)
    endif
  endif

  ! Si on est en v2f (phi-fbar ou BL-v2/k), on reserve un tableau
  ! de taille NCELET pour eviter de recalculer la production dans RESV2F
  ! (trois appels a GRDCEL)
  if (itytur.eq.5) then
    allocate(prdv2f(ncelet))
  endif

  if ((itytur.eq.2) .or. (itytur.eq.5)) then

    call turbke &
    !==========
  ( nvar   , nscal  ,                                              &
    ncepdc , ncetsm ,                                              &
    icepdc , icetsm , itypsm ,                                     &
    dt     ,                                                       &
    tslagr ,                                                       &
    ckupdc , smacel ,                                              &
    prdv2f )

    if( itytur.eq.5 )  then

      call resv2f &
      !==========
    ( nvar   , nscal  ,                                              &
      ncepdc , ncetsm ,                                              &
      icepdc , icetsm , itypsm ,                                     &
      dt     ,                                                       &
      ckupdc , smacel ,                                              &
      prdv2f )

      ! Free memory
      deallocate(prdv2f)

    endif

    call field_get_val_s(ivarfl(ik), cvar_k)
    call field_get_val_prev_s(ivarfl(ik), cvara_k)
    call field_get_val_s(ivarfl(iep), cvar_ep)
    call field_get_val_prev_s(ivarfl(iep), cvara_ep)

    !  RELAXATION DE K ET EPSILON SI IKECOU=0 EN INSTATIONNAIRE
    if (ikecou.eq.0 .and. idtvar.ge.0) then
      relaxk = relaxv(ik)
      relaxe = relaxv(iep)
      do iel = 1,ncel
        cvar_k(iel) = relaxk*cvar_k(iel) + (1.d0-relaxk)*cvara_k(iel)
        cvar_ep(iel) = relaxe*cvar_ep(iel) + (1.d0-relaxe)*cvara_ep(iel)
      enddo
    endif

  else if(itytur.eq.3) then

    ! Calcul de Alpha pour l'EBRSM
    if (iturb.eq.32) then

      call resalp(nvar)
      !==========

    endif

    call turrij &
    !==========
  ( nvar   , nscal  ,                                              &
    ncepdc , ncetsm ,                                              &
    icepdc , icetsm , itypsm ,                                     &
    dt     ,                                                       &
    tslagr ,                                                       &
    ckupdc , smacel )

  else if (iturb.eq.60) then

    call turbkw &
    !==========
  ( nvar   , nscal  ,                                              &
    ncepdc , ncetsm ,                                              &
    icepdc , icetsm , itypsm ,                                     &
    dt     ,                                                       &
    tslagr ,                                                       &
    ckupdc , smacel )

    call field_get_val_s(ivarfl(ik), cvar_k)
    call field_get_val_prev_s(ivarfl(ik), cvara_k)
    call field_get_val_s(ivarfl(iomg), cvar_omg)
    call field_get_val_prev_s(ivarfl(iomg), cvara_omg)

    !  RELAXATION DE K ET OMEGA SI IKECOU=0
    if (ikecou.eq.0 .and. idtvar.ge.0) then
      relaxk = relaxv(ik )
      relaxw = relaxv(iomg)
      do iel = 1,ncel
        cvar_k(iel)   = relaxk*cvar_k(iel)   + (1.d0-relaxk)*cvara_k(iel)
        cvar_omg(iel) = relaxw*cvar_omg(iel) + (1.d0-relaxw)*cvara_omg(iel)
      enddo
    endif

  else if( iturb.eq.70 ) then

    call turbsa &
    !==========
  ( nvar   , nscal  ,                                              &
    ncepdc , ncetsm ,                                              &
    icepdc , icetsm , itypsm ,                                     &
    dt     ,                                                       &
    ckupdc , smacel ,                                              &
    itypfb )

    call field_get_val_s(ivarfl(inusa), cvar_nusa)
    call field_get_val_prev_s(ivarfl(inusa), cvara_nusa)

    !  RELAXATION DE NUSA
    if (idtvar.ge.0) then
      relaxn = relaxv(inusa)
      do iel = 1,ncel
        cvar_nusa(iel) = relaxn*cvar_nusa(iel)+(1.d0-relaxn)*cvara_nusa(iel)
      enddo
    endif

  endif

endif  ! Fin si calcul sur champ de vitesse fige SUITE


!     Ici on peut liberer les eventuels tableaux SKW et DIVUKW

!===============================================================================
! 15.  RESOLUTION DES SCALAIRES
!===============================================================================

if (nscal.ge.1 .and. iirayo.gt.0) then

  if (iwarni(iu).ge.1 .and. mod(ntcabs,nfreqr).eq.0) then
    write(nfecra,1070)
  endif

  call raydom &
  !==========
 ( nvar   , nscal  ,                                              &
   itypfb ,                                                       &
   izfrad ,                                                       &
   dt     , propce )

endif

if (nscal.ge.1) then

  if(iwarni(iu).ge.1) then
    write(nfecra,1060)
  endif

  call scalai                                                     &
  !==========
 ( nvar   , nscal  ,                                              &
   dt     , propce )

  ! Diffusion terms for weakly compressible algorithm
  if (idilat.ge.4) then

    call diffst(nscal, propce)

  endif

endif

! Free memory
deallocate(icodcl, rcodcl)

! Darcy
if (allocated(delay_id)) deallocate(delay_id)

!===============================================================================
! 16.  TRAITEMENT DU FLUX DE MASSE, DE LA VISCOSITE,
!      DE LA MASSE VOLUMIQUE ET DE LA CHALEUR SPECIFIQUE POUR
!      UN THETA SCHEMA
!===============================================================================


iappel = 5
call schtmp(nscal, iappel, propce)
!==========

!===============================================================================
! 17.  SORTIE DANS LE CAS DE "zero pas de temps" ET INIT ALE
!===============================================================================

 200  continue


!===============================================================================

!--------
! FORMATS
!--------

#if defined(_CS_LANG_FR)

 1000 format(/,                                                   &
' ------------------------------------------------------------',/,&
                                                              /,/,&
'  INITIALISATIONS                                            ',/,&
'  ===============                                            ',/)
 1010 format(/,                                                   &
' ------------------------------------------------------------',/,&
                                                              /,/,&
'  CALCUL DES GRANDEURS PHYSIQUES                             ',/,&
'  ==============================                             ',/)
 1020 format(/,                                                   &
' ------------------------------------------------------------',/,&
                                                              /,/,&
'  CALCUL DU CFL, DU FOURIER ET DU DT VARIABLE                ',/,&
'  ===========================================                ',/)
 1030 format(/,                                                   &
' ------------------------------------------------------------',/,&
                                                              /,/,&
'  MISE EN PLACE DES CONDITIONS AUX LIMITES                   ',/,&
'  ========================================                   ',/)
 1040 format(/,                                                   &
' ------------------------------------------------------------',/,&
                                                              /,/,&
'  RESOLUTION DES EQUATIONS DE NAVIER-STOKES                  ',/,&
'  =========================================                  ',/)
 1050 format(/,                                                   &
' ------------------------------------------------------------',/,&
                                                              /,/,&
'  RESOLUTION DES EQUATIONS DES VARIABLES TURBULENTES         ',/,&
'  ==================================================         ',/)
 1060 format(/,                                                   &
' ------------------------------------------------------------',/,&
                                                              /,/,&
'  RESOLUTION DES EQUATIONS SUR L''ENERGIE ET LES SCALAIRES   ',/,&
'  ========================================================   ',/)
 1070 format(/,                                                   &
 '------------------------------------------------------------',/,&
                                                              /,/,&
 ' RESOLUTION DES TRANSFERTS THERMIQUES RADIATIFS             ',/,&
'  ==============================================             ',/)
 4010 format(/,                                                   &
' ** TEMPS POUR LA DISTANCE A LA PAROI : ',E14.5               ,/,&
'    ---------------------------------                        ',/)

#else

 1000 format(/,                                                   &
' ------------------------------------------------------------',/,&
                                                              /,/,&
'  INITIALISATIONS                                            ',/,&
'  ===============                                            ',/)
 1010 format(/,                                                   &
' ------------------------------------------------------------',/,&
                                                              /,/,&
'  COMPUTATION OF PHYSICAL QUANTITIES                         ',/,&
'  ==================================                         ',/)
 1020 format(/,                                                   &
' ------------------------------------------------------------',/,&
                                                              /,/,&
'  COMPUTATION OF CFL, FOURIER AND VARIABLE DT                ',/,&
'  ===========================================                ',/)
 1030 format(/,                                                   &
' ------------------------------------------------------------',/,&
                                                              /,/,&
'  SETTING UP THE BOUNDARY CONDITIONS                         ',/,&
'  ==================================                         ',/)
 1040 format(/,                                                   &
' ------------------------------------------------------------',/,&
                                                              /,/,&
'  SOLVING NAVIER-STOKES EQUATIONS                            ',/,&
'  ===============================                            ',/)
 1050 format(/,                                                   &
' ------------------------------------------------------------',/,&
                                                              /,/,&
'  SOLVING TURBULENT VARIABLES EQUATIONS                      ',/,&
'  =====================================                      ',/)
 1060 format(/,                                                   &
' ------------------------------------------------------------',/,&
                                                              /,/,&
'  SOLVING ENERGY AND SCALARS EQUATIONS                       ',/,&
'  ====================================                       ',/)
 1070 format(/,                                                   &
 '------------------------------------------------------------',/,&
                                                              /,/,&
 ' SOLVING THERMAL RADIATIVE TRANSFER                         ',/,&
'  ==================================                         ',/)

 4010 format(/,                                                   &
' ** TIME FOR THE WALL DISTANCE: ',E14.5                       ,/,&
'    ---------------------------                              ',/)

#endif

!----
! FIN
!----

end subroutine
