const https = require('https');
const http = require('http');
const { S3Client, ListObjectsV2Command, PutObjectCommand } = require('@aws-sdk/client-s3');

const s3 = new S3Client({ region: process.env.AWS_REGION || 'eu-west-3' });
const HEALTH_ENDPOINT = process.env.HEALTH_ENDPOINT;
const S3_BUCKET = process.env.S3_BUCKET;

function httpGet(url) {
  return new Promise((resolve) => {
    const lib = url.startsWith('https') ? https : http;
    lib.get(url, { timeout: 10000 }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve({ status: res.statusCode, body: JSON.parse(data) }));
    }).on('error', (err) => resolve({ status: 'error', error: err.message }));
  });
}

async function collectS3Metadata() {
  const prefixes = ['uploads/', 'documents/', 'reports/'];
  const result = {};

  for (const prefix of prefixes) {
    let count = 0, totalSize = 0;
    let token;

    do {
      const res = await s3.send(new ListObjectsV2Command({
        Bucket: S3_BUCKET, Prefix: prefix, ContinuationToken: token,
      }));
      for (const obj of res.Contents || []) { count++; totalSize += obj.Size; }
      token = res.NextContinuationToken;
    } while (token);

    result[prefix.replace('/', '')] = { objectCount: count, totalSizeBytes: totalSize };
  }

  return result;
}

exports.handler = async () => {
  const now = new Date();
  const timestamp = now.toISOString().replace(/[:.]/g, '-').slice(0, 19);

  const report = {
    generatedAt: now.toISOString(),
    healthCheck: await httpGet(`http://${HEALTH_ENDPOINT}/health`),
    s3Metadata: await collectS3Metadata(),
  };

  const key = `reports/service-check-${timestamp}.json`;
  await s3.send(new PutObjectCommand({
    Bucket: S3_BUCKET,
    Key: key,
    Body: JSON.stringify(report, null, 2),
    ContentType: 'application/json',
  }));

  console.log(`Report saved: s3://${S3_BUCKET}/${key}`);
  return { statusCode: 200, reportKey: key };
};
