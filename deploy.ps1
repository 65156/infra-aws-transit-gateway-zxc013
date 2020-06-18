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
$masteraccountID = ($accounts | ? Master -eq $true).AccountId   
$masterrole = ($accounts | ? Master -eq $true).Role
$transitgatewaysource = "./files/transit-gateway-source.yaml"
$resourcesharesource = "./files/resource-share-source.yaml"
$attachmentsource = "./files/attachment-source.yaml"
$transitgateway = "./files/transit-gateway.yaml"
$attachment = "./files/attachment.yaml"
$resourceshare = "./files/resource-share.yaml"
#$rollbackfile = "./files/rollback.csv"
#try{$rollbackhash = Import-csv $rollbackfile} 
# catch { $rollbackhash = @() } #try import existing rollback file else create a new array.

#Script Begin
Write-Host "---------------------------" 
Write-Host " Deploying Transit Gateway." -f white -b magenta
Write-Host "---------------------------" 
Write-Host ""

$stackname = $projectname

# Deploy transit gateway in master account
Write-Host "Processing Transit Gateway" -f black -b white
Write-Host "Connecting to account: $masteraccount" -f white
Switch-RoleAlias $masteraccount $masterrole

$phase = 1
#$account = "Master"
$infile = $transitgatewaysource
$outfile = $transitgateway
Write-Host "Writing $outfile file" -f green
(Get-Content $infile) | Foreach-Object {
    $_ -replace("regexbgpasn","$bgpASN") 
    } | Set-Content $outfile -force


    $error.clear() ; $stack = 0 ; $stackstatus = 0
    try { $stackstatus = ((Get-CFNStack -Stackname $stackname -region $region).StackStatus).Value }
    catch { $stack = 1 ; Write-Host "Stack does not exist..." } # set stack value to 1 if first deployment
    if($update -eq $true){$stack = 2}
      if($teardown -eq $true){$stack = 2}
    if($stack -eq 0){
        # If stack exists, get the stack deployment status and check against google values
        # If match , set stack value to 0 -> skip iteration, else set stack value to 2.
        $goodvalues = @("CREATE_COMPLETE","CREATE_IN_PROGRESS")
        foreach($v in $goodvalues){if($v -eq $stackstatus){ $stack = 0 ; break } else { $stack = 2 } }}
    if($stack -eq 0){ 
        # Stack already deployed or in process of being deployed -> Skip
        Write-Host "Existing Stack Found - Status:" -f white -b magenta -NoNewLine ; Write-Host " $stackstatus" 
        try{ Wait-CFNStack -Stackname $stackname -region $region } catch {}} # stack deployment already in progress, skip iteration
    if($stack -eq 2){
        # Stack exists update if required or delete  
        $stack = 0 
        Write-Host "Existing Stack Found - Status:" -f white -b magenta -NoNewLine ; Write-Host " $stackstatus"
        if($teardown -eq $true){ Write-Host "Removing Stack"
          # Remove-CFNStack -Stackname $stackname -region $region -force
          } else { Write-Host "Updating Stack"
          # Update-CFNStack -Stackname $stackname -region $region -force
          } 
        try{ Wait-CFNStack -Stackname $stackname -region $region } catch {}} # try wait for stack deployment if needed, catch will hide error if stack does not exist. 

    if($stack -ge 1){ # Stack does not exist -> Deploy 
        $error.clear()
        # Attempts to validate the CF template.
        Write-host "Validating CF Template: " -nonewline ; 
        Test-CFNTemplate -templateBody (Get-Content $outfile -raw) -Region $region
        if($error.count -gt 0){Write-Host "Error Validation Failure!" -f red ; Write-Host "" ;  continue } 
        if($error.count -eq 0){Write-Host "Template is Valid" -f green ; Write-Host "" }
        Write-Host "Creating Stack: " -f White -b Magenta -NoNewLine ; Write-Host " $stackname"-f black -b white
        # New-CFNStack -StackName $stackname -TemplateBody (Get-Content $outfile -raw) -Region $region
        try{ Wait-CFNStack -Stackname $stackname -region $region -timeout 240 } catch { Write-Host " $stackname failed" -f black -b red }
        }

#get variables to create yaml files for RAM and Transit Gateway attachments Cloud Formations
$transitgatewayID = (Get-CFNExport -Region $region | ? Name -eq $stackname).Value
$transitgatewayARN = (Get-EC2TransitGateway -region $region | ? TransitGatewayId -eq $transitgatewayID).TransitGatewayArn

#Share Transit Gateway via RAM
Write-Host "Processing Resource Share" -f black -b white
$principalslist = "" #Create principals list

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
    catch { $stack = 1 ; Write-Host "Stack does not exist..." } # set stack value to 1 if first deployment
    if($update -eq $true){$stack = 2} #updates
      if($teardown -eq $true){$stack = 2}
    if($stack -eq 0){
        # If stack exists, get the stack deployment status and check against google values
        # If match , set stack value to 0 -> skip iteration, else set stack value to 2.
        $goodvalues = @("CREATE_COMPLETE","CREATE_IN_PROGRESS")
        foreach($v in $goodvalues){if($v -eq $stackstatus){ $stack = 0 ; break } else { $stack = 2 } }}
    if($stack -eq 0){ 
        # Stack already deployed or in process of being deployed -> Skip
        Write-Host "Existing Stack Found - Status:" -f white -b magenta -NoNewLine ; Write-Host " $stackstatus" 
        try{ Wait-CFNStack -Stackname $stackname -region $region } catch {}} # 
    if($stack -eq 2){
        # Stack exists update if required or delete  
        $stack = 0 
        Write-Host "Existing Stack Found - Status:" -f white -b magenta -NoNewLine ; Write-Host " $stackstatus"
        if($teardown -eq $true){ Write-Host "Removing Stack"
          # Remove-CFNStack -Stackname $stackname -region $region -force
          } else { Write-Host "Updating Stack"
          # Update-CFNStack -Stackname $stackname -region $region -force
          } 
        try{ Wait-CFNStack -Stackname $stackname -region $region } catch {}} # try wait for stack deployment if needed, catch will hide error if stack does not exist. 
    if($stack -ge 1){ # Stack does not exist -> Deploy 
        $error.clear()
        # Attempts to validate the CF template.
        Write-host "Validating CF Template: " -nonewline ; 
        Test-CFNTemplate -templateBody (Get-Content $outfile -raw) -Region $region
        if($error.count -gt 0){Write-Host "Error Validation Failure!" -f red ; Write-Host "" ;  continue } 
        if($error.count -eq 0){Write-Host "Template is Valid" -f green ; Write-Host "" }
        Write-Host "Creating Stack: " -f White -b Magenta -NoNewLine ; Write-Host " $stackname"-f black -b white
        # New-CFNStack -StackName $stackname -TemplateBody (Get-Content $outfile -raw) -Region $region
        try{ Wait-CFNStack -Stackname $stackname -region $region -timeout 240 } catch { Write-Host " $stackname failed" -f black -b red }
        }
Write-Host ""

# Connect to each account and configure transit gateway attachment
Write-Host "Processing Attachments" -f black -b white
foreach($a in $accounts){   
    $skip = $a.Master ; if($skip -eq $true){continue} # Skip processing master account
    $account = $a.account
    $role = $a.Role
    $subnets = $a.subnets
    $vpc = $a.vpc
    $stackname = "$projectname-attachment-$vpc"
    $phase = 3

    # Connect to Account
    Write-Host "Connecting to account: $account" -f white 
    Switch-RoleAlias $account $role 

    # Build Subnet Array 
    $subnetlist = $null
    foreach($sub in $subnets){
      $subnetlist += "- $sub `n"+"        "
      }

    # Accept resource share ARN
    try {Get-RAMResourceShareInvitation -region $region | ? ResourceShareName -like $resourcesharename | Confirm-RAMResourceShareInvitation -region $region ; Write-Host "Accepting Share" -f black -b Magenta}
    catch { Write-Host "Error or Already Accepted!"}
    # Find and replace vpc, Subnets, project uuid and output to attachment.yaml
    $infile = $attachmentsource
    $outfile = $attachment
    Write-Host "Writing $outfile file" -f green
    (Get-Content $infile) | Foreach-Object {
        $_ -replace("regextransitgatewayID","$transitgatewayID") `
           -replace("regextagname",$Account)`
           -replace("regexvpc",$vpc) `
           -replace("regexsubnets",$subnetlist) `
           -replace("regexuuid",$uuid)
        } | Set-Content $outfile -force

        $error.clear() ; $stack = 0 ; $stackstatus = 0
        try { $stackstatus = ((Get-CFNStack -Stackname $stackname -region $region).StackStatus).Value }
        catch { $stack = 1 ; Write-Host "Stack does not exist..." } # set stack value to 1 if first deployment
        if($update -eq $true){$stack = 2} #tears down the stack and redeploys if set
        if($teardown -eq $true){$stack = 2}
        if($stack -eq 0){
            # If stack exists, get the stack deployment status and check against google values
            # If match , set stack value to 0 -> skip iteration, else set stack value to 2.
            $goodvalues = @("CREATE_COMPLETE","CREATE_IN_PROGRESS")
            foreach($v in $goodvalues){if($v -eq $stackstatus){ $stack = 0 ; break } else { $stack = 2 } }}
            if($stack -eq 0){ 
              # Stack already deployed or in process of being deployed -> Skip
              Write-Host "Existing Stack Found - Status:" -f white -b magenta -NoNewLine ; Write-Host " $stackstatus" 
              try{ Wait-CFNStack -Stackname $stackname -region $region } catch {}} # 
        if($stack -eq 2){
           # Stack exists update if required or delete  
            $stack = 0 
            Write-Host "Existing Stack Found - Status:" -f white -b magenta -NoNewLine ; Write-Host " $stackstatus"
            if($teardown -eq $true){ Write-Host "Removing Stack"
              # Remove-CFNStack -Stackname $stackname -region $region -force
              } else { Write-Host "Updating Stack"
              # Update-CFNStack -Stackname $stackname -region $region -force
            } 
        try{ Wait-CFNStack -Stackname $stackname -region $region } catch {}} # try wait for stack deployment if needed, catch will hide error if stack does not exist. 
        if($stack -ge 1){ # Stack does not exist -> Deploy 
            $error.clear()
            # Attempts to validate the CF template.
            Write-host "Validating CF Template: " -nonewline ; 
            Test-CFNTemplate -templateBody (Get-Content $outfile -raw) -Region $region
            if($error.count -gt 0){Write-Host "Error Validation Failure!" -f red ; Write-Host "" ;  continue } 
            if($error.count -eq 0){Write-Host "Template is Valid" -f green ; Write-Host "" }
            Write-Host "Creating Stack: " -f White -b Magenta -NoNewLine ; Write-Host " $stackname"-f black -b white
            # New-CFNStack -StackName $stackname -TemplateBody (Get-Content $outfile -raw) -Region $region
            try{ Wait-CFNStack -Stackname $stackname -region $region -timeout 240 } catch { Write-Host " $stackname failed" -f black -b red }
            }
    Write-Host ""

}
#$rollbackhash | Export-CSV $rollbackfile -force 

Write-Host ""
Write-Host "---------------------------" 
Write-Host "Script Processing Complete." -f white -b magenta
Write-Host "---------------------------" 
Write-Host ""
Write-Host ""