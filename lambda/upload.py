# Lambda needs zip files to be uploaded to S3
# Receives a drawing from the browser and stores it in the gallery S3 bucket
import json
import uuid
import boto3
import base64
import os

def lambda_handler(event, context):
    bucket_name = os.environ['BUCKET_NAME']
    # Connection to S3 
    s3_client = boto3.client('s3')
    image_data = base64.b64decode(event['image'])
    prompt = event['prompt']
    # Generate a unique filename for the image (example: a_banana_123123123eqwe1.png)
    filename = f"{prompt.replace(' ', '_')}_{uuid.uuid4()}.png"

    #Upload the image to S3
    s3_client.put_object(
        Bucket=bucket_name, 
        Key=filename, 
        Body=image_data, 
        ContentType='image/png')
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Upload successful',
            'filename': filename
        })
    }