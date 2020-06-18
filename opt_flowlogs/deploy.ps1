#                                                                         #
#    ▄▄▄█████▓▓█████ ▄▄▄       ███▄ ▄███▓          ██▓ ▄████▄  ▓█████     #
#    ▓  ██▒ ▓▒▓█   ▀▒████▄    ▓██▒▀█▀ ██▒         ▓██▒▒██▀ ▀█  ▓█   ▀     #
#    ▒ ▓██░ ▒░▒███  ▒██  ▀█▄  ▓██    ▓██░         ▒██▒▒▓█    ▄ ▒███       #
#    ░ ▓██▓ ░ ▒▓█  ▄░██▄▄▄▄██ ▒██    ▒██          ░██░▒▓▓▄ ▄██▒▒▓█  ▄     #
#      ▒██▒ ░ ░▒████▒▓█   ▓██▒▒██▒   ░██▒         ░██░▒ ▓███▀ ░░▒████▒    #
#      ▒ ░░   ░░ ▒░ ░▒▒   ▓▒█░░ ▒░   ░  ░         ░▓  ░ ░▒ ▒  ░░░ ▒░ ░    #
#        ░     ░ ░  ░ ▒   ▒▒ ░░  ░      ░          ▒ ░  ░  ▒    ░ ░  ░    #
#      ░         ░    ░   ▒   ░      ░             ▒ ░░           ░       #
#                ░ OFX INFRASTRUCTURE & CLOUD ENGINEERING         ░  ░    #
#                                                                         #                                                        
<#          
.DESCRIPTION
  <Deploys Flow Logs for Transit Gateway>
.INPUTS
  <Modules: PS-AWS-SSO-AUTH
 # Files
  ./files/attachment-source.yaml
  ./files/transit-gateway.yaml>
.OUTPUTS
  <./files/attachment.yaml>
.NOTES
  Author: Fraser Elliot Carter Smith
#>

#fixed variables
$account = "Master"
$redeploy = "true"
$vpcID = "vpc-d0b506b5"
$region = "ap-southeast-2"
$retention = 365
$projectname = "enable-vpc-flow-log"
$flowlogsource = "./vpc-flow-logs-source.yaml"
$flowlogout = "./vpc-flow-logs.yaml"

#Script Begin
Write-Host "---------------------------" 
Write-Host " Deploying VPC Flow Log." -f white -b magenta
Write-Host "---------------------------" 
Write-Host ""

$stackname = $projectname

# Deploy transit gateway in master account
Write-Host "Processing VPC Flow Log Deployment" -f black -b white
Write-Host "Connecting to account: $account" -f white
Switch-RoleAlias $Account okta

$infile = $flowlogsource
$outfile = $flowlogout
Write-Host "Writing $outfile file" -f green
(Get-Content $infile) | Foreach-Object {
    $_ -replace("regexvpcid","$vpcID")`
        -replace("regexretention","$retention")
        } | Set-Content $outfile -force

    $error.clear() ; $stack = 0 ; $stackstatus = 0
    try { $stackstatus = ((Get-CFNStack -Stackname $stackname -region $region).StackStatus).Value }
    catch { $stack = 1 ; Write-Host "Stack does not exist..." } # set stack value to 1 if first deployment
    if($redeploy -eq $true){$stack = 2} #tears down the stack and redeploys if set
      if($rollback -eq $true){$stack = 2}
    if($stack -eq 0){
        # If stack exists, get the stack deployment status and check against google values
        # If match , set stack value to 0 -> skip iteration, else set stack value to 2.
        $goodvalues = @("CREATE_COMPLETE","CREATE_IN_PROGRESS")
        foreach($v in $goodvalues){if($v -eq $stackstatus){ $stack = 0 ; break } else { $stack = 2 } }}
    if($stack -eq 0){ 
      # Stack already deployed or in process of being deployed -> Skip
      Write-Host "Existing Stack Found - Status:" -f white -b magenta -NoNewLine ; Write-Host " $stackstatus" 
      try{ Wait-CFNStack -Stackname $stackname -region $region } catch {}} # stack deployment already in progress, skip iteration
    if($stack -eq 2){
        # Stack exists in a bad state -> Delete  
        Write-Host "Existing Stack Found - Status:" -f white -b magenta -NoNewLine ; Write-Host " $stackstatus"
        Remove-CFNStack -Stackname $stackname -region $region -force  
        try{ Wait-CFNStack -Stackname $stackname -region $region } catch {} # try wait for stack removal if needed, catch will hide error if stack does not exist.
        if($rollback -eq $true){ $stack = 0 } #rolling back break loop
        }
    if($stack -ge 1){ # Stack does not exist -> Deploy 
        $error.clear()
        # Attempts to validate the CF template.
        Write-host "Validating CF Template: " -nonewline ; 
        Test-CFNTemplate -templateBody (Get-Content $outfile -raw) -Region $region
        if($error.count -gt 0){Write-Host "Error Validation Failure!" -f red ; Write-Host "" ;  continue } 
        if($error.count -eq 0){Write-Host "Template is Valid" -f green ; Write-Host "" }
        Write-Host "Creating Stack: " -f White -b Magenta -NoNewLine ; Write-Host " $stackname"-f black -b white
        try { New-CFNStack -StackName $stackname -TemplateBody (Get-Content $outfile -raw) -Region $region } catch [System.InvalidOperationException] {
            New-CFNStack -StackName $stackname -TemplateBody (Get-Content $outfile -raw) -Region $region -Capability CAPABILITY_NAMED_IAM
        } #tries to deploys the stack, if there is a invalidoperation error assumes its lacking IAM Capability and re-attempts.
        try{ Wait-CFNStack -Stackname $stackname -region $region -timeout 240 } catch { Write-Host " $stackname failed" -f black -b red }
        }

Write-Host ""
Write-Host "---------------------------" 
Write-Host "Script Processing Complete." -f white -b magenta
Write-Host "---------------------------" 
Write-Host ""
Write-Host ""