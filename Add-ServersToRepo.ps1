$AD = import-csv .\ServerList.csv | ? role -like "AD"

$User = $AD.Domain +"\Administrator"
$Pass = $AD.Password
$DSRMPWord = ConvertTo-SecureString -String $Pass -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $DSRMPWord
$Ad= $AD.Domain 



$VMName = get-vm | Out-GridView -OutputMode Multiple
$VMName = ($VMName).name

$VMName | % {

Invoke-Command -VMName $_ -Credential $Credential -ScriptBlock {

$Path = "\\REPO-SRV1\LocalRepository"
Import-Module PowerShellGet 

$repo = @{
    Name = 'LocalRepository'
    SourceLocation = $Path
    PublishLocation = $Path
    InstallationPolicy = 'Trusted'
}
Register-PSRepository @repo

Get-PSRepository


}

}