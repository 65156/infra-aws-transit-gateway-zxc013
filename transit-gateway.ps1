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
$accounts = @( 
    #accounts are dependant on account names configured in PS-AWS-SSO-AUTH.psm1
    [PSCustomObject]@{Account="SandboxICE"; VPC="vpc-07ef9b8277c459d64"; Subnet01="10.94.0.0/22"; Subnet02="10.94.4.0/22"},
    [PSCustomObject]@{Account="SandboxD3"; VPC="vpc-050885cb53b9a1d39"; Subnet01="10.95.0.0/22"; Subnet02="10.95.4.0/22"},
    [PSCustomObject]@{Account="PipelineProd"; VPC="vpc-e818128d"; Subnet01="10.64.100.0/23"; Subnet02="10.64.102.0/23"},
    [PSCustomObject]@{Account="PipelineDev"; VPC="vpc-881b11ed"; Subnet01="10.65.100.0/23"; Subnet02="10.65.102.0/23"},
    [PSCustomObject]@{Account="LegacyProd"; VPC="vpc-0dd57f68"; Subnet01="10.130.100.0/24"; Subnet02="10.130.101.0/24"},
    [PSCustomObject]@{Account="SharedServices"; VPC="vpc-f0d57f95"; Subnet01="10.131.100.0/24"; Subnet02="10.131.101.0/24"},
    [PSCustomObject]@{Account="LegacyDev"; VPC="vpc-bac369df"; Subnet01="10.129.100.0/24"; Subnet02="10.129.101.0/24"}
    #[PSCustomObject]@{Account=""; VPC=""; Subnet01=""; Subnet02=""}, 
) 

#module dependency check and exit on crit fail
if((Get-Module | ? Name -eq AWSPowerShell.NetCore) -eq $null)(Import-Module AWSPowerSHell.NetCore)
if((Get-Module | ? Name -eq AWSSSO) -eq $null)(Write-Host "Must Load AWSSSO Module PS-AWS-SSO-AUTH" ; exit)

#deploy transit gateway in master account
aws-role master okta
New-CFNStack -StackName $stackname -TemplateBody (Get-Content $transitgateway -raw) -Region $region

$transitgatewayID = (Get-EC2TransitGateway -Region $region | ? Tags -like *$uuid* ).TransitGatewayId

while($transitgatewayID -eq $null){sleep 1} #wait for transit gateway to provision

#connect to each account and configure transit gateway attachment
foreach($a in $accounts){
    
    #Connect to Account
    aws-role $a.Account admin 

    # Find and replace vpc, subnet01, subnet02 and project uuid and output to attachment.yaml
    (Get-Content $attachmentsource) | Foreach-Object {
        $_ -replace '$transitgatewayID',"$transitgatewayID" `
           -replace '$vpc',$a.VPC `
           -replace '$subnet01',$a.Subnet01 `
           -replace '$subnet02',$a.Subnet02 `
           -replace '$uuid',$uuid
        } | Set-Content $attachment -force

    New-CFNStack -StackName "$stackname-attachment" -TemplateBody (Get-Content $attachment -raw) -Region $region
    Remove-Item $attachment -force #cleanup
            }

Approve-EC2TransitGatewayPeeringAttachment -TransitGatewayAttachmentId $transitgatewayID -Region $region


