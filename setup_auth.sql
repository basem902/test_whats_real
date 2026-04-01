-- ============================================
-- Smart Real Estate Agent Test Platform - Auth & Access Control
-- Run this in Supabase SQL Editor
-- ============================================

-- 1. Access Requests table
CREATE TABLE IF NOT EXISTS access_requests (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  phone text NOT NULL,
  name text NOT NULL,
  otp_code text NOT NULL,
  otp_verified boolean DEFAULT false,
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  session_token text,
  admin_note text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  expires_at timestamptz DEFAULT (now() + interval '24 hours')
);

-- 2. Approved Users (whitelist for quick re-entry)
CREATE TABLE IF NOT EXISTS approved_users (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  phone text UNIQUE NOT NULL,
  name text NOT NULL,
  is_admin boolean DEFAULT false,
  is_active boolean DEFAULT true,
  last_login timestamptz,
  created_at timestamptz DEFAULT now()
);

-- 3. Indexes
CREATE INDEX IF NOT EXISTS idx_access_requests_phone ON access_requests(phone);
CREATE INDEX IF NOT EXISTS idx_access_requests_status ON access_requests(status);
CREATE INDEX IF NOT EXISTS idx_access_requests_token ON access_requests(session_token);
CREATE INDEX IF NOT EXISTS idx_approved_users_phone ON approved_users(phone);

-- 4. Auto-update trigger
DROP TRIGGER IF EXISTS access_requests_updated_at ON access_requests;
CREATE TRIGGER access_requests_updated_at
  BEFORE UPDATE ON access_requests
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- 5. RLS Policies
ALTER TABLE access_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE approved_users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all on access_requests" ON access_requests FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on approved_users" ON approved_users FOR ALL USING (true) WITH CHECK (true);

-- 6. Insert admin user (Basem)
INSERT INTO approved_users (phone, name, is_admin)
VALUES ('966544711074', 'باسم الحجري', true)
ON CONFLICT (phone) DO UPDATE SET is_admin = true;

-- 7. Realtime for live updates
ALTER PUBLICATION supabase_realtime ADD TABLE access_requests;
