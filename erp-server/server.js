const express = require('express');
const cors = require('cors');
const os = require('os');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 8000;

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Matches Flutter's ApiSettings.builtinDefault (http://<host>:8000/api/mobile/...)
app.use('/api/mobile', require('./routes'));

const db = require('./config/db');
const { assertDatabaseSchema } = require('./config/schema');
const { startDiscoveryServer } = require('./discovery');

async function start() {
  await assertDatabaseSchema(db);
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`Node.js ERP server running at http://0.0.0.0:${PORT}/api/mobile`);
    const lan = pickLanIPv4();
    if (lan) {
      console.log(`Phone health check: http://${lan}:${PORT}/api/mobile/health`);
      console.log('In the app: Login → Server → enter that IP:8000 → Test → Save & connect');
    }
    if (typeof startDiscoveryServer === 'function') {
      startDiscoveryServer(PORT);
    }
  });
}

function pickLanIPv4() {
  const nets = os.networkInterfaces();
  for (const name of Object.keys(nets)) {
    for (const net of nets[name] || []) {
      if ((net.family === 'IPv4' || net.family === 4) && !net.internal) {
        return net.address;
      }
    }
  }
  return null;
}

start().catch((err) => {
  console.error('Failed to start server:', err.message);
  process.exit(1);
});