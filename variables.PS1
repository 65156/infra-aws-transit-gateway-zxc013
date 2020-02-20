#configurable variables
$projectname = "transit-gateway"
$bgpASN = "65100"
$uuid = 'zxc013'
$region = "ap-southeast-2"

$accounts = @( 
    #accounts are dependant on account names configured in PS-AWS-SSO-AUTH.psm1
    [PSCustomObject]@{Account="Master"; AccountID="045932084931"; Master=$true},
    [PSCustomObject]@{Account="SandboxICE"; AccountID="925446695292" ;VPC="vpc-07ef9b8277c459d64"; Subnets=("subnet-0d7efaf1da7a86205","subnet-0ff57e15c6a149282")},
    [PSCustomObject]@{Account="SandboxD3"; AccountID="978308152145" ; VPC="vpc-050885cb53b9a1d39"; Subnets=("subnet-01b0674fb500c8c54","subnet-0b4fb911505d4de62")}
    #[PSCustomObject]@{Account="PipelineProd"; AccountID="995405243001" ; VPC="vpc-881b11ed"; Subnets=("","","")},
    #[PSCustomObject]@{Account="PipelineProd"; AccountID="995405243001" ; VPC="vpc-881b11ed"; Subnets=("","","")},
    #[PSCustomObject]@{Account="PipelineDev"; AccountID="995405243001" ; VPC="vpc-881b11ed"; Subnets=("","","")},
    #[PSCustomObject]@{Account="LegacyProd"; AccountID="368940151251" ; VPC="vpc-0dd57f68"; Subnets=("","","")},
    #[PSCustomObject]@{Account="LegacyProd"; AccountID="368940151251" ; VPC="vpc-f0d57f95"; Subnets=("","","")},
    #[PSCustomObject]@{Account="LegacyDev"; AccountID="128288646639" ; VPC="vpc-bac369df"; Subnets=("","","")} 
) 

