[CmdletBinding()]
Param()

. ../octopus-common.ps1

function Import-Configuration {
    # Check for custom import script
    if (Test-Path 'C:\Import\Import.ps1' ){
        C:\Import\Import.ps1 -Clean
    } elseif (Test-Path 'C:\Import\metadata.json' ){
        Write-Log "Running Migrator import on C:\Import directory ..."
        $args = @(
            'import',
            '--console',
            '--directory',
            'C:\Import',
            '--instance',
            'OctopusServer',
            '--password',
            'blank'
        )
        Execute-Command $MigratorExe $args
    }
}

function Start-OctopusDeploy
{

  Write-Log "Start Octopus Deploy instance ..."
  "Run started." | Set-Content "c:\octopus-run.initstate"

  & $ServerExe run --instance 'OctopusServer' --console

  Write-Log ""
}


try
{
  Write-Log "==============================================="
  Write-Log "Running Octopus Deploy"
  Write-Log "==============================================="

  Stop-Process -name "Octopus.Server" -Force -ErrorAction SilentlyContinue
  Import-Configuration
  Start-OctopusDeploy

  Write-Log "Run successful."
  Write-Log ""
}
catch
{
  Write-Log $_
  exit 2
}
