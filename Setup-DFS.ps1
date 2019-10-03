$AD = import-csv .\ServerList.csv | ? role -like "AD"

$User = $AD.Domain +"\Administrator"
$Pass = $AD.Password
$DSRMPWord = ConvertTo-SecureString -String $Pass -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $DSRMPWord
$Ad= $AD.Domain 


$VMName = get-vm | Out-GridView -OutputMode Single
$VMName = ($VMName).name



$VMName | % {

Invoke-Command -VMName $_ -Credential $Credential -ScriptBlock {

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
Install-MissingModule "DFSDsc"

Enable-PSRemoting -Force -Confirm:$false
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
New-Item "C:\public" –type directory


if (Test-Path  C:\public\departments\finance) {"Directory C:\public\departments\finance exist"}
else {
mkdir C:\public\departments\finance
}
if (Test-Path  C:\public\departments\management) {"Directory C:\public\departments\management exist"}
else {
mkdir C:\public\departments\management
}



IF (!(GET-SMBShare -Name "Finance"))
{

New-SMBShare –Name "Finance" –Path "C:\public\departments\finance" –FullAccess Everyone  `

} 
IF (!(GET-SMBShare -Name "Finance"))
{

New-SMBShare –Name "Management" –Path "C:\public\departments\management" –FullAccess Everyone  

} 

IF (!(GET-SMBShare -Name "Departments"))
{

New-SMBShare –Name "Departments" –Path "C:\public\departments" –FullAccess Everyone  

} 



}

}



$VMName | % {

Invoke-Command -VMName $_ -Credential $Credential -ScriptBlock {


$ConfigData = @{
    AllNodes = @(
        @{
            NodeName = "localhost"
            Role = "DFS"
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser = $true
            }
    )
}
# Save ConfigurationData in a file with .psd1 file extension


Configuration DFSNamespaceServerConfiguration
{

    Import-DscResource –ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName 'DFSDsc'



    Node localhost
    {
        <#
            Install the Prerequisite features first
            Requires Windows Server 2012 R2 Full install
        #>
        WindowsFeature RSATDFSMgmtConInstall
        {
            Ensure = 'Present'
            Name = 'RSAT-DFS-Mgmt-Con'
        }

        WindowsFeature DFS
        {
            Name = 'FS-DFS-Namespace'
            Ensure = 'Present'
        }
         # Configure the namespace root
         DFSNamespaceRoot DFSNamespaceRoot_Public
        {
            Path                 = "\\$Using:AD\public"
            TargetPath           = "\\DFS-SRV1\public"
            Ensure               = 'Present'
            Type                 = 'DomainV2'
            Description          = 'AD Domain based DFS namespace for storing departmental files'
            TimeToLiveSec        = 600
            PsDscRunAsCredential = $Using:Credential
        } # End of DFSNamespaceRoot Resource
        

        # Configure the namespace folder
        DFSNamespaceFolder DFSNamespaceFolder_Standalone_PublicBrochures
        {
            Path                 = "\\$Using:AD\public\brochures"
            TargetPath           = "\\DFS-SRV1\brochures"
            Ensure               = 'Present'
            Description          = 'AD Domain based DFS namespace for storing departmental files'
            PsDscRunAsCredential = $Using:Credential
        } # End of DFSNamespaceFolder Resource
        DFSNamespaceRoot DFSNamespaceRoot_Domain_Departments
        {
            Path                 = "\\$Using:AD\departments"
            TargetPath           = "\\DFS-SRV1\departments"
            Ensure               = 'Present'
            Type                 = 'DomainV2'
            Description          = 'AD Domain based DFS namespace for storing departmental files'
            TimeToLiveSec        = 600
            PsDscRunAsCredential = $Using:Credential
        } # End of DFSNamespaceRoot Resource

        # Configure the namespace folders
        DFSNamespaceFolder DFSNamespaceFolder_Domain_Finance
        {
            Path                 = "\\$Using:AD\departments\finance"
            TargetPath           = "\\DFS-SRV1\Finance"
            Ensure               = 'Present'
            Description          = 'AD Domain based DFS namespace folder for storing finance files'
            TimeToLiveSec        = 600
            PsDscRunAsCredential = $Using:Credential
        } # End of DFSNamespaceFolder Resource

        DFSNamespaceFolder DFSNamespaceFolder_Domain_Management
        {
            Path                 = "\\$Using:AD\departments\management"
            TargetPath           = "\\DFS-SRV1\Management"
            Ensure               = 'Present'
            Description          = 'AD Domain based DFS namespace folder for storing management files'
            TimeToLiveSec        = 600
            PsDscRunAsCredential = $Using:Credential
        } # End of DFSNamespaceFolder Resource




    }
}


# Build MOF (Managed Object Format) files based on the configuration defined above 
# (in folder under current dir) 
# Local Admin is assigned 
DFSNamespaceServerConfiguration -ConfigurationData $ConfigData

# Make sure that LCM is set to continue configuration after reboot            
Set-DSCLocalConfigurationManager -Path .\DFSNamespaceServerConfiguration –Verbose   -Force

# We now enforce the configuration using the command syntax below
Start-DscConfiguration -Wait -Force -Path .\DFSNamespaceServerConfiguration -Verbose -Debug



}




}