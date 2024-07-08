#!/bin/bash
subnets=$(aws ec2 describe-subnets --output json)
AWS_REGION_CODE=$(echo $subnets | jq -r '.Subnets[0].SubnetArn' | awk -F'[:/@]' '{print $4}')
azs=$(aws ec2 describe-instance-type-offerings --location-type availability-zone --filters "Name=instance-type,Values=c5.xlarge"  --query "InstanceTypeOfferings[?InstanceType=='c5.xlarge'].Location" --output json)
for az in $azs; do
    AWS_VPC_SUBNET_ID=$(jq -r ".Subnets[] | select(.AvailabilityZone==\"${az}\") | .SubnetId" <<< $subnets)
    terraform apply \
  -var="deploy-to-region=${AWS_REGION_CODE}" \
  -var="grafana_ec2_subnet=${AWS_VPC_SUBNET_ID}" \
  -var="solution_prefix=cmcd" \
  -auto-approve
   if [ $? -eq 0 ]; then break; fi
done
echo "AWS_VPC_SUBNET_ID=${AWS_VPC_SUBNET_ID}"