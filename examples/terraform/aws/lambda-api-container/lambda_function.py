import json
import os
import boto3
import psycopg2
from botocore.exceptions import ClientError
from flask import Flask, jsonify

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
            port=port,
            sslmode='require',
            sslrootcert='/var/task/rds-ca-2019-root.pem'
        )
        return connection
    except psycopg2.Error as e:
        raise Exception(f"Database connection failed: {e}")

def get_db_status():
    """Get database connection status"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT version();")
        version = cursor.fetchone()
        cursor.close()
        conn.close()
        
        return {
            'status': 'success',
            'message': 'Database connection successful',
            'postgres_version': version[0] if version else 'Unknown'
        }
    except Exception as e:
        return {
            'status': 'error',
            'error': str(e)
        }

def handler(event, context):
    """Lambda handler function"""
    result = get_db_status()
    
    if result['status'] == 'success':
        return {
            'statusCode': 200,
            'body': json.dumps(result)
        }
    else:
        return {
            'statusCode': 500,
            'body': json.dumps(result)
        }

# Flask app for ECS deployment
app = Flask(__name__)

@app.route('/')
@app.route('/health')
def health_check():
    """Health check endpoint"""
    return jsonify(get_db_status())

@app.route('/api/status')
def api_status():
    """API status endpoint"""
    return jsonify(get_db_status())

if __name__ == '__main__':
    # Check if running in ECS mode
    if os.getenv('RUN_MODE') == 'ECS':
        app.run(host='0.0.0.0', port=8080, debug=False)
    else:
        # Lambda mode - function will be called by AWS Lambda runtime
        pass