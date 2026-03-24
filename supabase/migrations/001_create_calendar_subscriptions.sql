-- Create calendar_subscriptions table for following other users' calendars
CREATE TABLE calendar_subscriptions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  subscriber_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  followed_user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(subscriber_id, followed_user_id)
);

-- Enable RLS
ALTER TABLE calendar_subscriptions ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own subscriptions
CREATE POLICY "Users can view own subscriptions" ON calendar_subscriptions
  FOR SELECT USING (auth.uid() = subscriber_id);

-- Policy: Users can manage their own subscriptions
CREATE POLICY "Users can manage own subscriptions" ON calendar_subscriptions
  FOR ALL USING (auth.uid() = subscriber_id);
