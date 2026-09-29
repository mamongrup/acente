-- Bounded application-security telemetry and temporary quarantine state.
-- Permanent blocks remain an explicit operator decision at the edge/WAF.

CREATE TABLE IF NOT EXISTS agency.security_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  request_id varchar(128) NOT NULL,
  client_id varchar(128),
  method varchar(16) NOT NULL,
  route varchar(512) NOT NULL,
  event_type varchar(64) NOT NULL,
  severity varchar(16) NOT NULL DEFAULT 'warning'
    CHECK (severity IN ('info', 'warning', 'critical')),
  decision varchar(32) NOT NULL
    CHECK (decision IN ('observed', 'rate_limited', 'temporarily_quarantined')),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX IF NOT EXISTS agency_security_events_occurred_idx
  ON agency.security_events(occurred_at DESC);

CREATE INDEX IF NOT EXISTS agency_security_events_client_idx
  ON agency.security_events(client_id, occurred_at DESC)
  WHERE client_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS agency_security_events_type_idx
  ON agency.security_events(event_type, occurred_at DESC);

CREATE TABLE IF NOT EXISTS agency.security_quarantines (
  client_id varchar(128) PRIMARY KEY,
  reason varchar(256) NOT NULL,
  blocked_until timestamptz NOT NULL,
  strike_count integer NOT NULL DEFAULT 1 CHECK (strike_count BETWEEN 1 AND 1000000),
  last_request_id varchar(128),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (client_id <> '' AND client_id <> 'unknown')
);

CREATE INDEX IF NOT EXISTS agency_security_quarantines_expiry_idx
  ON agency.security_quarantines(blocked_until);

CREATE OR REPLACE FUNCTION agency.record_security_event(
  p_request_id text,
  p_client_id text,
  p_method text,
  p_route text,
  p_event_type text,
  p_severity text,
  p_decision text,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, agency
AS $$
DECLARE
  v_id bigint;
BEGIN
  IF coalesce(p_request_id, '') = '' OR coalesce(p_event_type, '') = '' THEN
    RAISE EXCEPTION 'request_id and event_type are required';
  END IF;

  INSERT INTO agency.security_events(
    request_id, client_id, method, route, event_type, severity, decision, metadata
  ) VALUES (
    left(p_request_id, 128),
    nullif(left(coalesce(p_client_id, ''), 128), ''),
    left(upper(coalesce(p_method, 'UNKNOWN')), 16),
    left(coalesce(p_route, '/'), 512),
    left(p_event_type, 64),
    p_severity,
    p_decision,
    CASE WHEN jsonb_typeof(coalesce(p_metadata, '{}'::jsonb)) = 'object'
      THEN coalesce(p_metadata, '{}'::jsonb)
      ELSE '{}'::jsonb
    END
  ) RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION agency.temporarily_quarantine_client(
  p_client_id text,
  p_reason text,
  p_duration_seconds integer,
  p_request_id text DEFAULT NULL
)
RETURNS timestamptz
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, agency
AS $$
DECLARE
  v_until timestamptz;
BEGIN
  IF coalesce(p_client_id, '') IN ('', 'unknown') THEN
    RAISE EXCEPTION 'a resolved client id is required';
  END IF;
  IF p_duration_seconds < 60 OR p_duration_seconds > 86400 THEN
    RAISE EXCEPTION 'temporary quarantine duration must be between 60 and 86400 seconds';
  END IF;

  v_until := now() + make_interval(secs => p_duration_seconds);
  INSERT INTO agency.security_quarantines(
    client_id, reason, blocked_until, strike_count, last_request_id
  ) VALUES (
    left(p_client_id, 128), left(coalesce(p_reason, 'security policy'), 256),
    v_until, 1, nullif(left(coalesce(p_request_id, ''), 128), '')
  )
  ON CONFLICT (client_id) DO UPDATE SET
    reason = EXCLUDED.reason,
    blocked_until = greatest(agency.security_quarantines.blocked_until, EXCLUDED.blocked_until),
    strike_count = least(agency.security_quarantines.strike_count + 1, 1000000),
    last_request_id = EXCLUDED.last_request_id,
    updated_at = now()
  RETURNING blocked_until INTO v_until;

  RETURN v_until;
END;
$$;

CREATE OR REPLACE FUNCTION agency.security_client_is_quarantined(p_client_id text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, agency
AS $$
  SELECT CASE
    WHEN coalesce(p_client_id, '') IN ('', 'unknown') THEN false
    ELSE EXISTS (
      SELECT 1 FROM agency.security_quarantines
       WHERE client_id = left(p_client_id, 128)
         AND blocked_until > now()
    )
  END;
$$;

CREATE OR REPLACE FUNCTION agency.register_rate_limit_violation(
  p_request_id text,
  p_client_id text,
  p_method text,
  p_route text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, agency
AS $$
DECLARE
  v_recent integer;
BEGIN
  PERFORM agency.record_security_event(
    p_request_id, p_client_id, p_method, p_route,
    'rate_limit', 'warning', 'rate_limited', '{}'::jsonb
  );

  IF coalesce(p_client_id, '') IN ('', 'unknown') THEN
    RETURN false;
  END IF;

  SELECT count(*) INTO v_recent
    FROM agency.security_events
   WHERE client_id = left(p_client_id, 128)
     AND event_type = 'rate_limit'
     AND occurred_at > now() - interval '10 minutes';

  IF v_recent < 12 THEN
    RETURN false;
  END IF;

  -- The caller samples at most one event per client per ten seconds.
  -- Repeated violations receive a five-minute block, never a permanent ban.
  PERFORM agency.temporarily_quarantine_client(
    p_client_id, 'repeated rate-limit violations', 300, p_request_id
  );
  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION agency.purge_security_defense_data(
  p_keep_days integer DEFAULT 30,
  p_batch_size integer DEFAULT 5000
)
RETURNS TABLE(deleted_events integer, deleted_quarantines integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, agency
AS $$
BEGIN
  IF p_keep_days < 7 OR p_keep_days > 3650 THEN
    RAISE EXCEPTION 'security event retention must be between 7 and 3650 days';
  END IF;
  IF p_batch_size < 1 OR p_batch_size > 50000 THEN
    RAISE EXCEPTION 'security cleanup batch size out of range';
  END IF;

  WITH removed AS (
    DELETE FROM agency.security_events
     WHERE id IN (
       SELECT id FROM agency.security_events
        WHERE occurred_at < now() - make_interval(days => p_keep_days)
        ORDER BY occurred_at
        LIMIT p_batch_size
     )
     RETURNING 1
  ) SELECT count(*)::integer INTO deleted_events FROM removed;

  WITH removed AS (
    DELETE FROM agency.security_quarantines
     WHERE client_id IN (
       SELECT client_id FROM agency.security_quarantines
        WHERE blocked_until <= now()
        ORDER BY blocked_until
        LIMIT p_batch_size
     )
     RETURNING 1
  ) SELECT count(*)::integer INTO deleted_quarantines FROM removed;

  RETURN NEXT;
END;
$$;

REVOKE ALL ON agency.security_events FROM PUBLIC;
REVOKE ALL ON agency.security_quarantines FROM PUBLIC;
REVOKE ALL ON FUNCTION agency.record_security_event(text, text, text, text, text, text, text, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION agency.temporarily_quarantine_client(text, text, integer, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION agency.security_client_is_quarantined(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION agency.register_rate_limit_violation(text, text, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION agency.purge_security_defense_data(integer, integer) FROM PUBLIC;
GRANT SELECT ON agency.security_events TO agency_app;
GRANT SELECT ON agency.security_quarantines TO agency_app;
GRANT EXECUTE ON FUNCTION agency.record_security_event(text, text, text, text, text, text, text, jsonb) TO agency_app;
GRANT EXECUTE ON FUNCTION agency.temporarily_quarantine_client(text, text, integer, text) TO agency_app;
GRANT EXECUTE ON FUNCTION agency.security_client_is_quarantined(text) TO agency_app;
GRANT EXECUTE ON FUNCTION agency.register_rate_limit_violation(text, text, text, text) TO agency_app;
GRANT EXECUTE ON FUNCTION agency.purge_security_defense_data(integer, integer) TO agency_app;
