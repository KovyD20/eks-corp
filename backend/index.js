'use strict';

const express = require('express');
const multer = require('multer');
const { Pool } = require('pg');
const { SecretsManagerClient, GetSecretValueCommand } = require('@aws-sdk/client-secrets-manager');
const { S3Client, PutObjectCommand, GetObjectCommand, ListObjectsV2Command } = require('@aws-sdk/client-s3');

const app = express();
app.use(express.json());
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 50 * 1024 * 1024 } });

const wrap = fn => (req, res, next) => fn(req, res, next).catch(next);

const PORT = process.env.PORT || 3000;
const AWS_REGION = process.env.AWS_REGION || 'eu-west-3';
const DB_SECRET_ARN = process.env.DB_SECRET_ARN;
const S3_BUCKET = process.env.S3_BUCKET_NAME;

const s3 = new S3Client({ region: AWS_REGION });
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

// ─── Routes ──────────────────────────────────────────────────────────────────

app.get('/', (req, res) => {
  res.json({ app: 'eks-corp-backend', version: '1.2.0' });
});

app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.status(200).json({ status: 'healthy', db: 'connected' });
  } catch (err) {
    res.status(503).json({ status: 'unhealthy', db: err.message });
  }
});

app.post('/api/files/upload', upload.single('file'), wrap(async (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'No file provided' });

  const key = `uploads/${Date.now()}-${req.file.originalname}`;
  await s3.send(new PutObjectCommand({
    Bucket: S3_BUCKET,
    Key: key,
    Body: req.file.buffer,
    ContentType: req.file.mimetype,
  }));

  res.status(201).json({ key, size: req.file.size, contentType: req.file.mimetype });
}));

app.get('/api/files/download', wrap(async (req, res) => {
  const { key } = req.query;
  if (!key) return res.status(400).json({ error: 'key query param required' });

  const { Body, ContentType } = await s3.send(new GetObjectCommand({
    Bucket: S3_BUCKET,
    Key: key,
  }));

  res.setHeader('Content-Type', ContentType || 'application/octet-stream');
  res.setHeader('Content-Disposition', `attachment; filename="${key.split('/').pop()}"`);
  Body.pipe(res);
}));

app.get('/api/files/list', wrap(async (req, res) => {
  const prefix = req.query.prefix || 'uploads/';
  const { Contents = [] } = await s3.send(new ListObjectsV2Command({
    Bucket: S3_BUCKET,
    Prefix: prefix,
  }));

  res.json(Contents.map(obj => ({ key: obj.Key, size: obj.Size, lastModified: obj.LastModified })));
}));

app.use((err, req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: err.message });
});

// ─── Start ────────────────────────────────────────────────────────────────────

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
