if (!process.env.MONGODB_URI) {
  process.env.MONGODB_URI = 'mongodb+srv://jihad2jus:l9GrLciVEUvvK8Fd@jihad.8dyvx.mongodb.net/jgo?retryWrites=true&w=majority&appName=jihad';
}
if (!process.env.JWT_SECRET) {
  process.env.JWT_SECRET = 'layan_chargex_jwt_secret_key_2026_secure';
}
if (!process.env.JWT_REFRESH_SECRET) {
  process.env.JWT_REFRESH_SECRET = 'layan_chargex_refresh_secret_key_2026_secure';
}

let cachedHandler = null;

module.exports = async (req, res) => {
  try {
    if (!cachedHandler) {
      const main = await import('../dist/main.js');
      cachedHandler = main.default || main;
    }
    return await cachedHandler(req, res);
  } catch (error) {
    console.error('Vercel Handler Error:', error);
    res.statusCode = 500;
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    return res.end(`
      <div style="font-family: system-ui; max-width: 500px; margin: 40px auto; padding: 24px; background: #0F172A; color: white; border-radius: 16px; text-align: center;">
        <h2 style="color: #F87171;">⚠️ تعذر الاتصال بقاعدة البيانات السحابية</h2>
        <p style="color: #94A3B8; font-size: 14px; line-height: 1.6;">
          السيرفر السحابي يعمل بنجاح، ولكن MongoDB Atlas يرفض الاتصال لأن IP السيرفر لم تتم إضافته إلى القائمة البيضاء (IP Whitelist).
        </p>
        <p style="color: #38BDF8; font-size: 13px;">
          الحل: في موقع MongoDB Atlas -> Security -> Network Access -> اضغط Add IP Address واختر <b>Allow Access from Anywhere (0.0.0.0/0)</b>
        </p>
        <pre style="text-align: left; background: rgba(0,0,0,0.4); padding: 10px; border-radius: 8px; font-size: 11px; color: #FCA5A5; overflow-x: auto;">${error && error.message ? error.message : error}</pre>
      </div>
    `);
  }
};
