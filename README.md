# infra-aws-transit-gateway-zxc013
This repository manages the deployment of (Core AWS Cloud Routing Infrastructure) including Transit Gateway, TG Attachments and RAM Sharing to Child accounts.

## Prerequisites
PSCore6, OFX-Tools

## Powershell Logic
Due to the lack of StackSet availability at the time powershell logic was written to connect to child accounts to deploy cf templates and accept resource sharing requests for transit gateway attachments.

## How it works
Following an update to the variables.ps1 file deploy.ps1 will recreate the YAML CF templates, deploy the cf templates if a stack does not already exist, if a stack already exists a check will be performed and if the CF template contains a change it will update the stack with the new template.

## Warning
Removing configuration from the variables.ps1 may have unexpected results.

## Steps
1. Update variables
```
vi ./variables.ps1
```
2. Execute the Deployment script.
```
./deploy.ps1
```
