Param (
    [string]$searchPattern = "**\*.??proj",
    [string]$versionValue
)

# Write all params to the console.
Write-Host "VersionWriterTask v1.0.0"
Write-Host "=================="
Write-Host ("Search Pattern: " + $searchPattern)
Write-Host ("New version value: " + $versionValue)

function SetBuildVariable([string]$varName, [string]$varValue)
{
    $varName = $variablesPrefix + $varName
	Write-Host ("Setting variable " + $varName + " to '" + $varValue + "' and build is " + $Env:BUILD_BUILDID)
    Write-Output ("##vso[task.setvariable variable=" + $varName + ";]" +  $varValue )
    Write-Output ("##vso[task.setvariable variable=" + $varName + "_Build;]" +  $varValue + $buildPrefix + $Env:BUILD_BUILDID )
}

function PrepareNewVersionValue([string]$oldVersion)
{
	$version = $oldVersion.split("{.}")
	for($i=0; $i -lt $items.Count; $i++)
	{
		if($itemsValues[$i] -eq $true)
		{
			$version[$i] = $items[$i]
		}
	}
	$newVersion = $version[0] + "." + $version[1] + "." + $version[2]
	if($items.Count -eq 4)
	{
		$newVersion += "." + $version[3]
	}

	Write-Host ("New version to set : $newVersion")
	return $newVersion
}

function SetVersion([string]$fileFound)
{
	[xml]$xml = Get-Content -Path $fileFound
    [string]$version = ([string]$xml.Project.PropertyGroup.Version).Trim()
    if ($version -eq "")
    {
        Write-Warning ("No Version property value found, checking AssemblyVersion instead")
        $version = ([string]$xml.Project.PropertyGroup.AssemblyVersion).Trim()
        if ($version -eq "")
        {
			Write-Warning ("No AssemblyVersion property value found, checking FileVersion instead")
			$version = ([string]$xml.Project.PropertyGroup.FileVersion).Trim()
            if ($version -eq "")
			{
				$version = "1.0.0.0"
				Write-Warning ("No version was found in the project. the Version property will be added and initialized to 1.0.0.0")
				$child = $xml.CreateElement("Version");
				$child.set_InnerText($version)
				$xml.Project.PropertyGroup[0].AppendChild($child);
			}
        }
    }
	$newVersion = PrepareNewVersionValue $version

	for($i=0; $i -lt $xml.Project.PropertyGroup.Count; $i++)
	{
		if($xml.Project.PropertyGroup[$i].Version)
		{
			$xml.Project.PropertyGroup[$i].Version = $newVersion
		}
		if($xml.Project.PropertyGroup[$i].AssemblyVersion)
		{
			$xml.Project.PropertyGroup[$i].AssemblyVersion = $newVersion
		}
		if($xml.Project.PropertyGroup[$i].FileVersion)
		{
			$xml.Project.PropertyGroup[$i].FileVersion = $newVersion
		}
	}
	$xml.Save($fileFound)
}

function GetOrdinalNumber([int]$number)
{
	switch($number)
	{
		0 { return "first" }
		1 { return "second" }
		2 { return "third" }
		3 { return "fourth" }
	}
}

function IsNumericString([string]$value)
{
	return $value -match '^\d+$'
}

# MainCode

$items = $versionValue.Split("{.}")

if($items.Count -lt 3 -or $items.Count -gt 4)
{
	Throw "The version must contain at least 3 digits and at most 4 digits."
}

if($items.Count -eq 3)
{
    Write-Host ("The pattern in use is : x.y.z")
}

if($items.Count -eq 4)
{
    Write-Host ("The pattern in use is : x.y.z.p")
}

$itemsValues = @()

for ($i=0; $i -lt $items.Count; $i++)
{
	if(IsNumericString($items[$i]) -eq $true)
	{
		$itemsValues += $true
		Write-Host ("The " + $(GetOrdinalNumber $i) + " digit will be replaced by the value : " + $items[$i])
	}
	else
	{
		$itemsValues += $false
		Write-Warning ("The " + $(GetOrdinalNumber $i) + " digit contain an unkwown value, it will be ignored and the original value will be maintained")
	}
}



$filesFound = Get-ChildItem -Path $searchPattern -Recurse

if ($filesFound.Count -eq 0)
{
    Write-Warning ("No files matching pattern found.")
}

if ($filesFound.Count -gt 1)
{
   Write-Warning ("Multiple assemblyinfo files found.")
}

foreach ($fileFound in $filesFound)
{
    Write-Host ("Reading file: " + $fileFound)
    SetVersion($fileFound)
}