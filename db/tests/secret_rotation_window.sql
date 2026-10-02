-- Secret rotation window contract (agency mirror of the platform rotation
-- window contract; contract parity). Claims:
--   1) Migration 247 seeds 48h windows for SECRET_KEY_BASE and
--      SECRET_KEY_BASE_PREVIOUS; an unconfigured secret falls back to 48h.
--   2) rotation_window_state is fail-closed: no rotation record -> 'unknown'.
--   3) States with the default 48h window: fresh record -> 'open', boundary
--      (age == window) -> 'open', past the window -> 'expired'.
--   4) Owner path: set_rotation_window persists and moves the state
--      boundary; invalid values (0, 721, NULL) and blank names are rejected.  -- 5) Application path (agency_app): rotation settings are operational
  --      data - direct writes and set_rotation_window are written by the
  --      owner/management role only.
  -- Self-seeding and rollback-only: touches only CI_ROT_* fixture rows inside
  -- the transaction; never mutates live rotation records.
  \set ON_ERROR_STOP on
  BEGIN;
  DO $$
DECLARE
  v_open_secret text := 'CI_ROT_OPEN';
  v_edge_secret text := 'CI_ROT_EDGE';
  v_expired_secret text := 'CI_ROT_EXPIRED';
  v_unknown_secret text := 'CI_ROT_UNKNOWN';
  v_window_secret text := 'CI_ROT_WINDOW';
BEGIN
  -- 1) Seeded defaults: both production secrets are configured at 48h.
  IF (SELECT count(*) FROM agency.secret_rotation_settings
      WHERE secret_name IN ('SECRET_KEY_BASE', 'SECRET_KEY_BASE_PREVIOUS')
        AND window_hours = 48) <> 2 THEN
    RAISE EXCEPTION 'seeded_rotation_windows_missing';
  END IF;

  -- 2) Unconfigured secret falls back to the 48h default.
  IF agency.rotation_window_hours('CI_ROT_UNCONFIGURED') <> 48 THEN
    RAISE EXCEPTION 'default_window_expected_48';
  END IF;

  -- 3) No rotation record -> fail-closed 'unknown'.
  IF agency.rotation_window_state(v_unknown_secret) <> 'unknown' THEN
    RAISE EXCEPTION 'state_expected_unknown';
  END IF;

  -- 4) Fresh record within the default 48h window -> 'open'.
  INSERT INTO agency.secret_rotations(secret_name, rotated_at, source)
    VALUES (v_open_secret, now() - interval '1 hour', 'ci-fixture');
  IF agency.rotation_window_state(v_open_secret) <> 'open' THEN
    RAISE EXCEPTION 'state_expected_open';
  END IF;

  -- 5) Boundary: age == window (48h) is still 'open'.
  INSERT INTO agency.secret_rotations(secret_name, rotated_at, source)
    VALUES (v_edge_secret, now() - interval '48 hours', 'ci-fixture');
  IF agency.rotation_window_state(v_edge_secret) <> 'open' THEN
    RAISE EXCEPTION 'boundary_state_expected_open';
  END IF;

  -- 6) Past the default window (49h) -> 'expired'.
  INSERT INTO agency.secret_rotations(secret_name, rotated_at, source)
    VALUES (v_expired_secret, now() - interval '49 hours', 'ci-fixture');
  IF agency.rotation_window_state(v_expired_secret) <> 'expired' THEN
    RAISE EXCEPTION 'state_expected_expired';
  END IF;

  IF has_table_privilege(current_user, 'agency.secret_rotation_settings', 'INSERT') THEN
    -- Owner/management path: the window can be set and takes effect.
    PERFORM agency.set_rotation_window(v_window_secret, 72);
    IF agency.rotation_window_hours(v_window_secret) <> 72 THEN
      RAISE EXCEPTION 'custom_window_expected_72';
    END IF;
    INSERT INTO agency.secret_rotations(secret_name, rotated_at, source)
      VALUES (v_window_secret, now() - interval '3 hours', 'ci-fixture');
    IF agency.rotation_window_state(v_window_secret) <> 'open' THEN
      RAISE EXCEPTION 'custom_window_state_expected_open';
    END IF;
    PERFORM agency.set_rotation_window(v_window_secret, 2);
    IF agency.rotation_window_state(v_window_secret) <> 'expired' THEN
      RAISE EXCEPTION 'custom_window_state_expected_expired';
    END IF;
    BEGIN
      PERFORM agency.set_rotation_window(v_window_secret, 0);
      RAISE EXCEPTION 'window_zero_accepted';
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM = 'window_zero_accepted' THEN RAISE; END IF;
    END;
    BEGIN
      PERFORM agency.set_rotation_window(v_window_secret, 721);
      RAISE EXCEPTION 'window_721_accepted';
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM = 'window_721_accepted' THEN RAISE; END IF;
    END;
    BEGIN
      PERFORM agency.set_rotation_window(v_window_secret, NULL);
      RAISE EXCEPTION 'window_null_accepted';
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM = 'window_null_accepted' THEN RAISE; END IF;
    END;
    BEGIN
      PERFORM agency.set_rotation_window('   ', 48);
      RAISE EXCEPTION 'blank_secret_accepted';
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM = 'blank_secret_accepted' THEN RAISE; END IF;
    END;
  ELSE
    -- Application path: the settings table is read-only for the application
    -- role and the window is set only by owner/management.
    BEGIN
      PERFORM agency.set_rotation_window(v_window_secret, 72);
      RAISE EXCEPTION 'set_rotation_window_accepted_for_app_role';
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM = 'set_rotation_window_accepted_for_app_role' THEN RAISE; END IF;
    END;
    BEGIN
      INSERT INTO agency.secret_rotation_settings(secret_name, window_hours)
        VALUES (v_window_secret, 999);
      RAISE EXCEPTION 'settings_direct_write_accepted';
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM = 'settings_direct_write_accepted' THEN RAISE; END IF;
    END;
  END IF;
END $$;
ROLLBACK;
\echo 'PASS: secret rotation window contract (48h default, fail-closed unknown, open/expired states, owner-only window setting)'
