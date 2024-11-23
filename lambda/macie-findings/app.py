import json
import boto3
from datetime import datetime
from typing import Dict, Any

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
   """
   Handles Macie findings and initiates remediation.
   Triggered by EventBridge when Macie creates a finding.
   """
   
   # Initialise AWS clients
   s3 = boto3.client('s3')
   sns = boto3.client('sns')
   security_hub = boto3.client('securityhub')

   try:
       # Parse Macie finding
       finding = event['detail']
       bucket_name = finding['resourcesAffected']['s3Bucket']['name']
       object_key = finding['resourcesAffected']['s3Object']['key']
       severity = finding['severity']['description']

       # Check if unencrypted sensitive data
       if severity == 'HIGH' and 'Unencrypted' in finding['description']:
           # Enable default encryption on bucket
           s3.put_bucket_encryption(
               Bucket=bucket_name,
               ServerSideEncryptionConfiguration={
                   'Rules': [
                       {
                           'ApplyServerSideEncryptionByDefault': {
                               'SSEAlgorithm': 'AES256'
                           }
                       }
                   ]
               }
           )

           # Send to Security Hub
           security_hub.batch_import_findings([{
               'SchemaVersion': '2018-10-08',
               'Id': finding['id'],
               'ProductArn': f"arn:aws:securityhub:{finding['region']}:{finding['accountId']}:product/aws/macie",
               'GeneratorId': 'macie-sensitive-data',
               'AwsAccountId': finding['accountId'],
               'Types': ['Software and Configuration Checks/AWS Security Best Practices'],
               'CreatedAt': datetime.now().isoformat(),
               'UpdatedAt': datetime.now().isoformat(),
               'Severity': {'Label': 'HIGH'},
               'Title': 'Unencrypted Sensitive Data Detected',
               'Description': f'Unencrypted sensitive data found in {bucket_name}/{object_key}',
               'Remediation': {
                   'Recommendation': {
                       'Text': 'Bucket encryption has been automatically enabled'
                   }
               }
           }])

           # Alert security team
           sns.publish(
               TopicArn='YOUR_SNS_TOPIC_ARN',
               Subject='Macie Alert: Sensitive Data Exposure',
               Message=f"""
               Critical security alert:
               - Bucket: {bucket_name}
               - Object: {object_key}
               - Issue: Unencrypted sensitive data
               - Action: Bucket encryption enabled
               - Time: {datetime.now().isoformat()}
               """
           )

       return {
           'statusCode': 200,
           'body': json.dumps('Successfully processed Macie finding')
       }

   except Exception as e:
       print(f"Error processing Macie finding: {str(e)}")
       raise
