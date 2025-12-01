/**
 * Processes and validates Firebase private key from environment variable
 * Handles various formats and encoding issues
 */
function processFirebasePrivateKey(rawKey) {
  if (!rawKey || typeof rawKey !== 'string') {
    throw new Error('Private key must be a non-empty string');
  }

  let processed = rawKey;

  // Step 1: Replace escaped newlines with actual newlines
  processed = processed.replace(/\\n/g, '\n');

  // Step 2: Remove any carriage returns
  processed = processed.replace(/\r/g, '');

  // Step 3: Trim leading/trailing whitespace
  processed = processed.trim();

  // Step 4: Validate that it contains the required markers
  if (!processed.includes('BEGIN PRIVATE KEY') || !processed.includes('END PRIVATE KEY')) {
    throw new Error('Private key must include "-----BEGIN PRIVATE KEY-----" and "-----END PRIVATE KEY-----" markers');
  }

  // Step 5: Ensure proper line breaks around markers
  // Fix common issues where markers might be on the same line as content
  processed = processed.replace(/-----BEGIN PRIVATE KEY-----\s*/g, '-----BEGIN PRIVATE KEY-----\n');
  processed = processed.replace(/\s*-----END PRIVATE KEY-----/g, '\n-----END PRIVATE KEY-----');

  // Step 6: Remove any empty lines
  processed = processed.split('\n').filter(line => line.trim().length > 0).join('\n');

  // Step 7: Ensure the key body (between markers) is properly formatted
  // The key body should be base64 encoded lines, typically 64 characters each
  const beginMarker = '-----BEGIN PRIVATE KEY-----';
  const endMarker = '-----END PRIVATE KEY-----';
  
  const beginIndex = processed.indexOf(beginMarker);
  const endIndex = processed.indexOf(endMarker);
  
  if (beginIndex === -1 || endIndex === -1 || endIndex <= beginIndex) {
    throw new Error('Invalid private key structure: markers not found or in wrong order');
  }

  // Extract the key body
  const keyBody = processed.substring(beginIndex + beginMarker.length, endIndex).trim();
  
  // Validate key body is not empty
  if (!keyBody || keyBody.length < 100) {
    throw new Error('Private key body appears to be too short or empty');
  }

  // Reconstruct with proper formatting
  const formattedKey = `${beginMarker}\n${keyBody}\n${endMarker}\n`;

  return formattedKey;
}

/**
 * Validates Firebase Admin credentials before initialization
 */
function validateFirebaseCredentials(projectId, privateKey, clientEmail) {
  const errors = [];

  if (!projectId || typeof projectId !== 'string' || projectId.trim().length === 0) {
    errors.push('FIREBASE_PROJECT_ID is missing or empty');
  }

  if (!privateKey || typeof privateKey !== 'string' || privateKey.trim().length === 0) {
    errors.push('FIREBASE_PRIVATE_KEY is missing or empty');
  }

  if (!clientEmail || typeof clientEmail !== 'string' || clientEmail.trim().length === 0) {
    errors.push('FIREBASE_CLIENT_EMAIL is missing or empty');
  }

  if (clientEmail && !clientEmail.includes('@')) {
    errors.push('FIREBASE_CLIENT_EMAIL does not appear to be a valid email address');
  }

  if (errors.length > 0) {
    throw new Error(`Firebase credentials validation failed: ${errors.join(', ')}`);
  }

  return true;
}

module.exports = { processFirebasePrivateKey, validateFirebaseCredentials };




