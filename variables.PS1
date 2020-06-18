#configurable variables
$projectname = "transit-gateway"
$bgpASN = "65100"
$uuid = 'zxc013'
$region = "ap-southeast-2"
$update = $true # true -> instructs to update if not a new deployment
$teardown = $false

$accounts = @( 
    #accounts are dependant on account names configured in PS-AWS-SSO-AUTH.psm1
    [PSCustomObject]@{Account="Master"; Role="okta" ; AccountID="045932084931"; Master=$true},
    [PSCustomObject]@{Account="PipelineProd"; Role="admin" ; AccountID="479125032639" ; VPC="vpc-e818128d"; Subnets=("subnet-353ec243","subnet-a9837cf0","subnet-e111c085")},
   # [PSCustomObject]@{Account="PipelineProd"; Role="admin" ; AccountID="479125032639" ; VPC="vpc-bba786de"; Subnets=("subnet-c1d5d2b6","subnet-eb2137ad")}, #shared service vpc (causes routing issue)
    [PSCustomObject]@{Account="PipelineDev"; Role="admin" ; AccountID="995405243001" ; VPC="vpc-881b11ed"; Subnets=("subnet-e73dc191","subnet-82ee3fe6","subnet-21837c78")},
    [PSCustomObject]@{Account="LegacyProd"; Role="admin" ; AccountID="368940151251" ; VPC="vpc-0dd57f68"; Subnets=("subnet-f7894f81","subnet-eb05dd8f","subnet-28834671")},
    [PSCustomObject]@{Account="LegacyProd"; Role="admin" ; AccountID="368940151251" ; VPC="vpc-f0d57f95"; Subnets=("subnet-198b4d6f","subnet-1e03db7a","subnet-7f824726")},
    [PSCustomObject]@{Account="LegacyDev"; Role="admin" ; AccountID="128288646639" ; VPC="vpc-bac369df"; Subnets=("subnet-d0f1bbb5","subnet-41f44736","subnet-d398508a")}, 
    [PSCustomObject]@{Account="SandboxICE"; Role="admin" ; AccountID="925446695292" ;VPC="vpc-07ef9b8277c459d64"; Subnets=("subnet-0d7efaf1da7a86205","subnet-0ff57e15c6a149282","subnet-0c7e9ff958572b565")},
    [PSCustomObject]@{Account="SandboxD3"; Role="admin" ; AccountID="978308152145" ; VPC="vpc-050885cb53b9a1d39"; Subnets=("subnet-0b4fb911505d4de62","subnet-07132629930595b7c","subnet-01b0674fb500c8c54")}
    [PSCustomObject]@{Account="KumoDev"; Role="admin" ; AccountID="551178757864" ; VPC="vpc-0a44ccce5b9060c8e"; Subnets=("subnet-014e5ada44677e4da,subnet-0e0f62bc8935ceb40,subnet-05f55345f31d1e971")}
    [PSCustomObject]@{Account="KumoStaging"; Role="admin" ; AccountID="020474317366" ; VPC="vpc-042d09e40b8069d33"; Subnets=("subnet-096c2d5a3459b2d0e,subnet-062b050eaf2000989,subnet-07701c233d7e897bf")}
    [PSCustomObject]@{Account="KumoClientSandbox"; Role="admin" ; AccountID="329175007949" ; VPC="vpc-02bdf5c53fae72f3bq"; Subnets=("subnet-099249ae92221f419,subnet-001181513f79fab13,subnet-0995ea3c972f92ff7")}
    [PSCustomObject]@{Account="KumoProd"; Role="admin" ; AccountID="281802470829" ; VPC="vpc-080bf7929d0091313"; Subnets=("subnet-04503bb0c40f7a257,subnet-08839b2df9b51ce85,subnet-085dbb112e20012f8")}
    ) 

