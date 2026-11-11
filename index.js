import makeWASocket, { useMultiFileAuthState, DisconnectReason, fetchLatestBaileysVersion } from '@whiskeysockets/baileys';
import { Boom } from '@hapi/boom';
import { exec } from 'child_process';
import fs from 'fs';

async function startBot() {
  const { state, saveCreds } = await useMultiFileAuthState('auth');
  const { version } = await fetchLatestBaileysVersion();
  const sock = makeWASocket({ auth: state, version, printQRInTerminal: false, browser: ['Chrome', 'Chrome', '120.0.0.0'] });
  sock.ev.on('creds.update', saveCreds);

  // اذا ما فيه جلسة، اطلب كود ربط
  if (!state.creds.registered) {
    const phone = process.env.PHONE_NUMBER;
    if (phone) {
      setTimeout(async () => {
        try {
          const code = await sock.requestPairingCode(phone);
          console.log('🔑 كود الربط حقك:', code);
          console.log('روح واتساب > الأجهزة المرتبطة > ربط جهاز > ربط برقم الهاتف واكتب الكود');
        } catch(e) { console.log('خطأ كود الربط:', e.message); }
      }, 3000);
    }
  }

  sock.ev.on('connection.update', (u) => {
    if (u.connection === 'open') console.log('✅ البوت متصل!');
    if (u.connection === 'close') {
      const shouldReconnect = (u.lastDisconnect?.error instanceof Boom)?.output?.statusCode !== DisconnectReason.loggedOut;
      if (shouldReconnect) startBot();
    }
  });
  sock.ev.on('messages.upsert', async ({ messages }) => {
    try {
      const msg = messages[0];
      if (!msg.message || msg.key.fromMe) return;
      let m = msg.message;
      if (m.ephemeralMessage) m = m.ephemeralMessage.message;
      if (m.viewOnceMessage) m = m.viewOnceMessage.message;
      if (m.viewOnceMessageV2) m = m.viewOnceMessageV2.message;
      const text = m.conversation || m.extendedTextMessage?.text || '';
      if (!text) return;
      console.log('وصلتني:', text);
      const from = msg.key.remoteJid;
      const fileName = `song_${Date.now()}`;
      if (text.startsWith('!بحث ')) {
        const q = text.replace('!بحث ', '').trim();
        await sock.sendMessage(from, { text: `🔍 جاري البحث عن: ${q} ...` });
        try {
          const res = await fetch(`https://inv.nadeko.net/api/v1/search?q=${encodeURIComponent(q)}&type=video`);
          const results = await res.json();
          if (!results || results.length === 0) { await sock.sendMessage(from, { text: '❌ ما لقيت شي' }); return; }
          const url = `https://youtu.be/${results[0].videoId}`;
          await sock.sendMessage(from, { text: `✅ لقيت: ${results[0].title}\nجاري التحميل...` });
          exec(`yt-dlp -x --audio-format mp3 -o "${fileName}.%(ext)s" --no-playlist --extractor-args "youtube:player_client=android" "${url}"`, async (err2) => {
            if (err2) { await sock.sendMessage(from, { text: '❌ ما قدرت احملها' }); return; }
            try { await sock.sendMessage(from, { audio: fs.readFileSync(`${fileName}.mp3`), mimetype: 'audio/mpeg' }); } catch(e) { await sock.sendMessage(from, { text: '❌ الملف كبير' }); }
            try { fs.unlinkSync(`${fileName}.mp3`); } catch {}
          });
        } catch(e) { await sock.sendMessage(from, { text: '❌ البحث تعطل' }); }
        return;
      }
      if (text.includes('youtube.com') || text.includes('youtu.be')) {
        const url = text.match(/https?:\/\/\S+/)[0];
        await sock.sendMessage(from, { text: '⏳ جاري التحميل...' });
        exec(`yt-dlp -x --audio-format mp3 -o "${fileName}.%(ext)s" --no-playlist --extractor-args "youtube:player_client=android" "${url}"`, async (err) => {
          if (err) { await sock.sendMessage(from, { text: '❌ ما قدرت احمله' }); return; }
          await sock.sendMessage(from, { audio: fs.readFileSync(`${fileName}.mp3`), mimetype: 'audio/mpeg' });
          try { fs.unlinkSync(`${fileName}.mp3`); } catch {}
        });
      }
    } catch(e) { console.log(e.message); }
  });
}
startBot();
