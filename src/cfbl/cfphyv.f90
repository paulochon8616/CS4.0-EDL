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

subroutine cfphyv &
!================

 ( propce )

!===============================================================================
! FONCTION :
! --------

! ROUTINE PHYSIQUE PARTICULIERE : COMPRESSIBLE SANS CHOC

! Calcul des proprietes physiques variables


! Arguments
!__________________.____._____.________________________________________________.
! name             !type!mode ! role                                           !
!__________________!____!_____!________________________________________________!
! propce(ncelet, *)! ra ! <-- ! physical properties at cell centers            !
!__________________!____!_____!________________________________________________!

!     TYPE : E (ENTIER), R (REEL), A (ALPHANUMERIQUE), T (TABLEAU)
!            L (LOGIQUE)   .. ET TYPES COMPOSES (EX : TR TABLEAU REEL)
!     MODE : <-- donnee, --> resultat, <-> Donnee modifiee
!            --- tableau de travail
!===============================================================================

!===============================================================================
! Module files
!===============================================================================

use paramx
use numvar
use optcal
use cstphy
use cstnum
use entsor
use ppppar
use ppthch
use ppincl
use mesh
use field

!===============================================================================

implicit none

! Arguments

double precision propce(ncelet,*)

! Local variables

integer :: iel, ifcven, ifclam
double precision, dimension(:), pointer :: cpro_venerg, cpro_lambda

!===============================================================================

!===============================================================================
! 1. Update Lambda/Cv
!===============================================================================

! On a v�rifi� auparavant que CV0 �tait non nul.
! Si CV variable est nul, c'est une erreur utilisateur. On fait
!     un test � tous les passages (pas optimal), sachant que pour
!     le moment, on est en gaz parfait avec CV constant : si quelqu'un
!     essaye du CV variable, ce serait dommage que cela lui explose � la
!     figure pour de mauvaises raisons.
! Si la diffusivite de ienerg est constante, celle de itempk est forcement
!     constante ainsi que ICV.EQ.0, par construction dans
!     le sous-programme cfvarp

call field_get_key_int (ivarfl(isca(ienerg)), kivisl, ifcven)
if (ifcven.ge.0) then

  call field_get_val_s(ifcven, cpro_venerg)

  call field_get_key_int (ivarfl(isca(itempk)), kivisl, ifclam)
  if (ifclam.ge.0) then
    call field_get_val_s(ifclam, cpro_lambda)
    do iel = 1, ncel
      cpro_venerg(iel) = cpro_lambda(iel)
    enddo
  else
    do iel = 1, ncel
      cpro_venerg(iel) = visls0(itempk)
    enddo

  endif

  if (icv.gt.0) then

    do iel = 1, ncel
      if(propce(iel,ipproc(icv)).le.0.d0) then
        write(nfecra,2000)iel,propce(iel,ipproc(icv))
        call csexit (1)
        !==========
      endif
    enddo

    do iel = 1, ncel
      cpro_venerg(iel) = cpro_venerg(iel) / propce(iel,ipproc(icv))
    enddo

  else

    do iel = 1, ncel
      cpro_venerg(iel) = cpro_venerg(iel) / cv0
    enddo

  endif

else

  visls0(ienerg) = visls0(itempk)/cv0

endif

!--------
! Formats
!--------

 2000 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''EXECUTION (MODULE COMPRESSIBLE)  ',/,&
'@    =========                                               ',/,&
'@                                                            ',/,&
'@  La capacit� calorifique � volume constant pr�sente (au    ',/,&
'@    moins) une valeur n�gative ou nulle :                   ',/,&
'@    cellule ',I10,   '  Cv = ',E18.9                         ,/,&
'@                                                            ',/,&
'@  Le calcul ne sera pas execute.                            ',/,&
'@                                                            ',/,&
'@  Verifier usphyv.                                          ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)


!----
! End
!----

return
end subroutine
