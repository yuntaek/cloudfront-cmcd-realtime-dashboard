#!/bin/bash
subnets=$(aws ec2 describe-subnets --output json)
AWS_REGION_CODE=$(echo $subnets | jq -r '.Subnets[0].SubnetArn' | awk -F'[:/@]' '{print $4}')
azs=$(aws ec2 describe-instance-type-offerings --location-type availability-zone --filters "Name=instance-type,Values=c5.large"  --query "InstanceTypeOfferings[?InstanceType=='c5.large'].Location" --output text)
for az in $azs; do
  az=$(echo "$az" | sed 's/,$//')
  echo "AZ : ${az}"
  AWS_VPC_SUBNET_ID=$(echo "$subnets" | jq -r ".Subnets[] | select(.AvailabilityZone==\"$az\") | .SubnetId")
  terraform apply \
  -var="deploy-to-region=${AWS_REGION_CODE}" \
  -var="grafana_ec2_subnet=${AWS_VPC_SUBNET_ID}" \
  -var="solution_prefix=cmcd" \
  -auto-approve
   if [ $? -eq 0 ]; then break; fi
done
echo "AWS_VPC_SUBNET_ID=${AWS_VPC_SUBNET_ID}"