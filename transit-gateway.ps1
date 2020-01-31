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
  Author:   Fraser Elliot Carter Smith
#>

#configurable variables
$stackname = "transit-gateway"
$uuid = 'zxc013'
$region = "ap-southeast-2"

#fixed variables
$transitgateway = "./files/transit-gateway.yaml"
$attachmentsource = "./files/attachment-source.yaml"
$attachment = "./files/attachment.yaml"

Write-Host "Preparing Files"
Remove-Item $attachment -force 
Write-Host ""
Write-Host "---------------------------" -f black -b green
Write-Host " Deploying Transit Gateway." -f black -b green
Write-Host "---------------------------" -f black -b green
Write-Host ""

$accounts = @( 
    #accounts are dependant on account names configured in PS-AWS-SSO-AUTH.psm1
    [PSCustomObject]@{Account="SandboxICE"; VPC="vpc-07ef9b8277c459d64"; Subnet01="subnet-0d7efaf1da7a86205"; Subnet02="subnet-0ff57e15c6a149282"},
    [PSCustomObject]@{Account="SandboxD3"; VPC="vpc-050885cb53b9a1d39"; Subnet01="subnet-01b0674fb500c8c54"; Subnet02="subnet-0b4fb911505d4de62"}
    #[PSCustomObject]@{Account="PipelineProd"; VPC="vpc-e818128d"; Subnet01="10.64.100.0/23"; Subnet02="10.64.102.0/23"},
    #[PSCustomObject]@{Account="PipelineDev"; VPC="vpc-881b11ed"; Subnet01="10.65.100.0/23"; Subnet02="10.65.102.0/23"},
    #[PSCustomObject]@{Account="LegacyProd"; VPC="vpc-0dd57f68"; Subnet01="10.130.100.0/24"; Subnet02="10.130.101.0/24"},
    #[PSCustomObject]@{Account="SharedServices"; VPC="vpc-f0d57f95"; Subnet01="10.131.100.0/24"; Subnet02="10.131.101.0/24"},
    #[PSCustomObject]@{Account="LegacyDev"; VPC="vpc-bac369df"; Subnet01="10.129.100.0/24"; Subnet02="10.129.101.0/24"}
    #[PSCustomObject]@{Account=""; VPC=""; Subnet01=""; Subnet02=""}, 
) 

# Module dependency check and exit on crit fail
if((Get-Module | ? Name -eq AWSPowerShell.NetCore) -eq $null){Import-Module AWSPowerSHell.NetCore}
if((Get-Module | ? Name -eq AWSSSO) -eq $null){Write-Host "Must Load AWSSSO Module PS-AWS-SSO-AUTH" ; exit}

# Deploy transit gateway in master account
Write-Host "Create Transit Gateway" -f black -b red
Write-Host "Connecting to account: Master" -f cyan 
Switch-RoleAlias master okta

# Check if stack exists 
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
    New-CFNStack -StackName $stackname -TemplateBody (Get-Content $transitgateway -raw) -Region $region 
    
    # Wait for transit gateway to provision
    Wait-CFNStack -Stackname $stackname -region $region
    
  }
  $transitgatewayID = (Get-CFNExport -Region $region | ? Name -eq $stackname).Value
  $resourceshareArn = (Get-RAMResourceShare -resourceowner SELF -region $region | ? OwningAccountId -like 045932084931).ResourceShareArn

Write-Host ""
Write-Host "Create Transit Gateway Attachments" -f black -b red
# Connect to each account and configure transit gateway attachment
$stackname = "$stackname-attachment"

foreach($a in $accounts){   
    # Connect to Account
    $account = $a.account
    Write-Host "Connecting to account: $account" -f cyan 
    Switch-RoleAlias $account admin 


    # accept resource share ARN
    try {Get-RAMResourceShareInvitation -region $region | ? ResourceShareArn -like $resourceshareArn | Confirm-RAMResourceShareInvitation -region $region }
    catch { "Resource already accepted or does not exist...continuing"}
    # Find and replace vpc, subnet01, subnet02, project uuid and output to attachment.yaml
    Write-Host "Building $attachment file" -f green
    (Get-Content $attachmentsource) | Foreach-Object {
        $_ -replace("regextransitgatewayID","$transitgatewayID") `
           -replace("regexvpc",$a.VPC) `
           -replace("regexsubnet01",$a.Subnet01) `
           -replace("regexsubnet02",$a.Subnet02) `
           -replace("regexuuid",$uuid)
        } | Set-Content $attachment -force

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
        New-CFNStack -StackName $stackname -TemplateBody (Get-Content $attachment -raw) -Region $region
        # Wait for gateway attachment to provision
        Wait-CFNStack -Stackname $stackname -region $region
        }
    Write-Host ""
    # Cleanup -- Remove attachment configured .yaml file
    

#Approve-EC2TransitGatewayPeeringAttachment -TransitGatewayAttachmentId $transitgatewayID -Region $region

  }
 Write-Host ""
 Write-Host "---------------------------" -f black -b green
 Write-Host "Script Processing Complete." -f black -b green
 Write-Host "---------------------------" -f black -b green
 Write-Host ""