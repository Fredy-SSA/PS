$ServerList = import-csv .\ServerList.csv | ? VMName  -NotLike "*DC-AD*"  | Out-GridView -OutputMode Multiple -Title "Pre Configure VM's !"

$ServerList | % {

$VMName = "$($_.vmname)"
$IP = "$($_.ip)"
$SubMaskBit = 24


$LocalUser = "$VMName\Administrator"
$DSRMPWord = ConvertTo-SecureString -String $($_.Password) -AsPlainText -Force
$LocalCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $LocalUser, $DSRMPWord

function TestifRunning
{
    # After the inital provisioning, we wait until PowerShell Direct is functional and working within the guest VM before moving on.
    Write-Verbose “Waiting for PowerShell Direct to start on VM [$VMName]” -Verbose
    while ((icm -VMName $VMName -Credential $LocalCredential {“Test”} -ea SilentlyContinue) -ne “Test”) {Sleep -Seconds 1}
}


#Add new Private Private   
if ((get-VMNetworkAdapter -VMName $VMName).Count -le 2){
TestifRunning
Stop-VM -Name $VMName
Add-VMNetworkAdapter -VMName $VMName -SwitchName "Private Network"
Start-VM -Name $VMName
}

TestifRunning

# Next we configure the networking for the new DC VM. 
# NOTE: The InterfaceAlias value may be different for your gold image, so adjust accordingly.
# NOTE: InterfaceAlias can be found by making use of the Get-NetIPAddress Cmdlet  
$GW = (import-csv .\ServerList.csv | ? role -like "AD").IP
Invoke-Command -VMName $VMName -Credential $LocalCredential -ScriptBlock {
    
    New-NetIPAddress -IPAddress "$Using:IP" -InterfaceAlias "Ethernet 2" -PrefixLength "$Using:SubMaskBit"  -DefaultGateway $Using:GW | Out-Null
    $DCEffectiveIP = Get-NetIPAddress -InterfaceAlias "Ethernet 2" | Select-Object IPAddress
    Get-NetIPAddress -InterfaceAlias "Ethernet 2" | Set-DnsClientServerAddress -ServerAddresses ("$Using:GW")
    Write-Verbose "Assigned IPv4 and IPv6 IPs for VM [$Using:VMName] are as follows" -Verbose 
    Write-Host $DCEffectiveIP | Format-List

    $name = hostname #cheeck if name is diferent !
    if ($name -like $Using:VMName) {"Name  for VM is [$Using:VMName]"}
    else {
    Write-Verbose "Updating Hostname for VM [$Using:VMName]" -Verbose
    Rename-Computer -NewName "$Using:VMName"
    Write-Verbose "Rebooting VM [$Using:VMName] for hostname change to take effect" -Verbose

    
    }

   

    }

       
    Stop-VM -Name $VMName
    Start-VM -Name $VMName

    } 




