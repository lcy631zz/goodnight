@echo off
REM ============================================================
REM  goodnight forum - one-click Flutter Web build script (本地构建)
REM  Usage: close WorkBuddy, then double-click this file.
REM  仅用于本地生成网页产物（build/web）。部署请 git push 到 main，
REM  GitHub Actions 会自动构建并上线到 Netlify，无需手动拖拽。
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

REM 4. deliver: 确认产物并复制 SPA 跳转规则（仅本地构建，部署走 GitHub Actions 自动上线）
if exist "%OUT%\index.html" (
  echo [%TIME%] BUILD_OK >> "%LOG%"
  echo.
  echo ============================================================
  echo   BUILD SUCCESS! Website files are at:
  echo   %OUT%
  echo.
  echo   部署方式：本仓库已接入 GitHub Actions 自动部署。
  echo   把代码 git push 到 main 分支，Netlify 会自动重新构建并上线，
  echo   无需再手动拖拽。线上地址：https://goodnight12.netlify.app
  echo ============================================================
  REM copy SPA redirect rules so deep links work if served locally
  copy /Y "%~dp0_redirects" "%OUT%\_redirects" >nul 2>nul
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
