import * as crypto from 'crypto';

const ALGORITHM = 'aes-256-cbc';
// Ensure 32-byte key
const SECRET_KEY = crypto
  .createHash('sha256')
  .update(process.env.ENCRYPTION_SECRET || 'chargex-super-secret-safe-encryption-key-32')
  .digest();

export class CryptoUtil {
  /**
   * Encrypts plaintext string or JSON object into AES-256-CBC hex string with IV
   */
  static encrypt(data: any): string {
    if (data === null || data === undefined) return '';
    const text = typeof data === 'object' ? JSON.stringify(data) : String(data);
    const iv = crypto.randomBytes(16);
    const cipher = crypto.createCipheriv(ALGORITHM, SECRET_KEY, iv);
    let encrypted = cipher.update(text, 'utf8', 'hex');
    encrypted += cipher.final('hex');
    return `${iv.toString('hex')}:${encrypted}`;
  }

  /**
   * Decrypts AES-256-CBC string back to original string or parsed JSON object
   */
  static decrypt<T = any>(cipherText: string): T | null {
    if (!cipherText || !cipherText.includes(':')) return null;
    try {
      const [ivHex, encryptedHex] = cipherText.split(':');
      const iv = Buffer.from(ivHex, 'hex');
      const decipher = crypto.createDecipheriv(ALGORITHM, SECRET_KEY, iv);
      let decrypted = decipher.update(encryptedHex, 'hex', 'utf8');
      decrypted += decipher.final('utf8');

      try {
        return JSON.parse(decrypted) as T;
      } catch {
        return decrypted as unknown as T;
      }
    } catch {
      return null;
    }
  }

  /**
   * Masks sensitive information for display in public logs or notifications
   */
  static mask(value: string): string {
    if (!value) return '••••••';
    if (value.length <= 4) return '••••';
    return `${value.slice(0, 2)}••••${value.slice(-2)}`;
  }
}
