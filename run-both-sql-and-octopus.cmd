@echo off

set masterKey=XXX

cls
echo Setting up data folder structure
if not exist c:\temp\octopus-mapped-volumes\logs mkdir c:\temp\octopus-mapped-volumes\logs
if not exist c:\temp\octopus-mapped-volumes\artifacts mkdir c:\temp\octopus-mapped-volumes\artifacts
if not exist c:\temp\octopus-mapped-volumes\packagecache mkdir c:\temp\octopus-mapped-volumes\packagecache
if not exist c:\temp\octopus-mapped-volumes\packages mkdir c:\temp\octopus-mapped-volumes\packages
if not exist c:\temp\octopus-mapped-volumes\tasklogs mkdir c:\temp\octopus-mapped-volumes\tasklogs

rem hacky way of getting round docker bug https://github.com/docker/docker/issues/26178
powershell -command $env:masterKey -replace '=', '##equals##' ^| Set-Content -path '.run.tmp'
set /p masterKey=<.run.tmp

echo Starting SQL Server
docker run --interactive ^
           --tty ^
           --detach ^
           --publish 1433:1433 ^
           --name=OctopusDeploySqlServer ^
           --env sa_password=Password1! ^
           microsoft/mssql-server-2014-express-windows

echo Waiting 10 seconds for sql server to start and change SA password
powershell -command sleep 10

rem hacky way of getting the container's ip address, as --link doesn't work on windows
powershell -command ($(docker inspect OctopusDeploySqlServer) ^| ConvertFrom-Json).NetworkSettings.Networks.nat.IpAddress ^| Set-Content -path '.run.tmp'
set /p sqlServerContainerIpAddress=<.run.tmp

set sqlDbConnectionString=Server=tcp:%sqlServerContainerIpAddress%,1433;Initial Catalog=Octopus;Persist Security Info=False;User ID=sa;Password=Password1!;MultipleActiveResultSets=False;Connection Timeout=30;
rem hacky way of getting round docker bug https://github.com/docker/docker/issues/26178
powershell -command $env:sqlDbConnectionString -replace '=', '##equals##' ^| Set-Content -path '.run.tmp'
set /p sqlDbConnectionString=<.run.tmp

del .run.tmp

echo Starting OctopusDeploy
docker run --interactive ^
           --tty ^
           --detach ^
           --name=OctopusDeploy ^
           --publish 81:81 ^
           --env sqlDbConnectionString="%sqlDbConnectionString%" ^
           --env masterKey=%masterkey% ^
           --volume c:/temp/octopus-mapped-volumes/logs:c:/Octopus/Logs ^
           --volume c:/temp/octopus-mapped-volumes/artifacts:c:/Octopus/Artifacts ^
           --volume c:/temp/octopus-mapped-volumes/packagecache:c:/Octopus/OctopusServer/PackageCache ^
           --volume c:/temp/octopus-mapped-volumes/packages:c:/Octopus/Packages ^
           --volume c:/temp/octopus-mapped-volumes/tasklogs:c:/Octopus/TaskLogs ^
           octopusdeploy/octopusdeploy:3.4.2

rem ########## start: wait until octopus is ready ##########
set OctopusDeployCheckCount=0
:octopusdeploycheckhealth
set /a OctopusDeployCheckCount=%OctopusDeployCheckCount%+1
if %OctopusDeployCheckCount% gtr 12 (
  echo Waited 2 minutes for Octopus Deploy to come alive, but it didn't. Aborting.
  exit 4
)

powershell -command ($(docker inspect OctopusDeploy) ^| ConvertFrom-Json).State.Health.Status ^| Set-Content -path '.run.tmp'
set /p OctopusDeployContainerHealth=<.run.tmp
del .run.tmp

if "%OctopusDeployContainerHealth%" equ "" (
  echo OctopusDeploy container does not exist. Aborting.
  exit 5
)

echo [Attempt %OctopusDeployCheckCount%/12] OctopusDeploy container health state is '%OctopusDeployContainerHealth%'
if "%OctopusDeployContainerHealth%" equ "starting" (
    echo Sleeping for 10 seconds
    powershell -command sleep 10
    goto octopusdeploycheckhealth:
)
if "%OctopusDeployContainerHealth%" neq "healthy" (
    exit 6
)

rem ########## end: wait until octopus is ready ##########

echo Done. Octopus is available on port 81.
