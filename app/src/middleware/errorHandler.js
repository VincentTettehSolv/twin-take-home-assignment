'use strict';

const logger = require('../logger');

/**
 * Centralized Express error handler.
 * Logs the error with structured context and returns a sanitized JSON response.
 * In production, stack traces are never leaked to the client.
 */
const errorHandler = (err, req, res, _next) => {
  const status = err.status || err.statusCode || 500;
  const isProduction = process.env.APP_ENV === 'production';

  logger.error('Unhandled request error', {
    requestId: req.requestId,
    method: req.method,
    path: req.path,
    status,
    message: err.message,
    stack: err.stack,
  });

  const body = {
    error: isProduction && status >= 500 ? 'Internal Server Error' : err.message,
    requestId: req.requestId,
  };

  if (!isProduction) {
    body.stack = err.stack;
  }

  res.status(status).json(body);
};

module.exports = { errorHandler };
