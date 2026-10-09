import { request } from 'node:http';

// Fetch rejects WHATWG restricted ports even when a test server is listening.
// Node HTTP keeps ephemeral-port tests independent of browser port policy.
export function requestLocal(url, { method = 'GET', headers = {}, body } = {}) {
  return new Promise((resolve, reject) => {
    const req = request(url, { method, headers }, response => {
      const chunks = [];
      response.on('data', chunk => chunks.push(chunk));
      response.on('error', reject);
      response.on('end', () => {
        try {
          resolve(new Response(
            [204, 205, 304].includes(response.statusCode) ? null : Buffer.concat(chunks),
            { status: response.statusCode, headers: response.headers },
          ));
        } catch (error) { reject(error); }
      });
    });
    req.on('error', reject);
    req.setTimeout(10000, () => req.destroy(new Error('Local test request timed out')));
    req.end(body);
  });
}
