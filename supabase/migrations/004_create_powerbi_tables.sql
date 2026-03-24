-- Create powerbi_links table for storing URLs and HTML content
CREATE TABLE powerbi_links (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  url TEXT,
  html_code TEXT,
  is_active BOOLEAN DEFAULT true,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create powerbi_link_users table for user access control
CREATE TABLE powerbi_link_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  link_id UUID REFERENCES powerbi_links(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(link_id, user_id)
);

-- Enable Row Level Security
ALTER TABLE powerbi_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE powerbi_link_users ENABLE ROW LEVEL SECURITY;

-- RLS Policies for powerbi_links
CREATE POLICY "Allow read for all authenticated" ON powerbi_links
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow insert for authenticated" ON powerbi_links
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Allow update for all authenticated" ON powerbi_links
  FOR UPDATE TO authenticated USING (true);

CREATE POLICY "Allow delete for all authenticated" ON powerbi_links
  FOR DELETE TO authenticated USING (true);

-- RLS Policies for powerbi_link_users
CREATE POLICY "Allow read for all authenticated" ON powerbi_link_users
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow insert for authenticated" ON powerbi_link_users
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Allow update for all authenticated" ON powerbi_link_users
  FOR UPDATE TO authenticated USING (true);

CREATE POLICY "Allow delete for authenticated" ON powerbi_link_users
  FOR DELETE TO authenticated USING (true);

-- Add comments for documentation
COMMENT ON TABLE powerbi_links IS 'Stores Power BI report links and HTML content';
COMMENT ON TABLE powerbi_link_users IS 'Maps users to Power BI links for access control';
COMMENT ON COLUMN powerbi_links.html_code IS 'Custom HTML code for embedded reports';
