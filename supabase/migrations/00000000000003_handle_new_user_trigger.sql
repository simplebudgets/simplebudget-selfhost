-- Migration: Add handle_new_user trigger
-- Automatically creates a public.users row when a new auth user signs up,
-- bypassing RLS via SECURITY DEFINER. Also adds the email column and
-- tightens the INSERT policy.

-- =============================================================================
-- Add email column to users table (used by sharing/lookup features)
-- =============================================================================

ALTER TABLE public.users ADD COLUMN IF NOT EXISTS email character varying;

-- =============================================================================
-- Trigger function: create public.users row on auth.users insert
-- =============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users ("recordID", "fullName", "userType", email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    'free',
    NEW.email
  )
  ON CONFLICT ("recordID") DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- =============================================================================
-- Tighten INSERT policy: only the user themselves (or the SECURITY DEFINER
-- trigger) can insert their row.
-- =============================================================================

DROP POLICY IF EXISTS "INSERT -> authenticated" ON public.users;

CREATE POLICY "INSERT - yourself and authenticated"
  ON public.users FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = "recordID");
