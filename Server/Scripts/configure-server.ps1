[CmdletBinding()]
Param()

$sqlDbConnectionString=$env:sqlDbConnectionString
$masterKey=$env:masterKey
$masterKeySupplied = ($masterKey -ne $null) -and ($masterKey -ne "")
$octopusAdminUsername=$env:OctopusAdminUsername
$octopusAdminPassword=$env:OctopusAdminPassword
$configFile = "c:\Octopus\OctopusServer.config"

. ../octopus-common.ps1

function Configure-OctopusDeploy(){

  $configAlreadyExists = Test-Path $configFile

  if (-not($configAlreadyExists)) {
    # work around https://github.com/docker/docker/issues/20127
    Copy-item "c:\OctopusServer.config.orig" $configFile
  }

  Write-Log "Configuring Octopus Deploy instance ..."
  $args = @(
    'configure',
    '--console',
    '--instance', 'OctopusServer',
    '--home', 'C:\Octopus',
    '--storageConnectionString', $sqlDbConnectionString
  )
  if ($masterKeySupplied -and (-not ($configAlreadyExists))) {
    $args += '--masterkey'
    $args += $masterKey
  }
  Execute-Command $ServerExe $args

  Write-Log "Creating Octopus Deploy database ..."
  $args = @(
    'database',
    '--console',
    '--instance', 'OctopusServer',
    '--create'
  )
  Execute-Command $ServerExe $args

   Write-Log "Configuring Paths ..."
  $args = @(
    'path',
    '--console',
    '--instance', 'OctopusServer',
	'--nugetRepository', 'C:\Repository',
	'--artifacts', 'C:\Artifacts',
	'--taskLogs', 'C:\TaskLogs'
  )
  Execute-Command $ServerExe $args

  Write-Log "Stopping Octopus Deploy instance ..."
  $args = @(
    'service',
    '--console',
    '--instance', 'OctopusServer',
    '--stop'
  )
  Execute-Command $ServerExe $args

  Write-Log "Creating Admin User for Octopus Deploy instance ..."
  $args = @(
    'admin',
    '--console',
    '--instance', 'OctopusServer',
    '--username', $octopusAdminUserName,
    '--password', $octopusAdminPassword
  )
  Execute-Command $ServerExe $args

  Write-Log "Configuring Octopus Deploy instance to use free license ..."
  $args = @(
    'license',
    '--console',
    '--instance', 'OctopusServer',
    '--free'
  )
  Execute-Command $ServerExe $args

  if (($masterKey -eq $null) -or ($masterKey -eq "")) {
      Write-Log "Display master key ..."
      $args = @(
        'show-master-key',
        '--console',
        '--instance', 'OctopusServer'
      )
      Execute-Command $ServerExe $args
  }

  Write-Log ""
}

function Validate-Variables(){
  $masterKeySupplied = ($masterKey -ne $null) -and ($masterKey -ne "")
  if ((Test-Path $configFile) -and $masterKeySupplied) {
    Write-Log " - masterkey supplied, but server has already been configured - ignoring"
  }
  elseif (Test-Path $configFile) {
    Write-Log " - using previously configured masterkey from $configFile"
  }
  elseif ($masterKeySupplied) {
    Write-Log " - masterkey '##########'"
  }
  else {
    Write-Log " - masterkey not supplied. A new key will be generated automatically"
  }

  $maskedConnectionString = $sqlDbConnectionString -replace "password=.*?;", "password=###########;"
  Write-Log " - using database '$maskedConnectionString'"
  Write-Log " - local admin user '$octopusAdminUsername'"
  Write-Log " - local admin password '##########'"
}

function Wait-Db {
    param($Delay = 1)

    $Delay = $Delay * 1000
    $handler = [System.Data.SqlClient.SqlInfoMessageEventHandler] { Write-Verbose $_ }
    $Counter = 0
    do {
        $conn = [System.Data.SqlClient.SQLConnection]::new()
        $conn.ConnectionString = $env:sqlDbConnectionString
        $conn.add_InfoMessage( $handler )
        $result = 0

        try {
            $conn.Open()
            $command = [System.Data.SqlClient.SqlCommand]::new("Select 1",$conn)
            $command.CommandTimeout = $QueryTimeout
            try {
                $reader = $command.ExecuteReader()
                try
                {
                    while ($reader.Read())
                    {
                        Write-Host ("{0}, {1}" -f $reader[0], $reader[1])
                        $result = $reader[1]
                    }
                }
                catch
                {
                    Write-Log "Read finished!"
                }
                finally
                {
                    # Always call Close when done reading.
                    $reader.Close();
                }
            }
            catch
            {
                Write-Log "Database reader failed! Sleep 250ms"
            }
        }
        catch
        {
            Write-Log "Database server not up yet. Sleep 500ms"
            Start-Sleep -Milli 250
            $Counter += 250
        }
        Start-Sleep -Milli 250
        $Counter += 250
    } while($result -eq 0 -and $Counter -lt $Delay)
    Write-Log "Delayed $Counter ms"
}

try
{
    Write-Log "==============================================="
    Write-Log "==== Wait for database"
    Write-Log "==============================================="
    Wait-Db

    Write-Log "==============================================="
    Write-Log "==== Configuring Octopus Deploy"
    Write-Log "==============================================="
    if(Test-Path c:\octopus-configuration.initstate){
        Write-Verbose "This Server has already been initialized and registered so reconfiguration will be skipped.`nIf you need to change the configuration, please start a new container";
        exit 0
    }

    Write-Log "==============================================="

    Validate-Variables

    Configure-OctopusDeploy
    "Configuration complete." | Set-Content "c:\octopus-configuration.initstate"

    Write-Log "Configuration successful."
    Write-Log ""
}
catch
{
    Write-Log $_
    exit 2
}
