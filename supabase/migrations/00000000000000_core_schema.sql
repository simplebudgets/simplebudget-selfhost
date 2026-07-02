-- Core schema migration
-- Creates roles and the users table

-- =============================================================================
-- Roles (required for PostgREST and GoTrue)
-- =============================================================================

DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN NOINHERIT;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN NOINHERIT;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'service_role') THEN
    CREATE ROLE service_role NOLOGIN NOINHERIT BYPASSRLS;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticator') THEN
    CREATE ROLE authenticator NOINHERIT LOGIN;
  END IF;
END
$$;

GRANT anon TO authenticator;
GRANT authenticated TO authenticator;
GRANT service_role TO authenticator;

-- =============================================================================
-- Note: auth schema, auth.users table, and auth.uid() function are provided
-- by the supabase/postgres image. No need to create them here.
-- =============================================================================

-- =============================================================================
-- Tables
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.users (
  "recordID" uuid NOT NULL PRIMARY KEY,
  "fullName" character varying NOT NULL,
  "userType" character varying NOT NULL
);

-- =============================================================================
-- Enable Row Level Security
-- =============================================================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- RLS Policies: users
-- =============================================================================

CREATE POLICY "INSERT -> authenticated"
  ON public.users FOR INSERT
  TO public
  WITH CHECK (true);

CREATE POLICY "SELECT -> authenticated"
  ON public.users FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "UPDATE -> creator"
  ON public.users FOR UPDATE
  TO authenticated
  USING (auth.uid() = "recordID")
  WITH CHECK (auth.uid() = "recordID");

-- =============================================================================
-- Grant permissions to roles
-- =============================================================================

GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated, service_role;
