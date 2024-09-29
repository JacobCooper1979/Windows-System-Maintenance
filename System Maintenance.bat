@echo off
setlocal EnableDelayedExpansion

set "report="

echo Starting system maintenance...
echo.

:: Ask all questions upfront
set /p diskcleanup="Do you want to perform disk cleanup? (y/n): "
set /p regcheck="Do you want to analyze and fix registry issues? (y/n): "
set /p fsccheck="Do you want to analyze and fix file system issues? (y/n): "
set /p diskcheck="Do you want to check and repair disk health? (y/n): "
if /i "%diskcheck%"=="y" (
    set /p checkoption="Would you like to check all drives? (y/n): "
)
set /p defragcheck="Do you want to defragment and optimize drives? (y/n): "
if /i "%defragcheck%"=="y" (
    set /p defragoption="Would you like to defragment all drives? (y/n): "
)

echo.

:: Disk Cleanup
if /i "%diskcleanup%"=="y" (
    echo Performing disk cleanup...
    cleanmgr /sagerun:1
    if !errorlevel! neq 0 (
        echo Disk cleanup failed.
        set "report=!report! Disk cleanup was run but failed."
    ) else (
        echo Disk cleanup completed successfully.
        set "report=!report! Disk cleanup was run successfully."
    )
) else (
    echo Disk cleanup was not run.
    set "report=!report! Disk cleanup was not run."
)

echo.

:: Registry check and fix
if /i "%regcheck%"=="y" (
    echo Checking registry health...
    DISM.exe /Online /Cleanup-Image /CheckHealth
    if !errorlevel! neq 0 (
        echo Registry issues detected. Attempting to fix...
        DISM.exe /Online /Cleanup-Image /RestoreHealth
        if !errorlevel! neq 0 (
            echo Unable to fix registry issues.
            set "report=!report! Registry check was run but failed."
        ) else (
            echo Registry has been repaired successfully.
            set "report=!report! Registry check was run successfully."
        )
    ) else (
        echo No registry issues found.
        set "report=!report! Registry check was run with no issues found."
    )
) else (
    echo Registry check was not run.
    set "report=!report! Registry check was not run."
)

echo.

:: File system check and fix
if /i "%fsccheck%"=="y" (
    echo Verifying file system integrity...
    sfc /verifyonly
    if !errorlevel! neq 0 (
        echo File system issues detected. Attempting to repair...
        sfc /scannow
        if !errorlevel! neq 0 (
            echo File system repair failed.
            set "report=!report! File system check was run but failed."
        ) else (
            echo File system has been scanned and repaired successfully.
            set "report=!report! File system check was run successfully."
        )
    ) else (
        echo No file system issues found.
        set "report=!report! File system check was run with no issues found."
    )
) else (
    echo File system check was not run.
    set "report=!report! File system check was not run."
)

echo.

:: Disk health check
if /i "%diskcheck%"=="y" (
    if /i "%checkoption%"=="y" (
        echo Checking and repairing disk health on all fixed drives...
        for /f "skip=1 tokens=1" %%d in ('wmic logicaldisk where "drivetype=3" get name') do (
            echo Running chkdsk on %%d...
            echo Y | chkdsk %%d /f /r /x
            if !errorlevel! neq 0 (
                echo Error: chkdsk failed on %%d.
                set "report=!report! Disk health check on %%d was run but failed."
            ) else (
                echo Disk health has been checked and repaired successfully on %%d.
                set "report=!report! Disk health check on %%d was run successfully."
            )
        )
    ) else (
        echo Running chkdsk on C:...
        echo Y | chkdsk C: /f /r /x
        if !errorlevel! neq 0 (
            echo Error: chkdsk failed on C:.
            set "report=!report! Disk health check on C: was run but failed."
        ) else (
            echo Disk health has been checked and repaired successfully on C:.
            set "report=!report! Disk health check on C: was run successfully."
        )
    )
) else (
    echo Disk health check was not run.
    set "report=!report! Disk health check was not run."
)

echo.

:: SMART Status Check
echo Checking SMART status of drives...
wmic diskdrive get model,status
if !errorlevel! neq 0 (
    echo Error: Unable to retrieve SMART status.
    set "report=!report! SMART status check was not run due to an error."
) else (
    echo SMART status check complete.
    set "report=!report! SMART status check was run successfully."
)

echo.

:: Defragmentation/Optimization
if /i "%defragcheck%"=="y" (
    if /i "%defragoption%"=="y" (
        echo Defragmenting and optimizing all drives...
        for /f "skip=1 tokens=1" %%d in ('wmic logicaldisk get name') do (
            echo Defragmenting/Optimizing %%d...
            defrag %%d /O
            if !errorlevel! neq 0 (
                echo Error: Defragmentation/Optimization failed on %%d.
                set "report=!report! Defragmentation/Optimization on %%d was run but failed."
            ) else (
                echo Defragmentation/Optimization completed successfully on %%d.
                set "report=!report! Defragmentation/Optimization on %%d was run successfully."
            )
        )
    ) else (
        echo Defragmenting/Optimizing C:...
        defrag C: /O
        if !errorlevel! neq 0 (
            echo Error: Defragmentation/Optimization failed on C:.
            set "report=!report! Defragmentation/Optimization on C: was run but failed."
        ) else (
            echo Defragmentation/Optimization completed successfully on C:.
            set "report=!report! Defragmentation/Optimization on C: was run successfully."
        )
    )
) else (
    echo Defragmentation was not run.
    set "report=!report! Defragmentation was not run."
)

echo.

:: Final report
echo All checks completed.
echo.
echo Report:
echo !report!
echo.

pause
