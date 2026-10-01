import https from 'node:https';
import tls from 'node:tls';

const host = 'campus.scsldr.cn';

function checkTls(version) {
  return new Promise((resolve, reject) => {
    const socket = tls.connect({
      host,
      port: 443,
      servername: host,
      minVersion: version,
      maxVersion: version,
    });
    socket.setTimeout(8000, () => socket.destroy(new Error('timeout')));
    socket.once('secureConnect', () => {
      socket.end();
      resolve();
    });
    socket.once('error', reject);
  });
}

function checkHealth() {
  return new Promise((resolve, reject) => {
    const request = https.get(`https://${host}/api/health`, { timeout: 8000 }, (response) => {
      let body = '';
      response.setEncoding('utf8');
      response.on('data', (chunk) => {
        body += chunk;
        if (body.length > 4096) request.destroy(new Error('health response too large'));
      });
      response.once('end', () => {
        try {
          const result = JSON.parse(body);
          if (response.statusCode !== 200 || result.code !== 200) {
            reject(new Error(`HTTP ${response.statusCode}, API code ${result.code}`));
          } else {
            resolve();
          }
        } catch (error) {
          reject(error);
        }
      });
      response.once('error', reject);
    });
    request.once('timeout', () => request.destroy(new Error('timeout')));
    request.once('error', reject);
  });
}

let failures = 0;
for (const [name, check] of [
  ['TLS 1.2', () => checkTls('TLSv1.2')],
  ['TLS 1.3', () => checkTls('TLSv1.3')],
  ['PocketBase /api/health', checkHealth],
]) {
  try {
    await check();
    console.log(`${name}: OK`);
  } catch (error) {
    failures++;
    console.error(`${name}: ${error.code || error.message}`);
  }
}
if (failures) process.exitCode = 1;
