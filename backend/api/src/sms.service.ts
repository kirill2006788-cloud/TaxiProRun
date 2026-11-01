import { Injectable } from '@nestjs/common';
import axios from 'axios';
import type { SmsProvider } from './sms/sms-provider';

function otpMessage(code: string) {
  return `Код для входа в КОРОЛИ ДОРОГ: ${code}`;
}

/** Force-disable debug OTP shortcuts in production. */
export function isOtpDebugAllowed(): boolean {
  if ((process.env.NODE_ENV || '').toLowerCase() === 'production') {
    return false;
  }
  return process.env.OTP_DEBUG_LOG === '1';
}

class SmsAeroProvider implements SmsProvider {
  readonly name = 'smsaero';

  async sendOtp(phone: string, code: string, message: string): Promise<void> {
    const email = process.env.SMSAERO_EMAIL;
    const apiKey = process.env.SMSAERO_API_KEY;
    if (!email || !apiKey) {
      if ((process.env.NODE_ENV || '').toLowerCase() === 'production') {
        throw new Error('SMS Aero not configured in production');
      }
      process.stdout.write('SMS Aero not configured. Skipping SMS send.\n');
      return;
    }
    const digits = phone.replace(/\D/g, '');
    const authHeader = 'Basic ' + Buffer.from(`${email}:${apiKey}`).toString('base64');
    const sign = (process.env.SMSAERO_SIGN || 'SMS Aero').trim();
    const protocol = process.env.SMSAERO_USE_HTTP === '1' ? 'http' : 'https';
    const res = await axios.get(`${protocol}://gate.smsaero.ru/v2/sms/send`, {
      params: { number: digits, text: message || otpMessage(code), sign },
      headers: { Authorization: authHeader },
      timeout: 20_000,
    });
    if (!res.data?.success) {
      throw new Error(`SmsAero error: ${JSON.stringify(res.data)}`);
    }
  }
}

class SmscProvider implements SmsProvider {
  readonly name = 'smsc';

  async sendOtp(phone: string, code: string, message: string): Promise<void> {
    const login = process.env.SMSC_LOGIN;
    const psw = process.env.SMSC_PASSWORD;
    if (!login || !psw) {
      if ((process.env.NODE_ENV || '').toLowerCase() === 'production') {
        throw new Error('SMSC not configured in production');
      }
      process.stdout.write('SMSC not configured. Skipping SMS send.\n');
      return;
    }
    const params = new URLSearchParams({
      login,
      psw,
      phones: phone,
      mes: message || otpMessage(code),
      fmt: '3',
    });
    const res = await axios.get(`https://smsc.ru/sys/send.php?${params.toString()}`, {
      timeout: 20_000,
    });
    if (String(res.data?.error || res.data?.error_code || '').trim()) {
      throw new Error(`SMSC error: ${JSON.stringify(res.data)}`);
    }
  }
}

@Injectable()
export class SmsService {
  private provider: SmsProvider;

  constructor() {
    const name = (process.env.SMS_PROVIDER || 'smsaero').toLowerCase();
    this.provider = name === 'smsc' ? new SmscProvider() : new SmsAeroProvider();
  }

  /** Expose active provider name for health/diagnostics. */
  get providerName() {
    return this.provider.name;
  }

  async sendOtp(phone: string, code: string) {
    if (isOtpDebugAllowed()) {
      process.stdout.write(`OTP_DEBUG_LOG=1. OTP for ${phone}: ${code}\n`);
      return;
    }
    await this.provider.sendOtp(phone, code, otpMessage(code));
  }
}
