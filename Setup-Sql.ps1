$AD = import-csv .\ServerList.csv | ? role -like "AD"
$User = $AD.Domain +"\Administrator"
$Pass = $AD.Password
$Domain = $AD.Domain
$VMName = get-vm | Out-GridView -OutputMode Single 
$VMName = ($VMName).name

$DSRMPWord = ConvertTo-SecureString -String $Pass -AsPlainText -Force
$Cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $DSRMPWord



set-vmdvddrive -VMName $VMName -Path C:\Base\en_sql_server_2017_developer_x64_dvd_11296168.iso

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
Install-MissingModule "SqlServerDsc"
Install-MissingModule "cChoco"


}



Invoke-Command -VMName $VMName -Credential $Cred -ScriptBlock {

Configuration SQLServerConfiguration
{
  Import-DscResource -ModuleName PSDesiredStateConfiguration
  Import-DscResource -ModuleName SqlServerDsc
  node localhost
  {
    WindowsFeature 'NetFramework45' {
      Name   = 'NET-Framework-45-Core'
      Ensure = 'Present'
    }

    SqlSetup 'InstallDefaultInstance'
    {
      InstanceName        = 'MSSQLSERVER'
      Features            = 'SQLENGINE'
      SourcePath          = 'D:\'
      SQLSysAdminAccounts = @('Administrators')
      DependsOn           = '[WindowsFeature]NetFramework45'
    }
  }
}




# Build MOF (Managed Object Format) files based on the configuration defined above 
# (in folder under current dir) 
# Local Admin is assigned 
SQLServerConfiguration 

# Make sure that LCM is set to continue configuration after reboot            
Set-DSCLocalConfigurationManager -Path .\SQLServerConfiguration  –Verbose   -Force

# We now enforce the configuration using the command syntax below
Start-DscConfiguration -Wait -Force -Path .\SQLServerConfiguration  -Verbose -Debug



}



Invoke-Command -VMName $VMName -Credential $Cred -ScriptBlock {
Configuration SoftwarePackagesConfig {
    
    Import-DscResource -ModuleName cChoco

    Node $env:COMPUTERNAME  {

        cChocoInstaller InstallChocolatey {
            InstallDir = "C:\ProgramData\chocolatey"
        }

        cChocoPackageInstaller "sql-server-management-studio" {
            Name = "sql-server-management-studio"
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


#>


