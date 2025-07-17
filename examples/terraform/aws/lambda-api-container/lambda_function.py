import json
import os
import boto3
import psycopg2
from botocore.exceptions import ClientError

def get_secret(secret_arn):
    """Retrieve secret from AWS Secrets Manager"""
    client = boto3.client('secretsmanager')
    try:
        response = client.get_secret_value(SecretId=secret_arn)
        return json.loads(response['SecretString'])
    except ClientError as e:
        raise Exception(f"Error retrieving secret: {e}")

def get_db_connection():
    """Get database connection using credentials from Secrets Manager"""
    secret_arn = os.environ.get('DB_SECRET_ARN')
    if not secret_arn:
        raise Exception("DB_SECRET_ARN environment variable not set")
    
    secret = get_secret(secret_arn)
    host, port = secret['host'].split(":")
    try:
        connection = psycopg2.connect(
            host=host,
            database=secret['dbname'],
            user=secret['username'],
            password=secret['password'],
            port=port
        )
        return connection
    except psycopg2.Error as e:
        raise Exception(f"Database connection failed: {e}")

def handler(event, context):
    """Lambda handler function"""
    try:        
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT version();")
        version = cursor.fetchone()
        cursor.close()
        conn.close()
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Database connection successful',
                'postgres_version': version[0] if version else 'Unknown'
            })
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }