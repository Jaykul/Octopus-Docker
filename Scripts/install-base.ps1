[CmdletBinding()]
Param(
    [Parameter(Mandatory = $True)]
    [string]$Msi,

    $OctopusVersion = $Env:OctopusVersion
)
$installBasePath = "C:\Install\"
$installersPath  = "C:\Installers\"
$msiFileName = "${Msi}.${OctopusVersion}-x64.msi"
$downloadUrl = "https://download.octopusdeploy.com/octopus/$msiFileName"

. $PSScriptRoot/octopus-common.ps1

if ($OctopusVersion -or ($OctopusVersion -eq "latest")) {
    Write-Log "No version specified for install. Using latest";
    if ($Msi -eq "Octopus.Tentacle") {
        $downloadUrlLatest = "https://octopusdeploy.com/downloads/latest/OctopusTentacle64"
    } else {
        $downloadUrlLatest = "https://octopusdeploy.com/downloads/latest/OctopusServer64"
    }
}

$msiPath = Join-Path $installBasePath $msiFileName
$msiLogPath = Join-Path $installBasePath "$msiFileName.log"
$installerLogPath = Join-Path $installBasePath 'Install-OctopusDeploy.ps1.log'
$OFS = "`r`n"


function Create-InstallLocation {
    Write-Log "Create Install Location"

    if (!(Test-Path $installBasePath)) {
        Write-Log "Creating installation folder at '$installBasePath' ..."
        New-Item -ItemType Directory -Path $installBasePath | Out-Null
        Write-Log "done."
    } else {
        Write-Log "Installation folder at '$installBasePath' already exists."
    }

    Write-Log ""
}

function Stage-Installer {
    Write-Log "Stage Installer"
    $embeddedPath = Join-Path $installersPath $msiFileName
    Write-Log "Checking for $embeddedPath"
    if (Test-Path $embeddedPath) {
        Write-Log "Found correct version installer at '$embeddedPath'. Copying to '$msiPath' ..."
        Copy-Item $embeddedPath $msiPath
        Write-Log "done."
    } else {
        Write-Log "Downloading installer '$downloadUrl' to '$msiPath' ..."
        Invoke-WebRequest -Uri $downloadUrl -OutFile $msiPath
        Write-Log "done."
    }
}

function Install-OctopusDeploy {
    Write-Log "Installing $msiFileName"
    Write-Verbose "Starting MSI Installer"
    $msiExitCode = (Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $msiPath /qn /l*v $msiLogPath" -Wait -Passthru).ExitCode
    Write-Verbose "MSI installer returned exit code $msiExitCode"
    if ($msiExitCode -ne 0) {
        Write-Verbose "-------------"
        Write-Verbose "MSI Log file:"
        Write-Verbose "-------------"
        Get-Content $msiLogPath
        Write-Verbose "-------------"
        throw "Install of $Msi failed, MSIEXEC exited with code: $msiExitCode. View the log at $msiLogPath"
    }
}

function Delete-InstallLocation {
    Write-Log "Delete $installersPath Directory"
    if (!(Test-Path $installersPath)) {
        Write-Log "Installers directory didn't exist - skipping delete"
    } else {
        Remove-Item $installersPath -Recurse -Force
    }
    Write-Log ""

    Write-Log "Delete Install Location"
    if (!(Test-Path $installBasePath)) {
        Write-Log "Install location didn't exist - skipping delete"
    } else {
        Remove-Item $installBasePath -Recurse -Force
    }
    Write-Log ""
}

try {
    Write-Log "==============================================="
    Write-Log "Installing $Msi version '$OctopusVersion'"
    Write-Log "==============================================="

    Create-InstallLocation
    Stage-Installer
    Install-OctopusDeploy
    Delete-InstallLocation      # removes files we dont need to save space in the image

    "Msi Install complete." | Set-Content "c:\octopus-install.initstate"

    Write-Log "Msi Installed"
    exit 0
} catch {
    Write-Log $_
    exit 2
}
