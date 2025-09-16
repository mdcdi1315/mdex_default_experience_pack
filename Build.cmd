
:: =======================================================================================================
::
:: Data pack generator script - file for initializing the generator
::
:: © MDCDI1315. Do not modify this file unless you know really well what you are doing!
::
:: =======================================================================================================

@echo off

cd /d "%~dp0"

for %%I in (pwsh.exe powershell.exe) do (
	if not "%%~$PATH:I" == "" (
		%%I -NoLogo -Commnand "Write-Output 'success'" > nul
		if errorlevel 0 (
			%%I -NoProfile -ExecutionPolicy "Unrestricted" -File ".\PackCreator.ps1" -InputDirectory "./Mining Dimension EX Default Experience Pack" -OutputDirectory "./bin" -PropertiesFile "./project.properties"
			pause
			exit \b 0
		)
	)
)

echo Cannot find a usuable powershell installation to use.

echo Check that powershell is installed and retry.

echo Press any key to exit...

1>nul pause

exit \b 10 