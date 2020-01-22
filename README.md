# infra-aws-transit-gateway-zxc013


1. Configure IAM permissions across accounts to create a trust relationship between admin roles in subordinate accounts and the admin role in master account.

2. Deploy Transit Gateway in master account.
```
aws cloudformation deploy --region ap-southeast-2 --template-file transit-gateway.yaml --stack-name transit-gateway
```
3.Create Resource Share for transit gateway in master Account 
```
aws create-resource-share --name transit-gateway --resource-arns 

transit-gateway-ID

