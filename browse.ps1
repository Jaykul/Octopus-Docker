[CmdletBinding()]
param($Name="*octopus_*")

start $((Get-Container).Where{ $_.Names -like $Name}.ForEach{
    "http://{0}:{1}" -f $_.NetworkSettings.Networks["nat"].IPAddress, $_.Ports.Where{$_.IP -and $_.PublicPort}.PrivatePort
})
