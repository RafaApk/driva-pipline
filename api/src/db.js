require('dotenv').config();
const { Pool } = require('pg');
const { v4: uuidv4 } = require('uuid');

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  user: process.env.DB_USER || 'driva_user',
  password: process.env.DB_PASSWORD || 'driva_password_secure',
  database: process.env.DB_NAME || 'driva_warehouse',
});

pool.on('error', (err) => {
  console.error('Erro na pool de conexões:', err);
});

async function getConnection() {
  return pool.connect();
}

async function query(text, params = []) {
  const start = Date.now();
  try {
    const result = await pool.query(text, params);
    const duration = Date.now() - start;
    return { result, duration };
  } catch (error) {
    console.error('Erro na query:', text, error);
    throw error;
  }
}

async function closePool() {
  await pool.end();
}

module.exports = {
  pool,
  query,
  getConnection,
  closePool,
};
