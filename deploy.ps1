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
$masteraccount = ($accounts | ? Master -eq $true).Account
$masteraccountID = ($accounts | ? Account -eq $true).AccountId   
$transitgatewaysource = "./files/transit-gateway-source.yaml"
$resourcesharesource = "./files/resource-share-source.yaml"
$attachmentsource = "./files/attachment-source.yaml"
$transitgateway = "./files/transit-gateway.yaml"
$attachment = "./files/attachment.yaml"
$resourceshare = "./files/resource-share.yaml"
$rollbackhash = @()

#Script Begin
Write-Host "---------------------------" -f black -b green
Write-Host " Deploying Transit Gateway." -f black -b green
Write-Host "---------------------------" -f black -b green
Write-Host ""

# Deploy transit gateway in master account
Write-Host "Processing Transit Gateway" -f black -b red
Write-Host "Connecting to account: $masteraccount" -f cyan 
Switch-RoleAlias $masteraccount okta

$stackname = $projectname
$phase = 1

$infile = $transitgatewaysource
$outfile = $transitgateway
Write-Host "Writing $outfile file" -f green
(Get-Content $infile) | Foreach-Object {
    $_ -replace("regexbgpasn","$bgpASN") 
    } | Set-Content $outfile -force


$error.clear() ; $stack = 0 ; $stackstatus = 0
try { $stackstatus = ((Get-CFNStack -Stackname $stackname -region $region).StackStatus).Value }
catch { $stack = 1 ; Write-Host "Stack does not exist..." -f yellow } # set stack value to 1 if first deployment
if($redeploy -eq $true){$stack = 2} #tears down the stack and redeploys if set
if($cleanupmode -eq $true){$stack = 2}
if($stack -eq 0){
    # If stack exists, get the stack deployment status and check against google values
    # If match , set stack value to 0 -> skip iteration, else set stack value to 2.
    $goodvalues = @("CREATE_COMPLETE","CREATE_IN_PROGRESS")
    foreach($v in $goodvalues){if($v -eq $stackstatus){ $stack = 0 ; break } else { $stack = 2 } }}
if($stack -eq 0){ 
  # Stack already deployed or in process of being deployed
  Write-Host "Existing Stack Status:" -f cyan -NoNewLine ; 
  try{ Wait-CFNStack -Stackname $stackname -region $region } catch {}
  Write-Host " $stackstatus... Skipping." } # stack deployment already in progress, skip iteration
if($stack -eq 2){
    # Stack exists in bad state ->>> Delete it 
    Write-Host "Removing Stack"
    Remove-CFNStack -Stackname $stackname -region $region -force  
    try{ Wait-CFNStack -Stackname $stackname -region $region } catch {}# try wait for stack removal if needed, catch will hide error if stack does not exist.
    if($rollback -eq $true){ $stack = 0 }  
  }
if($stack -ge 1){# Create Stack if $stack = 1 or more 
    $error.clear()
    Write-host "Validating CF Template" -f cyan
    Test-CFNTemplate -templateBody (Get-Content $outfile -raw) -Region $region
    if($error.count -gt 0){Write-Host "Error Validation Failure!" -f red ; Write-Host "" ;  continue } # attempts to validate the CF template.
    if($error.count -eq 0){Write-Host "Template is Valid" -f green ; Write-Host "" }
    Write-Host "Creating Stack" -f black -b cyan
    New-CFNStack -StackName $stackname -TemplateBody (Get-Content $outfile -raw) -Region $region
    try{ Wait-CFNStack -Stackname $stackname -region $region } catch {}
  
  }

  #get variables to create yaml files for RAM and Transit Gateway attachments Cloud Formations
  $transitgatewayID = (Get-CFNExport -Region $region | ? Name -eq $stackname).Value
  $transitgatewayARN = (Get-EC2TransitGateway -region $region | ? TransitGatewayId -eq $transitgatewayID).TransitGatewayArn

  
  $stackstatus > $null
  #Create Roll Back Entry
  $obj = [PSCustomObject]@{
    Phase = "$Phase"
    Account = "$Account"
    Region = "$Region"
    Stackname = "$Stackname"
    StackStatus = "$stackstatus"
    }
  $rollbackhash += $obj # Add custom object to rollback array

#Share Transit Gateway via RAM
Write-Host "Processing Resource Share" -f black -b white

#Create principals list
$principalslist = ""
foreach($a in $accounts){
  $accountID = $a.AccountId 
  $skip = $a.Master ; if($skip -eq $true){continue} #skips adding master account ID to principals list
  $principalslist += "- $accountID `n"+"        "}

$stackname = "$projectname-share"
$phase = 2
$resourcesharename = $stackname #refernced later to accept the resource share in other accounts

$infile = $resourcesharesource
$outfile = $resourceshare
Write-Host "Writing $outfile file" -f green
(Get-Content $infile) | Foreach-Object {
    $_ -replace("regexprincipals","$principalslist") `
       -replace("regexname",$stackname) `
       -replace("regexresourcearns",$transitgatewayARN) 
    } | Set-Content $outfile -force

      $error.clear() ; $stack = 0 ; $stackstatus = 0
      try { $stackstatus = ((Get-CFNStack -Stackname $stackname -region $region).StackStatus).Value }
      catch { $stack = 1 ; Write-Host "Stack does not exist..." -f yellow } # set stack value to 1 if first deployment
      if($redeploy -eq $true){$stack = 2} #tears down the stack and redeploys if set
        if($rollback -eq $true){$stack = 2}
      if($stack -eq 0){
          # If stack exists, get the stack deployment status and check against google values
          # If match , set stack value to 0 -> skip iteration, else set stack value to 2.
          $goodvalues = @("CREATE_COMPLETE","CREATE_IN_PROGRESS")
          foreach($v in $goodvalues){if($v -eq $stackstatus){ $stack = 0 ; break } else { $stack = 2 } }}
      if($stack -eq 0){ 
        # Stack already deployed or in process of being deployed -> Skip
        Write-Host "Existing Stack Status:" -f cyan -NoNewLine ; 
        try{ Wait-CFNStack -Stackname $stackname -region $region } catch {}
        Write-Host " $stackstatus... Skipping." } # stack deployment already in progress, skip iteration
      if($stack -eq 2){
          # Stack exists in a bad state -> Delete  
          Write-Host "Removing Failed Stack"
          Remove-CFNStack -Stackname $stackname -region $region -force  
          try{ Wait-CFNStack -Stackname $stackname -region $region } catch {} # try wait for stack removal if needed, catch will hide error if stack does not exist.
          if($rollback -eq $true){ $stack = 0 } #rolling back break loop
          }
      if($stack -ge 1){ # Stack does not exist -> Deploy 
          $error.clear()
          # Attempts to validate the CF template.
          Write-host "Validating CF Template" -f cyan
          Test-CFNTemplate -templateBody (Get-Content $outfile -raw) -Region $region
          if($error.count -gt 0){Write-Host "Error Validation Failure!" -f red ; Write-Host "" ;  continue } 
          if($error.count -eq 0){Write-Host "Template is Valid" -f green ; Write-Host "" }
          Write-Host "Creating Stack" -f black -b cyan
          New-CFNStack -StackName $stackname -TemplateBody (Get-Content $outfile -raw) -Region $region
          try{ Wait-CFNStack -Stackname $stackname -region $region } catch {}
          }

  $stackstatus > $null
  #Create Roll Back Entry
  $obj = [PSCustomObject]@{
    Phase = "$Phase"
    Account = "$Account"
    Region = "$Region"
    Stackname = "$Stackname"
    StackStatus = "$stackstatus"
    }
  $rollbackhash += $obj # Add custom object to rollback array
          

Write-Host ""
Write-Host "Processing Attachments" -f black -b white
# Connect to each account and configure transit gateway attachment
$stackname = "$projectname-attachment"
$phase = 3
$infile = $attachmentsource
$outfile = $attachment

foreach($a in $accounts){   
    $skip = $a.Master ; if($skip -eq $true){continue} # Skip processing master account
    $account = $a.account
    $subnets = $a.subnets

    # Connect to Account
    Write-Host "Connecting to account: $account" -f cyan 
    Switch-RoleAlias $account admin 

    # Build Subnet Array 
    foreach($sub in $subnets){
      $subnetlist += "- $sub `n"+"        "
      }

    # Accept resource share ARN
    try {Get-RAMResourceShareInvitation -region $region | ? ResourceShareName -like $resourcesharename | Confirm-RAMResourceShareInvitation -region $region ; Write-Host "Accepting Share" -f black -b cyan}
    catch { Write-Host "Resource already accepted or does not exist...continuing" -f yellow }
    # Find and replace vpc, Subnets, project uuid and output to attachment.yaml
    Write-Host "Writing $outfile file" -f green
    (Get-Content $infile) | Foreach-Object {
        $_ -replace("regextransitgatewayID","$transitgatewayID") `
           -replace("regexvpc",$a.VPC) `
           -replace("regexsubnets",$subnetlist) `
           -replace("regexuuid",$uuid)
        } | Set-Content $outfile -force

    $error.clear() ; $stack = 0 ; $stackstatus = 0

    try { $stackstatus = ((Get-CFNStack -Stackname $stackname -region $region).StackStatus).Value }
    catch { $stack = 1 ; Write-Host "Stack does not exist..." -f yellow } # Set stack value to 1 if first deployment
    if($redeploy -eq $true){$stack = 2} # Tears down the stack and redeploys if set
    if($stack -eq 0){
        # If stack exists, get the stack deployment status and check against google values
        # If match , set stack value to 0 -> skip iteration, else set stack value to 2.
        $goodvalues = @("CREATE_COMPLETE","CREATE_IN_PROGRESS")
        foreach($v in $goodvalues){if($v -eq $stackstatus){ $stack = 0 ; break } else { $stack = 2 } }}
    if($stack -eq 0){ 
      # Stack already deployed or in process of being deployed
      Write-Host "Existing Stack Status:" -f cyan -NoNewLine ; 
      try{ Wait-CFNStack -Stackname $stackname -region $region } catch {}
      Write-Host " $stackstatus... Skipping." ; continue } # stack deployment already in progress, skip iteration
    if($stack -eq 2){
        # Stack exists in bad state ->>> Delete it 
        Write-Host "Removing Failed Stack"
        Remove-CFNStack -Stackname $stackname -region $region -force  
        try{ Wait-CFNStack -Stackname $stackname -region $region } catch {} # Try wait for stack removal if needed, catch will hide error if stack does not exist.
        }
    if($stack -ge 1){ # Create Stack if $stack = 1 or more 
        $error.clear()
        # Attempts to validate the CF template.
        Write-host "Validating CF Template" -f cyan
        Test-CFNTemplate -templateBody (Get-Content $outfile -raw) -Region $region
        if($error.count -gt 0){Write-Host "Error Validation Failure!" -f red ; Write-Host "" ;  continue } 
        if($error.count -eq 0){Write-Host "Template is Valid" -f green ; Write-Host "" }
        Write-Host "Creating Stack" -f black -b cyan
        New-CFNStack -StackName $stackname -TemplateBody (Get-Content $outfile -raw) -Region $region
        try{ Wait-CFNStack -Stackname $stackname -region $region } catch {}
        }
    Write-Host ""

    $stackstatus > $null
    #Create Roll Back Entry
    $obj = [PSCustomObject]@{
      Phase = "$Phase"
      Account = "$Account"
      Region = "$Region"
      Stackname = "$Stackname"
      StackStatus = "$stackstatus"
      TGWID = "$null"
      TGWARN = "$null"
      }
    $rollbackhash += $obj # Add custom object to rollback array
  
  }

  $rollbackhash | Export-CSV $rollbackfile -force
Remove-Item $attachment -force 
Remove-Item $resourceshare -force

Write-Host ""
Write-Host "---------------------------" -f black -b green
Write-Host "Script Processing Complete." -f black -b green
Write-Host "---------------------------" -f black -b green
