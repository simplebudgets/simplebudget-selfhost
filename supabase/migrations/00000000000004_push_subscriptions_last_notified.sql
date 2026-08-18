-- Add lastNotifiedDate to push_subscriptions
-- Tracks the last date (YYYY-MM-DD) a notification was sent for each subscription.
-- The worker/edge function checks this before sending to avoid duplicate notifications.

ALTER TABLE public.push_subscriptions
  ADD COLUMN IF NOT EXISTS "lastNotifiedDate" character varying;
