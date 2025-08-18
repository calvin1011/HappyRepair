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
