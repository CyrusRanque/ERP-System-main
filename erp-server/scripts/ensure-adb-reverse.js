/**
 * When a phone is connected over USB, forward localhost:8000 to this PC.
 * Silent no-op if adb or device is missing.
 */
const { execFile } = require('child_process');
const path = require('path');

const adbCandidates = [
  process.env.ADB,
  path.join(process.env.LOCALAPPDATA || '', 'Android', 'Sdk', 'platform-tools', 'adb.exe'),
  'adb',
].filter(Boolean);

function runAdb(adb, args) {
  return new Promise((resolve) => {
    execFile(adb, args, { windowsHide: true, timeout: 8000 }, (err, stdout) => {
      resolve({ err, out: (stdout || '').trim() });
    });
  });
}

async function main() {
  for (const adb of adbCandidates) {
    const devices = await runAdb(adb, ['devices']);
    if (devices.err) continue;
    if (!devices.out.includes('\tdevice')) continue;
    const rev = await runAdb(adb, ['reverse', 'tcp:8000', 'tcp:8000']);
    if (!rev.err) {
      console.log('USB: phone can use http://127.0.0.1:8000/api/mobile (adb reverse active)');
      return;
    }
  }
}

main().catch(() => {});
