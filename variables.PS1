#configurable variables
$projectname = "transit-gateway"
$bgpASN = "65100"
$uuid = 'zxc013'
$region = "ap-southeast-2"
# $update = $true # true -> instructs to update if not a new deployment
$teardown = $false

$accounts = @( 
    # accounts are dependant on account names configured in PS-AWS-SSO-AUTH.psm1
    [PSCustomObject]@{Account="Master"; Role="okta" ; AccountID="045932084931"; Master=$true},
    [PSCustomObject]@{Account="PipelineProd"; Role="admin" ; AccountID="479125032639" ; VPC="vpc-e818128d"; Subnets=("subnet-353ec243","subnet-a9837cf0","subnet-e111c085") ; teardown=$false; update=$false },
   # [PSCustomObject]@{Account="PipelineProd"; Role="admin" ; AccountID="479125032639" ; VPC="vpc-bba786de"; Subnets=("subnet-c1d5d2b6","subnet-eb2137ad") ; teardown=$false; update=$false }, #shared service vpc (causes routing issue as theres an overlap)
    [PSCustomObject]@{Account="PipelineDev"; Role="admin" ; AccountID="995405243001" ; VPC="vpc-881b11ed"; Subnets=("subnet-e73dc191","subnet-82ee3fe6","subnet-21837c78") ; teardown=$false; update=$false },
    [PSCustomObject]@{Account="LegacyProd"; Role="admin" ; AccountID="368940151251" ; VPC="vpc-0dd57f68"; Subnets=("subnet-f7894f81","subnet-eb05dd8f","subnet-28834671") ; teardown=$false; update=$false },
    [PSCustomObject]@{Account="LegacyProd"; Role="admin" ; AccountID="368940151251" ; VPC="vpc-f0d57f95"; Subnets=("subnet-198b4d6f","subnet-1e03db7a","subnet-7f824726") ; teardown=$false; update=$false },
    [PSCustomObject]@{Account="LegacyDev"; Role="admin" ; AccountID="128288646639" ; VPC="vpc-bac369df"; Subnets=("subnet-d0f1bbb5","subnet-41f44736","subnet-d398508a") ; teardown=$false; update=$false }, 
    [PSCustomObject]@{Account="SandboxICE"; Role="admin" ; AccountID="925446695292" ;VPC="vpc-07ef9b8277c459d64"; Subnets=("subnet-0d7efaf1da7a86205","subnet-0ff57e15c6a149282","subnet-0c7e9ff958572b565") ; teardown=$false; update=$false },
    [PSCustomObject]@{Account="SandboxD3"; Role="admin" ; AccountID="978308152145" ; VPC="vpc-050885cb53b9a1d39"; Subnets=("subnet-0b4fb911505d4de62","subnet-07132629930595b7c","subnet-01b0674fb500c8c54") ; teardown=$false; update=$false }
    [PSCustomObject]@{Account="KumoDev"; Role="admin" ; AccountID="551178757864" ; VPC="vpc-0dded09b8b819b952"; Subnets=("subnet-05bedc205024a860b","subnet-03fc3e7f57c6272ff","subnet-0ae8aaae3d276c0c8") ; teardown=$false; update=$false }
    [PSCustomObject]@{Account="KumoStaging"; Role="admin" ; AccountID="020474317366" ; VPC="vpc-01fc826e6accbb958"; Subnets=("subnet-04bdadc96f4aaaae1","subnet-0791542da239e5a47","subnet-0b000cbb61c7d8a36") ; teardown=$false; update=$false }
    [PSCustomObject]@{Account="KumoClientSandbox"; Role="admin" ; AccountID="329175007949" ; VPC="vpc-00fe835822bd385df"; Subnets=("subnet-07cfe690b5af033aa","subnet-0e5a118200697b735","subnet-0d5d773637687e808") ; teardown=$false; update=$false }
    [PSCustomObject]@{Account="KumoProd"; Role="admin" ; AccountID="281802470829" ; VPC="vpc-06caaf6f5ef406d5c"; Subnets=("subnet-044026c9bb4066cdc","subnet-0e8f2025f71156fa8","subnet-0f82a782bf9ebc433") ; teardown=$false; update=$false }
    ) 

