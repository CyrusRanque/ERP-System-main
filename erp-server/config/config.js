require('dotenv').config();
const mysql = require('mysql2/promise');
const allConfigs = require('./config.json');

const env = process.env.NODE_ENV || 'development';
const envConfig = allConfigs[env] || allConfigs.development;

const config = {
  env,
  port: process.env.PORT || 8000,
  db: {
    host: process.env.DB_HOST || envConfig.host || '127.0.0.1',
    port: parseInt(process.env.DB_PORT || envConfig.port || '3306', 10),
    user: process.env.DB_USER || envConfig.username || 'root',
    password: process.env.DB_PASSWORD ?? envConfig.password ?? '',
    database: process.env.DB_NAME || envConfig.database || 'rts_system',
    timezone: envConfig.timezone || '+08:00',
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0,
  },
};

// Create the MySQL connection pool
const pool = mysql.createPool(config.db);

module.exports = pool;
module.exports.config = config;