@ECHO off
REM This is the traditional way for Win32 nmake/MSVCxx; 
REM Although at this moment tested with dmake/GCC
IF /I "%1"=="/?" GOTO Usage
FOR %%a IN (h /h -h help /help -help) DO IF /I "%1"=="%%a" GOTO Usage

REM This could be run with AT like:
REM AT 22:25 /EVERY:M,T,W,Th,F,S,Su cd c:\path\to\smoke.bat

REM Change your BuildDir(PS_DB), Config File(PS_CF)
REM and C-Compiler(CCTYPE) here:
SET PS_BD=c:\usr\local\src\bleadperl\perl
SET PS_CF=smokew32.cfg
SET CCTYPE=GCC

REM Set GCC_VERSION here if your shell can't deal with
REM with this stuff. Only applies for for GCC
set GCC_VERSION=
set OS_VERSION=5.0 W2000Pro

REM If you don't want all this fancy checking
REM Just set MK to [dmake | nmake] here
SET MK=

REM Is this hack for WD=`pwd`, CMD.EXE specific?
REM You could also uncomment the SET WD= line (must end with '\'!)
REM and comment this one out
FOR %%I IN ( %0 ) DO SET WD=%%~dpI
REM SET WD=c:\path\to\

REM ############### CHANGES FROM THIS POINT, OLY IF YOU MUST ###############
REM The complete logfile
SET PS_LF=%WD%mktest.log

REM My maker is set, get on with it
IF DEFINED MK GOTO NoSet

:_GCC
    IF NOT "%CCTYPE%"=="GCC" GOTO _BCC
    SET MK=dmake
    IF NOT "%GCC_VERSION%"=="" GOTO Smoke
REM A Windows way to set GCC_VERSION
:GCC_V2_95
    gcc --version | find "2.95" > NUL: 2>&1
    IF ERRORLEVEL 1 GOTO GCC_V3
    FOR /F "usebackq" %%V IN (`gcc --version`) DO SET GCC_VERSION=%%V
goto Smoke
:GCC_V3
    FOR /F "usebackq delims=" %%V IN (`gcc --version`) DO ((ECHO %%V | find "gcc">NUL: 2>&1) && (IF NOT ERRORLEVEL 1 SET GCC_VERSION=%%V))

    IF "%GCC_VERSION%"=="" SET GCC_VERSION=unknown
GOTO Smoke

:_BCC
    IF NOT "%CCTYPE%"=="BORLAND" GOTO _MSVC
    SET MK=dmake
GOTO Smoke

:_MSVC
    REM Check if %CCTYPE% contains MSVC, FIND.EXE will exit(1) if not
    ECHO %CCTYPE% | find "MSVC" > NUL: 2>&1
    IF ERRORLEVEL 1 GOTO Error

    REM Use NMAKE.EXE as default maker for %CCTYPE%
    SET MK=nmake
GOTO Smoke

:NoSet
    ECHO Skipping maker settings(%MK%/%CCTYPE%)...

:Smoke
    ECHO Smoke %PS_BD%
    REM Sanity Check ...
    IF NOT EXIST %PS_BD% (ECHO Can't find %PS_BD%) && GOTO Exit
    
    ECHO Smokelog: builddir is %PS_BD% > %PS_LF%
    PUSHD %PS_BD% > NUL: 2>&1
    IF ERRORLEVEL 1 GOTO Exit

    REM Prepare the source-tree
    (PUSHD win32) && (%MK% -i distclean >NUL: 2>&1) && (POPD)

    IF /I "%1"=="nofetch" (ECHO Skipped rsync) && shift && GOTO _MKTEST
    REM You'll need a working rsync, maybe from cygwin
    rsync -avz --delete ftp.linux.activestate.com::perl-current .>>%PS_LF% 2>&1

:_MKTEST
    IF EXIST %WD%patchperl.bat CALL %WD%patchperl
    IF /I "%1"=="nosmoke" shift && GOTO _MKOVZ

    IF NOT "%GCC_VERSION%"=="" SET GCC_VERSION=gccversion=%GCC_VERSION%
    IF NOT "%OS_VERSION%"==""  SET OS_VERSION=osvers=%OS_VERSION%

    REM Configure, build and test
    perl %WD%mktest.pl -m %MK% -c %CCTYPE% -v 1 %WD%%PS_CF% "%GCC_VERSION%" "%OS_VERSION%" >>%PS_LF% 2>&1
    IF ERRORLEVEL 1 ECHO mktest.pl exited with code %ERRORLEVEL%

:_MKOVZ
    IF /I "%1"=="noreport" shift && GOTO Exit
    REM Create the report and send to: <daily-build@perl.org>
    perl %WD%/mkovz.pl noemail %PS_DB%
    IF ERRORLEVEL 1 ECHO mkovz.pl  exited with code %ERRORLEVEL%
GOTO Exit

:Usage
    ECHO Welcome to "perl core smoke suite"
    ECHO.
    ECHO Usage: %0 [nofetch[ nosmoke[ noreport]]] 
    ECHO.
    ECHO Arguments *must* be in the right order.
    ECHO Any argument can be ommitted.
    ECHO.
    ECHO Have fun!
GOTO Exit

:Error
    ECHO Unknown C Compiler (%CCTYPE%), use [BORLAND,GCC,MSVC,MSVC20,MSVC60]

:Exit
    SET MK=
    SET CCTYPE=
    SET GCC_VERSION=
    SET OS_VERSION=
    SET PS_BD=
    SET PS_CF=
    SET PS_LF=
    SET WD=
    POPD
