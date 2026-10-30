#!/usr/bin/env node
/* Eddy's Zoho mailbox (contact@ / bible.standard@canonfidei.com), read and send.
   No dependencies. Secrets stay in the macOS Keychain; nothing is printed.

     zoho_mail.mjs folders
     zoho_mail.mjs list <folder name> [count=25]          newest first
     zoho_mail.mjs read <folder name> <messageId>...       plain text
     zoho_mail.mjs attachments <folder name> <messageId> <new-empty-dir>
     zoho_mail.mjs send <to> <subject> <body.txt>          from bible.standard@canonfidei.com;
                                                           blank line = new paragraph
     zoho_mail.mjs reply <folder> <messageId> <body.txt>   threaded reply to a message in the newest 200
                                                           (both append the Zoho "Bible Standard" signature)

   Keychain items (service names): cf-zoho-client-secret, cf-zoho-refresh-token
   (read-only), cf-zoho-send-token (ZohoMail.messages.CREATE). Same ids as
   biblestandard/site-testers/tools/mail/welcome.mjs. Before replying to a partner,
   read their thread and Sent first (canonfidei.md). */
import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync, mkdirSync, readdirSync } from 'node:fs';

const CLIENT_ID = '1000.K5NKFRIGK43T1I5ZF9MY7QJ1W2K3LU', ACC = '273261000000002002';
const FROM = 'Bible Standard <bible.standard@canonfidei.com>';
const kc = (n) => execFileSync('security', ['find-generic-password', '-s', n, '-w'], { encoding: 'utf8' }).trim();
const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const plain = (h) => h.replace(/<style[\s\S]*?<\/style>/gi, '').replace(/<br\s*\/?>/gi, '\n').replace(/<\/(p|div)>/gi, '\n').replace(/<[^>]+>/g, '')
  .replace(/&nbsp;/g, ' ').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, '&').replace(/\n{3,}/g, '\n\n');

async function token(send) {
  const q = new URLSearchParams({ refresh_token: kc(send ? 'cf-zoho-send-token' : 'cf-zoho-refresh-token'), client_id: CLIENT_ID, client_secret: kc('cf-zoho-client-secret'), grant_type: 'refresh_token' });
  const t = (await (await fetch(`https://accounts.zoho.eu/oauth/v2/token?${q}`, { method: 'POST' })).json()).access_token;
  if (!t) throw new Error('Zoho refused the token');
  return t;
}
const call = async (t, path, init = {}) => fetch(`https://mail.zoho.eu/api/accounts/${ACC}${path}`, { ...init, headers: { Authorization: `Zoho-oauthtoken ${t}`, 'Content-Type': 'application/json' } });
const data = async (t, path) => (await (await call(t, path)).json()).data;
const folderId = async (t, name) => {
  const f = (await data(t, '/folders')).find((x) => x.folderName.toLowerCase() === name.toLowerCase());
  if (!f) throw new Error(`No folder "${name}"`);
  return f.folderId;
};
// Eddy's saved Zoho signature "Bible Standard" (read token). Its logo lives behind his login, so the
// relative <img> is dropped; a hosted copy goes in LOGO_URL once one exists.
const LOGO_URL = '';
const signature = async () => {
  const r = await (await fetch('https://mail.zoho.eu/api/accounts/signature', { headers: { Authorization: `Zoho-oauthtoken ${await token()}` } })).json();
  const html = (r.data || []).find((x) => x.name === 'Bible Standard')?.content;
  if (!html) throw new Error('No Zoho signature named "Bible Standard"');
  return html.replace(/<img[^>]*><\/img>/gi, LOGO_URL ? `<img src="${LOGO_URL}" width="400" height="121" alt="Canon Fidei Software Studio">` : '').replace(/<div style="width:400px; height:121px">/, '<div>');
};

const [cmd, ...a] = process.argv.slice(2);
if (cmd === 'folders') {
  for (const f of await data(await token(), '/folders')) console.log(f.folderName);
} else if (cmd === 'list') {
  const t = await token(), f = await folderId(t, a[0]);
  for (const m of (await data(t, `/messages/view?folderId=${f}&start=1&limit=${a[1] || 25}&sortBy=date&sortorder=false`)) || [])
    console.log([new Date(+m.receivedTime).toISOString().slice(0, 16), m.messageId, m.status === '0' ? 'UNREAD' : 'read', m.hasAttachment === '1' ? 'ATT' : '-', m.fromAddress, '|', plain(m.subject || '')].join(' '));
} else if (cmd === 'read') {
  const t = await token(), f = await folderId(t, a[0]);
  for (const id of a.slice(1)) console.log(`\n######## ${id}\n${plain((await data(t, `/folders/${f}/messages/${id}/content`)).content || '')}`);
} else if (cmd === 'attachments') {
  const t = await token(), f = await folderId(t, a[0]), dir = a[2];
  if (readdirSync(dir, { throwIfNoEntry: false })?.length) throw new Error(`${dir} is not empty`);
  mkdirSync(dir, { recursive: true });
  for (const at of (await data(t, `/folders/${f}/messages/${a[1]}/attachmentinfo`)).attachments || []) {
    const buf = Buffer.from(await (await call(t, `/folders/${f}/messages/${a[1]}/attachments/${at.attachmentId}`)).arrayBuffer());
    writeFileSync(`${dir}/${at.attachmentName.replace(/[\/\\]/g, '_')}`, buf);
    console.log('saved', at.attachmentName, buf.length);
  }
} else if (cmd === 'send' || cmd === 'reply') {
  // reply <folder> <messageId> <body.txt>: threads under the message (Zoho sets In-Reply-To/References).
  // Both append Eddy's saved "Bible Standard" Zoho signature; end the body at "Eddy", not a signature block.
  const reply = cmd === 'reply', [to, subject, bodyFile] = reply ? [null, null, a[2]] : a;
  const html = readFileSync(bodyFile, 'utf8').trim().split(/\n\s*\n/).map((p) => `<p>${esc(p).replace(/\n/g, '<br>').replace(/(https?:\/\/[^\s<]+)/g, '<a href="$1">$1</a>')}</p>`).join('');
  const sig = await signature();
  let path = '/messages', msg = { fromAddress: FROM, content: `<div style="font-family:sans-serif;font-size:14px;line-height:1.6">${html}<br>${sig}</div>`, mailFormat: 'html', askReceipt: 'no' };
  if (reply) {
    const t = await token(), f = await folderId(t, a[0]);
    const orig = (await data(t, `/messages/view?folderId=${f}&start=1&limit=200`) || []).find((x) => x.messageId === a[1]);
    if (!orig) throw new Error(`Message ${a[1]} not in the newest 200 of ${a[0]}`);
    path = `/messages/${a[1]}`;
    msg = { ...msg, action: 'reply', toAddress: orig.fromAddress, subject: /^re:/i.test(plain(orig.subject)) ? plain(orig.subject) : `Re: ${plain(orig.subject)}` };
  } else Object.assign(msg, { toAddress: to, subject });
  const res = await call(await token(true), path, { method: 'POST', body: JSON.stringify(msg) });
  console.log(res.status, (await res.json()).status?.description, reply ? `reply to ${msg.toAddress}` : '');
} else {
  console.error('usage: folders | list <folder> [n] | read <folder> <id>... | attachments <folder> <id> <dir> | send <to> <subject> <body.txt> | reply <folder> <id> <body.txt>');
  process.exit(2);
}
