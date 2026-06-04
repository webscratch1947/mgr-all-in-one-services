// api/payment.js — Vercel serverless function (must live in /api/ folder)
const Razorpay = require('razorpay');

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const { amount, currency = 'INR', receipt, notes } = req.body || {};
  if (!amount) return res.status(400).json({ error: 'Amount is required' });

  const KEY_ID     = process.env.RAZORPAY_KEY_ID;
  const KEY_SECRET = process.env.RAZORPAY_KEY_SECRET;

  if (!KEY_ID || !KEY_SECRET) {
    return res.status(200).json({
      id: 'order_DUMMY_' + Math.random().toString(36).substr(2, 9).toUpperCase(),
      amount: amount * 100,
      currency,
      receipt: receipt || 'dummy_receipt',
      status: 'created',
      dummy: true
    });
  }

  try {
    const instance = new Razorpay({ key_id: KEY_ID, key_secret: KEY_SECRET });
    const order = await instance.orders.create({
      amount: Math.round(amount * 100),
      currency,
      receipt: receipt || ('mgr_' + Date.now()),
      notes: notes || {}
    });
    return res.status(200).json(order);
  } catch (err) {
    console.error('Razorpay order error:', err);
    return res.status(500).json({ error: err.message || 'Payment initialization failed' });
  }
};
