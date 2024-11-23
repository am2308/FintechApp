import json
import boto3
from typing import Dict, Any

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
   """
   Handles AWS Config changes to security groups.
   Reverts unauthorised changes and notifies security team.
   """
   
   # Initialize AWS clients
   ec2 = boto3.client('ec2')
   sns = boto3.client('sns')

   try:
       # Parse Config change event
       config_item = event['detail']['configurationItem']
       sg_id = config_item['resourceId']
       changes = config_item['changes']

       APPROVED_PORTS = {443, 80, 22}  
       
       # Check security group rules
       sg_details = ec2.describe_security_groups(GroupIds=[sg_id])['SecurityGroups'][0]
       unauthorised_rules = []

       # Check ingress rules
       for rule in sg_details['IpPermissions']:
           port_range_from = rule.get('FromPort', 0)
           port_range_to = rule.get('ToPort', 0)
           
           # Check for overly permissive rules
           if (port_range_from == 0 and port_range_to == 0) or \
              ('0.0.0.0/0' in [ip['CidrIp'] for ip in rule.get('IpRanges', [])]):
               unauthorised_rules.append(rule)
           
           # Check for unauthorised ports
           elif not (port_range_from in APPROVED_PORTS and port_range_to in APPROVED_PORTS):
               unauthorised_rules.append(rule)

       if unauthorised_rules:
           # Revert unauthorized changes
           ec2.revoke_security_group_ingress(
               GroupId=sg_id,
               IpPermissions=unauthorised_rules
           )

           # Alert security team
           sns.publish(
               TopicArn='YOUR_SNS_TOPIC_ARN',
               Subject='Security Group Change Alert',
               Message=f"""
               Unauthorised security group change detected and reverted:
               - Security Group: {sg_id}
               - VPC: {sg_details['VpcId']}
               - Unauthorised Rules: {json.dumps(unauthorised_rules, indent=2)}
               - Action: Changes reverted
               - Time: {config_item['configurationItemCaptureTime']}
               """
           )

       return {
           'statusCode': 200,
           'body': json.dumps('Successfully processed security group change')
       }

   except Exception as e:
       print(f"Error processing Config change: {str(e)}")
       raise