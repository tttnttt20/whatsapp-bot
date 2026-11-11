import makeWASocket, { useMultiFileAuthState, DisconnectReason, fetchLatestBaileysVersion } from '@whiskeysockets/baileys';
import { Boom } from '@hapi/boom';
import { exec, execSync } from 'child_process';
import fs from 'fs';

async function startBot() {
  const { state, saveCreds } = await useMultiFileAuthState('auth');
  const { version } = await fetchLatestBaileysVersion();
  const sock = makeWASocket({ auth: state, version, printQRInTerminal: false, browser: ['Chrome','Chrome','120.0.0.0'] });
  sock.ev.on('creds.update', saveCreds);
  if (!state.creds.registered) {
    const phone = process.env.PHONE_NUMBER;
    if (phone) { setTimeout(async () => { try { const code = await sock.requestPairingCode(phone); console.log('🔑 كود الربط حقك:', code); } catch(e) { console.log('خطأ كود الربط:', e.message); } }, 3000); }
  }
  sock.ev.on('connection.update', (u) => {
    if (u.connection === 'open') console.log('✅ البوت متصل!');
    if (u.connection === 'close') { const shouldReconnect = (u.lastDisconnect?.error instanceof Boom)?.output?.statusCode !== DisconnectReason.loggedOut; if (shouldReconnect) startBot(); }
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
      const from = msg.key.remoteJid;
      const fileName = `song_${Date.now()}`;
      if (text.startsWith('!بحث ')) {
        const q = text.replace('!بحث ', '').trim();
        await sock.sendMessage(from, { text: `🔍 جاري البحث عن: ${q} ...` });
        try {
          const safeQ = q.replace(/"/g, '');
          const out = execSync(`yt-dlp --get-id --get-title "ytsearch1:${safeQ}"`, { timeout: 30000 }).toString().trim().split('\n');
          const title = out[0];
          const videoId = out[1] || out[0];
          const url = `https://youtu.be/${videoId}`;
          await sock.sendMessage(from, { text: `✅ لقيت: ${title}\nجاري التحميل...` });
          exec(`yt-dlp -x --audio-format mp3 -o "${fileName}.%(ext)s" --no-playlist --extractor-args "youtube:player_client=android" "${url}"`, async (err2) => {
            if (err2) { await sock.sendMessage(from, { text: '❌ ما قدرت احملها' }); return; }
            try { await sock.sendMessage(from, { audio: fs.readFileSync(`${fileName}.mp3`), mimetype: 'audio/mpeg' }); } catch(e) { await sock.sendMessage(from, { text: '❌ الملف كبير' }); }
            try { fs.unlinkSync(`${fileName}.mp3`); } catch {}
          });
        } catch(e) { console.log('خطأ بحث:', e.message); await sock.sendMessage(from, { text: '❌ البحث تعطل' }); }
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
        return;
      }
      await sock.sendMessage(from, { text: `🤖 أنا بوت تمت برمجتي بواسطة المطور عبدالله الازهوري\n\nيمكنك عبر البوت تحميل أو البحث عن أي شي عبر اليوتيوب\n\n📱 رقم المطور للتواصل: 777442187\n\nاكتب:\n!بحث اسم الزامل\nأو ارسل رابط يوتيوب` });
    } catch(e) { console.log(e.message); }
  });
}
startBot();
