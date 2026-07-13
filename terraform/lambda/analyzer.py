import json
import urllib.parse
import urllib3
import os
import boto3

# Initialize AWS clients
s3_client = boto3.client('s3')

# Amazon Bedrock is not available in all regions (e.g. us-west-1).
# We initialize the client in a supported region (like us-west-2 or us-east-1).
bedrock_region = os.environ.get('BEDROCK_REGION', 'us-west-2')
bedrock_runtime = boto3.client('bedrock-runtime', region_name=bedrock_region)


def clean_llm_json(text):
    """
    Strips potential markdown code blocks and conversational filler 
    from the LLM output to ensure clean JSON parsing.
    """
    text = text.strip()
    if text.startswith("```"):
        lines = text.splitlines()
        if lines[0].startswith("```"):
            lines = lines[1:]
        if lines and lines[-1].startswith("```"):
            lines = lines[:-1]
        text = "\n".join(lines).strip()
    return text

def handler(event, context):
    print("Received transcripts event:", json.dumps(event))
    
    webhook_url = os.environ.get('WEBHOOK_URL')
    model_id = os.environ.get('BEDROCK_MODEL_ID', 'anthropic.claude-3-haiku-20240307-v1:0')
    
    for record in event.get('Records', []):
        try:
            # 1. Retrieve the bucket name and transcript JSON object key
            bucket_name = record['s3']['bucket']['name']
            raw_key = record['s3']['object']['key']
            object_key = urllib.parse.unquote_plus(raw_key)
            
            print(f"Reading transcript file from S3: s3://{bucket_name}/{object_key}")
            
            # Verify file is JSON
            if not object_key.lower().endswith('.json'):
                print(f"Skipping: '{object_key}' is not a JSON file.")
                continue

            # 2. Retrieve transcript JSON content from S3
            response = s3_client.get_object(
                Bucket=bucket_name,
                Key=object_key
            )
            transcript_content = response['Body'].read().decode('utf-8')
            transcript_json = json.loads(transcript_content)
            
            # Extract transcript text
            transcripts = transcript_json.get('results', {}).get('transcripts', [])
            if not transcripts:
                print(f"No transcripts found inside the JSON results: {object_key}")
                continue
                
            transcript_text = transcripts[0].get('transcript', '').strip()
            if not transcript_text:
                print(f"Transcript text is empty for key: {object_key}")
                continue

            print(f"Extracted transcript text: {transcript_text[:150]}...")

            # 3. Formulate LLM Prompt for Bedrock
            prompt = (
                "You are an expert audio analysis AI. Analyze the following recording transcript. "
                "Produce a clean, structured JSON response with exactly the following keys:\n"
                "1. 'topic': A short string representing the main topic discussed.\n"
                "2. 'summary': A brief, 2-3 sentence paragraph summarizing the audio.\n"
                "3. 'key_points': An array of strings capturing the main ideas.\n"
                "4. 'action_items': An array of strings describing any tasks or action items identified.\n"
                "5. 'answer': A helpful string answering any question, query, or request explicitly made in the transcript. "
                "For example, if the transcript asks 'What is the capital of Kyrgyzstan?', this should be 'The capital of Kyrgyzstan is Bishkek.' "
                "If no question, request, or query is made, this should be empty (\"\").\n\n"
                "Return raw, valid JSON only. Do not wrap the JSON output in markdown formatting (like ```json ... ```) or add text before or after the JSON payload.\n\n"
                f"Transcript:\n{transcript_text}"
            )

            # 4. Invoke the model via Bedrock Converse API (unified interface for Claude, Llama, Titan, etc.)
            print(f"Invoking Bedrock model '{model_id}' via Converse API...")
            converse_response = bedrock_runtime.converse(
                modelId=model_id,
                messages=[
                    {
                        "role": "user",
                        "content": [
                            {
                                "text": prompt
                            }
                        ]
                    }
                ],
                inferenceConfig={
                    "maxTokens": 1000,
                    "temperature": 0.3
                }
            )

            analysis_raw_text = converse_response['output']['message']['content'][0]['text'].strip()

            
            print(f"Raw response from Bedrock: {analysis_raw_text[:200]}...")
            
            # Clean and parse JSON
            cleaned_json_text = clean_llm_json(analysis_raw_text)
            try:
                analysis_results = json.loads(cleaned_json_text)
            except json.JSONDecodeError as jde:
                print(f"Failed to parse LLM response directly as JSON: {jde}. Using raw text as fallback.")
                analysis_results = {
                    "topic": "Unknown (Failed to parse JSON)",
                    "summary": cleaned_json_text,
                    "key_points": [],
                    "action_items": [],
                    "answer": ""
                }

            # 5. Save results to DynamoDB (for iOS Mobile App sync)
            db_table_name = os.environ.get('DYNAMODB_TABLE')
            if not db_table_name:
                print("Skipping DynamoDB: DYNAMODB_TABLE environment variable is not defined.")
            else:
                import uuid
                from datetime import datetime
                
                dynamodb = boto3.resource('dynamodb')
                table = dynamodb.Table(db_table_name)
                
                # Format conversation object to match SwiftUI Conversation model keys (camelCase)
                conversation_item = {
                    "id": str(uuid.uuid4()),
                    "title": analysis_results.get("topic", "New Recording"),
                    "date": datetime.utcnow().isoformat() + "Z", # ISO8601 timestamp string
                    "duration": 30, # Default duration placeholder
                    "transcript": transcript_text,
                    "summary": analysis_results.get("summary", ""),
                    "keyPoints": analysis_results.get("key_points", []) or analysis_results.get("keyPoints", []),
                    "actionItems": analysis_results.get("action_items", []) or analysis_results.get("actionItems", []),
                    "tags": [analysis_results.get("topic", "General")],
                    "status": "Synced & Analyzed",
                    "answer": analysis_results.get("answer", "")
                }
                
                print(f"Saving conversation item to DynamoDB table '{db_table_name}' with ID: {conversation_item['id']}")
                table.put_item(Item=conversation_item)
                print("Conversation successfully saved to DynamoDB.")

            # 6. Send results to Webhook URL
            if not webhook_url:
                print("Skipping Webhook: WEBHOOK_URL environment variable is not defined.")
            else:
                webhook_payload = {
                    "bucket": bucket_name,
                    "objectKey": object_key,
                    "originalWavKey": object_key.replace("transcripts/", "raw/").replace(".json", ".wav"),
                    "transcript": transcript_text,
                    "analysis": analysis_results
                }
                
                http = urllib3.PoolManager()
                encoded_data = json.dumps(webhook_payload).encode('utf-8')
                
                print(f"POSTing analysis payload to webhook: {webhook_url}")
                webhook_response = http.request(
                    'POST',
                    webhook_url,
                    headers={'Content-Type': 'application/json'},
                    body=encoded_data
                )
                print(f"Webhook response status: {webhook_response.status}, body: {webhook_response.data.decode('utf-8')}")


        except Exception as e:
            print(f"Error executing transcript analysis for record: {e}")
            raise e

    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'Transcripts successfully processed'})
    }
