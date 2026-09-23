@echo off
setlocal enabledelayedexpansion
rem ---------------------------------------------------------------------------
rem  Types the cheat word into Officer Choi on the running Android emulator.
rem
rem      cheat-unlock.bat            types "papers"
rem      cheat-unlock.bat papers     the same thing, said out loud
rem
rem  IT IS A TOGGLE. Run it once to unlock every mission, the Toronto Pearson
rem  encounter and the [locked] dialogue branches; run it again to put the
rem  season back exactly as it was.
rem
rem  IT ONLY REGISTERS ON THE MISSION SELECT SCREEN. That is where the key
rem  handler lives. Sent from the main menu or mid-conversation the letters go
rem  nowhere, so this reads the game's own log back to say which way it went.
rem
rem  WHY THIS DOES NOT HARDCODE emulator-5554. The port changes when the
rem  emulator restarts, and an audio service intermittently squats a nearby one,
rem  which adb lists as a second "offline" emulator. With two entries a bare adb
rem  command fails with "more than one device/emulator", so the booted one is
rem  found here and named explicitly.
rem
rem  TWO THINGS THIS DELIBERATELY AVOIDS:
rem    * "timeout" dies with "Input redirection is not supported" whenever the
rem      script is run non-interactively. ping is the portable wait.
rem    * a for /f wrapping a PIPED command with a quoted exe path cannot launch
rem      ("The filename, directory name, or volume label syntax is incorrect"),
rem      and its failure looks exactly like the cheat not working. The log goes
rem      through a temp file instead.
rem ---------------------------------------------------------------------------

set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
if not exist "%ADB%" (
    echo Could not find adb at:
    echo   %ADB%
    exit /b 1
)

set "WORD=%~1"
if "%WORD%"=="" set "WORD=papers"

set "LOG=%TEMP%\choi_cheat_log.txt"
set "HIT=%TEMP%\choi_cheat_hit.txt"

rem Only lines whose second column is exactly "device" are real and booted.
rem "offline" and "unauthorized" entries are skipped, as is the header line.
set "SERIAL="
for /f "tokens=1,2" %%a in ('"%ADB%" devices') do (
    if "%%b"=="device" set "SERIAL=%%a"
)

if "%SERIAL%"=="" (
    echo No booted emulator. Start one first, then run this again.
    echo.
    "%ADB%" devices
    exit /b 1
)

echo Device: %SERIAL%

"%ADB%" -s %SERIAL% shell pidof com.example.officerchoi >nul 2>&1
if errorlevel 1 (
    echo Officer Choi is not running on that device - start the game first.
    exit /b 1
)

rem Note where the log already ends, so an OLD toggle is never mistaken for
rem this one. Without this the script happily reports yesterday's success.
set "BEFORE="
"%ADB%" -s %SERIAL% logcat -d -t 400 > "%LOG%" 2>nul
findstr /C:"cheat: missions" "%LOG%" > "%HIT%" 2>nul
for /f "usebackq tokens=*" %%l in ("%HIT%") do set "BEFORE=%%l"

"%ADB%" -s %SERIAL% shell input text %WORD%

rem A beat for the game to react. ping, not timeout - see the note above.
ping -n 3 127.0.0.1 >nul 2>&1

set "AFTER="
"%ADB%" -s %SERIAL% logcat -d -t 400 > "%LOG%" 2>nul
findstr /C:"cheat: missions" "%LOG%" > "%HIT%" 2>nul
for /f "usebackq tokens=*" %%l in ("%HIT%") do set "AFTER=%%l"

echo.
if "%AFTER%"=="" goto :nochange
if "%AFTER%"=="%BEFORE%" goto :nochange

rem The line reads:
rem   09-14 20:33:07.123  5730  5873 I godot   : cheat: missions all unlocked
rem so splitting on ":" hits the TIMESTAMP first and prints "33". Strip
rem everything up to and including the marker instead of tokenising on a
rem character the line already uses three times.
set "SAID=!AFTER:*cheat: missions=!"
echo Sent "%WORD%" - missions!SAID!
goto :done

:nochange
echo Sent "%WORD%", but the game did not report a change.
echo You are probably not on the mission select screen - go there and retry.

:done
del "%LOG%" >nul 2>&1
del "%HIT%" >nul 2>&1
endlocal
