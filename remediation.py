import boto3
import os

def handler(event, context):
    s3 = boto3.client('s3')
    bucket_name = os.environ['BUCKET_NAME']
    
    print(f"Checking ACL for bucket: {bucket_name}")
    
    try:
        # Reverting the bucket to private
        # In a real scenario, this would be triggered by a specific 'Public' event
        s3.put_bucket_acl(
            Bucket=bucket_name,
            ACL='private'
        )
        print(f"Successfully remediated bucket {bucket_name} to private.")
        return {
            'statusCode': 200,
            'body': f"Remediated {bucket_name} to private."
        }
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': str(e)
        }
