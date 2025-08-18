import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import compression from 'compression';
import rateLimit from 'express-rate-limit';
import 'express-async-errors';

import { config } from './config/environment';
import { logger } from './utils/logger';
import { database } from './database';
import { errorHandler } from './middleware/errorHandler';
import { notFoundHandler } from './middleware/notFoundHandler';

// Import route handlers
import authRoutes from './api/routes/auth';
import mechanicRoutes from './api/routes/mechanics';
import customerRoutes from './api/routes/customers';
import bookingRoutes from './api/routes/bookings';
import serviceRoutes from './api/routes/services';

const app = express();

// Security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
}));

app.use(cors({
  origin: config.cors.origins,
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'Accept-Language'],
}));

const limiter = rateLimit({
  windowMs: config.rateLimit.windowMs,
  max: config.rateLimit.maxRequests,
  message: {
    error: 'Too many requests, please try again later.',
    retryAfter: config.rateLimit.windowMs / 1000,
  },
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/api/', limiter);

// General middleware
app.use(morgan(config.isDevelopment ? 'dev' : 'combined', {
  stream: { write: (message) => logger.info(message.trim()) }
}));

app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use(compression());

// Health check
app.get('/health', async (req, res) => {
  try {
    const dbResult = await database.query('SELECT 1 as status');

    res.json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      environment: config.nodeEnv,
      version: '1.0.0',
      database: dbResult.rows[0] ? 'connected' : 'disconnected',
      uptime: process.uptime(),
    });
  } catch (error) {
    logger.error('Health check failed:', error);
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      error: 'Database connection failed',
    });
  }
});

// API routes
app.use('/api/auth', authRoutes);
app.use('/api/mechanics', mechanicRoutes);
app.use('/api/customers', customerRoutes);
app.use('/api/bookings', bookingRoutes);
app.use('/api/services', serviceRoutes);

app.get('/api', (req, res) => {
  res.json({
    name: 'HappyRepair API',
    version: '1.0.0',
    description: 'Stop wasting time scrolling Google. Find mechanics with transparent pricing.',
    endpoints: {
      health: 'GET /health',
      auth: 'POST /api/auth/login, POST /api/auth/register',
      mechanics: 'GET /api/mechanics/nearby, GET /api/mechanics/:id',
      customers: 'GET /api/customers/profile, PUT /api/customers/profile',
      bookings: 'POST /api/bookings, GET /api/bookings/:id',
      services: 'GET /api/services, GET /api/services/:id',
    },
    documentation: 'https://docs.happyrepair.com',
  });
});

// Error handling
app.use(notFoundHandler);
app.use(errorHandler);

async function startServer(): Promise<void> {
  try {
    await database.connect();
    logger.info('✅ Database connected successfully');

    const port = config.port;
    app.listen(port, () => {
      logger.info(`🚀 HappyRepair API server running on port ${port}`);
      logger.info(`🌍 Environment: ${config.nodeEnv}`);
      logger.info(`📊 Health check: http://localhost:${port}/health`);
      logger.info(`📚 API docs: http://localhost:${port}/api`);
    });

  } catch (error) {
    logger.error('❌ Failed to start server:', error);
    process.exit(1);
  }
}

process.on('SIGINT', async () => {
  logger.info('🛑 Shutting down server...');
  await database.disconnect();
  process.exit(0);
});

process.on('SIGTERM', async () => {
  logger.info('🛑 Shutting down server...');
  await database.disconnect();
  process.exit(0);
});

if (require.main === module) {
  startServer();
}

export { app };
