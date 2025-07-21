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
    let client;
    try {
        console.log('Fetching DB credentials...');
        const dbCreds = await getDbCredentials();

        console.log('Creating new PostgreSQL client...');
        const [hostname] = dbCreds.host.split(':');
        client = new Client({
            host: hostname,
            port: dbCreds.port,
            database: dbCreds.dbname,
            user: dbCreds.username,
            password: dbCreds.password,
            ssl: {
                rejectUnauthorized: true,
                ca: require('fs').readFileSync('/var/task/rds-ca-2019-root.pem')
            }
        });

        console.log('Connecting to PostgreSQL...');
        await client.connect();

        console.log('Ensuring test_data table exists...');
        // Create table if it doesn't exist
        await client.query(`
            CREATE TABLE IF NOT EXISTS test_data (
            id SERIAL PRIMARY KEY,
            value INTEGER NOT NULL
            )
        `);

        console.log('Querying for current max value...');
        // Get the highest value
        const maxResult = await client.query('SELECT MAX(value) as max_value FROM test_data');
        const currentMax = maxResult.rows[0].max_value || 0;
        console.log('Current max value:', currentMax);

        const nextValue = currentMax + 1;
        console.log('Next value to insert:', nextValue);

        console.log('Inserting new row...');
        // Insert new row with incremented value
        await client.query('INSERT INTO test_data (value) VALUES ($1)', [nextValue]);

        console.log('Preparing response...');
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
        console.log('Returning response:', response);
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
        if (client) {
            await client.end();
        }
    }
};