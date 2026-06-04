-- ============================================================
-- PATCH: Add payment columns to bookings table
-- Run this in Supabase SQL Editor → New Query → Run
-- Safe to run even if columns already exist
-- ============================================================

ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS payment_id     TEXT,
  ADD COLUMN IF NOT EXISTS payment_status TEXT DEFAULT 'pending'
    CHECK (payment_status IN ('pending','paid','failed'));
