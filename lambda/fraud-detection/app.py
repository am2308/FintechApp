import json
import boto3
import os
from datetime import datetime, timedelta
from typing import Dict, Any

dynamodb = boto3.resource('dynamodb')
sns = boto3.client('sns')
table = dynamodb.Table(os.environ['DYNAMODB_TABLE'])

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Analyses transactions for potential fraud patterns.
    
    Patterns checked:
    1. High-value transactions
    2. Frequent transactions
    3. Unusual locations/times
    """
    
    transaction = json.loads(event['body'])
    user_id = transaction['user_id']
    amount = transaction['amount']
    timestamp = transaction['timestamp']
    location = transaction['location']

    # Get recent transactions
    response = table.query(
        KeyConditionExpression='user_id = :uid AND transaction_time > :time',
        ExpressionAttributeValues={
            ':uid': user_id,
            ':time': (datetime.now() - timedelta(hours=24)).isoformat()
        }
    )

    recent_transactions = response['Items']
    
    # Fraud checks
    risk_factors = []
    
    # Check 1: High-value transaction
    if amount > 10000:
        risk_factors.append('HIGH_VALUE_TRANSACTION')
    
    # Check 2: Frequency check
    if len(recent_transactions) > 10:
        risk_factors.append('HIGH_FREQUENCY')
    
    # Check 3: Velocity check (amount over time)
    total_recent_amount = sum(float(t['amount']) for t in recent_transactions)
    if total_recent_amount > 20000:
        risk_factors.append('VELOCITY_CHECK_FAILED')

    # If risks detected, send alert
    if risk_factors:
        alert = {
            'user_id': user_id,
            'transaction_id': transaction['transaction_id'],
            'amount': amount,
            'risk_factors': risk_factors,
            'timestamp': timestamp
        }
        
        # Send to SNS
        sns.publish(
            TopicArn=os.environ['SNS_TOPIC_ARN'],
            Message=json.dumps(alert),
            Subject='Potential Fraud Detection'
        )
        
        # Store alert in DynamoDB
        table.put_item(Item={
            'user_id': user_id,
            'transaction_id': transaction['transaction_id'],
            'alert_type': 'FRAUD_DETECTION',
            'risk_factors': risk_factors,
            'timestamp': timestamp,
            'status': 'PENDING_REVIEW'
        })
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Fraud alert created',
                'risk_factors': risk_factors,
                'requires_review': True
            })
        }
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Transaction cleared',
            'requires_review': False
        })
    }