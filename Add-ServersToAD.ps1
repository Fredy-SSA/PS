$AD = import-csv .\ServerList.csv | ? role -like "AD"

$User = $AD.Domain +"\Administrator"
$Pass = $AD.Password
$DSRMPWord = ConvertTo-SecureString -String $Pass -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $DSRMPWord
$Ad= $AD.Domain 



$VMName = get-vm | ? name -NotLike "dc-ad*" |Out-GridView -OutputMode Multiple
$VMName = ($VMName).name

$LocalUser = "$VMName\Administrator"
$DSRMPWord = ConvertTo-SecureString -String $Pass -AsPlainText -Force
$LocalCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $LocalUser, $DSRMPWord

$VMName | % {

Invoke-Command -VMName $_ -Credential $LocalCredential -ScriptBlock {

add-computer –domainname $Using:AD -Credential $Using:Credential -restart –force

}

}