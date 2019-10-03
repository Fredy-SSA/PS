$AD = import-csv .\ServerList.csv | ? role -like "AD"
$User = $AD.Domain +"\Administrator"
$Pass = $AD.Password
$Domain = $AD.Domain
$VMName = get-vm | Out-GridView -OutputMode Single 
$VMName = ($VMName).name

$DSRMPWord = ConvertTo-SecureString -String $Pass -AsPlainText -Force
$Cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $DSRMPWord


Invoke-Command -VMName $VMName -Credential $Cred -ScriptBlock {

if (Test-Path "c:\LocalRepository"){"Install aborted c:\LocalRepository is allredy created"}
else{
MKdir "c:\LocalRepository"

New-SmbShare -Name "LocalRepository" -Description "LocalRepository" -Path "c:\LocalRepository"
Grant-SmbShareAccess -Name "LocalRepository" -AccountName "$Using:Domain\DG-IT" -AccessRight Full -Force
Grant-SmbShareAccess -Name "LocalRepository" -AccountName "$Using:Domain\Administrator" -AccessRight Full -Force

$Path = "\\$env:COMPUTERNAME\LocalRepository"

Install-PackageProvider -Name NuGet -Force -Confirm:$False
Import-Module PowerShellGet

$repo = @{
    Name = 'LocalRepository'
    SourceLocation = $Path
    PublishLocation = $Path
    InstallationPolicy = 'Trusted'
}
Register-PSRepository @repo

Get-PSRepository
}


function Install-MissingModule ($Module)
{
    if (Get-Module -ListAvailable -Name "$Module") {
    Write-Host "Module $Module allredy exists"
    } 
    else {
    find-module  $Module | Install-Module -force -Confirm:$False
    Publish-Module -Name $Module -Repository LocalRepository -Verbose -Force
    }
    
}

Install-PackageProvider -Name NuGet -Force -Confirm:$False

Install-MissingModule "xActiveDirectory"
Install-MissingModule "xComputerManagement" 
Install-MissingModule "xNetworking"
Install-MissingModule "xStorage"
Install-MissingModule "xWebAdministration"
Install-MissingModule "xPsDesiredStateConfiguration"
Install-MissingModule "DFSDsc"



}




