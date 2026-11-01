import { LoggerService, LogLevel } from '@nestjs/common';

type LogFields = Record<string, unknown>;

function serialize(level: string, message: string, context?: string, fields?: LogFields) {
  return JSON.stringify({
    ts: new Date().toISOString(),
    level,
    msg: message,
    context: context || undefined,
    ...fields,
  });
}

/**
 * JSON line logger for production log aggregators.
 * Enable with LOG_FORMAT=json (default in production).
 */
export class StructuredLogger implements LoggerService {
  private readonly json: boolean;
  private readonly levels: Set<string>;

  constructor() {
    const env = (process.env.NODE_ENV || '').toLowerCase();
    const format = (process.env.LOG_FORMAT || (env === 'production' ? 'json' : 'text')).toLowerCase();
    this.json = format === 'json';
    const raw = (process.env.LOG_LEVEL || 'log').toLowerCase();
    const order = ['error', 'warn', 'log', 'debug', 'verbose'];
    const idx = Math.max(0, order.indexOf(raw === 'info' ? 'log' : raw));
    this.levels = new Set(order.slice(0, idx + 1));
  }

  private write(level: string, message: any, context?: string, fields?: LogFields) {
    if (!this.levels.has(level === 'info' ? 'log' : level)) return;
    const text = typeof message === 'string' ? message : JSON.stringify(message);
    if (this.json) {
      const line = serialize(level, text, context, fields);
      if (level === 'error') process.stderr.write(line + '\n');
      else process.stdout.write(line + '\n');
      return;
    }
    const prefix = context ? `[${context}] ` : '';
    const out = `${prefix}${text}`;
    if (level === 'error') console.error(out);
    else if (level === 'warn') console.warn(out);
    else console.log(out);
  }

  log(message: any, context?: string) {
    this.write('log', message, context);
  }
  error(message: any, trace?: string, context?: string) {
    this.write('error', message, context, trace ? { trace } : undefined);
  }
  warn(message: any, context?: string) {
    this.write('warn', message, context);
  }
  debug?(message: any, context?: string) {
    this.write('debug', message, context);
  }
  verbose?(message: any, context?: string) {
    this.write('verbose', message, context);
  }
  setLogLevels?(_levels: LogLevel[]) {
    // Nest may call this; levels are env-driven.
  }

  /** Ad-hoc structured event (payments, audit, etc.). */
  event(name: string, fields: LogFields, context = 'audit') {
    this.write('log', name, context, fields);
  }
}

let sentryInitialized = false;

/** Wire Sentry when SENTRY_DSN is set. Soft-fails if @sentry/node is absent. */
export function initSentryIfConfigured(): void {
  if (sentryInitialized) return;
  const dsn = (process.env.SENTRY_DSN || '').trim();
  if (!dsn) return;
  try {
    // Optional dependency — install @sentry/node on the host when enabling.
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const Sentry = require('@sentry/node') as {
      init: (opts: Record<string, unknown>) => void;
    };
    Sentry.init({
      dsn,
      environment: process.env.SENTRY_ENVIRONMENT || process.env.NODE_ENV || 'production',
      release: process.env.APP_VERSION || undefined,
      tracesSampleRate: Number(process.env.SENTRY_TRACES_SAMPLE_RATE || 0.05),
    });
    sentryInitialized = true;
    process.stdout.write(
      serialize('log', 'Sentry initialized', 'bootstrap', { hasDsn: true }) + '\n',
    );
  } catch (err) {
    process.stderr.write(
      serialize('warn', `Sentry not loaded: ${err}`, 'bootstrap') + '\n',
    );
  }
}
