'use strict';

const express = require('express');
const { Pool } = require('pg');
const { SecretsManagerClient, GetSecretValueCommand } = require('@aws-sdk/client-secrets-manager');

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 3000;
const AWS_REGION = process.env.AWS_REGION || 'eu-west-3';
const DB_SECRET_ARN = process.env.DB_SECRET_ARN;

let pool;

async function getDbCredentials() {
  if (DB_SECRET_ARN) {
    const client = new SecretsManagerClient({ region: AWS_REGION });
    const { SecretString } = await client.send(
      new GetSecretValueCommand({ SecretId: DB_SECRET_ARN })
    );
    const s = JSON.parse(SecretString);
    return { host: s.host, port: s.port, database: s.dbname, user: s.username, password: s.password };
  }
  return {
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '5432'),
    database: process.env.DB_NAME || 'ekscorp',
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD || 'postgres',
  };
}

app.get('/', (req, res) => {
  res.json({ app: 'eks-corp-backend', version: '1.1.0' });
});

app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.status(200).json({ status: 'healthy', db: 'connected' });
  } catch (err) {
    res.status(503).json({ status: 'unhealthy', db: err.message });
  }
});

async function start() {
  const creds = await getDbCredentials();
  pool = new Pool({ ...creds, max: 5 });
  await pool.query('SELECT 1');
  console.log('DB connection established');
  app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
}

start().catch(err => {
  console.error('Startup failed:', err);
  process.exit(1);
});
