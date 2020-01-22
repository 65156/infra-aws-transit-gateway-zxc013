#configurable variables
$stackname = "transit-gateway"
$uuid = 'zxc013'
$region = "ap-southeast-2"

#fixed variables
$transitgateway = "./files/transit-gateway.yaml"
$source = "./files/source.yaml"
$attachment = "./files/attachment.yaml"
$Accounts = @( 
    [PSCustomObject]@{Account="SandboxICE"; VPC="vpc-07ef9b8277c459d64"; Subnet01="10.94.0.0/22"; Subnet02="10.94.4.0/22"},
    [PSCustomObject]@{Account="SandboxD3"; VPC="vpc-050885cb53b9a1d39"; Subnet01="10.95.0.0/22"; Subnet02="10.95.4.0/22"},
    [PSCustomObject]@{Account="PipelineProd"; VPC="vpc-e818128d"; Subnet01="10.64.100.0/23"; Subnet02="10.64.102.0/23"},
    [PSCustomObject]@{Account="PipelineDev"; VPC="vpc-881b11ed"; Subnet01="10.65.100.0/23"; Subnet02="10.65.102.0/23"},
    [PSCustomObject]@{Account="LegacyProd"; VPC="vpc-0dd57f68"; Subnet01="10.130.100.0/24"; Subnet02="10.130.101.0/24"},
    [PSCustomObject]@{Account="LegadyProdSharedServices"; VPC="vpc-f0d57f95"; Subnet01="10.131.100.0/24"; Subnet02="10.131.101.0/24"},
    [PSCustomObject]@{Account="LegacyDev"; VPC="vpc-bac369df"; Subnet01="10.129.100.0/24"; Subnet02="10.129.101.0/24"}
    #[PSCustomObject]@{Account=""; VPC=""; Subnet01=""; Subnet02=""}, 
) 

#deploy transit gateway in master account
aws-role master master
New-CFNStack -StackName $stackname -TemplateBody (Get-Content $transitgateway -raw) -Region ap-southeast-2

$transitgatewayID = (Get-EC2TransitGateway -Region ap-southeast-2 | ? Tags -like *$projectuuid* ).TransitGatewayId
(Get-Content $source) -replace '$transitgatewayID',"$transitgatewayID" | Out-File $attachment -force

#connect to account to configure transit gateway attachment
foreach($a in $accounts){
    
    aws-role $a.Account admin #Connect to Account

    # Find and replace VPC, Subnets into final attachment.yaml file 
    (Get-Content $attachment) -replace '$vpc',$a.VPC | Out-File $attachment -force
    (Get-Content $attachment) -replace '$subnet01',$a.Subnet01 | Out-File $attachment -force
    (Get-Content $attachment) -replace '$subnet02',$a.Subnet02 | Out-File $attachment -force
    (Get-Content $attachment) -replace '$uuid',$uuid | Out-File $attachment -force

    New-CFNStack -StackName "$stackname-attachment" -TemplateBody (Get-Content $attachment -raw) -Region $region

            }

#Approve-EC2TransitGatewayPeeringAttachment -TransitGatewayAttachmentId $transitgatewayID -Region ap-southeast-2


