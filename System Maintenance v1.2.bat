@echo off
setlocal EnableDelayedExpansion

set "tasks_run="

:menu
echo ====================================
echo          System Maintenance Menu    
echo ====================================
echo Would you like to run the complete system maintenance?
echo y. y to run complete maintenance
echo n. n to run a customized system maintenance
set /p option="Please choose an option (y/n): "

if "%option%"=="y" (
    goto run_all
) else if "%option%"=="n" (
    goto advanced_options
) else (
    echo Invalid choice. Please choose y or n.
    goto menu
)

:run_all
echo Running complete system maintenance...
set diskcleanup=y
set regcheck=y
set fsccheck=y
set defragcheck=y
goto run_tasks

:advanced_options
:: Ask all questions upfront
set /p diskcleanup="Do you want to run disk cleanup? (y/n): "
set /p regcheck="Do you want to scan and repair the registry? (y/n): "
set /p fsccheck="Do you want to scan and repair the file system? (y/n): "
set /p defragcheck="Do you want to defrag/trim all drives? (y/n): "

:run_tasks
echo.

:: Disk Cleanup
if /i "%diskcleanup%"=="y" (
    echo Performing disk cleanup...
    cleanmgr /sagerun:1
    set "tasks_run=!tasks_run! Disk cleanup; "
) else (
    echo Disk cleanup was not run.
)

echo.

:: Registry check and fix
if /i "%regcheck%"=="y" (
    echo Checking and fixing registry issues...
    DISM.exe /Online /Cleanup-Image /RestoreHealth
    set "tasks_run=!tasks_run! Registry check; "
) else (
    echo Registry check was not run.
)

echo.

:: File system check and fix
if /i "%fsccheck%"=="y" (
    echo Repairing file system...
    sfc /scannow
    set "tasks_run=!tasks_run! File system check; "
) else (
    echo File system check was not run.
)

echo.

:: Defragmentation/Optimization
if /i "%defragcheck%"=="y" (
    echo Defragmenting and optimizing all drives...
    defrag /C /O /U /V
    set "tasks_run=!tasks_run! Defragmentation on all drives; "
) else (
    echo Defragmentation was not run.
)

echo.

:: Completion Message
echo All tasks have been completed.
echo Tasks run:
echo !tasks_run!

echo.

:: SMART Status Check
echo Checking SMART status of drives...
wmic diskdrive get model,status

echo.

pause
