cat > index.js << 'EOF'
import makeWASocket, { useMultiFileAuthState } from '@whiskeysockets/baileys';
import { exec } from 'child_process';
import fs from 'fs';
const { state, saveCreds } = await useMultiFileAuthState('auth');
const sock = makeWASocket({ auth: state, printQRInTerminal: false, browser: ['Chrome', 'Chrome', '120.0.0.0'] });
sock.ev.on('creds.update', saveCreds);
sock.ev.on('connection.update', (u) => { if (u.connection === 'open') console.log('✅ البوت متصل!'); });
sock.ev.on('messages.upsert', async ({ messages }) => {
  const msg = messages[0];
  if (!msg.message || msg.key.fromMe) return;
  let m = msg.message;
  if (m.ephemeralMessage) m = m.ephemeralMessage.message;
  if (m.viewOnceMessage) m = m.viewOnceMessage.message;
  if (m.viewOnceMessageV2) m = m.viewOnceMessageV2.message;
  const text = m.conversation || m.extendedTextMessage?.text || '';
  const from = msg.key.remoteJid;
  const isGroup = from.endsWith('@g.us');

  // بحث يوتيوب بالاسم
  if (text.startsWith('!بحث ')) {
    const q = text.replace('!بحث ', '');
    await sock.sendMessage(from, { text: `🔍 جاري البحث عن: ${q} ...` });
    exec(`yt-dlp -x --audio-format mp3 -o "song.%(ext)s" "ytsearch1:${q}"`, async (err) => {
      if (err) { await sock.sendMessage(from, { text: '❌ ما لقيت شي' }); return; }
      await sock.sendMessage(from, { audio: fs.readFileSync('song.mp3'), mimetype: 'audio/mpeg' });
      fs.unlinkSync('song.mp3');
    });
    return;
  }

  // بحث قوقل
  if (text.startsWith('!جوجل ')) {
    const q = text.replace('!جوجل ', '');
    await sock.sendMessage(from, { text: '🔍 جاري البحث في قوقل...' });
    try {
      const res = await fetch(`https://api.duckduckgo.com/?q=${encodeURIComponent(q)}&format=json&no_html=1&skip_disambig=1`);
      const data = await res.json();
      const ans = data.AbstractText || data.RelatedTopics?.[0]?.Text || 'ما لقيت جواب واضح، جرب كلمة ثانية';
      await sock.sendMessage(from, { text: `🔍 نتيجة البحث عن: ${q}\n\n${ans}` });
    } catch { await sock.sendMessage(from, { text: '❌ البحث تعطل، جرب بعد شوي' }); }
    return;
  }

  if (text.includes('youtube.com') || text.includes('youtu.be')) {
    const url = text.match(/https?:\/\/\S+/)[0];
    await sock.sendMessage(from, { text: '⏳ جاري التحميل...' });
    exec(`yt-dlp -x --audio-format mp3 -o "song.%(ext)s" "${url}"`, async (err) => {
      if (err) { await sock.sendMessage(from, { text: '❌ ما قدرت احمله' }); return; }
      await sock.sendMessage(from, { audio: fs.readFileSync('song.mp3'), mimetype: 'audio/mpeg' });
      fs.unlinkSync('song.mp3');
    });
    return;
  }
});
EOF

node index.js
npm install @whiskeysockets/baileys@latest
echo '{"type":"module"}' > package.json
cat > index.js << 'EOF'
import makeWASocket, { useMultiFileAuthState, DisconnectReason } from '@whiskeysockets/baileys';
import { Boom } from '@hapi/boom';
import { exec } from 'child_process';
import fs from 'fs';

async function startBot() {
  const { state, saveCreds } = await useMultiFileAuthState('auth');
  const sock = makeWASocket({ auth: state, printQRInTerminal: false, browser: ['Chrome', 'Chrome', '120.0.0.0'] });
  sock.ev.on('creds.update', saveCreds);
  sock.ev.on('connection.update', (u) => {
    if (u.connection === 'open') console.log('✅ البوت متصل!');
    if (u.connection === 'close') {
      const shouldReconnect = (u.lastDisconnect?.error instanceof Boom)?.output?.statusCode !== DisconnectReason.loggedOut;
      console.log('فصل، بحاول ارجع اشبك...');
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
      const from = msg.key.remoteJid;
      if (text.startsWith('!بحث ')) {
        const q = text.replace('!بحث ', '');
        await sock.sendMessage(from, { text: `🔍 جاري البحث عن: ${q} ...` });
        exec(`yt-dlp -x --audio-format mp3 -o "song.%(ext)s" "ytsearch1:${q}"`, async (err) => {
          if (err) { await sock.sendMessage(from, { text: '❌ ما لقيت شي' }); return; }
          await sock.sendMessage(from, { audio: fs.readFileSync('song.mp3'), mimetype: 'audio/mpeg' });
          fs.unlinkSync('song.mp3');
        });
        return;
      }
      if (text.startsWith('!جوجل ')) {
        const q = text.replace('!جوجل ', '');
        await sock.sendMessage(from, { text: '🔍 جاري البحث...' });
        try {
          const res = await fetch(`https://api.duckduckgo.com/?q=${encodeURIComponent(q)}&format=json&no_html=1&skip_disambig=1`);
          const data = await res.json();
          const ans = data.AbstractText || data.RelatedTopics?.[0]?.Text || 'ما لقيت جواب واضح';
          await sock.sendMessage(from, { text: `🔍 ${q}\n\n${ans}` });
        } catch { await sock.sendMessage(from, { text: '❌ البحث تعطل' }); }
        return;
      }
      if (text.includes('youtube.com') || text.includes('youtu.be')) {
        const url = text.match(/https?:\/\/\S+/)[0];
        await sock.sendMessage(from, { text: '⏳ جاري التحميل...' });
        exec(`yt-dlp -x --audio-format mp3 -o "song.%(ext)s" "${url}"`, async (err) => {
          if (err) { await sock.sendMessage(from, { text: '❌ ما قدرت احمله' }); return; }
          await sock.sendMessage(from, { audio: fs.readFileSync('song.mp3'), mimetype: 'audio/mpeg' });
          fs.unlinkSync('song.mp3');
        });
      }
    } catch(e) { console.log('تجاهلت رسالة مشفرة'); }
  });
}
startBot();
EOF

node index.js
cat > index.js << 'EOF'
import makeWASocket, { useMultiFileAuthState, DisconnectReason } from '@whiskeysockets/baileys';
import { Boom } from '@hapi/boom';
import { exec } from 'child_process';
import fs from 'fs';

async function startBot() {
  const { state, saveCreds } = await useMultiFileAuthState('auth');
  const sock = makeWASocket({ auth: state, printQRInTerminal: false, browser: ['Chrome', 'Chrome', '120.0.0.0'] });
  sock.ev.on('creds.update', saveCreds);
  sock.ev.on('connection.update', (u) => {
    if (u.connection === 'open') console.log('✅ البوت متصل!');
    if (u.connection === 'close') {
      const shouldReconnect = (u.lastDisconnect?.error instanceof Boom)?.output?.statusCode !== DisconnectReason.loggedOut;
      console.log('فصل، بحاول ارجع...');
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
      console.log('وصلتني رسالة:', text);
      const from = msg.key.remoteJid;
      const fileName = `song_${Date.now()}`;

      if (text.startsWith('!بحث ')) {
        const q = text.replace(' بحث ', '');
        await sock.sendMessage(from, { text: `🔍 جاري البحث عن: ${q} ...` });
        exec(`yt-dlp -x --audio-format mp3 -o "${fileName}.%(ext)s" "ytsearch1:${q}"`, async (err) => {
          if (err) { console.log('خطأ تحميل:', err.message); await sock.sendMessage(from, { text: '❌ ما لقيت شي، جرب اسم ثاني' }); return; }
          try {
            await sock.sendMessage(from, { audio: fs.readFileSync(`${fileName}.mp3`), mimetype: 'audio/mpeg' });
            console.log('تم الارسال ✅');
          } catch(e) { await sock.sendMessage(from, { text: '❌ الملف كبير مرة، جرب زوامل ثانية' }); }
          try { fs.unlinkSync(`${fileName}.mp3`); } catch {}
        });
        return;
      }
      if (text.includes('youtube.com') || text.includes('youtu.be')) {
        const url = text.match(/https?:\/\/\S+/)[0];
        await sock.sendMessage(from, { text: '⏳ جاري التحميل...' });
        exec(`yt-dlp -x --audio-format mp3 -o "${fileName}.%(ext)s" "${url}"`, async (err) => {
          if (err) { await sock.sendMessage(from, { text: '❌ ما قدرت احمله' }); return; }
          await sock.sendMessage(from, { audio: fs.readFileSync(`${fileName}.mp3`), mimetype: 'audio/mpeg' });
          try { fs.unlinkSync(`${fileName}.mp3`); } catch {}
        });
        return;
      }
      if (text.startsWith('!جوجل ')) {
        const q = text.replace('!جوجل ', '');
        try {
          const res = await fetch(`https://api.duckduckgo.com/?q=${encodeURIComponent(q)}&format=json&no_html=1&skip_disambig=1`);
          const data = await res.json();
          const ans = data.AbstractText || data.RelatedTopics?.[0]?.Text || 'ما لقيت جواب';
          await sock.sendMessage(from, { text: `🔍 ${q}\n\n${ans}` });
        } catch { await sock.sendMessage(from, { text: '❌ البحث تعطل' }); }
      }
    } catch(e) { console.log('تجاهلت رسالة:', e.message); }
  });
}
startBot();
EOF

node index.js
pip install -U yt-dlp
cat > index.js << 'EOF'
import makeWASocket, { useMultiFileAuthState, DisconnectReason } from '@whiskeysockets/baileys';
import { Boom } from '@hapi/boom';
import { exec } from 'child_process';
import fs from 'fs';

async function startBot() {
  const { state, saveCreds } = await useMultiFileAuthState('auth');
  const sock = makeWASocket({ auth: state, printQRInTerminal: false, browser: ['Chrome', 'Chrome', '120.0.0.0'] });
  sock.ev.on('creds.update', saveCreds);
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
        console.log('ابحث عن:', q);
        // الطريقة الجديدة: نبحث اولاً ونجيب الرابط، بعدين نحمله
        exec(`yt-dlp --no-playlist --default-search ytsearch1 --get-id "${q}"`, async (err, stdout) => {
          if (err || !stdout) { console.log('خطأ بحث:', err?.message, stdout); await sock.sendMessage(from, { text: '❌ ما لقيت شي، جرب تكتب الاسم بالانجليزي' }); return; }
          const videoId = stdout.trim().split('\n')[0];
          const url = `https://youtu.be/${videoId}`;
          console.log('لقيت:', url);
          await sock.sendMessage(from, { text: '✅ لقيتها، جاري التحميل...' });
          exec(`yt-dlp -x --audio-format mp3 -o "${fileName}.%(ext)s" --no-playlist "${url}"`, async (err2) => {
            if (err2) { console.log('خطأ تحميل:', err2.message); await sock.sendMessage(from, { text: '❌ ما قدرت احملها' }); return; }
            try {
              await sock.sendMessage(from, { audio: fs.readFileSync(`${fileName}.mp3`), mimetype: 'audio/mpeg' });
              console.log('تم الارسال ✅');
            } catch(e) { await sock.sendMessage(from, { text: '❌ الملف كبير' }); }
            try { fs.unlinkSync(`${fileName}.mp3`); } catch {}
          });
        });
        return;
      }

      if (text.includes('youtube.com') || text.includes('youtu.be')) {
        const url = text.match(/https?:\/\/\S+/)[0];
        await sock.sendMessage(from, { text: '⏳ جاري التحميل...' });
        exec(`yt-dlp -x --audio-format mp3 -o "${fileName}.%(ext)s" --no-playlist "${url}"`, async (err) => {
          if (err) { await sock.sendMessage(from, { text: '❌ ما قدرت احمله' }); return; }
          await sock.sendMessage(from, { audio: fs.readFileSync(`${fileName}.mp3`), mimetype: 'audio/mpeg' });
          try { fs.unlinkSync(`${fileName}.mp3`); } catch {}
        });
        return;
      }

      if (text.startsWith('!جوجل ')) {
        const q = text.replace('!جوجل ', '');
        try {
          const res = await fetch(`https://api.duckduckgo.com/?q=${encodeURIComponent(q)}&format=json&no_html=1&skip_disambig=1`);
          const data = await res.json();
          const ans = data.AbstractText || data.RelatedTopics?.[0]?.Text || 'ما لقيت جواب';
          await sock.sendMessage(from, { text: `🔍 ${q}\n\n${ans}` });
        } catch { await sock.sendMessage(from, { text: '❌ البحث تعطل' }); }
      }
    } catch(e) { console.log('تجاهلت رسالة:', e.message); }
  });
}
startBot();
EOF

node index.js
curl -s "https://inv.nadeko.net/api/v1/search?q=عيسى%20الليث&type=video" | head -c 500
node index.js
