# PS
Create template VM's on Hyper-V with Powershell-Direct , Powershell DSC 

In Progress
Prerequisite:
Edit  - >  ServerList.csv (In this momend just add new VM's if is needed)

Edit -> Create-New-VM-FromList.ps1 ->  C:\Base\Base19D-WS19-1809\Base19D-WS19-1809.vhd 
Or
Prepare the base line - Create a new Windows Server and prepare to be cloned with Sysprep and shutdown the VM
Copy VHD in C:\Base\Base19D-WS19-1809\ rename to Base19D-WS19-1809.vhd  or edit in Create-New-VM-FromList.ps1 

https://www.petri.com/using-syspre-windows-10

Download sql setup iso  en_sql_server_2017_developer_x64_dvd_11296168.iso 
copy in C:\Base\en_sql_server_2017_developer_x64_dvd_11296168.iso

Run Install-DSCModule-on-Host.ps1 on Hyper-V Host


Copy all file in a local Directory ex: c:\SetupVM  
Run all scripts from this directory c:\SetupVM  

## Setup
1. - Create-New-VM-FromList.ps1
2. - Create local Password on VM's
3. - Setup-AD.ps1
4. - PopulateAD.ps1
5. - Pre-Configure-VM-FromList.ps1
6. - Add-ServersToAD.ps1
7. - Setup-Repo.ps1, Setup-DFS.ps1 , Setup-SQL.ps1 ,Setup-WEB.ps1
8. - Add-ServersToRepo.ps1
10. - Install-ChocoDsc.ps1 


