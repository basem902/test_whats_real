-- ============================================
-- Smart Real Estate Agent - Manual Testing Platform
-- Database Setup Script
-- Run this in Supabase SQL Editor (one time)
-- ============================================

-- 1. Test Runs table
CREATE TABLE IF NOT EXISTS test_runs (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  run_name text NOT NULL,
  tester_name text NOT NULL,
  tester_phone text,
  app_version text DEFAULT '1.0.0',
  environment text DEFAULT 'production',
  status text DEFAULT 'in_progress' CHECK (status IN ('in_progress', 'completed', 'paused')),
  total_tests int DEFAULT 0,
  passed int DEFAULT 0,
  failed int DEFAULT 0,
  skipped int DEFAULT 0,
  blocked int DEFAULT 0,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- 2. Test Results table
CREATE TABLE IF NOT EXISTS test_results (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  run_id uuid REFERENCES test_runs(id) ON DELETE CASCADE,
  test_id text NOT NULL,
  category text NOT NULL,
  test_title text NOT NULL,
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'pass', 'fail', 'skip', 'blocked')),
  notes text,
  screenshot_url text,
  bug_id text,
  severity text CHECK (severity IN (NULL, 'critical', 'major', 'minor', 'cosmetic')),
  tester_name text,
  tested_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(run_id, test_id)
);

-- 3. Indexes for performance
CREATE INDEX IF NOT EXISTS idx_test_results_run_id ON test_results(run_id);
CREATE INDEX IF NOT EXISTS idx_test_results_test_id ON test_results(test_id);
CREATE INDEX IF NOT EXISTS idx_test_results_status ON test_results(status);
CREATE INDEX IF NOT EXISTS idx_test_results_category ON test_results(category);

-- 4. Auto-update timestamp trigger
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS test_runs_updated_at ON test_runs;
CREATE TRIGGER test_runs_updated_at
  BEFORE UPDATE ON test_runs
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS test_results_updated_at ON test_results;
CREATE TRIGGER test_results_updated_at
  BEFORE UPDATE ON test_results
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- 5. Disable RLS (internal tool only)
ALTER TABLE test_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE test_results ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all on test_runs" ON test_runs FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on test_results" ON test_results FOR ALL USING (true) WITH CHECK (true);

-- 6. Storage bucket for screenshots
INSERT INTO storage.buckets (id, name, public)
VALUES ('test-screenshots', 'test-screenshots', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Public read test-screenshots" ON storage.objects
  FOR SELECT USING (bucket_id = 'test-screenshots');

CREATE POLICY "Anon upload test-screenshots" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'test-screenshots');

CREATE POLICY "Anon update test-screenshots" ON storage.objects
  FOR UPDATE USING (bucket_id = 'test-screenshots');

CREATE POLICY "Anon delete test-screenshots" ON storage.objects
  FOR DELETE USING (bucket_id = 'test-screenshots');

-- 7. View for run statistics
CREATE OR REPLACE VIEW test_run_stats AS
SELECT
  r.id,
  r.run_name,
  r.tester_name,
  r.status,
  r.created_at,
  COUNT(tr.id) as total,
  COUNT(CASE WHEN tr.status = 'pass' THEN 1 END) as passed,
  COUNT(CASE WHEN tr.status = 'fail' THEN 1 END) as failed,
  COUNT(CASE WHEN tr.status = 'skip' THEN 1 END) as skipped,
  COUNT(CASE WHEN tr.status = 'blocked' THEN 1 END) as blocked,
  COUNT(CASE WHEN tr.status = 'pending' THEN 1 END) as pending,
  ROUND(
    COUNT(CASE WHEN tr.status IN ('pass','fail','skip','blocked') THEN 1 END)::numeric /
    NULLIF(COUNT(tr.id), 0) * 100, 1
  ) as progress_pct
FROM test_runs r
LEFT JOIN test_results tr ON tr.run_id = r.id
GROUP BY r.id, r.run_name, r.tester_name, r.status, r.created_at;
