import makeWASocket, { useMultiFileAuthState, DisconnectReason } from '@whiskeysockets/baileys';
import qrcode from 'qrcode-terminal';

const { state, saveCreds } = await useMultiFileAuthState('auth');

const sock = makeWASocket({
  auth: state,
  printQRInTerminal: false
});

sock.ev.on('creds.update', saveCreds);

sock.ev.on('connection.update', (update) => {
  const { connection, lastDisconnect, qr } = update;
  if (qr) {
    console.log('\n📷 امسح هذا الباركود:\n');
    qrcode.generate(qr, { small: false });
  }
  if (connection === 'close') {
    console.log('انقطع، شغل من جديد: node index.js');
  } else if (connection === 'open') {
    console.log('✅ البوت متصل!');
  }
});
