const defaultOrigins = [
  'https://admin.trezv7777.ru', 'https://trezv7777.ru', 'https://api.trezv7777.ru',
  'http://admin.trezv7777.ru', 'http://trezv7777.ru', 'http://api.trezv7777.ru',
  'http://194.67.84.155', 'https://194.67.84.155',
  'http://161.104.19.23', 'https://161.104.19.23',
];

export function allowOrigin(origin: string | undefined): boolean {
  if (!origin) return true; // Native mobile clients send no Origin header.
  const allowed = (process.env.CORS_ORIGINS ?? defaultOrigins.join(','))
    .split(',').map(value => value.trim()).filter(Boolean);
  if (allowed.includes(origin)) return true;
  try {
    const url = new URL(origin);
    return process.env.NODE_ENV !== 'production'
      && ['http:', 'https:'].includes(url.protocol)
      && ['localhost', '127.0.0.1', '[::1]'].includes(url.hostname);
  } catch {
    return false;
  }
}

export function corsOrigin(origin: string | undefined, callback: (error: Error | null, allowed?: boolean) => void) {
  if (allowOrigin(origin)) callback(null, true);
  else callback(new Error('Origin is not allowed'));
}
