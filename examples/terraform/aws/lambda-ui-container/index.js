const { Client } = require('pg');
const { SecretsManagerClient, GetSecretValueCommand } = require('@aws-sdk/client-secrets-manager');

const secretsClient = new SecretsManagerClient({ region: 'eu-west-1' });

async function getDbCredentials() {
    const command = new GetSecretValueCommand({
        SecretId: process.env.DB_SECRET_ARN
    });
    
    const response = await secretsClient.send(command);
    return JSON.parse(response.SecretString);
}

exports.handler = async (event) => {
    try {
        const dbCreds = await getDbCredentials();
        
        const client = new Client({
            host: dbCreds.host,
            port: dbCreds.port,
            database: dbCreds.dbname,
            user: dbCreds.username,
            password: dbCreds.password,
            ssl: true
        });

        await client.connect();

        // Create table if it doesn't exist
        await client.query(`
            CREATE TABLE IF NOT EXISTS test_data (
                id SERIAL PRIMARY KEY,
                value INTEGER NOT NULL
            )
        `);

        // Get the highest value
        const maxResult = await client.query('SELECT MAX(value) as max_value FROM test_data');
        const currentMax = maxResult.rows[0].max_value || 0;
        const nextValue = currentMax + 1;

        // Insert new row with incremented value
        await client.query('INSERT INTO test_data (value) VALUES ($1)', [nextValue]);

        const response = {
            statusCode: 200,
            body: JSON.stringify({
                message: 'Hello from Tenzir UI Lambda!',
                nodeVersion: process.version,
                timestamp: new Date().toISOString(),
                previousMax: currentMax,
                newValue: nextValue
            }),
        };
        return response;
    } catch (error) {
        console.error('Database error:', error);
        return {
            statusCode: 500,
            body: JSON.stringify({
                error: 'Database operation failed',
                message: error.message
            })
        };
    } finally {
        await client.end();
    }
};