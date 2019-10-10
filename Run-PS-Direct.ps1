$VMName = get-vm | Out-GridView -OutputMode Multiple
$VMName = ($VMName).name

$Cred = Get-Credential

Invoke-Command -VMName $VMName -Credential $Cred -ScriptBlock {

"Hostname is :"
Hostname



}