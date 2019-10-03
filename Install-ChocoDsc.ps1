$AD = import-csv .\ServerList.csv | ? role -like "AD"
$User = $AD.Domain +"\Administrator"
$Pass = $AD.Password
$Domain = $AD.Domain
$VMName = get-vm | Out-GridView -OutputMode Single 
$VMName = ($VMName).name

$DSRMPWord = ConvertTo-SecureString -String $Pass -AsPlainText -Force
$Cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $DSRMPWord



Invoke-Command -VMName $VMName -Credential $Cred -ScriptBlock {

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
Install-MissingModule "cChoco"


}


Invoke-Command -VMName $VMName -Credential $Cred -ScriptBlock {
Configuration SoftwarePackagesConfig {
    
    Import-DscResource -ModuleName cChoco

    Node $env:COMPUTERNAME  {

        cChocoInstaller InstallChocolatey {
            InstallDir = "C:\ProgramData\chocolatey"
        }

        cChocoPackageInstaller "sysinternals" {
            Name = "sysinternals"
            DependsOn = "[cChocoInstaller]InstallChocolatey"
        }
        cChocoPackageInstaller "vscode" {
            Name = "vscode"
            DependsOn = "[cChocoInstaller]InstallChocolatey"
        }
         cChocoPackageInstaller "adobereader" {
         Name = "adobereader"
         DependsOn = "[cChocoInstaller]InstallChocolatey"
        }
    }
}




# Build MOF (Managed Object Format) files based on the configuration defined above 
# (in folder under current dir) 
# Local Admin is assigned 
SoftwarePackagesConfig

# Make sure that LCM is set to continue configuration after reboot            
Set-DSCLocalConfigurationManager -Path .\SoftwarePackagesConfig  –Verbose   -Force

# We now enforce the configuration using the command syntax below
Start-DscConfiguration -Wait -Force -Path .\SoftwarePackagesConfig  -Verbose -Debug



}