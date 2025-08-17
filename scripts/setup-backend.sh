# ============================================================================
# Safe HappyRepair Backend Setup - No Auto-Restart
# Manual build and run approach to prevent crashes
# ============================================================================


# Safe package.json without nodemon
cat > package.json << 'EOF'
{
  "name": "@happyrepair/backend",
  "version": "1.0.0",
  "description": "HappyRepair Backend API",
  "main": "dist/server.js",
  "scripts": {
    "build": "tsc",
    "start": "node dist/server.js",
    "dev:build": "tsc && node dist/server.js",
    "clean": "rimraf dist"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "helmet": "^7.0.0",
    "morgan": "^1.10.0",
    "dotenv": "^16.3.1",
    "pg": "^8.11.3",
    "compression": "^1.7.4"
  },
  "devDependencies": {
    "@types/express": "^4.17.17",
    "@types/cors": "^2.8.13",
    "@types/morgan": "^1.9.4",
    "@types/node": "^20.5.0",
    "@types/pg": "^8.10.2",
    "@types/compression": "^1.7.2",
    "typescript": "^5.1.6",
    "rimraf": "^5.0.1"
  }
}
EOF

# Simple tsconfig.json
cat > tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": false,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
EOF

echo "📦 Installing dependencies safely..."
npm install

echo "📁 Creating source structure..."
mkdir -p src

# Create a simple, safe server file
cat > src/server.ts << 'EOF'
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import { Pool } from 'pg';
import * as dotenv from 'dotenv';

// Load environment variables
dotenv.config({ path: '../.env' });

const app = express();
const port = process.env.API_PORT || 3000;

// Database connection
const database = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://happyrepair:dev_password_2024@localhost:5432/happyrepair_dev',
});

// Basic middleware
app.use(helmet());
app.use(cors());
app.use(morgan('combined'));
app.use(express.json({ limit: '1mb' }));

// Health check endpoint
app.get('/health', async (req, res) => {
  try {
    const result = await database.query('SELECT NOW() as timestamp, 1 as status');
    res.json({
      status: 'healthy',
      database: 'connected',
      timestamp: result.rows[0].timestamp,
      uptime: process.uptime()
    });
  } catch (error) {
    console.error('Database error:', error);
    res.status(503).json({
      status: 'unhealthy',
      database: 'disconnected',
      error: 'Database connection failed'
    });
  }
});

// API documentation endpoint
app.get('/api', (req, res) => {
  res.json({
    name: 'HappyRepair API',
    version: '1.0.0',
    description: 'Stop wasting time scrolling Google. Find mechanics with transparent pricing.',
    endpoints: {
      health: 'GET /health - Check API and database status',
      services: 'GET /api/services?language=en|es - Get all services',
      mechanics: 'GET /api/mechanics/nearby?lat=X&lng=Y&radius=10 - Find nearby mechanics'
    },
    database: 'PostgreSQL with PostGIS',
    languages: ['English', 'Spanish']
  });
});

// Get all services with translation support
app.get('/api/services', async (req, res) => {
  try {
    const language = req.query.language || 'en';

    const query = `
      SELECT
        s.id,
        s.category,
        s.estimated_duration,
        COALESCE(st.name, s.name) as name,
        COALESCE(st.description, s.description) as description
      FROM services s
      LEFT JOIN service_translations st ON s.id = st.service_id
        AND st.language_code = $1
      WHERE s.is_active = true
      ORDER BY s.category, s.name
    `;

    const result = await database.query(query, [language]);

    res.json({
      status: 'success',
      data: {
        services: result.rows,
        language: language,
        count: result.rows.length
      }
    });

  } catch (error) {
    console.error('Services error:', error);
    res.status(500).json({
      status: 'error',
      message: 'Failed to fetch services',
      error: error instanceof Error ? error.message : 'Unknown error'
    });
  }
});

// Find nearby mechanics using PostGIS
app.get('/api/mechanics/nearby', async (req, res) => {
  try {
    const { latitude, longitude, radius = 10 } = req.query;

    // Validate required parameters
    if (!latitude || !longitude) {
      return res.status(400).json({
        status: 'error',
        message: 'latitude and longitude parameters are required',
        example: '/api/mechanics/nearby?latitude=34.0522&longitude=-118.2437&radius=10'
      });
    }

    const lat = parseFloat(latitude as string);
    const lng = parseFloat(longitude as string);
    const radiusMiles = parseInt(radius as string, 10);

    // Validate parameter ranges
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      return res.status(400).json({
        status: 'error',
        message: 'Invalid coordinates. Latitude: -90 to 90, Longitude: -180 to 180'
      });
    }

    // Use our custom PostGIS function
    const query = `SELECT * FROM find_mechanics_within_radius($1, $2, $3)`;
    const result = await database.query(query, [lat, lng, radiusMiles]);

    res.json({
      status: 'success',
      data: {
        mechanics: result.rows,
        searchCriteria: {
          latitude: lat,
          longitude: lng,
          radius: radiusMiles,
          unit: 'miles'
        },
        count: result.rows.length
      }
    });

  } catch (error) {
    console.error('Nearby mechanics error:', error);
    res.status(500).json({
      status: 'error',
      message: 'Failed to find nearby mechanics',
      error: error instanceof Error ? error.message : 'Unknown error'
    });
  }
});

// Test database function endpoint
app.get('/api/test/database', async (req, res) => {
  try {
    // Test basic query
    const basicTest = await database.query('SELECT COUNT(*) as service_count FROM services');

    // Test PostGIS function exists
    const functionTest = await database.query(`
      SELECT EXISTS (
        SELECT 1 FROM pg_proc WHERE proname = 'find_mechanics_within_radius'
      ) as function_exists
    `);

    res.json({
      status: 'success',
      tests: {
        basic_query: 'passed',
        service_count: basicTest.rows[0].service_count,
        postgis_function: functionTest.rows[0].function_exists ? 'available' : 'missing',
        database_connection: 'working'
      }
    });

  } catch (error) {
    console.error('Database test error:', error);
    res.status(500).json({
      status: 'error',
      message: 'Database test failed',
      error: error instanceof Error ? error.message : 'Unknown error'
    });
  }
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    status: 'error',
    message: `Route ${req.method} ${req.path} not found`,
    availableRoutes: [
      'GET /health',
      'GET /api',
      'GET /api/services',
      'GET /api/mechanics/nearby',
      'GET /api/test/database'
    ]
  });
});

// Error handler
app.use((err: any, req: express.Request, res: express.Response, next: express.NextFunction) => {
  console.error('Unhandled error:', err);
  res.status(500).json({
    status: 'error',
    message: 'Internal server error',
    timestamp: new Date().toISOString()
  });
});

// Start server
app.listen(port, () => {
  console.log(`🚀 HappyRepair API Server Started`);
  console.log(`📊 Health Check: http://localhost:${port}/health`);
  console.log(`📚 API Info: http://localhost:${port}/api`);
  console.log(`🔧 Services: http://localhost:${port}/api/services?language=es`);
  console.log(`📍 Mechanics: http://localhost:${port}/api/mechanics/nearby?latitude=34.0522&longitude=-118.2437`);
  console.log(`🧪 Database Test: http://localhost:${port}/api/test/database`);
  console.log(`⚡ Server running on port ${port}`);
});

// Graceful shutdown
process.on('SIGINT', async () => {
  console.log('\n🛑 Shutting down server gracefully...');
  await database.end();
  process.exit(0);
});
EOF

echo "✅ Safe backend setup complete!"
echo ""
echo "🔨 Manual build and run process:"
echo "1. npm run build        # Compile TypeScript"
echo "2. npm start           # Run the server once"
echo "3. Ctrl+C to stop      # Clean shutdown"
echo ""
echo "🧪 Quick test:"
echo "npm run dev:build      # Build and run in one command"