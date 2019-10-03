$ServerList = import-csv .\ServerList.csv |  Out-GridView -OutputMode Multiple -Title "Choose VM's"

$ServerList | % {

$templatePath = "C:\Base\Base19D-WS19-1809\Base19D-WS19-1809.vhd"
$VMFolderPath = "C:\Base\Virtual Machines"
$vSwitch = "External Network"
$maxRAM
$diffName = "New - VM"
$SubMaskBit = "24"
$VMName = "$($_.VMName)"
$IP = "$($_.IP)"


#Set the parent VHDX as Read-Only
Set-ItemProperty -Path $templatePath -Name IsReadOnly -Value $true

#Create a folder for the new VM, check if exists.
If (Test-Path ($VMFolderPath + "\" + $VMName)){
 Write-host "FOLDER ALREADY EXISTS. EXITING."
 exit
 }
If ((Test-Path $templatePath) -eq $false){
 Write-host "COULDN'T FIND YOUR TEMPLATE. EXITING."
 exit
 }
$path = new-item $VMFolderPath\$VMName -ItemType Directory

#Create the Differencing Disk VHD
$VHD = New-VHD -Path ($path.FullName + "\" + $VMName + ".vhd") -ParentPath $templatePath  -Differencing

#Create the Virtual Machine; point to the Differential VHD
new-vm -Name $VMName -Path $VMFolderPath -VHDPath $VHD.Path -BootDevice VHD -Generation 1 -SwitchName $vSwitch  | `
 Set-VMMemory -DynamicMemoryEnabled $true `
 -MaximumBytes 2GB -MinimumBytes 512MB -StartupBytes 2GB `

#Checkpoint the VM in case you want to roll it back to before its initial boot
Get-VM $VMName -ComputerName localhost | checkpoint-vm -SnapshotName $diffName

#Turn it up
Start-vm $VMName
#End.

write-host "
================= $VMName =====================
VM  $VMName is created 
Please connect and set Password !
================================================
" -ForegroundColor Yellow


}