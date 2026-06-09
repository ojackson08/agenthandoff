import json
import boto3
import os
import uuid
from datetime import datetime

s3 = boto3.client('s3')
sqs = boto3.client('sqs')

BUCKET_NAME = os.environ.get('CONTEXT_BUCKET')
QUEUE_URL = os.environ.get('ROUTING_QUEUE_URL')

def lambda_handler(event, context):
    """
    AgentHandoff Protocol:
    Accepts a stateful context envelope from an AI agent, stores the heavy payload in S3,
    and places a routing message on SQS for the next agent to pick up.
    """
    try:
        body = json.loads(event.get('body', '{}')) if isinstance(event.get('body'), str) else event
        
        source_agent = body.get('source_agent')
        target_agent = body.get('target_agent')
        session_id = body.get('session_id', str(uuid.uuid4()))
        context_payload = body.get('context_payload') # The heavy JSON (history, reasoning, tool outputs)
        
        if not all([source_agent, target_agent, context_payload]):
            return {"statusCode": 400, "body": json.dumps({"error": "Missing required fields"})}

        # 1. Store the heavy context payload in S3 (State serialization)
        timestamp = datetime.utcnow().strftime('%Y%m%d%H%M%S')
        s3_key = f"handoffs/{session_id}/{timestamp}_{source_agent}_to_{target_agent}.json"
        
        s3.put_object(
            Bucket=BUCKET_NAME,
            Key=s3_key,
            Body=json.dumps(context_payload),
            ContentType='application/json'
        )
        
        # 2. Send routing message to SQS (Guaranteed delivery)
        sqs_message = {
            "session_id": session_id,
            "source_agent": source_agent,
            "target_agent": target_agent,
            "context_s3_uri": f"s3://{BUCKET_NAME}/{s3_key}",
            "handoff_timestamp": timestamp
        }
        
        sqs.send_message(
            QueueUrl=QUEUE_URL,
            MessageBody=json.dumps(sqs_message),
            MessageAttributes={
                'TargetAgent': {
                    'DataType': 'String',
                    'StringValue': target_agent
                }
            }
        )

        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": "Handoff successful",
                "session_id": session_id,
                "s3_uri": f"s3://{BUCKET_NAME}/{s3_key}"
            })
        }

    except Exception as e:
        print(f"Handoff error: {e}")
        return {"statusCode": 500, "body": json.dumps({"error": str(e)})}
