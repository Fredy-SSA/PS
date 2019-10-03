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
Install-MissingModule "xWebAdministration"

if (Test-Path c:\webpage) {"Webpage dir exist"}
else { mkdir c:\webpage } 



}



Invoke-Command -VMName $VMName -Credential $Cred -ScriptBlock {


Configuration xWebsite_FromConfigurationData
{
    # Import the module that defines custom resources
    Import-DscResource –ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -Module xWebAdministration


    # Dynamically find the applicable nodes from configuration data
    Node $AllNodes.where{$_.Role -eq "Web"}.NodeName
    {
        File DemoFile 
        {
            DestinationPath = 'c:\webpage\life-care\'
            Ensure = 'Present'
            Type = 'File'
            Contents = 'Test Web Site'
            Force = $true
        }
        # Install the IIS role
        WindowsFeature IIS
        {
            Ensure          = "Present"
            Name            = "Web-Server"

        }

        WindowsFeature IISManagement
        {
            Ensure          = "Present"
            Name            = "Web-Mgmt-Tools"
        }
        
  

        # Stop an existing website (set up in Sample_xWebsite_Default)
        xWebsite DefaultSite
        {
            Ensure          = "Present"
            Name            = "Default Web Site"
            State           = "Started"
            PhysicalPath    = $Node.DefaultWebSitePath
            DependsOn       = "[WindowsFeature]IIS"
        }


    }
}

# Content of configuration data file (e.g. ConfigurationData.psd1) could be:
# Hashtable to define the environmental data
$ConfigurationData = @{
    # Node specific data
    AllNodes = @(
       # All the WebServer has following identical information
       @{
            NodeName           = "*"
            WebsiteName        = "foresttime"
       },
       @{
            NodeName           = "localhost"
            Role               = "Web"
        }
    )
}




# Build MOF (Managed Object Format) files based on the configuration defined above 
# (in folder under current dir) 
# Local Admin is assigned 
xWebsite_FromConfigurationData -ConfigurationData $ConfigurationData

# Make sure that LCM is set to continue configuration after reboot            
Set-DSCLocalConfigurationManager -Path .\xWebsite_FromConfigurationData –Verbose   -Force

# We now enforce the configuration using the command syntax below
Start-DscConfiguration -Wait -Force -Path .\xWebsite_FromConfigurationData -Verbose -Debug



}




Invoke-Command -VMName $VMName -Credential $Cred -ScriptBlock {


if (Test-Path c:\webpage\foresttime.zip) {"Zip exist"}
else { 

$url = "https://www.free-css.com/assets/files/free-css-templates/download/page242/chamb.zip"
$output = "c:\webpage\chamb.zip"
$start_time = Get-Date

Invoke-WebRequest -Uri $url -OutFile $output
Write-Output "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"

Expand-Archive c:\webpage\chamb.zip -DestinationPath c:\webpage } 

Copy-Item -Path C:\webpage\chamb\* -Destination C:\inetpub\wwwroot -recurse -Force

}



#>