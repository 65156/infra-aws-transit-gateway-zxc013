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

#Script Begin
Write-Host "---------------------------" 
Write-Host "  Script Processing Start. " -f white -b magenta
Write-Host "---------------------------" 
Write-Host ""

# Deploy transit gateway in master account
Write-Host "Processing Transit Gateway" -f black -b white
Write-Host "Connecting to account: $masteraccount" -f white
Switch-RoleAlias $masteraccount $masterrole

$stackname = $projectname
$infile = $transitgatewaysource
$outfile = $transitgateway

Write-Host "Writing $outfile file" -f green
Write-Host "Processing $stackname" -f Magenta
(Get-Content $infile) | Foreach-Object {
    $_ -replace("regexbgpasn","$bgpASN") 
    } | Set-Content $outfile -force

    $error.clear() ; $stack = 0 ; $stack_status = 0 ; $changeset_status = 0

    # Try get existing stack
    try { $stack_status = ((Get-CFNStack -Stackname $stackname -region $region).StackStatus).Value }
    catch {Write-Host "Stack does not exist..." -f yellow ;  $stack = 3 } # set stack value to 3 to deploy 
    if($redeploy -eq $true){$stack = 1} # if forcing update (delete + new)
    if($delete -eq $true){$stack = 1} # if forcing teardown (delete only)
    
    # Check Stack Status
    if($stack -eq 0){
      $updatevalues = @("CREATE_COMPLETE","CREATE_IN_PROGRESS","UPDATE_COMPLETE","UPDATE_IN_PROGRESS","ROLLBACK_COMPLETE","UPDATE_ROLLBACK_COMPLETE")
      $deletevalues = @("CREATE_FAILED","DELETE_FAILED")
      $newvalues = @("DELETE_COMPLETE")
      foreach($value in $updatevalues){if($value -eq $stack_status){ 
        # Create a change set and compare to see if there are changes being provided.

        try { New-CFNChangeSet -StackName $stackname -Region $region -ChangeSetName $stackname -TemplateBody (Get-Content $outfile -raw)} catch {}  
        try { $changeset_status = (Get-CFNChangeSet -Region $region -ChangeSetName $stackname -stackname $stackname).status }
        catch {Write-Host "No Change Set Exists -- this should never happen!" -f red ; continue } # break as logic error
        if($changeset_status -eq "FAILED" ){ Write-Host "No Changes" -f white ; Write-Host "" ; continue } # break as no changes
        if($changeset_status -eq "CREATE_COMPLETE" ){ Write-Host "Changes Detected, Updating Stack" -f yellow ; $stack = 2 }
        } } #skip iteration
      foreach($value in $deletevalues){if($value -eq $stack_status){ $stack = 1 ; $redeploy = $true }
      foreach($value in $newvalues){if($value -eq $stack_status){ $stack = 3 }}
    }
  }
      
    # Delete Stack
    if($stack -eq 1){
      Write-Host "Removing Stack: " -f black -b red -NoNewLine ; Write-Host " $stackname"-f black -b white
      # Remove-CFNStack -Stackname $stackname -region $region -force
      # try{ Wait-CFNStack -Stackname $stackname -region $region -timeout 240 } catch { Write-Host " $stackname failed" -f black -b red }
      # Force Update (New Stack after Force Delete)
      if($redeploy -eq $true){$stack = 3}
      }
    
    # Update Stack
    if($stack -eq 2){
      Write-Host "Updating Stack: " -f black -b red -NoNewLine ; Write-Host " $stackname"-f black -b white
      # Remove-CFNChangeSet -Stackname $stackname -ChangeSetName $stackname -Region $region -Force | Out-Null #cleanup change set
      # $stack = 0 
      # Update-CFNStack -Stackname $stackname -region $region -force
      # try{ Wait-CFNStack -Stackname $stackname -region $region -timeout 240 } catch { Write-Host " $stackname failed" -f black -b red }
    } # try wait for stack deployment if needed, catch will hide error if stack does not exist. 
    
    # Create Stack (Generally a New Stack)
    if($stack -eq 3){ 
        $error.clear()
        # Attempts to validate the CF template.
        Write-host "Validating CF Template: " -nonewline ; 
        Test-CFNTemplate -templateBody (Get-Content $outfile -raw) -Region $region
        if($error.count -gt 0){Write-Host "Error Validation Failure!" -f red ; Write-Host "" ;  continue } 
        if($error.count -eq 0){Write-Host "Template is Valid" -f green ; Write-Host "" }
        Write-Host "Creating Stack: " -f White -b Magenta -NoNewLine ; Write-Host " $stackname"-f black -b white
        # New-CFNStack -StackName $stackname -TemplateBody (Get-Content $outfile -raw) -Region $region
        # try{ Wait-CFNStack -Stackname $stackname -region $region -timeout 240 } catch { Write-Host " $stackname failed" -f black -b red }
        }
Write-Host ""

#get variables to create yaml files for RAM and Transit Gateway attachments Cloud Formations
$transitgatewayID = (Get-CFNExport -Region $region | ? Name -eq $stackname).Value
$transitgatewayARN = (Get-EC2TransitGateway -region $region | ? TransitGatewayId -eq $transitgatewayID).TransitGatewayArn

#Share Transit Gateway via RAM
Write-Host "Processing Resource Share" -f black -b white

$principalslist = "" #Create principals list
foreach($a in $accounts){
  $accountID = $a.AccountId 
  $skip = $a.Master ; if($skip -eq $true){continue} #skips adding master account ID to principals list
  $principalslist += "- `"$accountID`" `n"+"        "}

$stackname = "$projectname-share"
$resourcesharename = $stackname #refernced later to accept the resource share in other accounts
$infile = $resourcesharesource
$outfile = $resourceshare

Write-Host "Writing $outfile file" -f green
Write-Host "Processing $stackname" -f Magenta
(Get-Content $infile) | Foreach-Object {
    $_ -replace("regexprincipals","$principalslist") `
       -replace("regexname",$stackname) `
       -replace("regexresourcearns",$transitgatewayARN) 
    } | Set-Content $outfile -force

    $error.clear() ; $stack = 0 ; $stack_status = 0 ; $changeset_status = 0

    # Try get existing stack
    try { $stack_status = ((Get-CFNStack -Stackname $stackname -region $region).StackStatus).Value }
    catch {Write-Host "Stack does not exist..." -f yellow ;  $stack = 3 } # set stack value to 3 to deploy 
    if($redeploy -eq $true){$stack = 1} # if forcing update (delete + new)
    if($delete -eq $true){$stack = 1} # if forcing teardown (delete only)
    
    # Check Stack Status
    if($stack -eq 0){
      $updatevalues = @("CREATE_COMPLETE","CREATE_IN_PROGRESS","UPDATE_COMPLETE","UPDATE_IN_PROGRESS","ROLLBACK_COMPLETE","UPDATE_ROLLBACK_COMPLETE")
      $deletevalues = @("CREATE_FAILED","DELETE_FAILED")
      $newvalues = @("DELETE_COMPLETE")
      foreach($value in $updatevalues){if($value -eq $stack_status){ 
        # Create a change set and compare to see if there are changes being provided.
        # This might not be working properly, it did not detect a change when a Principal was Removed.
        try { New-CFNChangeSet -StackName $stackname -Region $region -ChangeSetName $stackname -TemplateBody (Get-Content $outfile -raw)} catch {}  
        try { $changeset_status = (Get-CFNChangeSet -Region $region -ChangeSetName $stackname -stackname $stackname).status }
        catch {Write-Host "No Change Set Exists -- this should never happen!" -f red ; continue } # break as logic error
        if($changeset_status -eq "FAILED" ){ Write-Host "No Changes" -f white ; Write-Host "" ; continue } # break as no changes
        if($changeset_status -eq "CREATE_COMPLETE" ){ Write-Host "Changes Detected, Updating Stack" -f yellow ; $stack = 2 }
        } } #skip iteration
      foreach($value in $deletevalues){if($value -eq $stack_status){ $stack = 1 ; $redeploy = $true }
      foreach($value in $newvalues){if($value -eq $stack_status){ $stack = 3 }}
    }
  }
      
    # Delete Stack
    if($stack -eq 1){
      Write-Host "Removing Stack: " -f black -b red -NoNewLine ; Write-Host " $stackname"-f black -b white
      # Remove-CFNStack -Stackname $stackname -region $region -force
      # try{ Wait-CFNStack -Stackname $stackname -region $region -timeout 240 } catch { Write-Host " $stackname failed" -f black -b red }
      # Force Update (New Stack after Force Delete)
      if($redeploy -eq $true){$stack = 3}
      }
    
    # Update Stack
    if($stack -eq 2){
      Write-Host "Updating Stack: " -f black -b red -NoNewLine ; Write-Host " $stackname"-f black -b white
      # Remove-CFNChangeSet -Stackname $stackname -ChangeSetName $stackname -Region $region -Force | Out-Null #cleanup change set
      # $stack = 0 
      # Update-CFNStack -Stackname $stackname -region $region -force
      # try{ Wait-CFNStack -Stackname $stackname -region $region -timeout 240 } catch { Write-Host " $stackname failed" -f black -b red }
    } # try wait for stack deployment if needed, catch will hide error if stack does not exist. 
    
    # Create Stack (Generally a New Stack)
    if($stack -eq 3){ 
        $error.clear()
        # Attempts to validate the CF template.
        Write-host "Validating CF Template: " -nonewline ; 
        Test-CFNTemplate -templateBody (Get-Content $outfile -raw) -Region $region
        if($error.count -gt 0){Write-Host "Error Validation Failure!" -f red ; Write-Host "" ;  continue } 
        if($error.count -eq 0){Write-Host "Template is Valid" -f green ; Write-Host "" }
        Write-Host "Creating Stack: " -f White -b Magenta -NoNewLine ; Write-Host " $stackname"-f black -b white
        # New-CFNStack -StackName $stackname -TemplateBody (Get-Content $outfile -raw) -Region $region
        # try{ Wait-CFNStack -Stackname $stackname -region $region -timeout 240 } catch { Write-Host " $stackname failed" -f black -b red }
        }
Write-Host ""

Pause
# Connect to each account and configure transit gateway attachment
Write-Host "Processing Attachments" -f black -b white
foreach($a in $accounts){   
    $skip = $a.Master ; if($skip -eq $true){continue} # Skip processing master account
    $account = $a.account
    $role = $a.Role
    $subnets = $a.subnets
    $vpc = $a.vpc
    $stackname = "$projectname-attachment-$vpc"

    # Connect to Account
    Write-Host "Connecting to account: $account" -f white 
    Switch-RoleAlias $account $role 

    # Build Subnet Array 
    $subnetlist = $null
    foreach($sub in $subnets){
      $subnetlist += "- $sub `n"+"        "
      }

    # Find and replace vpc, Subnets, project uuid and output to attachment.yaml
    $infile = $attachmentsource
    $outfile = $attachment
    Write-Host "Writing $outfile file" -f green
    Write-Host "Processing $stackname" -f Magenta
    (Get-Content $infile) | Foreach-Object {
        $_ -replace("regextransitgatewayID","$transitgatewayID") `
           -replace("regextagname",$Account)`
           -replace("regexvpc",$vpc) `
           -replace("regexsubnets",$subnetlist) `
           -replace("regexuuid",$uuid)
        } | Set-Content $outfile -force

        # Accept resource share ARN
        try {Get-RAMResourceShareInvitation -region $region | ? ResourceShareName -like $resourcesharename | Confirm-RAMResourceShareInvitation -region $region ; Write-Host "Accepting Share" -f green }
        catch { Write-Host "Error or already accepted!" -f yellow}

        $error.clear() ; $stack = 0 ; $stack_status = 0 ; $changeset_status = 0

        # Try get existing stack
        try { $stack_status = ((Get-CFNStack -Stackname $stackname -region $region).StackStatus).Value }
        catch {Write-Host "Stack does not exist..." -f yellow ;  $stack = 3 } # set stack value to 3 to deploy 
        if($redeploy -eq $true){$stack = 1} # if forcing update (delete + new)
        if($delete -eq $true){$stack = 1} # if forcing teardown (delete only)
        
        # Check Stack Status
        if($stack -eq 0){
          $updatevalues = @("CREATE_COMPLETE","CREATE_IN_PROGRESS","UPDATE_COMPLETE","UPDATE_IN_PROGRESS","ROLLBACK_COMPLETE","UPDATE_ROLLBACK_COMPLETE")
          $deletevalues = @("CREATE_FAILED","DELETE_FAILED")
          $newvalues = @("DELETE_COMPLETE")
          foreach($value in $updatevalues){if($value -eq $stack_status){ 
            # Create a change set and compare to see if there are changes being provided.
            try { New-CFNChangeSet -StackName $stackname -Region $region -ChangeSetName $stackname -TemplateBody (Get-Content $outfile -raw)} catch {}  
            try { $changeset_status = (Get-CFNChangeSet -Region $region -ChangeSetName $stackname -stackname $stackname).status }
            catch {Write-Host "No Change Set Exists -- this should never happen!" -f red ; continue } # break as logic error
            if($changeset_status -eq "FAILED" ){ Write-Host "No Changes" -f white ; Write-Host "" ; continue } # break as no changes
            if($changeset_status -eq "CREATE_COMPLETE" ){ Write-Host "Changes Detected, Updating Stack" -f yellow ; $stack = 2 }
            } } #skip iteration
          foreach($value in $deletevalues){if($value -eq $stack_status){ $stack = 1 ; $redeploy = $true }
          foreach($value in $newvalues){if($value -eq $stack_status){ $stack = 3 }}
        }
      }
          
        # Delete Stack
        if($stack -eq 1){
          Write-Host "Removing Stack: " -f black -b red -NoNewLine ; Write-Host " $stackname"-f black -b white
          # Remove-CFNStack -Stackname $stackname -region $region -force
          # try{ Wait-CFNStack -Stackname $stackname -region $region -timeout 240 } catch { Write-Host " $stackname failed" -f black -b red }
          # Force Update (New Stack after Force Delete)
          if($redeploy -eq $true){$stack = 3}
          }
        
        # Update Stack
        if($stack -eq 2){
          Write-Host "Updating Stack: " -f black -b red -NoNewLine ; Write-Host " $stackname"-f black -b white
          # Remove-CFNChangeSet -Stackname $stackname -ChangeSetName $stackname -Region $region -Force | Out-Null #cleanup change set
          # $stack = 0 
          # Update-CFNStack -Stackname $stackname -region $region -force
          # try{ Wait-CFNStack -Stackname $stackname -region $region -timeout 240 } catch { Write-Host " $stackname failed" -f black -b red }
        } # try wait for stack deployment if needed, catch will hide error if stack does not exist. 
        
        # Create Stack (Generally a New Stack)
        if($stack -eq 3){ 
            $error.clear()
            # Attempts to validate the CF template.
            Write-host "Validating CF Template: " -nonewline ; 
            Test-CFNTemplate -templateBody (Get-Content $outfile -raw) -Region $region
            if($error.count -gt 0){Write-Host "Error Validation Failure!" -f red ; Write-Host "" ;  continue } 
            if($error.count -eq 0){Write-Host "Template is Valid" -f green ; Write-Host "" }
            Write-Host "Creating Stack: " -f White -b Magenta -NoNewLine ; Write-Host " $stackname"-f black -b white
            # New-CFNStack -StackName $stackname -TemplateBody (Get-Content $outfile -raw) -Region $region
            # try{ Wait-CFNStack -Stackname $stackname -region $region -timeout 240 } catch { Write-Host " $stackname failed" -f black -b red }
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