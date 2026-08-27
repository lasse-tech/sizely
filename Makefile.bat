@echo off
REM ---------------------------------------------------------------------------
REM Sizely ist eine Cinnamon-Extension und laeuft ausschliesslich unter
REM Linux mit dem Cinnamon-Desktop (Muffin/X11). Unter Windows gibt es nichts
REM zu bauen, zu installieren oder zu deployen.
REM
REM Diese Datei existiert nur, weil die Projektkonvention fuer jedes Projekt ein
REM Makefile.bat vorsieht. Sie taeuscht bewusst keine Funktionalitaet vor.
REM ---------------------------------------------------------------------------

echo.
echo   Sizely - Cinnamon-Extension
echo.
echo   Dieses Projekt laesst sich unter Windows nicht bauen oder installieren.
echo   Es benoetigt Cinnamon (Muffin) unter X11, z.B. Linux Mint.
echo.
echo   Auf einem Linux-Host:  make install
echo   Alle Targets:          make help
echo.
exit /b 1
