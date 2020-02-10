    
$stackrem = 0
try { $stackstatus = ((Get-CFNStack -Stackname $stackname -region $region).StackStatus).Value }
catch { $stackrem = 1 ; Write-Host "Stack does not exist, nothing to remove."} # stack does not exist nothing to remove
if($stackrem -eq 0){
    Write-Host "Removing Failed Stack:" -f magenta -nonewline ; Write-Host " $stackname"
    Remove-CFNStack -Stackname $stackname -region $region -force }