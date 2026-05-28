#Returns a list of all images in the S3 bucket
import json
import boto3
import os  

def lambda_handler(event, context):
    bucket_name = os.environ['BUCKET_NAME']
    # Connection to S3
    s3_client = boto3.client('s3', region_name='eu-north-1')
    # List objects in the S3 bucket
    response = s3_client.list_objects_v2(Bucket=bucket_name, Prefix="gallery/")
    images = []
    if 'Contents' in response:
        for obj in response['Contents']:
            images.append(obj['Key'])
    return {
        'statusCode': 200,
        'body': json.dumps({
            'images': images
        })
    }