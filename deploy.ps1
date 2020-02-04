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
  <Deploys Transit Gateway and Transit Gateway Attachments in Child Accounts>
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
$variables = . "./variables.ps1"
$transitgateway = "./files/transit-gateway.yaml"
$resourcesharesource = "./files/resource-share-source.yaml"
$attachmentsource = "./files/attachment-source.yaml"
$attachment = "./files/attachment.yaml"
$resourceshare = "./files/resource-share.yaml"

Write-Host "Preparing Files"
$accounts = @( 
    #accounts are dependant on account names configured in PS-AWS-SSO-AUTH.psm1
    [PSCustomObject]@{Account="Master"; AccountID="045932084931"; Skip=$true},
    [PSCustomObject]@{Account="SandboxICE"; AccountID="925446695292" ;VPC="vpc-07ef9b8277c459d64"; Subnet01="subnet-0d7efaf1da7a86205"; Subnet02="subnet-0ff57e15c6a149282"},
    [PSCustomObject]@{Account="SandboxD3"; AccountID="978308152145" ; VPC="vpc-050885cb53b9a1d39"; Subnet01="subnet-01b0674fb500c8c54"; Subnet02="subnet-0b4fb911505d4de62"}
    #[PSCustomObject]@{Account="PipelineProd"; AccountID="995405243001" ; VPC="vpc-881b11ed"; Subnet01="10.65.100.0/23"; Subnet02="10.65.102.0/23"},
    #[PSCustomObject]@{Account="PipelineDev"; AccountID="995405243001" ; VPC="vpc-881b11ed"; Subnet01="10.65.100.0/23"; Subnet02="10.65.102.0/23"},
    #[PSCustomObject]@{Account="LegacyProd"; AccountID="368940151251" ; VPC="vpc-0dd57f68"; Subnet01="10.130.100.0/24"; Subnet02="10.130.101.0/24"},
    #[PSCustomObject]@{Account="SharedServices"; AccountID="368940151251" ; VPC="vpc-f0d57f95"; Subnet01="10.131.100.0/24"; Subnet02="10.131.101.0/24"; Skip=$true },
    #[PSCustomObject]@{Account="LegacyDev"; AccountID="128288646639" ; VPC="vpc-bac369df"; Subnet01="10.129.100.0/24"; Subnet02="10.129.101.0/24"} 
) 
$masteraccountid = ($accounts | ? Account -eq $masteraccountname).AccountId   

Remove-Item $attachment -force 
Remove-Item $resourceshare -force
Write-Host ""
Write-Host "---------------------------" -f black -b green
Write-Host " Deploying Transit Gateway." -f black -b green
Write-Host "---------------------------" -f black -b green
Write-Host ""

# Module dependency check and exit on crit fail
if((Get-Module | ? Name -eq AWSPowerShell.NetCore) -eq $null){Import-Module AWSPowerSHell.NetCore}
if((Get-Module | ? Name -eq AWSSSO) -eq $null){Write-Host "Must Load AWSSSO Module PS-AWS-SSO-AUTH" ; exit}

# Deploy transit gateway in master account
Write-Host "Create Transit Gateway" -f black -b red
Write-Host "Connecting to account: $masteraccountname" -f cyan 
Switch-RoleAlias $masteraccountname okta

# Check if stack exists 
$stackname = $projectname
$file = $transitgateway
$error.clear() ; $stack = 0 ; $stackstatus = 0
try { $stackstatus = ((Get-CFNStack -Stackname $stackname -region $region).StackStatus) }
catch { Write-Host "Stack does not exist" -f green ; $stack = 1 }
  if($stackstatus -eq "CREATE_COMPLETE"){$stack = 0 ; Write-Host "Existing Stack Status: " -f yellow -b magenta -NoNewLine ; Write-Host "CREATE_COMPLETE... Skipping."} 
  if($stackstatus -ne "CREATE_COMPLETE"){$stack = 2}
  if($stack -eq 2){
    Write-Host "Removing Failed Stack"
    Remove-CFNStack -Stackname $stackname -region $region -force  
    Wait-CFNStack -Stackname $stackname -region $region -Status 'DELETE_COMPLETE' 
    } #stack exists but in bad state ->>> delete 
  if($stack -ge 1){ 
    # Create Stack
    Write-Host "Creating Stack" -f black -b cyan
    New-CFNStack -StackName $stackname -TemplateBody (Get-Content $file -raw) -region $region    
    # Wait for transit gateway to provision
    Wait-CFNStack -Stackname $stackname -region $region 
  }
  #get variables to create yaml files for RAM and Transit Gateway attachments Cloud Formations
  $transitgatewayID = (Get-CFNExport -Region $region | ? Name -eq $stackname).Value
  $transitgatewayARN = (Get-EC2TransitGateway -region $region | ? TransitGatewayId -eq $transitgatewayID).TransitGatewayArn

#Share Transit Gateway via RAM
Write-Host "Create Transit Gateway Resource Share" -f black -b red

Write-Host "Creating Principals List"
$principalslist = ""
foreach($a in $accounts){
  $accountID = $a.AccountId 
  $skip = $a.Skip ; if($skip -eq $true){continue}
  $principalslist += "- $accountID `n"+"        "}
  
Write-Host "Building $file file" -f green
$file = $resourceshare
$resourcesharename = $stackname
(Get-Content $resourcesharesource) | Foreach-Object {
    $_ -replace("regexprincipals","$principalslist") `
       -replace("regexname",$stackname) `
       -replace("regexresourcearns",$transitgatewayARN) 
    } | Set-Content $file -force

$stackname = "$projectname-share"
Write-Host "Creating Resource Share" 
$error.clear() ; $stack = 0 ; $stackstatus = 0
try {$resourceshareArn = (Get-RAMResourceShare -resourceowner SELF -region $region | ? Name -like $stackname).ResourceShareArn
      if($resourceshareArn -eq $nul){ $stack = 1 } }
      catch { "Resource share does not exist...continuing" }
      try { $stackstatus = ((Get-CFNStack -Stackname $stackname -region $region).StackStatus) }
      catch { Write-Host "Stack does not exist" -f green  ; $stack = 1 }
      if($stackstatus -eq "CREATE_COMPLETE"){$stack = 0 ; Write-Host "Existing Stack Status: " -f yellow -b magenta -NoNewLine ; Write-Host "CREATE_COMPLETE... Skipping."} 
      if($stackstatus -ne "CREATE_COMPLETE"){$stack = 2}

      if($stack -eq 2){
          Write-Host "Removing Failed Stack"
          Remove-CFNStack -Stackname $stackname -region $region -force  
          Wait-CFNStack -Stackname $stackname -region $region -Status 'DELETE_COMPLETE' 
          } #stack exists but in bad state ->>> delete 
      if($stack -ge 1){  
          # Create Stack
          Write-Host "Creating Stack" -f black -b cyan
          New-CFNStack -StackName $stackname -TemplateBody (Get-Content $file -raw) -Region $region
          # Wait for gateway attachment to provision
          Wait-CFNStack -Stackname $stackname -region $region
          }
    
Write-Host ""
Write-Host "Create Transit Gateway Attachments" -f black -b red
# Connect to each account and configure transit gateway attachment
$stackname = "$projectname-attachment"
$file = $attachment
foreach($a in $accounts){   
    # Connect to Account
    $accountskip = $a.Skip ; if($accountskip -eq $true){continue} #skips processing 
    $account = $a.account
    Write-Host "Connecting to account: $account" -f cyan 
    Switch-RoleAlias $account admin 

    # accept resource share ARN
    try {Get-RAMResourceShareInvitation -region $region | ? ResourceShareName -like $resourcesharename | Confirm-RAMResourceShareInvitation -region $region ; Write-Host "Accepting Share" -f black -b cyan}
    catch { "Resource already accepted or does not exist...continuing" -f yellow }
    # Find and replace vpc, subnet01, subnet02, project uuid and output to attachment.yaml
    Write-Host "Building $file file" -f green
    (Get-Content $attachmentsource) | Foreach-Object {
        $_ -replace("regextransitgatewayID","$transitgatewayID") `
           -replace("regexvpc",$a.VPC) `
           -replace("regexsubnet01",$a.Subnet01) `
           -replace("regexsubnet02",$a.Subnet02) `
           -replace("regexuuid",$uuid)
        } | Set-Content $file -force

    $error.clear() ; $stack = 0 ; $stackstatus = 0
 
    try { $stackstatus = ((Get-CFNStack -Stackname $stackname -region $region).StackStatus) }
    catch { Write-Host "Stack does not exist" -f green  ; $stack = 1 }
    if($stackstatus -eq "CREATE_COMPLETE"){$stack = 0 ; Write-Host "Existing Stack Status: " -f yellow -b magenta -NoNewLine ; Write-Host "CREATE_COMPLETE... Skipping."} 
    if($stackstatus -ne "CREATE_COMPLETE"){$stack = 2}

    if($stack -eq 2){
        Write-Host "Removing Failed Stack"
        Remove-CFNStack -Stackname $stackname -region $region -force  
        Wait-CFNStack -Stackname $stackname -region $region -Status 'DELETE_COMPLETE' 
        } #stack exists but in bad state ->>> delete 
    if($stack -ge 1){  
        # Create Stack
        Write-Host "Creating Stack" -f black -b cyan
        New-CFNStack -StackName $stackname -TemplateBody (Get-Content $file -raw) -Region $region
        # Wait for gateway attachment to provision
        Wait-CFNStack -Stackname $stackname -region $region
        }
    Write-Host ""
    # Cleanup -- Remove attachment configured .yaml file
    

  }
 Write-Host ""
 Write-Host "---------------------------" -f black -b green
 Write-Host "Script Processing Complete." -f black -b green
 Write-Host "---------------------------" -f black -b green
 Write-Host ""