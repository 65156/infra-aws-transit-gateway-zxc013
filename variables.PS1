#configurable variables
$projectname = "transit-gateway"
$bgpASN = "65100"
$uuid = 'zxc013'
$region = "ap-southeast-2"
# $redeploy = $false # true --> instructs to delete the stack and create a new stack (DOES NOT UPDATE STACK)
# $delete = $false # true --> deletes all deployed stacks.
$delete = $false

$accounts = @( 
    # accounts are dependant on account names configured in PS-AWS-SSO-AUTH.psm1
    [PSCustomObject]@{Account="Master"; Role="okta" ; AccountID="0"; Master=$true},
    [PSCustomObject]@{Account="PipelineProd"; Role="admin" ; AccountID="0" ; VPC="vpc-dsadf2432"; Subnets=("subnet-353ec243","subnet-a9837cf0","subnet-e111c085") ; delete=$false; redeploy=$false },
   # [PSCustomObject]@{Account="PipelineProd"; Role="admin" ; AccountID="0" ; VPC="vpc-bba786de"; Subnets=("subnet-c1d5d2b6","subnet-eb2137ad") ; delete=$false; redeploy=$false }, #shared service vpc (causes routing issue as theres an overlap)
    [PSCustomObject]@{Account="PipelineDev"; Role="admin" ; AccountID="0" ; VPC="vpc-dsadf2432"; Subnets=("subnet-e73dc191","subnet-82ee3fe6","subnet-21837c78") ; delete=$false; redeploy=$false },
    [PSCustomObject]@{Account="LegacyProd"; Role="admin" ; AccountID="0" ; VPC="vpc-dsadf2432"; Subnets=("subnet-f7894f81","subnet-eb05dd8f","subnet-28834671") ; delete=$false; redeploy=$false },
    [PSCustomObject]@{Account="LegacyProd"; Role="admin" ; AccountID="0" ; VPC="vpc-dsadf2432"; Subnets=("subnet-198b4d6f","subnet-1e03db7a","subnet-7f824726") ; delete=$false; redeploy=$false },
    [PSCustomObject]@{Account="LegacyDev"; Role="admin" ; AccountID="0" ; VPC="vpc-dsadf2432"; Subnets=("subnet-d0f1bbb5","subnet-41f44736","subnet-d398508a") ; delete=$false; redeploy=$false }, 
    [PSCustomObject]@{Account="SandboxICE"; Role="admin" ; AccountID="0" ;VPC="vpc-dsadf2432"; Subnets=("subnet-0d7efaf1da7a86205","subnet-0ff57e15c6a149282","subnet-0c7e9ff958572b565") ; delete=$false; redeploy=$false },
    [PSCustomObject]@{Account="SandboxD3"; Role="admin" ; AccountID="0" ; VPC="vpc-dsadf2432"; Subnets=("subnet-0b4fb911505d4de62","subnet-07132629930595b7c","subnet-01b0674fb500c8c54") ; delete=$false; redeploy=$false }
    [PSCustomObject]@{Account="KumoDev"; Role="admin" ; AccountID="0" ; VPC="vpc-dsadf2432"; Subnets=("subnet-05bedc205024a860b","subnet-03fc3e7f57c6272ff","subnet-0ae8aaae3d276c0c8") ; delete=$false; redeploy=$false }
    [PSCustomObject]@{Account="KumoStaging"; Role="admin" ; AccountID="0" ; VPC="vpc-dsadf2432"; Subnets=("subnet-04bdadc96f4aaaae1","subnet-0791542da239e5a47","subnet-0b000cbb61c7d8a36") ; delete=$false; redeploy=$false }
    [PSCustomObject]@{Account="KumoClientSandbox"; Role="admin" ; AccountID="0" ; VPC="vpc-dsadf2432"; Subnets=("subnet-07cfe690b5af033aa","subnet-0e5a118200697b735","subnet-0d5d773637687e808") ; delete=$false; redeploy=$false }
    [PSCustomObject]@{Account="KumoProd"; Role="admin" ; AccountID="0" ; VPC="vpc-dsadf2432"; Subnets=("subnet-044026c9bb4066cdc","subnet-0e8f2025f71156fa8","subnet-0f82a782bf9ebc433") ; delete=$false; redeploy=$false }
    ) 

