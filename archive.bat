@echo off

setlocal

set "dir=%~dp0"

set "archiveName=%~1"
set "outputDir=%dir%\pack"

set "os=%RUNNER_OS%"
if "%os%"=="" (
  set "os=Windows"
)

if "%archiveName%"=="" (
  if "%RUNNER_ARCH%"=="X86" (
    set "arch=x86"
  ) else if "%RUNNER_ARCH%"=="X64" (
    set "arch=x64"
  ) else if "%RUNNER_ARCH%"=="ARM64" (
    set "arch=arm64"
  ) else if "%RUNNER_ARCH%"=="ARM" (
    set "arch=arm"
  ) else (
    if "%PROCESSOR_ARCHITECTURE%"=="x86" (
      set "arch=x86"
    ) else if "%PROCESSOR_ARCHITECTURE%"=="ARM64" (
      set "arch=arm64"
    ) else (
      set "arch=x64"
    )
  )

  set "archive=v8_%os%_%arch%.7z"
) else (
  set "archive=%archiveName%.7z"
)

if not exist "%outputDir%" (
  mkdir "%outputDir%"
)

xcopy "%dir%\v8\out\release" "%outputDir%" /s /e /y
if errorlevel 1 (
  echo Failed to copy build output.
  exit /b 1
)

rem Fail instead of shipping a bogus archive when the build did not produce V8.
for %%f in (d8.exe v8.dll) do (
  if not exist "%outputDir%\%%f" (
    echo Expected %%f is missing from the build output.
    exit /b 1
  )
)

rmdir "%outputDir%\gen" /s /q
rmdir "%outputDir%\obj" /s /q

where 7z >nul 2>nul
if errorlevel 1 (
  echo 7z not found
  exit /b %errorlevel%
)

pushd "%outputDir%"

call 7z a -r "%dir%\%archive%" .
if errorlevel 1 (
  echo Failed to archive.
  exit /b 1
)

7z l "%dir%\%archive%" | findstr /i /c:"v8.dll" >nul
if errorlevel 1 (
  echo Archive does not contain v8.dll.
  exit /b 1
)

popd

dir "%dir%\%archive%"

endlocal
