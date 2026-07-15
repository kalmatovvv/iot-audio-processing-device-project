import base64
import json
import os
import uuid
import boto3
import decimal
from botocore.exceptions import ClientError
from datetime import datetime

class DecimalEncoder(json.JSONEncoder):
    def default(self, o):
        if isinstance(o, decimal.Decimal):
            if o % 1 == 0:
                return int(o)
            return float(o)
        return super(DecimalEncoder, self).default(o)


# Initialize the S3 client
s3_client = boto3.client('s3')

# Read variables from environment
BUCKET_NAME = os.environ.get('BUCKET_NAME')
DYNAMODB_TABLE = os.environ.get('DYNAMODB_TABLE')
URL_EXPIRATION = int(os.environ.get('URL_EXPIRATION', '300'))

def handler(event, context):
    print("Received event:", json.dumps(event))
    
    route_key = event.get('routeKey', '')
    
    # 1. Route GET /conversations
    if 'GET /conversations' in route_key:
        if not DYNAMODB_TABLE:
            print("Configuration Error: DYNAMODB_TABLE is not set.")
            return {
                'statusCode': 500,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({'error': 'DynamoDB table configuration is missing'})
            }
        try:
            dynamodb = boto3.resource('dynamodb')
            table = dynamodb.Table(DYNAMODB_TABLE)
            
            print(f"Scanning DynamoDB table: {DYNAMODB_TABLE}")
            response = table.scan()
            items = response.get('Items', [])
            
            # Sort chronologically by date descending (latest first)
            items.sort(key=lambda x: x.get('date', ''), reverse=True)
            
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps(items, cls=DecimalEncoder)
            }
        except Exception as e:
            print(f"Error scanning DynamoDB: {e}")
            return {
                'statusCode': 500,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({'error': f'Failed to retrieve conversations: {str(e)}'})
            }
            
    # 2. Route DELETE /conversations
    if 'DELETE /conversations' in route_key:
        if not DYNAMODB_TABLE:
            print("Configuration Error: DYNAMODB_TABLE is not set.")
            return {
                'statusCode': 500,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({'error': 'DynamoDB table configuration is missing'})
            }
        
        query_params = event.get('queryStringParameters') or {}
        convo_id = query_params.get('id')
        if not convo_id:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({'error': 'Missing query parameter: id'})
            }
            
        try:
            dynamodb = boto3.resource('dynamodb')
            table = dynamodb.Table(DYNAMODB_TABLE)
            
            print(f"Deleting conversation ID '{convo_id}' from table: {DYNAMODB_TABLE}")
            table.delete_item(Key={'id': convo_id})
            
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods': 'DELETE,OPTIONS'
                },
                'body': json.dumps({'message': f'Conversation {convo_id} successfully deleted'})
            }
        except Exception as e:
            print(f"Error deleting conversation {convo_id}: {e}")
            return {
                'statusCode': 500,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({'error': f'Failed to delete conversation: {str(e)}'})
            }
            
    # 3. Route GET /presigned-url (existing flow)
    if not BUCKET_NAME:
        print("Configuration Error: BUCKET_NAME is not set.")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({'error': 'S3 bucket configuration is missing'})
        }

    # 3. Extract configuration from query string parameters
    query_params = event.get('queryStringParameters') or {}

    
    # Extract file extension, sanitize it to alphanumeric characters, default to wav
    file_ext = query_params.get('file_ext', 'wav')
    file_ext = ''.join(c for c in file_ext if c.isalnum())
    if not file_ext:
        file_ext = 'wav'
        
    # Extract Content-Type header (client must send the same header in the PUT request)
    content_type = query_params.get('content_type', 'application/octet-stream')

    # 3. Generate unique object key (e.g. raw/YYYY/MM/DD/timestamp_uuid.ext)
    now = datetime.utcnow()
    date_path = now.strftime('%Y/%m/%d')
    timestamp = now.strftime('%H%M%S')
    unique_id = uuid.uuid4().hex
    object_key = f"raw/{date_path}/{timestamp}_{unique_id}.{file_ext}"

    # 4. Generate S3 Presigned URL for PUT
    try:
        presigned_url = s3_client.generate_presigned_url(
            ClientMethod='put_object',
            Params={
                'Bucket': BUCKET_NAME,
                'Key': object_key,
                'ContentType': content_type
            },
            ExpiresIn=URL_EXPIRATION
        )
        
        print(f"Generated PUT presigned URL for s3://{BUCKET_NAME}/{object_key} (Content-Type: {content_type})")
        
        # 5. Return success response
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET,OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type'
            },
            'body': json.dumps({
                'uploadUrl': presigned_url,
                'objectKey': object_key,
                'contentType': content_type,
                'expiresInSeconds': URL_EXPIRATION
            })
        }
        
    except ClientError as e:
        print(f"AWS ClientError during URL generation: {e}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({'error': f'Failed to generate upload URL: {str(e)}'})
        }
    except Exception as e:
        print(f"Unexpected error: {e}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({'error': 'Internal server error'})
        }
