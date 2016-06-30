; Script generated by the Inno Setup Script Wizard.
; SEE THE DOCUMENTATION FOR DETAILS ON CREATING INNO SETUP SCRIPT FILES!

;-------------------------------------------------------------------------------

; This file is part of Code_Saturne, a general-purpose CFD tool.
;
; Copyright (C) 1998-2016 EDF S.A.
;
; This program is free software; you can redistribute it and/or modify it under
; the terms of the GNU General Public License as published by the Free Software
; Foundation; either version 2 of the License, or (at your option) any later
; version.
;
; This program is distributed in the hope that it will be useful, but WITHOUT
; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
; FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
; details.
;
; You should have received a copy of the GNU General Public License along with
; this program; if not, write to the Free Software Foundation, Inc., 51 Franklin
; Street, Fifth Floor, Boston, MA 02110-1301, USA.

;-------------------------------------------------------------------------------

#define MyAppName "Code_Saturne"
#define MyAppVersion "4.0"
#define MyAppVersionFull "4.0.5"
#define MyAppVersionShort "4.0"
#define MyAppPublisher "EDF"
#define MyAppCopyright "Copyright (C) 1998-2016 EDF S.A."
#define MyAppURL "http://www.code-saturne.org/"
#define MyAppExeName "code_saturne.exe"

#define HAVE_CGNS "yes"
#define HAVE_HDF5 "yes"
#define HAVE_LIBXML2 "yes"
#define HAVE_MED "yes"
#define HAVE_METIS "yes"
#define HAVE_MPI "yes"
#define HAVE_SCOTCH "yes"

#define HAVE_SALOME "yes"

#define GCC_VERSION "4.4.5"
#define PYTHON_VERSION ""

#define Install ""
#define MinGW "C:\MinGW"
#define CxFreeze "\build\exe.win32-" + PYTHON_VERSION

#ifexist Install + "\share\doc\code_saturne\user.pdf"
  #define HAVE_PDF "yes"
#else
  #define HAVE_PDF "no"
#endif
#ifexist Install + "\share\doc\code_saturne\doxygen\src\index.html"
  #define HAVE_DOXYGEN "yes"
#else
  #define HAVE_DOXYGEN "no"
#endif
#ifexist Install + "\share\doc\salome\gui\CFDSTUDY\index.html"
  #define HAVE_SPHINX "yes"
#else
  #define HAVE_SPHINX "no"
#endif
#ifexist Install + "\share\locale\fr\LC_MESSAGES\code_saturne.mo"
  #define HAVE_LOCALE "yes"
#else
  #define HAVE_LOCALE "no"
#endif

;-------------------------------------------------------------------------------

[Setup]
; NOTE: The value of AppId uniquely identifies this application.
; Do not use the same AppId value in installers for other applications.
; (To generate a new GUID, click Tools | Generate GUID inside the IDE.)
AppId={{51C212F8-B939-4F9C-A67B-5532202851BD}
AppName={#MyAppName}
AppVersion={#MyAppVersionFull}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={pf}\{#MyAppName}\{#MyAppVersionShort}
DefaultGroupName={#MyAppName} {#MyAppVersionShort}
LicenseFile={#Install}\share\code_saturne\COPYING
OutputBaseFilename={#MyAppName} {#MyAppVersionFull} win32
Compression=lzma
SolidCompression=yes

;-------------------------------------------------------------------------------

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

;-------------------------------------------------------------------------------

[Components]
Name: "core"; Description: "Code_Saturne main files"; Types: full compact custom; Flags: checkablealone fixed
#if HAVE_SALOME == "yes"
Name: "salome"; Description: "Code_Saturne SALOME plugin"; Types: full
#endif
Name: "help"; Description: "Code_Saturne Help files"; Types: full compact
#if HAVE_PDF == "yes"
Name: "help\pdf"; Description: "Documentation manuals"; Types: full compact
#endif
#if HAVE_DOXYGEN == "yes"
Name: "help\doxygen"; Description: "Source code documentation"; Types: full
#endif
Name: "dev"; Description: "Development tools, headers and libraries"; Types: full
Name: "dev\saturne"; Description: "Code_Saturne"; Types: full
Name: "dev\system"; Description: "System files"; Types: full
Name: "dev\binutils"; Description: "GNU Binutils"; Types: full
Name: "dev\gcc"; Description: "GNU Compiler Collection"; Types: full
#if HAVE_CGNS == "yes"
Name: "dev\cgns"; Description: "CGNS"; Types: full
#define CGNSPATH ""
#endif
#if HAVE_HDF5 == "yes"
Name: "dev\hdf5"; Description: "HDF5"; Types: full
#define HDF5PATH ""
#endif
#if HAVE_LIBXML2 == "yes"
Name: "dev\libxml2"; Description: "LibXML2"; Types: full
#define LIBXML2PATH ""
#endif
#if HAVE_MED == "yes"
Name: "dev\med"; Description: "MED"; Types: full
#define MEDPATH ""
#endif
#if HAVE_METIS == "yes"
Name: "dev\metis"; Description: "Metis"; Types: full
#define METISPATH ""
#endif
#if HAVE_MPI == "yes"
Name: "dev\mpi"; Description: "MPI"; Types: full
#define MPIPATH ""
#endif
#if HAVE_SCOTCH == "yes"
Name: "dev\scotch"; Description: "Scotch"; Types: full
#define SCOTCHPATH ""
#endif

;-------------------------------------------------------------------------------

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

;-------------------------------------------------------------------------------

[Files]
; NOTE: Don't use "Flags: ignoreversion" on any shared system files
; Low-level dependencies (zlib, gettext, pthread, ...)
Source: "{#MinGW}\bin\libiconv-2.dll"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: core
Source: "{#MinGW}\bin\libintl-8.dll"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: core
Source: "{#MinGW}\bin\libz-1.dll"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: core
Source: "{#MinGW}\bin\pthreadGC2.dll"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: core
; Windows CRT DLL
Source: "C:\Windows\System32\msvcrt.dll"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: core
; GCC runtime
Source: "{#MinGW}\bin\libgcc_s_dw2-1.dll"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: core
Source: "{#MinGW}\bin\libgfortran-3.dll"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: core
Source: "{#MinGW}\bin\libquadmath-0.dll"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: core
Source: "{#MinGW}\bin\libstdc++-6.dll"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: core
; GCC executables
Source: "{#MinGW}\bin\cpp.exe"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: dev\gcc
Source: "{#MinGW}\bin\g++.exe"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: dev\gcc
Source: "{#MinGW}\bin\gcc.exe"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: dev\gcc
Source: "{#MinGW}\bin\gfortran.exe"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: dev\gcc
Source: "{#MinGW}\bin\libgomp-1.dll"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: dev\gcc
Source: "{#MinGW}\bin\libgmp-10.dll"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: dev\gcc
Source: "{#MinGW}\bin\libgmpxx-4.dll"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: dev\gcc
Source: "{#MinGW}\bin\libmpc-2.dll"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: dev\gcc
Source: "{#MinGW}\bin\libmpfr-1.dll"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: dev\gcc
Source: "{#MinGW}\lib\gcc\mingw32\{#GCC_VERSION}\*"; DestDir: "{app}\lib\gcc\mingw32\{#GCC_VERSION}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: dev\gcc
Source: "{#MinGW}\libexec\gcc\mingw32\{#GCC_VERSION}\*"; DestDir: "{app}\libexec\gcc\mingw32\{#GCC_VERSION}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: dev\gcc
; Binutils
Source: "{#MinGW}\bin\addr2line.exe"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: dev\binutils
Source: "{#MinGW}\bin\ar.exe"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: dev\binutils
Source: "{#MinGW}\bin\as.exe"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: dev\binutils
Source: "{#MinGW}\bin\c++filt.exe"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: dev\binutils
Source: "{#MinGW}\bin\dlltool.exe"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: dev\binutils
Source: "{#MinGW}\bin\dllwrap.exe"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: dev\binutils
Source: "{#MinGW}\bin\elfedit.exe"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: dev\binutils
Source: "{#MinGW}\bin\gprof.exe"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: dev\binutils
Source: "{#MinGW}\bin\ld.bfd.exe"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: dev\binutils
Source: "{#MinGW}\bin\ld.exe"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: dev\binutils
Source: "{#MinGW}\bin\nm.exe"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: dev\binutils
Source: "{#MinGW}\bin\objcopy.exe"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: dev\binutils
Source: "{#MinGW}\bin\objdump.exe"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: dev\binutils
Source: "{#MinGW}\bin\ranlib.exe"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: dev\binutils
Source: "{#MinGW}\bin\readelf.exe"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: dev\binutils
Source: "{#MinGW}\bin\size.exe"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: dev\binutils
Source: "{#MinGW}\bin\strings.exe"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: dev\binutils
Source: "{#MinGW}\bin\strip.exe"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: dev\binutils
Source: "{#MinGW}\bin\windmc.exe"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: dev\binutils
Source: "{#MinGW}\bin\windres.exe"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: dev\binutils
Source: "{#MinGW}\include\ansidecl.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\binutils
Source: "{#MinGW}\include\bfd.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\binutils
Source: "{#MinGW}\include\bfdlink.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\binutils
Source: "{#MinGW}\include\dis-asm.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\binutils
Source: "{#MinGW}\include\symcat.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\binutils
Source: "{#MinGW}\lib\libbfd.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\binutils
Source: "{#MinGW}\lib\libiberty.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\binutils
Source: "{#MinGW}\lib\libopcodes.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\binutils
; MinGW system headers and libraries
Source: "{#MinGW}\include\_mingw.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\assert.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\complex.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\conio.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\ctype.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\dir.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\direct.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\dirent.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\dos.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\errno.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\excpt.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\fcntl.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\fenv.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\float.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\getopt.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\gmon.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\inttypes.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\io.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\libgen.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\limits.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\locale.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\malloc.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\math.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\mbctype.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\mbstring.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\mem.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\memory.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\process.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\profil.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\profile.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\search.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\setjmp.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\share.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\signal.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\stdint.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\stdio.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\stdlib.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\string.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\strings.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\sys\*"; DestDir: "{app}\include\sys"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: dev\system
Source: "{#MinGW}\include\tchar.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\time.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\unistd.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\utime.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\values.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\varargs.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\wchar.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\include\wctype.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\CRT_fp10.o"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\CRT_fp8.o"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\CRT_noglob.o"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\binmode.o"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\crt1.o"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\crt2.o"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\crtmt.o"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\crtst.o"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\dllcrt1.o"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\dllcrt2.o"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\gcrt1.o"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\gcrt2.o"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\libcoldname.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\libcrtdll.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\libgmon.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\libm.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\libmingw32.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\libmingwex.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\libmingwthrd.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\libmingwthrd_old.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\libmoldname.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\libmoldname100.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\libmoldname100d.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\libmoldname70.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\libmoldname70d.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\libmoldname71.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\libmoldname71d.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\libmoldname80.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\libmoldname80d.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\libmoldname90.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\libmoldname90d.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\libmoldnamed.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\libmsvcr100.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\libmsvcr100d.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\libmsvcr70.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\libmsvcr70d.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\libmsvcr71.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\libmsvcr71d.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\libmsvcr80.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\libmsvcr80d.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\libmsvcr90.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\libmsvcr90d.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\libmsvcrt.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\libmsvcrtd.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
Source: "{#MinGW}\lib\txtmode.o"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\system
; Pre-requisites
#if HAVE_CGNS == "yes"
Source: "{#MinGW}\bin\libcgns.dll"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: core
Source: "{#MinGW}\include\cgns_io.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\cgns
Source: "{#MinGW}\include\cgnslib.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\cgns
Source: "{#MinGW}\include\cgnstypes.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\cgns
Source: "{#MinGW}\lib\libcgns.dll.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\cgns
#endif
#if HAVE_HDF5 == "yes"
Source: "{#MinGW}\bin\libhdf5-7.dll"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: core
Source: "{#MinGW}\include\hdf5.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\hdf5
Source: "{#MinGW}\include\H5*.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\hdf5
Source: "{#MinGW}\lib\libhdf5.dll.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\hdf5
#endif
#if HAVE_LIBXML2 == "yes"
Source: "{#MinGW}\bin\libxml2-2.dll"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: core
Source: "{#MinGW}\include\libxml2\*"; DestDir: "{app}\include\libxml2"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: dev\libxml2
Source: "{#MinGW}\lib\libxml2.dll.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\libxml2
#endif
#if HAVE_MED == "yes"
Source: "{#MinGW}\bin\libmedC-1.dll"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: core
Source: "{#MinGW}\include\med.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\med
Source: "{#MinGW}\include\med_proto.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\med
Source: "{#MinGW}\include\medC_win_dll.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\med
Source: "{#MinGW}\lib\libmedC.dll.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\med
#endif
#if HAVE_METIS == "yes"
Source: "{#MinGW}\bin\libmetis.dll"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: core
Source: "{#MinGW}\include\metis.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\metis
Source: "{#MinGW}\lib\libmetis.dll.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\metis
#endif
#if HAVE_MPI == "yes"
Source: "{#MinGW}\bin\mpicsync.exe"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: core
Source: "{#MinGW}\bin\mpiexec.exe"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: core
Source: "{#MinGW}\bin\msmpi.dll"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: core
Source: "{#MinGW}\bin\smpd.exe"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: core
Source: "{#MinGW}\include\mpi.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\mpi
Source: "{#MinGW}\lib\libmsmpi.dll.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\mpi
#endif
#if HAVE_SCOTCH == "yes"
Source: "{#MinGW}\bin\libscotch.dll"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: core
Source: "{#MinGW}\bin\libscotcherr.dll"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: core
Source: "{#MinGW}\include\scotch.h"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\scotch
Source: "{#MinGW}\lib\libscotch.dll.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\scotch
Source: "{#MinGW}\lib\libscotcherr.dll.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\scotch
#endif
; Code_Saturne
Source: "{#Install}\bin\libple-0.dll"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: core
Source: "{#Install}\etc\code_saturne.cfg.template"; DestDir: "{commonappdata}\{#MyAppName}\{#MyAppVersionShort}"; DestName: "code_saturne.ini"; Flags: onlyifdoesntexist; Components: core
Source: "{#Install}\etc\code_saturne.cfg.template"; DestDir: "{userappdata}\{#MyAppName}\{#MyAppVersionShort}"; DestName: "code_saturne.ini"; Flags: onlyifdoesntexist; Components: core
Source: "{#Install}\include\code_saturne\*"; DestDir: "{app}\include\code_saturne"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: dev\saturne
Source: "{#Install}\include\ple_*"; DestDir: "{app}\include"; Flags: ignoreversion; Components: dev\saturne
Source: "{#Install}\lib\libple.dll.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\saturne
Source: "{#Install}\lib\libsaturne.a"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: dev\saturne
Source: "{#Install}\libexec\code_saturne\cs_check_syntax.exe"; DestDir: "{app}\libexec\code_saturne"; Flags: ignoreversion; Components: core
Source: "{#Install}\libexec\code_saturne\cs_io_dump.exe"; DestDir: "{app}\libexec\code_saturne"; Flags: ignoreversion; Components: core
Source: "{#Install}\libexec\code_saturne\cs_preprocess.exe"; DestDir: "{app}\libexec\code_saturne"; Flags: ignoreversion; Components: core
Source: "{#Install}\libexec\code_saturne\cs_solver.exe"; DestDir: "{app}\libexec\code_saturne"; Flags: ignoreversion; Components: core
Source: "{#Install}\share\code_saturne\*"; DestDir: "{app}\share\code_saturne"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: core
#if HAVE_PDF == "yes"
Source: "{#Install}\share\doc\code_saturne\autovnv.pdf"; DestDir: "{app}\share\doc\code_saturne"; Flags: ignoreversion; Components: help\pdf
Source: "{#Install}\share\doc\code_saturne\developer.pdf"; DestDir: "{app}\share\doc\code_saturne"; Flags: ignoreversion; Components: help\pdf
Source: "{#Install}\share\doc\code_saturne\install.pdf"; DestDir: "{app}\share\doc\code_saturne"; Flags: ignoreversion; Components: help\pdf
Source: "{#Install}\share\doc\code_saturne\refcard.pdf"; DestDir: "{app}\share\doc\code_saturne"; Flags: ignoreversion; Components: help\pdf
Source: "{#Install}\share\doc\code_saturne\theory.pdf"; DestDir: "{app}\share\doc\code_saturne"; Flags: ignoreversion; Components: help\pdf
Source: "{#Install}\share\doc\code_saturne\user.pdf"; DestDir: "{app}\share\doc\code_saturne"; Flags: ignoreversion; Components: help\pdf
#endif
#if HAVE_DOXYGEN == "yes"
Source: "{#Install}\share\doc\code_saturne\doxygen\src\*"; DestDir: "{app}\share\doc\code_saturne\doxygen\src"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: help\doxygen
#endif
#if HAVE_LOCALE == "yes"
Source: "{#Install}\share\locale\*"; DestDir: "{app}\share\locale"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: core
#endif
; Graphical user interface (generated by cx_freeze)
Source: "{#CxFreeze}\code_saturne.com"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: core
Source: "{#CxFreeze}\code_saturne.exe"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: core
Source: "{#CxFreeze}\_hashlib.pyd"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: core
Source: "{#CxFreeze}\_socket.pyd"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: core
Source: "{#CxFreeze}\_ssl.pyd"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: core
Source: "{#CxFreeze}\bz2.pyd"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: core
Source: "{#CxFreeze}\library.zip"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: core
Source: "{#CxFreeze}\pyexpat.pyd"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: core
Source: "{#CxFreeze}\PyQt4.Qtcore.pyd"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: core
Source: "{#CxFreeze}\PyQt4.QtGui.pyd"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: core
Source: "{#CxFreeze}\python27.dll"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: core
Source: "{#CxFreeze}\Qtcore4.dll"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: core
Source: "{#CxFreeze}\QtGui4.dll"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: core
Source: "{#CxFreeze}\select.pyd"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: core
Source: "{#CxFreeze}\sip.pyd"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: core
Source: "{#CxFreeze}\unicodedata.pyd"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: core
Source: "{#CxFreeze}\translations\*"; DestDir: "{app}\translations"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: core
; SALOME plugin
#if HAVE_SALOME == "yes"
Source: "{#Install}\bin\SalomeIDLCFDSTUDY-0.dll"; DestDir: "{app}\bin"; Flags: ignoreversion; Components: salome
Source: "{#Install}\lib\python{#PYTHON_VERSION}\site-packages\code_saturne\*"; DestDir: "{app}\lib\python{#PYTHON_VERSION}\site-packages\code_saturne"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: salome
Source: "{#Install}\lib\python{#PYTHON_VERSION}\site-packages\salome\*"; DestDir: "{app}\lib\python{#PYTHON_VERSION}\site-packages\salome"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: salome
Source: "{#Install}\lib\salome\SalomeIDLCFDSTUDY.dll.lib"; DestDir: "{app}\lib\salome"; Flags: ignoreversion; Components: salome
Source: "{#Install}\share\salome\resources\cfdstudy\*"; DestDir: "{app}\share\salome\resources\cfdstudy"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: salome
#if HAVE_SPHINX == "yes"
Source: "{#Install}\share\doc\salome\gui\CFDSTUDY\*"; DestDir: "{app}\share\doc\salome\gui\CFDSTUDY"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: salome
#endif
#endif

;-------------------------------------------------------------------------------

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\bin\{#MyAppExeName}"
Name: "{group}\{cm:ProgramOnTheWeb,{#MyAppName}}"; Filename: "{#MyAppURL}"
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\bin\{#MyAppExeName}"; WorkingDir: "{userdesktop}"; Tasks: desktopicon
#if HAVE_PDF == "yes"
Name: "{group}\theory.pdf"; Filename: "{app}\share\doc\code_saturne\theory.pdf"
Name: "{group}\autovnv.pdf"; Filename: "{app}\share\doc\code_saturne\autovnv.pdf"
Name: "{group}\refcard.pdf"; Filename: "{app}\share\doc\code_saturne\refcard.pdf"
Name: "{group}\theory.pdf"; Filename: "{app}\share\doc\code_saturne\theory.pdf"
Name: "{group}\user.pdf"; Filename: "{app}\share\doc\code_saturne\user.pdf"
#endif
#if HAVE_DOXYGEN == "yes"
Name: "{group}\doxygen"; Filename: "{app}\share\doc\code_saturne\doxygen\src\index.html"
#endif

;-------------------------------------------------------------------------------

[Run]
Filename: "{app}\bin\{#MyAppExeName}"; WorkingDir: "{userdesktop}"; Flags: nowait postinstall skipifsilent; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"