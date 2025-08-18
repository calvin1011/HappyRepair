import dotenv from 'dotenv';
import path from 'path';

dotenv.config({ path: path.join(__dirname, '../../../.env') });

interface Config {
  nodeEnv: string;
  isDevelopment: boolean;
  isProduction: boolean;
  port: number;
  cors: {
    origins: string[];
  };
  rateLimit: {
    windowMs: number;
    maxRequests: number;
  };
}

export const config: Config = {
  nodeEnv: process.env.NODE_ENV || 'development',
  isDevelopment: process.env.NODE_ENV === 'development',
  isProduction: process.env.NODE_ENV === 'production',
  port: parseInt(process.env.API_PORT || '3000', 10),
  cors: {
    origins: (process.env.CORS_ORIGIN || 'http://localhost:3000').split(','),
  },
  rateLimit: {
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MINUTES || '15', 10) * 60 * 1000,
    maxRequests: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS || '100', 10),
  },
};
