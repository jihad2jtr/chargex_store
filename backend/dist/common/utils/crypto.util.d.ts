export declare class CryptoUtil {
    static encrypt(data: any): string;
    static decrypt<T = any>(cipherText: string): T | null;
    static mask(value: string): string;
}
