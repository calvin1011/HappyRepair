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
