import json
import urllib.parse
import boto3
import io
import wave
import uuid

# Initialize clients
s3_client = boto3.client('s3')
transcribe_client = boto3.client('transcribe')

def handler(event, context):
    print("Received S3 event:", json.dumps(event))
    
    for record in event.get('Records', []):
        try:
            # 1. Retrieve the bucket and key from the event payload
            bucket_name = record['s3']['bucket']['name']
            
            # Decodes URL-encoded characters (like '+' or '%20') from key name
            raw_key = record['s3']['object']['key']
            object_key = urllib.parse.unquote_plus(raw_key)
            
            print(f"Processing raw audio file from S3: s3://{bucket_name}/{object_key}")
            
            # 2. Validate it's a .raw file
            if not object_key.lower().endswith('.raw'):
                print(f"Skipping conversion: object '{object_key}' does not have a .raw extension.")
                continue

            # 3. Read the raw binary data from S3
            response = s3_client.get_object(
                Bucket=bucket_name,
                Key=object_key
            )
            raw_audio_data = response['Body'].read()
            print(f"Read {len(raw_audio_data)} bytes of raw audio data.")

            # 4. Perform in-memory WAV header injection
            wav_buffer = io.BytesIO()
            
            # Open wave stream in write-binary mode targeting the buffer
            with wave.open(wav_buffer, 'wb') as wav_file:
                wav_file.setnchannels(1)      # Mono Channel
                wav_file.setsampwidth(2)      # 16-bit PCM (2 bytes per sample)
                wav_file.setframerate(16000)  # 16kHz sampling rate
                wav_file.writeframes(raw_audio_data)
            
            # Retrieve the complete WAV file bytes
            wav_file_data = wav_buffer.getvalue()
            wav_buffer.close()
            print(f"Created WAV file: size is {len(wav_file_data)} bytes (includes 44-byte WAV header).")

            # 5. Swap extension from .raw to .wav
            new_object_key = object_key[:-4] + '.wav'

            # 6. Upload the playable .wav file back to S3
            s3_client.put_object(
                Bucket=bucket_name,
                Key=new_object_key,
                Body=wav_file_data,
                ContentType='audio/wav'
            )
            print(f"Successfully converted and saved: s3://{bucket_name}/{new_object_key}")

            # 7. Trigger AWS Transcribe job on the newly saved .wav file
            # Format transcription job name to be unique and alphanumeric/hyphen/underscore
            sanitized_key = new_object_key.replace('/', '_').replace('.', '_')
            job_name = f"transcribe_{sanitized_key}_{uuid.uuid4().hex[:6]}"
            media_uri = f"s3://{bucket_name}/{new_object_key}"
            
            # Save the transcript JSON inside transcripts/ prefix (e.g. transcripts/filename.json)
            file_name = new_object_key.split('/')[-1]
            transcript_key = f"transcripts/{file_name.replace('.wav', '.json')}"

            print(f"Starting transcription job '{job_name}' for media URI: {media_uri}")
            transcribe_client.start_transcription_job(
                TranscriptionJobName=job_name,
                Media={'MediaFileUri': media_uri},
                MediaFormat='wav',
                LanguageCode='en-US',
                OutputBucketName=bucket_name,
                OutputKey=transcript_key
            )
            print(f"Transcribe job '{job_name}' successfully launched. Target output key: {transcript_key}")

        except Exception as e:
            print(f"Error processing S3 object: {e}")
            raise e

    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'Audio conversion completed successfully'})
    }
