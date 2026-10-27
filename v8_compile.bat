@echo off

setlocal

set "dir=%~dp0"
set "v8Dir=%dir%\v8"

if not exist "%v8Dir%" (
  echo V8 not found at %v8Dir%
  exit /b 1
)

set "depotToolsDir=%v8Dir%\third_party\depot_tools"

if not exist "%depotToolsDir%" (
  set "depotToolsDir=%dir%\depot_tools"
)

set "Path=%depotToolsDir%;%Path%"

rem Newer depot_tools wrappers need the bundled Python that win_tools.bat installs;
rem v8\third_party\depot_tools is a separate checkout that is never bootstrapped.
if not exist "%depotToolsDir%\python3_bin_reldir.txt" (
  call "%depotToolsDir%\bootstrap\win_tools.bat"
  if errorlevel 1 exit /b 1
)

set "DEPOT_TOOLS_WIN_TOOLCHAIN=0"

set "os=%RUNNER_OS%"
if "%os%"=="" (
  set "os=Windows"
)

if "%RUNNER_ARCH%"=="X86" (
  set "targetCpu=x86"
) else if "%RUNNER_ARCH%"=="ARM64" (
  set "targetCpu=arm64"
) else if "%RUNNER_ARCH%"=="X64" (
  set "targetCpu=x64"
) else if "%RUNNER_ARCH%"=="ARM" (
  set "targetCpu=arm"
) else (
  if "%PROCESSOR_ARCHITECTURE%"=="x86" (
    set "targetCpu=x86"
  ) else if "%PROCESSOR_ARCHITECTURE%"=="ARM64" (
    set "targetCpu=arm64"
  ) else (
    set "targetCpu=x64"
  )
)

echo Building V8 for %os% %targetCpu%

setlocal EnableDelayedExpansion

set "gnArgs="

for /F "usebackq delims=" %%i in ("%dir%\args\%os%.gn") do (
  set "line=%%i"

  if not "!line!"=="" if not "!line:~0,1!"=="#" (
    set "line=!line:"=""!"
    set "gnArgs=!gnArgs!!line! "
  )
)

endlocal & set "gnArgs=%gnArgs%"

set "ccWrapper="

where sccache >nul 2>nul
if not errorlevel 1 (
  set "ccWrapper=sccache"
)

set "gnArgs=%gnArgs%cc_wrapper=""%ccWrapper%"" target_cpu=""%targetCpu%"" v8_target_cpu=""%targetCpu%"""

pushd "%dir%\v8"

rem Do not trust the exit code of the gn.bat wrapper alone: require fresh build files.
if exist ".\out\release\build.ninja" del ".\out\release\build.ninja"

call gn gen ".\out\release" --args="%gnArgs%"
if errorlevel 1 (
  echo Failed to generate build files.
  exit /b 1
)
if not exist ".\out\release\build.ninja" (
  echo Failed to generate build files: build.ninja not found.
  exit /b 1
)

echo ==================== Build args start ====================
call gn args ".\out\release" --list > "%dir%\gn-args_%os%.txt"
type "%dir%\gn-args_%os%.txt"
echo ==================== Build args end ====================

call ninja -C ".\out\release" -j %NUMBER_OF_PROCESSORS% d8
if errorlevel 1 (
  echo Build failed.
  exit /b 1
)
if not exist ".\out\release\d8.exe" (
  echo Build failed: d8.exe not found.
  exit /b 1
)

dir ".\out\release\"

popd

endlocal
