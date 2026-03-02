'use strict';

const { createLogger, format, transports } = require('winston');

const { combine, timestamp, errors, json, colorize, simple } = format;

const isProduction = process.env.APP_ENV === 'production';

const logger = createLogger({
  level: process.env.LOG_LEVEL || (isProduction ? 'info' : 'debug'),
  defaultMeta: {
    service: 'devops-takehome',
    version: process.env.APP_VERSION || '1.0.0',
    environment: process.env.APP_ENV || 'local',
  },
  format: combine(
    timestamp({ format: 'YYYY-MM-DDTHH:mm:ss.SSSZ' }),
    errors({ stack: true }),
    json()
  ),
  transports: [
    new transports.Console({
      format: isProduction
        ? combine(timestamp(), json())
        : combine(colorize(), simple()),
    }),
  ],
  exitOnError: false,
});

// Add http level
logger.http = (message) => logger.log('http', message);

module.exports = logger;
