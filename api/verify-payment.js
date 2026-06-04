// api/verify-payment.js — Vercel serverless function (must live in /api/ folder)
const crypto = require('crypto');

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ success: false, error: 'Method not allowed' });

  const { razorpay_order_id, razorpay_payment_id, razorpay_signature } = req.body || {};

  if (!razorpay_order_id || !razorpay_payment_id || !razorpay_signature) {
    return res.status(400).json({ success: false, error: 'Missing payment parameters' });
  }

  const KEY_SECRET = process.env.RAZORPAY_KEY_SECRET;
  if (!KEY_SECRET) {
    return res.status(200).json({ success: true, dummy: true });
  }

  try {
    const body = razorpay_order_id + '|' + razorpay_payment_id;
    const expectedSignature = crypto
      .createHmac('sha256', KEY_SECRET)
      .update(body)
      .digest('hex');

    const sigBuffer      = Buffer.from(razorpay_signature, 'hex');
    const expectedBuffer = Buffer.from(expectedSignature,  'hex');

    if (sigBuffer.length !== expectedBuffer.length) {
      return res.status(400).json({ success: false, error: 'Invalid signature' });
    }

    const isValid = crypto.timingSafeEqual(expectedBuffer, sigBuffer);
    if (!isValid) {
      return res.status(400).json({ success: false, error: 'Invalid signature' });
    }

    return res.status(200).json({ success: true, payment_id: razorpay_payment_id });
  } catch (err) {
    console.error('Verification error:', err);
    return res.status(500).json({ success: false, error: 'Verification failed' });
  }
};
