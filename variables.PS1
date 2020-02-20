#configurable variables
$projectname = "transit-gateway"
$bgpASN = "65100"
$uuid = 'zxc013'
$region = "ap-southeast-2"
$rollback = $false

$accounts = @( 
    #accounts are dependant on account names configured in PS-AWS-SSO-AUTH.psm1
    [PSCustomObject]@{Account="Master"; AccountID="045932084931"; Master=$true},
    [PSCustomObject]@{Account="PipelineProd"; AccountID="479125032639" ; VPC="vpc-e818128d"; Subnets=("subnet-353ec243","subnet-a9837cf0","subnet-e111c085")},
    [PSCustomObject]@{Account="PipelineProd"; AccountID="479125032639" ; VPC="vpc-bba786de"; Subnets=("subnet-c1d5d2b6","subnet-eb2137ad")},
    [PSCustomObject]@{Account="PipelineDev"; AccountID="995405243001" ; VPC="vpc-881b11ed"; Subnets=("subnet-e73dc191","subnet-82ee3fe6","subnet-21837c78")},
    [PSCustomObject]@{Account="LegacyProd"; AccountID="368940151251" ; VPC="vpc-0dd57f68"; Subnets=("subnet-f7894f81","subnet-eb05dd8f","subnet-28834671")},
    [PSCustomObject]@{Account="LegacyProd"; AccountID="368940151251" ; VPC="vpc-f0d57f95"; Subnets=("subnet-198b4d6f","subnet-1e03db7a","subnet-7f824726")},
    [PSCustomObject]@{Account="LegacyDev"; AccountID="128288646639" ; VPC="vpc-bac369df"; Subnets=("subnet-d0f1bbb5","subnet-41f44736","subnet-d398508a")}, 
    [PSCustomObject]@{Account="SandboxICE"; AccountID="925446695292" ;VPC="vpc-07ef9b8277c459d64"; Subnets=("subnet-0d7efaf1da7a86205","subnet-0ff57e15c6a149282","subnet-0c7e9ff958572b565")},
    [PSCustomObject]@{Account="SandboxD3"; AccountID="978308152145" ; VPC="vpc-050885cb53b9a1d39"; Subnets=("subnet-0b4fb911505d4de62","subnet-07132629930595b7c","subnet-01b0674fb500c8c54")}
    ) 

