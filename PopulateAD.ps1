$AD = import-csv .\ServerList.csv | ? role -like "AD"
$ADDC= ($AD.Domain).Split(".")
$User = $AD.Domain +"\Administrator"
$Pass = $AD.Password
$VMName = $AD.VMName

$DSRMPWord = ConvertTo-SecureString -String $Pass -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $DSRMPWord


$users = import-csv .\Users.csv

Invoke-Command -VMName $VMName -Credential $Credential -ScriptBlock {

#Create OU
$ou = "Managers","Sales","Marketing","Employees","IT"
$ou | % {
#Create OU
New-ADOrganizationalUnit -Name $_ -Description "Account for : $_" -PassThru  -verbose
#Create Security Groups
New-ADGroup -Path "OU=$_,DC=$($Using:ADDC[0]),DC=$($Using:ADDC[1])" -Name "DG-$_" -GroupScope Global -GroupCategory Security  -verbose
}
#Create Users
$Using:users | % {
New-ADUser -Name "$($_.GivenName)" -GivenName $($_.GivenName) -Surname $($_.Surname) -SamAccountName "$($_.GivenName).$($_.Surname)" -UserPrincipalName "$($_.GivenName) $($_.Surname)@$env:USERDNSDOMAIN" -Path "OU=$($_.Role),DC=$($Using:ADDC[0]),DC=$($Using:ADDC[1])" -AccountPassword($Using:DSRMPWord) -Enabled $true -verbose
}
#PopulateSecurityGroup
$Using:users | select Role -Unique

$PopulateGroup = ($Using:users | select Role -Unique).Role
$PopulateGroup |% {

$Users = Get-ADUser -Filter * | ?  DistinguishedName -like "*$_*"

Get-ADGroup -Filter * -Properties DistinguishedName | ?  DistinguishedName -like "*$_*" | Add-ADGroupMember -Members $Users
}


}

