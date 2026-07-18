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
BEDROCK_MODEL_ID = os.environ.get('BEDROCK_MODEL_ID', 'meta.llama3-1-8b-instruct-v1:0')
BEDROCK_REGION = os.environ.get('BEDROCK_REGION', 'us-west-2')


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
            
    # 3. Route POST /chat
    if 'POST /chat' in route_key:
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
            body = json.loads(event.get('body', '{}'))
        except Exception as e:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({'error': 'Invalid JSON body'})
            }
            
        convo_id = body.get('conversationId')
        user_message = body.get('message')
        chat_history = body.get('history', [])
        
        if not convo_id or not user_message:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({'error': 'Missing required fields: conversationId and message'})
            }
            
        # Retrieve transcript from DynamoDB
        try:
            dynamodb = boto3.resource('dynamodb')
            table = dynamodb.Table(DYNAMODB_TABLE)
            
            print(f"Retrieving transcript for conversation ID: {convo_id}")
            response = table.get_item(Key={'id': convo_id})
            convo_item = response.get('Item')
            
            if not convo_item:
                return {
                    'statusCode': 404,
                    'headers': {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*'
                    },
                    'body': json.dumps({'error': f'Conversation {convo_id} not found'})
                }
                
            transcript_text = convo_item.get('transcript', '').strip()
            if not transcript_text:
                transcript_text = "No transcript content available."
        except Exception as e:
            print(f"Error fetching from DynamoDB: {e}")
            return {
                'statusCode': 500,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({'error': f'Failed to retrieve conversation metadata: {str(e)}'})
            }
            
        # Invoke Bedrock Converse API with history and system prompt
        try:
            bedrock_runtime = boto3.client('bedrock-runtime', region_name=BEDROCK_REGION)
            
            # Format history to match Bedrock Converse API requirements
            formatted_messages = []
            for msg in chat_history:
                role = msg.get('role')
                content = msg.get('content', '')
                if role in ['user', 'assistant'] and content:
                    formatted_messages.append({
                        'role': role,
                        'content': [{'text': content}]
                    })
                    
            # Append new user message
            formatted_messages.append({
                'role': 'user',
                'content': [{'text': user_message}]
            })
            
            system_prompt = (
                "You are a helpful AI assistant. Answer the user's questions about the following audio recording transcript. "
                "Base your answers strictly on the facts, discussions, and statements directly present in the transcript. "
                "If the answer cannot be determined or inferred from the transcript, state that clearly.\n\n"
                f"Transcript:\n{transcript_text}"
            )
            
            print(f"Invoking Bedrock model '{BEDROCK_MODEL_ID}' via Converse API for conversation ID: {convo_id}")
            converse_response = bedrock_runtime.converse(
                modelId=BEDROCK_MODEL_ID,
                messages=formatted_messages,
                system=[{'text': system_prompt}],
                inferenceConfig={
                    'maxTokens': 1000,
                    'temperature': 0.5
                }
            )
            
            reply_text = converse_response['output']['message']['content'][0]['text'].strip()
            
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({'reply': reply_text})
            }
        except Exception as e:
            print(f"Error executing chat via Bedrock: {e}")
            return {
                'statusCode': 500,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({'error': f'Failed to execute assistant query: {str(e)}'})
            }
            
    # 4. Route GET /presigned-url (existing flow)

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
