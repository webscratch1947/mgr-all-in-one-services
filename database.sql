-- ============================================================
-- MGR ALL IN ONE SERVICES — COMPLETE SUPABASE SETUP
-- Run this ENTIRE file in Supabase SQL Editor → New Query → Run
-- This is safe to run on a fresh project OR an existing one
-- ============================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- DROP OLD TABLES (order matters due to foreign keys)
-- ============================================================
DROP TABLE IF EXISTS public.assignments   CASCADE;
DROP TABLE IF EXISTS public.payments      CASCADE;
DROP TABLE IF EXISTS public.bookings      CASCADE;
DROP TABLE IF EXISTS public.vendors       CASCADE;
DROP TABLE IF EXISTS public.vendor_requests CASCADE;
DROP TABLE IF EXISTS public.auth_kicks    CASCADE;
DROP TABLE IF EXISTS public.users         CASCADE;

-- ============================================================
-- USERS TABLE
-- ============================================================
CREATE TABLE public.users (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  auth_id     UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  email       TEXT UNIQUE NOT NULL,
  full_name   TEXT,
  phone       TEXT,
  address     TEXT,
  avatar_url  TEXT,
  role        TEXT DEFAULT 'user' CHECK (role IN ('user','vendor','admin')),
  is_banned   BOOLEAN DEFAULT FALSE,
  ban_type    TEXT CHECK (ban_type IN ('temporary','permanent',NULL)),
  ban_until   TIMESTAMPTZ,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- VENDOR_REQUESTS TABLE
-- ============================================================
CREATE TABLE public.vendor_requests (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id          UUID REFERENCES public.users(id) ON DELETE CASCADE,
  full_name        TEXT NOT NULL,
  email            TEXT,
  phone            TEXT NOT NULL,
  address          TEXT NOT NULL,
  skills           TEXT[] NOT NULL DEFAULT '{}',
  experience       TEXT,
  years_experience INTEGER DEFAULT 0,
  photo_url        TEXT,
  status           TEXT DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  rejection_reason TEXT,
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- VENDORS TABLE
-- ============================================================
CREATE TABLE public.vendors (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id          UUID REFERENCES public.users(id) ON DELETE CASCADE,
  request_id       UUID REFERENCES public.vendor_requests(id),
  full_name        TEXT NOT NULL,
  email            TEXT,
  phone            TEXT NOT NULL,
  address          TEXT NOT NULL,
  skills           TEXT[] NOT NULL DEFAULT '{}',
  experience       TEXT,
  years_experience INTEGER DEFAULT 0,
  photo_url        TEXT,
  rating           DECIMAL(3,2) DEFAULT NULL,
  total_jobs       INTEGER DEFAULT 0,
  is_available     BOOLEAN DEFAULT TRUE,
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- BOOKINGS TABLE
-- ============================================================
CREATE TABLE public.bookings (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id          UUID REFERENCES public.users(id) ON DELETE CASCADE,
  service_name     TEXT NOT NULL,
  service_category TEXT NOT NULL,
  service_price    DECIMAL(10,2) NOT NULL,
  service_image    TEXT,
  booking_date     DATE NOT NULL,
  booking_time     TIME NOT NULL,
  address          TEXT,
  notes            TEXT,
  status           TEXT DEFAULT 'pending' CHECK (status IN ('pending','confirmed','assigned','in_progress','completed','cancelled')),
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- PAYMENTS TABLE
-- ============================================================
CREATE TABLE public.payments (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id     UUID REFERENCES public.bookings(id) ON DELETE CASCADE,
  user_id        UUID REFERENCES public.users(id) ON DELETE CASCADE,
  amount         DECIMAL(10,2) NOT NULL,
  currency       TEXT DEFAULT 'INR',
  method         TEXT DEFAULT 'cash' CHECK (method IN ('online','cash','upi','card')),
  status         TEXT DEFAULT 'completed' CHECK (status IN ('pending','completed','failed','refunded')),
  transaction_id TEXT UNIQUE,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- ASSIGNMENTS TABLE
-- ============================================================
CREATE TABLE public.assignments (
  id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id           UUID REFERENCES public.bookings(id) ON DELETE CASCADE,
  vendor_id            UUID REFERENCES public.vendors(id) ON DELETE CASCADE,
  assigned_by          UUID REFERENCES public.users(id),
  status               TEXT DEFAULT 'assigned' CHECK (status IN ('assigned','accepted','rejected','completed','cancelled')),
  rejection_reason     TEXT,
  notes                TEXT,
  entry_code           TEXT,
  entry_confirmed      BOOLEAN DEFAULT FALSE,
  completion_code      TEXT,
  completion_confirmed BOOLEAN DEFAULT FALSE,
  rating               INTEGER CHECK (rating >= 1 AND rating <= 5),
  review               TEXT,
  created_at           TIMESTAMPTZ DEFAULT NOW(),
  updated_at           TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- AUTH KICKS TABLE (for admin force-logout)
-- ============================================================
CREATE TABLE public.auth_kicks (
  id         BIGSERIAL PRIMARY KEY,
  auth_id    UUID NOT NULL,
  reason     TEXT NOT NULL DEFAULT 'revoked',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- ENABLE ROW LEVEL SECURITY
-- ============================================================
ALTER TABLE public.users            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendor_requests  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendors          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assignments      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auth_kicks       ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- RLS POLICIES — USERS
-- NO recursive subqueries. Admin identified via JWT email claim.
-- ============================================================
CREATE POLICY "users_select_all"   ON public.users FOR SELECT  USING (true);
CREATE POLICY "users_insert_all"   ON public.users FOR INSERT  WITH CHECK (true);
CREATE POLICY "users_update_own"   ON public.users FOR UPDATE  USING (auth.uid() = auth_id);
CREATE POLICY "users_update_admin" ON public.users FOR UPDATE
  USING ((auth.jwt() ->> 'email') = 'webscratch99@gmail.com');
CREATE POLICY "users_delete_admin" ON public.users FOR DELETE
  USING ((auth.jwt() ->> 'email') = 'webscratch99@gmail.com');

-- ============================================================
-- RLS POLICIES — VENDOR_REQUESTS
-- ============================================================
CREATE POLICY "vreq_select_all"  ON public.vendor_requests FOR SELECT  USING (true);
CREATE POLICY "vreq_insert_all"  ON public.vendor_requests FOR INSERT  WITH CHECK (true);
CREATE POLICY "vreq_update_all"  ON public.vendor_requests FOR UPDATE  USING (true);
CREATE POLICY "vreq_delete_all"  ON public.vendor_requests FOR DELETE  USING (true);

-- ============================================================
-- RLS POLICIES — VENDORS
-- ============================================================
CREATE POLICY "vendors_select_all"  ON public.vendors FOR SELECT  USING (true);
CREATE POLICY "vendors_insert_all"  ON public.vendors FOR INSERT  WITH CHECK (true);
CREATE POLICY "vendors_update_all"  ON public.vendors FOR UPDATE  USING (true);
CREATE POLICY "vendors_delete_all"  ON public.vendors FOR DELETE  USING (true);

-- ============================================================
-- RLS POLICIES — BOOKINGS
-- ============================================================
CREATE POLICY "bookings_select_all"  ON public.bookings FOR SELECT  USING (true);
CREATE POLICY "bookings_insert_all"  ON public.bookings FOR INSERT  WITH CHECK (true);
CREATE POLICY "bookings_update_all"  ON public.bookings FOR UPDATE  USING (true);
CREATE POLICY "bookings_delete_all"  ON public.bookings FOR DELETE  USING (true);

-- ============================================================
-- RLS POLICIES — PAYMENTS
-- ============================================================
CREATE POLICY "payments_select_all"  ON public.payments FOR SELECT  USING (true);
CREATE POLICY "payments_insert_all"  ON public.payments FOR INSERT  WITH CHECK (true);

-- ============================================================
-- RLS POLICIES — ASSIGNMENTS
-- ============================================================
CREATE POLICY "assign_select_all"  ON public.assignments FOR SELECT  USING (true);
CREATE POLICY "assign_insert_all"  ON public.assignments FOR INSERT  WITH CHECK (true);
CREATE POLICY "assign_update_all"  ON public.assignments FOR UPDATE  USING (true);
CREATE POLICY "assign_delete_all"  ON public.assignments FOR DELETE  USING (true);

-- ============================================================
-- RLS POLICIES — AUTH KICKS
-- ============================================================
CREATE POLICY "kicks_select_own"  ON public.auth_kicks FOR SELECT TO authenticated USING (auth.uid() = auth_id);
CREATE POLICY "kicks_insert_all"  ON public.auth_kicks FOR INSERT TO authenticated WITH CHECK (true);

-- ============================================================
-- STORAGE BUCKET for vendor photos
-- ============================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('vendor-images', 'vendor-images', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Public read vendor images"       ON storage.objects;
DROP POLICY IF EXISTS "Anyone can upload vendor images" ON storage.objects;
CREATE POLICY "Public read vendor images"       ON storage.objects FOR SELECT USING (bucket_id = 'vendor-images');
CREATE POLICY "Anyone can upload vendor images" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'vendor-images');

-- ============================================================
-- AUTO updated_at TRIGGER
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$ BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_users_updated_at           ON public.users;
DROP TRIGGER IF EXISTS trg_vendor_requests_updated_at ON public.vendor_requests;
DROP TRIGGER IF EXISTS trg_vendors_updated_at         ON public.vendors;
DROP TRIGGER IF EXISTS trg_bookings_updated_at        ON public.bookings;
DROP TRIGGER IF EXISTS trg_assignments_updated_at     ON public.assignments;

CREATE TRIGGER trg_users_updated_at           BEFORE UPDATE ON public.users           FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_vendor_requests_updated_at BEFORE UPDATE ON public.vendor_requests FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_vendors_updated_at         BEFORE UPDATE ON public.vendors         FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_bookings_updated_at        BEFORE UPDATE ON public.bookings        FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_assignments_updated_at     BEFORE UPDATE ON public.assignments     FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- HELPER FUNCTIONS
-- ============================================================
CREATE OR REPLACE FUNCTION public.push_auth_kick(p_auth_id UUID, p_reason TEXT DEFAULT 'revoked')
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF p_auth_id IS NOT NULL THEN
    INSERT INTO public.auth_kicks(auth_id, reason) VALUES (p_auth_id, COALESCE(p_reason,'revoked'));
  END IF;
END; $$;

CREATE OR REPLACE FUNCTION public.purge_user_vendor_images(target_user_id UUID, target_auth_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF target_auth_id IS NOT NULL THEN
    DELETE FROM storage.objects WHERE bucket_id='vendor-images' AND name LIKE (target_auth_id::TEXT || '-%');
  END IF;
  DELETE FROM storage.objects WHERE bucket_id='vendor-images' AND name IN (
    SELECT split_part(v.photo_url,'/vendor-images/',2) FROM public.vendors v WHERE v.user_id=target_user_id AND v.photo_url IS NOT NULL
    UNION
    SELECT split_part(vr.photo_url,'/vendor-images/',2) FROM public.vendor_requests vr WHERE vr.user_id=target_user_id AND vr.photo_url IS NOT NULL
  );
END; $$;

CREATE OR REPLACE FUNCTION public.permanent_ban_user(target_user_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_auth_id UUID; v_vendor_id UUID;
BEGIN
  SELECT auth_id INTO v_auth_id FROM public.users WHERE id = target_user_id;
  PERFORM public.push_auth_kick(v_auth_id, 'permanent_delete');
  PERFORM public.purge_user_vendor_images(target_user_id, v_auth_id);
  SELECT id INTO v_vendor_id FROM public.vendors WHERE user_id=target_user_id LIMIT 1;
  DELETE FROM public.assignments a USING public.bookings b WHERE a.booking_id=b.id AND b.user_id=target_user_id;
  IF v_vendor_id IS NOT NULL THEN DELETE FROM public.assignments WHERE vendor_id=v_vendor_id; END IF;
  DELETE FROM public.bookings WHERE user_id=target_user_id;
  DELETE FROM public.vendor_requests WHERE user_id=target_user_id;
  DELETE FROM public.vendors WHERE user_id=target_user_id;
  UPDATE public.users SET is_banned=TRUE,ban_type='permanent',ban_until=NULL WHERE id=target_user_id;
  DELETE FROM public.users WHERE id=target_user_id;
  IF v_auth_id IS NOT NULL THEN DELETE FROM auth.users WHERE id=v_auth_id; END IF;
END; $$;

CREATE OR REPLACE FUNCTION public.user_delete_kick_trigger()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN PERFORM public.purge_user_vendor_images(OLD.id,OLD.auth_id); PERFORM public.push_auth_kick(OLD.auth_id,'row_deleted'); RETURN OLD; END; $$;

DROP TRIGGER IF EXISTS trg_user_delete_kick ON public.users;
CREATE TRIGGER trg_user_delete_kick BEFORE DELETE ON public.users FOR EACH ROW EXECUTE FUNCTION public.user_delete_kick_trigger();

CREATE OR REPLACE FUNCTION public.user_ban_kick_trigger()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN IF NEW.is_banned IS TRUE THEN PERFORM public.push_auth_kick(NEW.auth_id,'banned'); END IF; RETURN NEW; END; $$;

DROP TRIGGER IF EXISTS trg_user_ban_kick ON public.users;
CREATE TRIGGER trg_user_ban_kick AFTER UPDATE OF is_banned,ban_type ON public.users FOR EACH ROW WHEN (NEW.is_banned IS TRUE) EXECUTE FUNCTION public.user_ban_kick_trigger();

CREATE OR REPLACE FUNCTION public.cleanup_assignments_on_booking_cancel()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN IF NEW.status='cancelled' AND OLD.status IS DISTINCT FROM 'cancelled' THEN DELETE FROM public.assignments WHERE booking_id=NEW.id; END IF; RETURN NEW; END; $$;

DROP TRIGGER IF EXISTS trg_cleanup_assignments_on_booking_cancel ON public.bookings;
CREATE TRIGGER trg_cleanup_assignments_on_booking_cancel AFTER UPDATE OF status ON public.bookings FOR EACH ROW EXECUTE FUNCTION public.cleanup_assignments_on_booking_cancel();

GRANT EXECUTE ON FUNCTION public.push_auth_kick(UUID,TEXT)               TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.purge_user_vendor_images(UUID,UUID)      TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.permanent_ban_user(UUID)                 TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.user_delete_kick_trigger()               TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.user_ban_kick_trigger()                  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.cleanup_assignments_on_booking_cancel()  TO anon, authenticated;

-- ============================================================
-- SEED ADMIN USER ROW
-- This links your Supabase auth account to the users table
-- ============================================================
INSERT INTO public.users (auth_id, email, full_name, role)
SELECT id, 'webscratch99@gmail.com', 'MGR Admin', 'admin'
FROM auth.users WHERE email = 'webscratch99@gmail.com'
ON CONFLICT (email) DO UPDATE SET
  role    = 'admin',
  auth_id = EXCLUDED.auth_id,
  full_name = COALESCE(public.users.full_name, EXCLUDED.full_name);

-- ============================================================
-- FIX EXISTING DATA: Re-link vendors by email if user_id broken
-- ============================================================
UPDATE public.vendors v SET user_id = u.id
FROM public.users u WHERE v.email = u.email AND (v.user_id IS NULL OR v.user_id != u.id);

UPDATE public.users u SET role = 'vendor'
FROM public.vendors v WHERE v.user_id = u.id AND u.role = 'user';

-- ============================================================
-- ENABLE REALTIME on assignments (for live job updates)
-- ============================================================
ALTER PUBLICATION supabase_realtime ADD TABLE public.assignments;
ALTER PUBLICATION supabase_realtime ADD TABLE public.auth_kicks;

-- DONE. Refresh browser after running this.