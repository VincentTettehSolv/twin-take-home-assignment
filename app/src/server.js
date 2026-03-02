'use strict';

const app = require('./app');
const logger = require('./logger');

const PORT = parseInt(process.env.APP_PORT || '3000', 10);
const HOST = process.env.APP_HOST || '0.0.0.0';

const server = app.listen(PORT, HOST, () => {
  logger.info('Server started', {
    host: HOST,
    port: PORT,
    environment: process.env.APP_ENV || 'local',
    version: process.env.APP_VERSION || '1.0.0',
    nodeVersion: process.version,
  });
});

// Graceful shutdown
const shutdown = (signal) => {
  logger.info(`Received ${signal}, shutting down gracefully...`);
  server.close((err) => {
    if (err) {
      logger.error('Error during shutdown', { error: err.message });
      process.exit(1);
    }
    logger.info('Server closed. Goodbye.');
    process.exit(0);
  });

  // Force shutdown after 10 seconds
  setTimeout(() => {
    logger.error('Forced shutdown after timeout');
    process.exit(1);
  }, 10000);
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled Promise Rejection', { reason, promise });
});

process.on('uncaughtException', (error) => {
  logger.error('Uncaught Exception', { error: error.message, stack: error.stack });
  process.exit(1);
});

module.exports = server;
