#!/bin/bash

# ============================================================================
# HappyRepair Backend API - Complete Setup Script
# Run this script from the project root directory
# ============================================================================

set -e

echo "🚀 Setting up HappyRepair Backend API..."
echo "========================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# 1. Navigate to backend directory
cd backend

print_info "Installing backend dependencies..."
npm install

print_status "Backend dependencies installed"

# 2. Create all the source files
print_info "Creating backend source files..."

# Create the main server files (server.ts, config, database, etc.)
cat > src/server.ts << 'EOF'
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
EOF

# Create a simple auth route for testing
mkdir -p src/api/routes
cat > src/api/routes/auth.ts << 'EOF'
import { Router } from 'express';

const router = Router();

router.post('/register', (req, res) => {
  res.json({
    status: 'success',
    message: 'Registration endpoint - coming soon!',
    data: {
      phone: req.body.phone,
      userType: req.body.userType,
    },
  });
});

router.post('/login', (req, res) => {
  res.json({
    status: 'success',
    message: 'Login endpoint - coming soon!',
    data: {
      phone: req.body.phone,
      userType: req.body.userType,
    },
  });
});

export default router;
EOF

# Create a simple mechanics route
cat > src/api/routes/mechanics.ts << 'EOF'
import { Router } from 'express';
import { database } from '../../database';

const router = Router();

router.get('/nearby', async (req, res) => {
  try {
    const { latitude, longitude, radius = 10 } = req.query;

    if (!latitude || !longitude) {
      return res.status(400).json({
        status: 'error',
        message: 'Latitude and longitude are required',
      });
    }

    // Use our PostGIS function to find nearby mechanics
    const query = `
      SELECT * FROM find_mechanics_within_radius($1, $2, $3)
    `;

    const result = await database.query(query, [
      parseFloat(latitude as string),
      parseFloat(longitude as string),
      parseInt(radius as string, 10)
    ]);

    res.json({
      status: 'success',
      data: {
        mechanics: result.rows,
        searchCriteria: {
          latitude: parseFloat(latitude as string),
          longitude: parseFloat(longitude as string),
          radius: parseInt(radius as string, 10),
        },
      },
    });

  } catch (error) {
    console.error('Nearby mechanics error:', error);
    res.status(500).json({
      status: 'error',
      message: 'Failed to find nearby mechanics',
    });
  }
});

router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;

    const query = `
      SELECT
        m.*,
        array_agg(DISTINCT s.name) FILTER (WHERE s.name IS NOT NULL) as services
      FROM mechanics m
      LEFT JOIN mechanic_services ms ON m.id = ms.mechanic_id
      LEFT JOIN services s ON ms.service_id = s.id
      WHERE m.id = $1 AND m.is_active = true
      GROUP BY m.id
    `;

    const result = await database.query(query, [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({
        status: 'error',
        message: 'Mechanic not found',
      });
    }

    res.json({
      status: 'success',
      data: {
        mechanic: result.rows[0],
      },
    });

  } catch (error) {
    console.error('Get mechanic error:', error);
    res.status(500).json({
      status: 'error',
      message: 'Failed to get mechanic details',
    });
  }
});

export default router;
EOF

# Create empty route files for other endpoints
cat > src/api/routes/customers.ts << 'EOF'
import { Router } from 'express';

const router = Router();

router.get('/profile', (req, res) => {
  res.json({
    status: 'success',
    message: 'Customer profile endpoint - coming soon!',
  });
});

export default router;
EOF

cat > src/api/routes/bookings.ts << 'EOF'
import { Router } from 'express';

const router = Router();

router.post('/', (req, res) => {
  res.json({
    status: 'success',
    message: 'Create booking endpoint - coming soon!',
  });
});

export default router;
EOF

cat > src/api/routes/services.ts << 'EOF'
import { Router } from 'express';
import { database } from '../../database';

const router = Router();

router.get('/', async (req, res) => {
  try {
    const { language = 'en' } = req.query;

    const query = `
      SELECT
        s.id,
        s.category,
        s.estimated_duration,
        COALESCE(st.name, s.name) as name,
        COALESCE(st.description, s.description) as description
      FROM services s
      LEFT JOIN service_translations st ON s.id = st.service_id AND st.language_code = $1
      WHERE s.is_active = true
      ORDER BY s.category, s.name
    `;

    const result = await database.query(query, [language]);

    res.json({
      status: 'success',
      data: {
        services: result.rows,
        language,
      },
    });

  } catch (error) {
    console.error('Get services error:', error);
    res.status(500).json({
      status: 'error',
      message: 'Failed to get services',
    });
  }
});

export default router;
EOF

print_status "API routes created"

# Create remaining required files
print_info "Creating remaining backend files..."

# Config
mkdir -p src/config
cat > src/config/environment.ts << 'EOF'
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
EOF

# Database connection
cat > src/database/index.ts << 'EOF'
import { Pool, QueryResult } from 'pg';

class Database {
  private pool: Pool;
  private isConnected = false;

  constructor() {
    this.pool = new Pool({
      connectionString: process.env.DATABASE_URL || 'postgresql://happyrepair:dev_password_2024@localhost:5432/happyrepair_dev',
      ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
    });

    this.pool.on('error', (err) => {
      console.error('Unexpected error on idle client:', err);
    });
  }

  async connect(): Promise<void> {
    try {
      const client = await this.pool.connect();
      await client.query('SELECT NOW()');
      client.release();
      this.isConnected = true;
      console.log('Database connection pool initialized');
    } catch (error) {
      console.error('Failed to connect to database:', error);
      throw error;
    }
  }

  async disconnect(): Promise<void> {
    try {
      await this.pool.end();
      this.isConnected = false;
      console.log('Database connection pool closed');
    } catch (error) {
      console.error('Error closing database connection:', error);
      throw error;
    }
  }

  async query(text: string, params?: any[]): Promise<QueryResult> {
    try {
      const result = await this.pool.query(text, params);
      return result;
    } catch (error) {
      console.error('Database query error:', {
        query: text,
        params,
        error: error instanceof Error ? error.message : error,
      });
      throw error;
    }
  }

  get connected(): boolean {
    return this.isConnected;
  }
}

export const database = new Database();
EOF

# Utils
mkdir -p src/utils
cat > src/utils/logger.ts << 'EOF'
export const logger = {
  info: (message: string, meta?: any) => {
    console.log(`[INFO] ${new Date().toISOString()} - ${message}`, meta ? JSON.stringify(meta) : '');
  },
  error: (message: string, error?: any) => {
    console.error(`[ERROR] ${new Date().toISOString()} - ${message}`, error);
  },
  warn: (message: string, meta?: any) => {
    console.warn(`[WARN] ${new Date().toISOString()} - ${message}`, meta ? JSON.stringify(meta) : '');
  },
  debug: (message: string, meta?: any) => {
    if (process.env.NODE_ENV === 'development') {
      console.log(`[DEBUG] ${new Date().toISOString()} - ${message}`, meta ? JSON.stringify(meta) : '');
    }
  },
};
EOF

# Middleware
mkdir -p src/middleware
cat > src/middleware/errorHandler.ts << 'EOF'
import { Request, Response, NextFunction } from 'express';

export interface AppError extends Error {
  statusCode?: number;
  isOperational?: boolean;
}

export const errorHandler = (
  err: AppError,
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  const statusCode = err.statusCode || 500;

  console.error('API Error:', {
    message: err.message,
    statusCode,
    stack: err.stack,
    url: req.url,
    method: req.method,
  });

  const errorResponse = {
    status: 'error',
    message: err.message || 'Internal server error',
    timestamp: new Date().toISOString(),
    path: req.path,
    ...(process.env.NODE_ENV === 'development' && {
      stack: err.stack,
    }),
  };

  res.status(statusCode).json(errorResponse);
};
EOF

cat > src/middleware/notFoundHandler.ts << 'EOF'
import { Request, Response } from 'express';

export const notFoundHandler = (req: Request, res: Response): void => {
  res.status(404).json({
    status: 'error',
    message: `Route ${req.method} ${req.path} not found`,
    timestamp: new Date().toISOString(),
    availableEndpoints: {
      health: 'GET /health',
      api: 'GET /api',
      auth: 'POST /api/auth/*',
      mechanics: 'GET /api/mechanics/*',
      services: 'GET /api/services',
    },
  });
};
EOF

print_status "Backend source files created"

# 3. Build the TypeScript code
print_info "Building TypeScript code..."
npm run build

print_status "TypeScript compilation successful"

# 4. Test the setup
print_info "Testing the API server..."

# Start the server in background for testing
npm run dev &
SERVER_PID=$!

# Wait a moment for server to start
sleep 3

# Test health endpoint
if curl -s http://localhost:3000/health > /dev/null; then
    print_status "API server is running and responding"
else
    print_warning "API server may not be responding properly"
fi

# Stop the test server
kill $SERVER_PID 2>/dev/null || true

# Go back to project root
cd ..

echo ""
echo "🎉 Backend API setup complete!"
echo "================================"
echo ""
echo "🚀 To start the development server:"
echo "   cd backend"
echo "   npm run dev"
echo ""
echo "📊 API endpoints will be available at:"
echo "   http://localhost:3000/health      - Health check"
echo "   http://localhost:3000/api         - API documentation"
echo "   http://localhost:3000/api/services - Get services (with Spanish)"
echo "   http://localhost:3000/api/mechanics/nearby?latitude=34.0522&longitude=-118.2437 - Find LA mechanics"
echo ""
echo "🧪 Test the APIs:"
echo "   curl http://localhost:3000/health"
echo "   curl \"http://localhost:3000/api/services?language=es\""
echo "   curl \"http://localhost:3000/api/mechanics/nearby?latitude=34.0522&longitude=-118.2437&radius=10\""
echo ""
print_status "Ready to develop! 🔥"