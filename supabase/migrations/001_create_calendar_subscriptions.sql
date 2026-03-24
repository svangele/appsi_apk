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
CREATE POLICY "calendar_subscriptions_select" ON calendar_subscriptions
  FOR SELECT USING (auth.uid() = subscriber_id);

-- Policy: Users can manage their own subscriptions
CREATE POLICY "calendar_subscriptions_all" ON calendar_subscriptions
  FOR ALL USING (auth.uid() = subscriber_id);

-- Policy: Allow viewing events from followed users
-- This policy allows users to see events from users they follow
CREATE POLICY "events_select_for_followed" ON events
  FOR SELECT USING (
    creator_id IN (
      SELECT followed_user_id 
      FROM calendar_subscriptions 
      WHERE subscriber_id = auth.uid() AND is_active = true
    )
    OR creator_id = auth.uid()
  );
