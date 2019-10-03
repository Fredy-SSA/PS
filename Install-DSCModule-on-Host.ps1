
function Install-MissingModule ($Module)
{
    if (Get-Module -ListAvailable -Name "$Module") {
    Write-Host "Module $Module allredy exists"
    } 
    else {
    find-module  $Module | Install-Module -force -Confirm:$False

    }
    
}

Install-PackageProvider -Name NuGet -Force -Confirm:$False
Install-MissingModule "SqlServerDsc"
Install-MissingModule "xActiveDirectory"
Install-MissingModule "xComputerManagement" 
Install-MissingModule "xNetworking"
Install-MissingModule "xStorage"
Install-MissingModule "xWebAdministration"
Install-MissingModule "xPsDesiredStateConfiguration"
Install-MissingModule "DFSDsc"
Install-MissingModule "cChoco"
