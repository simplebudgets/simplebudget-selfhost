-- Push Subscriptions schema migration
-- Stores Web Push (VAPID) subscriptions for both simpleBudget and simpleTracker.
-- Each row represents one device + app combination for a user.

-- =============================================================================
-- Tables
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.push_subscriptions (
  "recordID" character varying NOT NULL PRIMARY KEY,
  "userID" uuid NOT NULL,
  "app" character varying NOT NULL,           -- 'simplebudget' | 'simpletracker'
  "endpoint" text NOT NULL,                   -- Push service URL (unique per browser+SW)
  "keyP256dh" text NOT NULL,                  -- Client public key for encryption
  "keyAuth" text NOT NULL,                    -- Auth secret for encryption
  "createdAt" bigint NOT NULL,
  "updatedAt" bigint NOT NULL,

  -- Prevent duplicate subscriptions for the same endpoint + app
  CONSTRAINT "push_subscriptions_endpoint_app_unique" UNIQUE ("endpoint", "app")
);

-- =============================================================================
-- Foreign Keys
-- =============================================================================

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'push_subscriptions_userID_fkey') THEN
    ALTER TABLE public.push_subscriptions
      ADD CONSTRAINT "push_subscriptions_userID_fkey"
      FOREIGN KEY ("userID") REFERENCES public.users("recordID");
  END IF;
END $$;

-- =============================================================================
-- Indexes
-- =============================================================================

-- Fast lookup: "give me all subscriptions for this user + app"
CREATE INDEX IF NOT EXISTS "idx_push_subscriptions_user_app"
  ON public.push_subscriptions ("userID", "app");

-- Fast lookup: "give me all subscriptions for a given app" (worker batch query)
CREATE INDEX IF NOT EXISTS "idx_push_subscriptions_app"
  ON public.push_subscriptions ("app");

-- =============================================================================
-- Enable Row Level Security
-- =============================================================================

ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- RLS Policies
-- =============================================================================

-- Users can only see their own subscriptions
DROP POLICY IF EXISTS "push_subscriptions_select" ON public.push_subscriptions;
CREATE POLICY "push_subscriptions_select"
  ON public.push_subscriptions FOR SELECT
  TO authenticated
  USING ("userID" = auth.uid());

-- Users can only insert their own subscriptions
DROP POLICY IF EXISTS "push_subscriptions_insert" ON public.push_subscriptions;
CREATE POLICY "push_subscriptions_insert"
  ON public.push_subscriptions FOR INSERT
  TO authenticated
  WITH CHECK ("userID" = auth.uid());

-- Users can only update their own subscriptions (e.g., refresh keys)
DROP POLICY IF EXISTS "push_subscriptions_update" ON public.push_subscriptions;
CREATE POLICY "push_subscriptions_update"
  ON public.push_subscriptions FOR UPDATE
  TO authenticated
  USING ("userID" = auth.uid())
  WITH CHECK ("userID" = auth.uid());

-- Users can only delete their own subscriptions (unsubscribe)
DROP POLICY IF EXISTS "push_subscriptions_delete" ON public.push_subscriptions;
CREATE POLICY "push_subscriptions_delete"
  ON public.push_subscriptions FOR DELETE
  TO authenticated
  USING ("userID" = auth.uid());

-- =============================================================================
-- Service role: the notification worker uses SERVICE_ROLE_KEY to read all
-- subscriptions (bypasses RLS). No extra policy needed — service_role has
-- BYPASSRLS by default.
-- =============================================================================

-- =============================================================================
-- Grant permissions to roles
-- =============================================================================

GRANT ALL ON public.push_subscriptions TO anon, authenticated, service_role;
