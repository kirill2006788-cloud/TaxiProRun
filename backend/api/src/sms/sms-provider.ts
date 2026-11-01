/**
 * Production SMS OTP provider interface.
 * Implementations: SmsAero, SMSC. Select via SMS_PROVIDER env.
 */
export interface SmsProvider {
  readonly name: string;
  sendOtp(phone: string, code: string, message: string): Promise<void>;
}

export type SmsProviderFactory = () => SmsProvider | null;
