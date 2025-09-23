
<#
.SYNOPSIS
PackCreator.ps1 - A Minecraft: Java Edition Pack Generator
.DESCRIPTION
PackCreator.ps1 is a friendly script for creating Minecraft: Java Edition data and resource packs as .zip files. 
It is useful for using it inside a repository where there you need this for fast-creating releases.
Apart from the generator, it also offers property expansion to the pack.mcmeta file for easier development and maintainability.
.PARAMETER InputDirectory
The directory where the generator will search for pack files.
The script will fail to execute correctly if this directory is not fully qualified.
If not, the script will elsewise attempt to create a full path, but try to always provide the full path to it.
.PARAMETER OutputDirectory
The directory where the generated .zip files will be placed to.
Can be existing or not.
If not exists, it is created.
.PARAMETER PropertiesFile
Specifies the path to the properties file to read before generating the packs.
It is required for the project's properties, as well as supporting custom properties for expanding them
at various files, such as the pack.mcmeta file.
#>
param(
	
	[Parameter(Mandatory)]
	[Alias("InDir")]
	[ValidateNotNullOrEmpty()]
	[System.String] $InputDirectory,
	
	[Parameter(Mandatory)]
	[Alias("OutDir")]
	[ValidateNotNullOrEmpty()]
	[System.String] $OutputDirectory,
	
	[Parameter(Mandatory)]
	[Alias("PropFile")]
	[ValidateNotNullOrEmpty()]
	[System.String] $PropertiesFile
)

try {
	
	Write-Output "Initializing script..."

	Add-Type -AssemblyName "System.IO", "System.IO.Compression" , "System.IO.Compression.FileSystem" # For creating the ZIP packages

	if ($PSEdition -eq "Core") {
		Add-Type -AssemblyName "System.Console" # Consider that the System.Console is already loaded by mscorlib in .NET framework.
	}
	
	Write-Output "Initialization phase 1 completed."

} catch {
	Write-Output "An unexpected error occured while trying to initialize script: " + $_
}

# REGION: Console utilities. These are the utilities that are used for basic console interaction.

function Print_ErrorMessage
{
	param(
		[System.String] $STR
	)
	
	[System.ConsoleColor] $clr = [System.Console]::ForegroundColor;
	[System.Console]::ForegroundColor = [System.ConsoleColor]::Red;
	[System.Console]::Write($STR)
	[System.Console]::ForegroundColor = $clr;
}

function Print_ErrorMessageLine
{
	param(
		[System.String] $STR
	)
	Print_ErrorMessage([System.String]::Concat($STR , "`n"));
}

function PrintMessage
{
	param(
		[System.String] $STR
	)
	[System.Console]::Write($STR);
}

function PrintMessageLine
{
	param(
		[System.String] $STR
	)
	PrintMessage([System.String]::Concat($STR , "`n"));
}

function Print_WarningMessage
{
	param(
		[System.String] $STR
	)
	
	[System.ConsoleColor] $clr = [System.Console]::ForegroundColor;
	[System.Console]::ForegroundColor = [System.ConsoleColor]::Yellow;
	[System.Console]::Write($STR)
	[System.Console]::ForegroundColor = $clr;
}

function Print_WarningMessageLine
{
	param(
		[System.String] $STR
	)
	Print_WarningMessage([System.String]::Concat($STR , "`n"));
}


# ENDREGION

# REGION: Common utilities, such as exception utilities.

function ThrowIfNull
{
	param(
		$Any
	)
	
	if ($Any -eq $null) {
		throw [System.ArgumentNullException]::new("" , "A parameter value was null while this is disallowed.");
	}
}

function DisposeObjectIfNotNull
{
	param(
		[System.IDisposable] $Disposable
	)
	
	if ($Disposable -ne $null)
	{
		try {
			$Disposable.Dispose();
		} catch {
			Print_ErrorMessageLine(
				[System.String]::Format(
					"Cannot dispose object of type {0} with hash code {1} because of a catastrophic failure: {2}" , 
					$Disposable.GetType().FullName , 
					$Disposable.GetHashCode() , 
					$_
				)
			);
		} finally {
			$Disposable = $null;
		}
	}
}

function CreateStringDictionary
{
	return New-Object 'System.Collections.Generic.Dictionary[System.String,System.String]'
}

# ENDREGION

# REGION: Basic I/O utilities. Defines common I/O utilities that will be used throughout the script.

function FileExists 
{
	param(
		[System.String] $Path
	)
	
	ThrowIfNull($Path);
	
	return [System.IO.File]::Exists($Path);	
}

function DirectoryExists 
{
	param(
		[System.String] $Path
	)
	
	ThrowIfNull($Path);
	
	return [System.IO.Directory]::Exists($Path);
}

function OpenExistingFile_ReadOnly
{
	param(
		[System.String] $Path
	)
	
	ThrowIfNull($Path);
	
	return [System.IO.FileStream]::new($Path , [System.IO.FileMode]::Open , [System.IO.FileAccess]::Read);
}

function CreateFile
{
	param(
		[System.String] $Path
	)
	
	ThrowIfNull($Path);
	
	return [System.IO.FileStream]::new($Path , [System.IO.FileMode]::Create);
}

function CopySpecifiedStreamTo
{
	param(
		[System.IO.Stream] $Source,
		[System.IO.Stream] $Destination
	)
	
	ThrowIfNull($Source);
	ThrowIfNull($Destination);
	
	[System.Int32] $count;
	
	[System.Byte[]] $temp = [System.Array]::CreateInstance([System.Type]::GetType("System.Byte") , 2048);
	
	while (($count = $Source.Read($temp , 0 , 2048)) -gt 0)
	{
		$Destination.Write($temp , 0 , $count);
	}
}

function EnumerateFilesRecursively
{
	param(
		[System.String] $Path
	)
	
	ThrowIfNull($Path);
	
	return ([System.IO.DirectoryInfo]::new($Path)).EnumerateFiles("*.*" , [System.IO.SearchOption]::AllDirectories);
}

function EnumerateFilesOnlyPassedDirectory
{
	param(
		[System.String] $Path
	)
	
	ThrowIfNull($Path);
	
	return ([System.IO.DirectoryInfo]::new($Path)).EnumerateFiles("*.*" , [System.IO.SearchOption]::TopDirectoryOnly);
}

function EnumerateDirectoriesOnlyPassedDirectory
{
	param(
		[System.String] $Path
	)
	
	ThrowIfNull($Path);
	
	return ([System.IO.DirectoryInfo]::new($Path)).EnumerateDirectories("*" , [System.IO.SearchOption]::TopDirectoryOnly);
}

function CreateZipArchiveObject_Creation
{
	param(
		[System.IO.Stream] $Stream
	)
	
	ThrowIfNull($Stream);
	
	return [System.IO.Compression.ZipArchive]::new($Stream , [System.IO.Compression.ZipArchiveMode]::Create, $true);
}

function CreateZipArchiveObject_Read
{
	param(
		[System.IO.Stream] $destination
	)
	
	ThrowIfNull($destination);
	
	return [System.IO.Compression.ZipArchive]::new($destination , [System.IO.Compression.ZipArchiveMode]::Read , $true);
}

function PathEndsWithDirectorySlash
{
	param(
		[System.String] $Path
	)
	
	ThrowIfNull($Path);
	
	return $Path.EndsWith("/") -or $Path.EndsWith("\");
}

function PathStartsWithDirectorySlash
{
	param(
		[System.String] $Path
	)
	
	ThrowIfNull($Path);
	
	return $Path.StartsWith("/") -or $Path.StartsWith("\");
}

function StripSpecifiedPathIfFoundAtBeginning
{
	param(
		[System.String] $Path,
		[System.String] $PathToFind
	)
	
	ThrowIfNull($Path);
	if ($PathToFind -eq $null) { return $Path; }
	
	if ($Path.StartsWith($PathToFind)) {
		[System.String] $ret = $Path.Substring($PathToFind.Length + 1);
		if (PathStartsWithDirectorySlash -Path $ret)
		{
			return $ret.Substring(1);
		}
		return $ret;
	} else {
		return $Path;
	}
}

function CreateDirectory
{
	param(
		[System.String] $Where
	)
	
	ThrowIfNull($Where);
	
	$null = [System.IO.Directory]::CreateDirectory($Where);
}

function CreateDirectoryIfNotExisting
{
	param(
		[System.String] $Where
	)
	
	ThrowIfNull($Where);
	
	if ((DirectoryExists -Path $Where) -eq $false) {
		$null = [System.IO.Directory]::CreateDirectory($Where);
	}
}

function ConvertToArchivePath
{
	param(
		[System.String] $PathToBeStripped,
		[System.String] $ActualPath
	)
	
	$ActualPath = StripSpecifiedPathIfFoundAtBeginning -Path $ActualPath -PathToFind $PathToBeStripped
	
	return $ActualPath.Replace('\' , '/');
}

# ENDREGION

# REGION Script utilities

function PropertiesFile_LineIsComment
{
	param(
		[System.String] $Line
	)
	
	if ($Line -eq $null) { return $false; }
	
	foreach ($c in $Line.GetEnumerator())
	{
		if (($c -eq ' ') -or ($c -eq '`t')) {
			continue;
		} elseif ($c -eq '#') {
			return $true;
		} else {
			break;
		}
	}
	return $false;
}

function PropertiesFile_ProcessValue
{
	[OutputType([System.String])]
	param(
		[System.String] $Line
	)
	
	if ($Line -eq $null) { return $false; }
	
	$Line = $Line.TrimStart();
	
	[System.Text.StringBuilder] $sb = [System.Text.StringBuilder]::new($Line.Length);
	
	[System.Boolean] $literalstarted = $false;
	
	foreach ($c in $Line.GetEnumerator())
	{
		if ($c -eq '"') {
			if ($literalstarted)
			{
				$literalstarted = $false;
				break;
			}
			$literalstarted = $true;
		} elseif ($c -eq '#') {
			break; # Comment after the property, break
		} elseif (($literalstarted -eq $false) -and (($c -eq ' ') -or ($c -eq '`t'))) {
			break; # The property has been possibly defined
		} elseif (($c -eq '`r') -or ($c -eq '`n')) {
			break; # Break at such case
		} else {
			$null = $sb.Append($c);
			continue;
		}
	}
	
	if ($literalstarted)
	{
		# A string literal has begun, but not closed. We are ought to throw.
		throw "A string literal had begun, but was not appropriately closed.";
	}
	
	return $sb.ToString();
}

function CreateMinecraftPackage_CreateCommonPropertiesFile
{
	param(
		[System.IO.Compression.ZipArchiveEntry] $DedicatedEntry,
		[System.Collections.Generic.IDictionary[System.String, System.String]] $Properties
	)
	
	[System.IO.StreamWriter] $sw;
	
	try {
		$sw = [System.IO.StreamWriter]::new($DedicatedEntry.Open());
		$sw.WriteLine("# -- AUTOGEN --");
		$sw.WriteLine([System.String]::Concat("# Common properties file for the " , $Properties["ProjectFriendlyName"] , " project."));
		$sw.WriteLine("# This is an auto-generated file. Do not modify this file.");
		$sw.WriteLine("# -- AUTOGEN --");
		foreach ($k in $Properties.GetEnumerator())
		{
			$sw.WriteLine([System.String]::Concat($k.Key , "=" , $k.Value));
		}
	} finally {
		DisposeObjectIfNotNull -Disposable $sw;
	}
}

function ProcessPropertyExpandedFile
{
	param(
		[System.IO.Stream] $InputFileData,
		[System.IO.Compression.ZipArchiveEntry] $FinalArchiveEntry,
		[System.Collections.Generic.IDictionary[System.String, System.String]] $Properties
	)
	
	[System.IO.StreamReader] $stream_input = $null;
	[System.IO.StreamWriter] $streamdataoutwriter = $null;
	
	try {
		# Open a stream reader of the stream data to expand, assuming UTF-8 if the encoding cannot be determined
		$stream_input = [System.IO.StreamReader]::new($InputFileData , [System.Text.Encoding]::UTF8 , $true, 4096, $false);
		
		[System.String] $tempstring = $null;
		
		[System.Int32] $lineordinal = 0;
		
		[System.Text.StringBuilder] $sb2 = [System.Text.StringBuilder]::new();
		[System.Text.StringBuilder] $sb = [System.Text.StringBuilder]::new(500);
		
		<# 
			This formatter supports the following property Gradle-like syntax:
		
			${Name} - Expands the property named 'Name'.

			$$ - Escapes the dollar sign required for expanding properties.

			Thus, even if this formatter runs on a JSON file (that are using braces), the formatter will not fail because it requires a dollar sign first in order to work.

			Appropriate error messages are reported on any failure. (e.g. unclosed property definition and EOL reached)
		#>
		while ($stream_input.EndOfStream -eq $false)
		{
			$lineordinal++;
			$tempstring = $stream_input.ReadLine();
			if ($streamdataoutwriter -eq $null)
			{
				$streamdataoutwriter = [System.IO.StreamWriter]::new($FinalArchiveEntry.Open() , $stream_input.CurrentEncoding);
			}
			[System.Boolean] $variablefound = $false;
			[System.Boolean] $dollarfound = $false;
			[System.Int32] $linepos = 0;
			foreach ($c in $tempstring.GetEnumerator())
			{
				$linepos++;
				if ($c -eq '$') {
					if ($dollarfound)
					{
						$sb.Append('$');
						$dollarfound = $false;
						continue;
					}
					$dollarfound = $true;
				} elseif ($dollarfound -and ($c -eq '{')) {
					$variablefound = $true;
				} elseif ($dollarfound -and ($c -eq '}')) {
					$variablefound = $false;
					$dollarfound = $false;
					# We have the variable to expand, expand it
					# If not existing, it will be just replaced with empty value
					$sb.Append($Properties[$sb2.ToString()]);
					$sb2.Clear();
				} elseif ($variablefound) {
					$sb2.Append($c);
				} else {
					$sb.Append($c);
				}
			}
			if ($variablefound)
			{
				throw "The opened variable at line " + $lineordinal + " and position " + $linepos + " of the file was not closed.";
			}
			if ($dollarfound)
			{
				throw "A dollar sign was found at line " + $lineordinal + " and position " + $linepos + " of the file, but it was not found whether that sign was a variable or the escape code.";;
			}
			$streamdataoutwriter.WriteLine($sb.ToString());
			$sb.Clear();
		}
		
		if ($streamdataoutwriter -eq $null)
		{
			$streamdataoutwriter = [System.IO.StreamWriter]::new($FinalArchiveEntry.Open() , $stream_input.CurrentEncoding);
		}
		
		$streamdataoutwriter.Flush();
		

	} finally {
		DisposeObjectIfNotNull -Disposable $stream_input;
		DisposeObjectIfNotNull -Disposable $streamdataoutwriter;
	}
}

PrintMessageLine("Initialization phase 2 completed.");

# Creates a Minecraft pack , either if this is a resource or data pack
# Does also check whether pack.png and pack.mcmeta files do exist.
# For pack.mcmeta, it reports a failure and the script exits; for pack.png, an appropriate warning is displayed.
function CreateMinecraftPackage
{
	param(
		[System.String] $PackageType = $(throw 'PackageType argument must be defined.'),
		[System.Collections.Generic.IDictionary[System.String, System.String]] $Properties = $(throw 'Properties argument must be defined.'),
		[System.String] $OutDir = $(throw 'OutDir argument must be defined.')
	)
	
	ThrowIfNull($PackageType);
	
	[System.IO.FileStream] $out = $null;
	[System.IO.FileStream] $tp = $null;
	[System.IO.Stream] $archtempstream = $null;

	[System.IO.Compression.ZipArchive] $archive = $null;
	[System.IO.Compression.ZipArchiveEntry] $archentry = $null;
	
	[System.String] $PackageTypeFriendlyName = $null;
	[System.String] $ExpectedMcMetaFileName = $null;
	
	if ($PackageType -eq "assets") {
		$PackageTypeFriendlyName = "Resources";
		$ExpectedMcMetaFileName = "pack_assets.mcmeta";
	} elseif ($PackageType -eq "data") {
		$PackageTypeFriendlyName = "Data";
		$ExpectedMcMetaFileName = "pack_data.mcmeta";
	}
	
	[System.String] $fp = [System.IO.Path]::Combine(
		$OutDir , 
		[System.String]::Concat(
			$Properties["ProjectId"] , 
			"-",
			$PackageTypeFriendlyName,
			"-",			
			$Properties["Version"],
			"-",
			$Properties["ReleaseCycle"],
			".zip"
		)
	);
	
	[System.Boolean] $packmcmetafilefound = $false;
	[System.Boolean] $packpngfilefound = $false;
	
	try {
		$out = CreateFile -Path $fp;
		$archive = CreateZipArchiveObject_Creation -Stream $out;		

		[System.String] $CFileName = $null;
		
		foreach ($fileinfo in (EnumerateFilesOnlyPassedDirectory -Path $InputDirectory))
		{
			# First processing pass - transform the name 
			if ($fileinfo.Name -eq $ExpectedMcMetaFileName) {
				$CFileName = "pack.mcmeta";
			} elseif ($fileinfo.Extension -eq ".mcmeta") {
				continue;
			} else {
				$CFileName = $fileinfo.Name;
			}
			# Second processing pass - decide what has to be done
			if ($CFileName -eq "pack.png") {
				$packpngfilefound = $true;
			} elseif ($CFileName -eq "pack.mcmeta") {
				$packmcmetafilefound = $true;
				$null = ProcessPropertyExpandedFile -InputFileData $fileinfo.OpenRead() -FinalArchiveEntry $archive.CreateEntry($CFileName) -Properties $Properties
				continue;
			} else {
				try {
					$archentry = $archive.CreateEntry($CFileName);
					$tp = $fileinfo.OpenRead();
					$archtempstream = $archentry.Open();
				
					$null = CopySpecifiedStreamTo -Source $tp -Destination $archtempstream
				
				} finally {
					DisposeObjectIfNotNull -Disposable $archtempstream;
					DisposeObjectIfNotNull -Disposable $tp;
				}
			}
		}
		
		if ($packmcmetafilefound -eq $false) {
			throw [System.String]::Format("The {0} file required for pack cannot be retrieved." , $ExpectedMcMetaFileName);
		}
		
		if ($packpngfilefound -eq $false) {
			Print_WarningMessageLine("A pack.png file representing the image of the pack was not found. It is recommended to add such an image. It's dimensions must be 128 X 128 pixels.");
		}
		
		CreateMinecraftPackage_CreateCommonPropertiesFile -DedicatedEntry $archive.CreateEntry("project.mdcdi1315_info") -Properties $Properties
		
		foreach ($fileinfo in (EnumerateFilesRecursively -Path $([System.IO.Path]::Combine($InputDirectory , $PackageType))))
		{
			try {
				$archentry = $archive.CreateEntry((ConvertToArchivePath -PathToBeStripped $InputDirectory -ActualPath $fileinfo.FullName));
				$tp = $fileinfo.OpenRead();
				$archtempstream = $archentry.Open();
				
				$null = CopySpecifiedStreamTo -Source $tp -Destination $archtempstream
				
			} finally {
				DisposeObjectIfNotNull -Disposable $archtempstream;
				DisposeObjectIfNotNull -Disposable $tp;
			}
		}
		
	} catch {
		Print_ErrorMessageLine([System.String]::Format("Cannot generate the pack {0} because of an exception: {1}`nExiting abnormally.", $PackageType , $_));
		DisposeObjectIfNotNull -Disposable $archive;
		DisposeObjectIfNotNull -Disposable $out;
		[System.IO.File]::Delete($fp);
		exit 2;
	} finally {
		DisposeObjectIfNotNull -Disposable $archive;
		DisposeObjectIfNotNull -Disposable $out;
	}
}

# ENDREGION

# REGION Main script

PrintMessageLine("Initialization phase 3 completed.");

$InputDirectory = [System.IO.Path]::GetFullPath($InputDirectory);

$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory);

$PropertiesFile = [System.IO.Path]::GetFullPath($PropertiesFile);

PrintMessageLine("Script initialization completed successfully.");

PrintMessageLine("Creating package...");

PrintMessageLine("Package is generated from: " + $InputDirectory);

PrintMessageLine("Package will be created at: " + $OutputDirectory);

CreateDirectoryIfNotExisting -Where $OutputDirectory

PrintMessageLine("Processing properties file " + $PropertiesFile);

# Load properties file.
# This is the Gradle properties file, so that mod developers are familiar with the properties semantics defined there.

# An additional extension for the properties file is the string literals, enclosed in double quotes instead.

# TODO: String literal support with ''' is not implemented yet. Implement such support.

[System.Collections.Generic.IDictionary[System.String,System.String]] $properties = CreateStringDictionary;
[System.IO.StreamReader] $reader;
[System.IO.FileStream] $fsm = OpenExistingFile_ReadOnly -Path $PropertiesFile;
	
try {
	$reader = [System.IO.StreamReader]::new($fsm , [System.Text.Encoding]::UTF8 , $true, 4096, $true);
			
	[System.UInt32] $linecounter = 0;
			
	while ($reader.EndOfStream -eq $false)
	{
		$linecounter++;
		[System.String] $temp = $reader.ReadLine();
		if ([System.String]::IsNullOrWhitespace($temp)) { continue; }
		if (PropertiesFile_LineIsComment -Line $temp) { continue; }
		[System.Int32] $index = $temp.IndexOf('=');
		if ($index -eq -1) { throw "The properties file at line " + $linecounter + " does not have a property definition, while a definition was expected."; }
		$null = $properties.Add(
			$temp.Remove($index).TrimEnd(), 
			$(PropertiesFile_ProcessValue -Line $temp.Substring($index + 1))
		);
	}

} catch {
	Print_ErrorMessageLine([System.String]::Format("ERROR: Cannot read the properties file due to an exception: {0}.`nExiting directly." , $_));
	exit 2;
} finally {
	DisposeObjectIfNotNull -Disposable $reader
	DisposeObjectIfNotNull -Disposable $fsm
}

if ($properties -eq $null) { 
	Print_ErrorMessageLine("ERROR: PROPERTIES ARE NULL!!!");
	exit 2; 
}

PrintMessageLine("Successfully read the properties file!");

if ($properties.ContainsKey("ProjectId") -eq $false)
{
	Print_ErrorMessageLine("Cannot find the required property 'ProjectId' in the project properties file.");
	exit 1;
}

if ($properties.ContainsKey("Version") -eq $false)
{
	Print_ErrorMessageLine("Cannot find the required property 'Version' in the project properties file.");
	exit 1;
}

if ($properties.ContainsKey("Author") -eq $false)
{
	Print_WarningMessageLine("Cannot find the property 'Author' in the project properties file. It is recommended to set this property so that the users of the pack can identify you.");
	$properties.Add("Author" , "");
}

if ($properties.ContainsKey("ProjectFriendlyName") -eq $false)
{
	Print_WarningMessageLine("Cannot find the property 'ProjectFriendlyName' in the project properties file. It is recommended to set this property so that the users of the pack can identify that the pack is part of this project.");
	$properties.Add("ProjectFriendlyName" , $properties["ProjectId"]);
}

if ($properties.ContainsKey("ProjectURL") -eq $false)
{
	Print_WarningMessageLine("Cannot find the property 'ProjectURL' in the project properties file. It is recommended to set this property to a valid URL so that the users of the pack can credit you and file their issues.");
	$properties.Add("ProjectURL" , "");
}

if ($properties.ContainsKey("ReleaseCycle") -eq $false)
{
	Print_WarningMessageLine("Cannot find the property 'ReleaseCycle' in the project properties file. It is recommended to set this property to one of the valid release cycles (Snapshot, Pre-Release and Stable) so that the users can be warned about beta features.");
	$properties.Add("ReleaseCycle" , "Snapshot");
}

# Find pack files for processing

foreach ($directory in (EnumerateDirectoriesOnlyPassedDirectory -Path $InputDirectory))
{
	if (($directory.Name -eq "data") -or ($directory.Name -eq "assets")) {
		CreateMinecraftPackage -PackageType $directory.Name -Properties $properties -OutDir $OutputDirectory;
	} else {
		Print_WarningMessageLine("This pack type is not supported: " + $directory.Name + ". This pack type will be ignored by the script.");
	}
}


PrintMessageLine("Package(s) are created at: " + $OutputDirectory);

PrintMessageLine("Build succeeeded.");

# ENDREGION