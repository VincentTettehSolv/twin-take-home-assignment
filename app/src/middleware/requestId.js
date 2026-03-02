'use strict';

const { v4: uuidv4 } = require('uuid');

/**
 * Attaches a unique request ID to every incoming request.
 * Uses X-Request-ID header if provided, otherwise generates a new UUID.
 * The ID is echoed back in the response headers for distributed tracing.
 */
const requestId = (req, res, next) => {
  const id = req.headers['x-request-id'] || uuidv4();
  req.requestId = id;
  res.setHeader('X-Request-ID', id);
  next();
};

module.exports = { requestId };
