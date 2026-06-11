-- ═══════════════════════════════════════════════════════════════════
-- PART 3 of 4 — Update the auto-create-staff-profile trigger
-- to also copy email from auth.users into staff_profiles.email
-- Run after PART 2 succeeds.
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION handle_new_staff_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO staff_profiles (id, full_name, role, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
    COALESCE((NEW.raw_user_meta_data->>'role')::staff_role, 'outlet_clerk'),
    NEW.email
  )
  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    role      = EXCLUDED.role,
    email     = EXCLUDED.email;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RETURN NEW; -- Never block user creation if profile insert fails
END;
$$;

-- Verify
SELECT proname AS function_name, prosrc IS NOT NULL AS exists
FROM pg_proc WHERE proname = 'handle_new_staff_user';
