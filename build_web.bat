@echo off
REM ============================================================
REM  goodnight forum - one-click Flutter Web build script
REM  Usage: close WorkBuddy, then double-click this file.
REM  After the build finishes, the build/web folder opens.
REM  Drag that whole folder into Netlify (drop page) to go live.
REM ============================================================
REM Self-protection: if not a persistent console, relaunch self
REM in a cmd /k window so it never flashes away (errors stay visible).
if "%GNW_PERSIST%"=="1" goto :main
set GNW_PERSIST=1
cmd /k "%~f0"
exit /b

:main
set PUB_HOSTED_URL=https://pub.dev
set PUB_CACHE=D:\ai\.pub-cache
set PATH=D:\ai\flutter\bin;%PATH%

set LOG=D:\ai\build_web.log
set SRC=D:\campus goodnight\goodnight
set OUT=D:\campus goodnight\goodnight\build\web

title goodnight web build
cls
echo ============================================================
echo          goodnight WEB build (Flutter Web)
echo ============================================================
echo LOG: %LOG%
echo.
echo NOTE: first build takes a few minutes (downloads + compiles).
echo.

REM 0. check flutter
echo [check] locating flutter...
where flutter >nul 2>nul
if errorlevel 1 (
  echo [ERROR] flutter not found. Make sure D:\ai\flutter is installed.
  goto :end
)

cd /d "%SRC%"

REM 1. enable web platform (idempotent: only creates web/ if missing)
echo [%TIME%] [1/4] enable web platform (flutter create --platforms web)...
call flutter create --platforms web . >> "%LOG%" 2>&1
if errorlevel 1 (
  echo [warn] web enable step had issues, continuing anyway...
)

REM 2. fetch deps
echo [%TIME%] [2/4] flutter pub get...
call flutter pub get >> "%LOG%" 2>&1
if errorlevel 1 goto :fail

REM 3. build web (release)
echo [%TIME%] [3/4] flutter build web --release (first run may take minutes)...
call flutter build web --release >> "%LOG%" 2>&1
if errorlevel 1 goto :fail

REM 4. deliver: open the folder so you can drag it to Netlify
if exist "%OUT%\index.html" (
  echo [%TIME%] BUILD_OK >> "%LOG%"
  echo.
  echo ============================================================
  echo   SUCCESS! Website files are at:
  echo   %OUT%
  echo.
  echo   Next: drag that whole folder into Netlify
  echo   https://app.netlify.com/drop  ->  your site goes live.
  echo ============================================================
  REM copy SPA redirect rules so deep links work on Netlify
  copy /Y "%~dp0_redirects" "%OUT%\_redirects" >nul 2>nul
  explorer "%OUT%"
  echo Opening Netlify drop page in your browser...
  start https://app.netlify.com/drop
  goto :end
) else (
  goto :fail
)

:fail
echo [%TIME%] BUILD_FAIL >> "%LOG%"
echo.
echo ============================================================
echo   BUILD FAILED. See log: %LOG%
echo.
echo   Common fixes:
echo     - Make sure lib/config/supabase_config.dart has your
echo       Supabase URL + anon key filled in.
echo     - Make sure D:\ai\flutter is installed.
echo ============================================================

:end
echo.
echo Press any key to close this window...
pause
