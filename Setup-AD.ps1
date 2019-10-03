$DomainName = (import-csv .\ServerList.csv | ? role -like "AD").Domain

$VMName = get-vm | Out-GridView -OutputMode Single 
$VMName = ($VMName).name
$LocalUser = "$VMName\Administrator"
$DSRMPWord = ConvertTo-SecureString -String "Pa55w.rd" -AsPlainText -Force
$LocalCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $LocalUser, $DSRMPWord

function TestifRunning
{
    # After the inital provisioning, we wait until PowerShell Direct is functional and working within the guest VM before moving on.
    # Big thanks to Ben Armstrong for the below useful Wait code 
    Write-Verbose “Waiting for PowerShell Direct to start on VM [$VMName]” -Verbose
    while ((icm -VMName $VMName -Credential $LocalCredential {“Test”} -ea SilentlyContinue) -ne “Test”) {Sleep -Seconds 1}
}


if ((get-VMNetworkAdapter -VMName $VMName).Count -le 2){
TestifRunning
Stop-VM -Name $VMName
Add-VMNetworkAdapter -VMName $VMName -SwitchName "Private Network"
Start-VM -Name $VMName
}

TestifRunning


#Add DSC Modules
Invoke-Command -VMName $VMName -Credential $LocalCredential -ScriptBlock {


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
Install-MissingModule "xActiveDirectory"
Install-MissingModule "xComputerManagement" 
Install-MissingModule "xNetworking"
Install-MissingModule "xStorage"


}



Invoke-Command -VMName $VMName -Credential $LocalCredential -ScriptBlock {

# Configure all of the settings we want to apply for this configuration
$ConfigData = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'
            MachineName = $Using:VMName
            IPAddress = '10.10.10.10'
            InterfaceAlias = 'Ethernet 2'
            DefaultGateway = '127.0.0.1'
            PrefixLength = '24'
            AddressFamily = 'IPv4'
            DNSAddress = '127.0.0.1', '10.10.10.10'
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser = $true
        }
    )
}

Configuration BuildADDC {

    param (
        [Parameter(Mandatory)]
        [String]$FQDomainName,

        [Parameter(Mandatory)]
        [PSCredential]$DomainAdminstratorCreds,

        [Parameter(Mandatory)]
        [PSCredential]$AdmintratorUserCreds,

        [Int]$RetryCount=5,
        [Int]$RetryIntervalSec=30
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xActiveDirectory, `
                                    xComputerManagement, `
                                    xNetworking, `
									xStorage
 
    Node $AllNodes.NodeName 
    {
        LocalConfigurationManager 
        {
            ActionAfterReboot = 'ContinueConfiguration'            
            ConfigurationMode = 'ApplyOnly'            
            RebootNodeIfNeeded = $true  
        }

        # Change Server Name
        xComputer SetName { 
          Name = $Node.MachineName 
        }

        # Networking
        xDhcpClient DisabledDhcpClient
        {
            State          = 'Disabled'
            InterfaceAlias = $Node.InterfaceAlias
            AddressFamily  = $Node.AddressFamily
        }

         xIPAddress NewIPAddress
        {
            IPAddress      = $Node.IPAddress
            InterfaceAlias = $Node.InterfaceAlias
            AddressFamily  = $Node.AddressFamily
        }

        xDefaultGatewayAddress SetDefaultGateway
        {
            Address        = $Node.DefaultGateway
            InterfaceAlias = $Node.InterfaceAlias
            AddressFamily  = $Node.AddressFamily
            DependsOn = '[xIPAddress]NewIPAddress'
        }

       
        xDNSServerAddress SetDNS {
            Address = $Node.DNSAddress
            InterfaceAlias = $Node.InterfaceAlias
            AddressFamily = $Node.AddressFamily
        }

        # Install the Windows Feature for AD DS
        WindowsFeature ADDSInstall {
            Ensure = 'Present'
            Name = 'AD-Domain-Services'
        }

        # Make sure the Active Directory GUI Management tools are installed
        WindowsFeature ADDSTools            
        {             
            Ensure = 'Present'             
            Name = 'RSAT-ADDS'             
        }           

        # Create the ADDS DC
        xADDomain FirstDC {
            DomainName = $FQDomainName
            DomainAdministratorCredential = $DomainAdminstratorCreds
            SafemodeAdministratorPassword = $DomainAdminstratorCreds
            DependsOn = '[xComputer]SetName','[xDefaultGatewayAddress]SetDefaultGateway','[WindowsFeature]ADDSInstall'
        }   
        
        $domain = $FQDomainName.split('.')[0] 
        xWaitForADDomain DscForestWait
        {
            DomainName = $domain
            DomainUserCredential = $DomainAdminstratorCreds
            RetryCount = $RetryCount
            RetryIntervalSec = $RetryIntervalSec
            DependsOn = '[xADDomain]FirstDC'
        } 

        #
        xADRecycleBin RecycleBin
        {
           EnterpriseAdministratorCredential = $DomainAdminstratorCreds
           ForestFQDN = $domain
           DependsOn = '[xADDomain]FirstDC'
        }
        
        # Create an admin user so that the default Administrator account is not used
        xADUser FirstUser
        {
            DomainAdministratorCredential = $DomainAdminstratorCreds
            DomainName = $domain
            UserName = $AdmintratorUserCreds.UserName
            Password = $AdmintratorUserCreds
            Ensure = 'Present'
            DependsOn = '[xADDomain]FirstDC'
        }
        
        xADGroup AddToDomainAdmins
        {
            GroupName = 'Domain Admins'
            MembersToInclude = $AdmintratorUserCreds.UserName
            Ensure = 'Present'
            DependsOn = '[xADUser]FirstUser'
        }
        
    }
}

# Build MOF (Managed Object Format) files based on the configuration defined above 
# (in folder under current dir) 
# Local Admin is assigned 
BuildADDC -ConfigurationData $ConfigData `
          -FQDomainName $Using:DomainName `
          -DomainAdminstratorCreds $using:LocalCredential `
          -AdmintratorUserCreds $using:LocalCredential 

# Make sure that LCM is set to continue configuration after reboot            
Set-DSCLocalConfigurationManager -Path .\BuildADDC –Verbose   -Force

# We now enforce the configuration using the command syntax below
Start-DscConfiguration -Wait -Force -Path .\BuildADDC -Verbose -Debug

}
