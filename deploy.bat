@echo off
setlocal enabledelayedexpansion
title SevenShield - Landingpage Deploy

rem GitHub-Konto, dem das Repo gehoert. Wird fest in die Repo-Adresse
rem eingetragen, damit Git nie ein anderes angemeldetes Konto verwendet.
set KONTO=hagenhofweg13-hub
set REPONAME=sevenshield-landingpage
set SOLL_URL=https://%KONTO%@github.com/%KONTO%/%REPONAME%.git

rem Das Repo liegt je nach Rechner auf C: oder D:.
rem Das Skript nimmt den ersten Pfad, der existiert.
set REPO=
for %%L in (C D) do (
    if not defined REPO (
        if exist "%%L:\09_Internetseite\.git" (
            set REPO=%%L:\09_Internetseite
        )
    )
)

echo ============================================
echo   SevenShield Landingpage - Deploy
echo ============================================
echo.

if not defined REPO (
    echo FEHLER: Repo-Ordner weder auf C: noch auf D: gefunden.
    echo Erwartet: ?:\09_Internetseite
    echo Bitte Pfad im Skript anpassen ^(Schleife "for %%%%L in"^).
    pause
    exit /b 1
)

cd /d "%REPO%"
echo Aktueller Ordner: %CD%
echo.

rem Vorab pruefen, ob Git mit dem Ordner arbeiten kann.
git status >nul 2>&1
if errorlevel 1 (
    echo FEHLER: Git kann in diesem Ordner nicht arbeiten.
    echo Ursache siehe folgende Meldung:
    echo.
    git status
    echo.
    echo Haeufigste Ursache auf Laufwerken ohne Besitzerinformation
    echo ^(z. B. exFAT^): einmalig ausfuehren
    echo   git config --global --add safe.directory %REPO:\=/%
    pause
    exit /b 1
)

rem Repo-Adresse pruefen und bei Bedarf auf das richtige Konto festlegen.
for /f "delims=" %%U in ('git remote get-url origin') do set IST_URL=%%U
if /i not "!IST_URL!"=="%SOLL_URL%" (
    echo Repo-Adresse wird auf das Konto %KONTO% festgelegt ...
    git remote set-url origin %SOLL_URL%
    echo.
)

rem Schutz: Dateien ueber 100 MB lehnt GitHub beim Push ab.
rem Programme wie SevenErase.exe gehoeren ins Release, nicht ins Repo.
set GROSS=
for /r %%F in (*.exe *.zip *.msi) do (
    echo %%F | find /i "\.git\" >nul || (
        if %%~zF GTR 100000000 (
            echo FEHLER: Datei zu gross fuer GitHub ^(ueber 100 MB^):
            echo   %%F
            set GROSS=1
        )
    )
)
if defined GROSS (
    echo.
    echo Bitte diese Datei aus dem Website-Ordner entfernen und
    echo stattdessen als GitHub Release hochladen.
    pause
    exit /b 1
)

echo [1/5] Aenderungen werden vorbereitet ^(git add^) ...
git add -A
echo.

echo Gefundene Aenderungen:
git status --short
echo.

git diff --cached --quiet --exit-code
if !errorlevel!==0 (
    rem Keine neuen Aenderungen. Liegt noch ein alter Commit herum,
    rem der beim letzten Mal nicht hochgeladen wurde?
    git fetch --quiet >nul 2>&1
    set OFFEN=0
    for /f %%N in ('git rev-list --count @{u}..HEAD 2^>nul') do set OFFEN=%%N
    if "!OFFEN!"=="0" (
        echo Keine Aenderungen gefunden - nichts zu tun.
        pause
        exit /b 0
    )
    echo Keine neuen Aenderungen, aber !OFFEN! Commit^(s^) vom letzten Mal
    echo wurden noch nicht hochgeladen. Diese werden jetzt nachgereicht.
    echo.
    goto PULL
)

set DATUM=%date% %time%
echo [2/5] Commit wird erstellt ...
git commit -m "Landingpage Update %DATUM%"
if errorlevel 1 (
    echo Hinweis: Commit evtl. leer oder fehlgeschlagen. Fahre trotzdem fort.
)
echo.

:PULL
echo [3/5] Hole eventuelle Aenderungen vom Server ^(pull --rebase^) ...
git pull --rebase
if errorlevel 1 (
    echo.
    echo ACHTUNG: Abgleich mit GitHub fehlgeschlagen.
    echo Bei einem Konflikt: per "git status" pruefen, danach dieses
    echo Skript erneut starten. Bei "403" oder "Permission denied"
    echo siehe Hinweis zur Anmeldung weiter unten.
    goto NICHT_OK
)
echo.

echo [4/5] Push zu GitHub ...
git push
if errorlevel 1 goto NICHT_OK

rem Gegenprobe: Ist wirklich alles bei GitHub angekommen?
git fetch --quiet >nul 2>&1
set OFFEN=1
for /f %%N in ('git rev-list --count @{u}..HEAD 2^>nul') do set OFFEN=%%N
if not "!OFFEN!"=="0" goto NICHT_OK

echo.
echo [5/5] Fertig.
echo ============================================
echo   OK: Alle Aenderungen sind bei GitHub.
echo   GitHub Pages baut die Seite in der Regel
echo   innerhalb von 1-2 Minuten neu.
echo   Live-Check: https://sevenshield.de/
echo ============================================
echo.
pause
exit /b 0

:NICHT_OK
echo.
echo ############################################
echo   NICHT HOCHGELADEN!
echo   Die Aenderungen liegen nur auf diesem Rechner.
echo ############################################
echo.
echo Haeufigste Ursache: Anmeldung mit dem falschen GitHub-Konto
echo ^(Meldung "403" oder "Permission ... denied to ..."^).
echo So beheben:
echo   1. git credential-manager github logout ^<falsches Konto^>
echo   2. Skript erneut starten
echo   3. Im Fenster "Connect to GitHub" "Sign in with a code" waehlen
echo   4. Code im privaten Browserfenster unter github.com/login/device
echo      eingeben, angemeldet als %KONTO%
echo.
echo Der Commit geht nicht verloren: Beim naechsten Start
echo reicht das Skript ihn automatisch nach.
echo.
pause
exit /b 1
