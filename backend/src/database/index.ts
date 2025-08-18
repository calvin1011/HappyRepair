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
