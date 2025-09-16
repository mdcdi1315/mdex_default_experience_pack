#/bin/bash

# =======================================================================================================
#
# Data pack generator script - file for initializing the generator
#
# © MDCDI1315. Do not modify this file unless you know really well what you are doing!
#
# =======================================================================================================

declare PWSH_FILE="$(type -p -f pwsh)";

if [ "$POWERSHELL_EXEC" != "" ]
then $PWSH_FILE="$POWERSHELL_EXEC";
fi

if [ "$PWSH_FILE" == "" ] 
then 
	echo -e "\aPowershell cannot be found in the current environment. Either provide it by using the environment variable POWERSHELL_EXEC or install it globally."
	exit 1;
fi

"$PWSH_FILE" -NoProfile -File "./PackCreator.ps1" -InputDirectory "./Mining Dimension EX Default Experience Pack" -OutputDirectory "./bin" -PropertiesFile "./project.properties";

