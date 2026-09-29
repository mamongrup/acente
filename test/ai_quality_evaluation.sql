BEGIN;
DO $$
BEGIN
  IF agency.ai_quality_text_rules(
    '{"contains":["otel"],"not_contains":["garanti"],"max_length":30}'::jsonb,
    '{"text":"otel önerisi"}'::jsonb
  ) IS DISTINCT FROM true THEN RAISE EXCEPTION 'expected_pass'; END IF;

  IF agency.ai_quality_text_rules(
    '{"contains":["uçuş"]}'::jsonb,
    '{"text":"otel önerisi"}'::jsonb
  ) IS DISTINCT FROM false THEN RAISE EXCEPTION 'expected_fail'; END IF;

  IF agency.ai_quality_text_rules(
    '{"contains":42}'::jsonb,
    '{"text":"otel"}'::jsonb
  ) IS NOT NULL THEN RAISE EXCEPTION 'invalid_rule_must_wait'; END IF;

  IF agency.ai_quality_text_rules(
    '{"contains":["otel"]}'::jsonb,
    NULL
  ) IS NOT NULL THEN RAISE EXCEPTION 'missing_output_must_wait'; END IF;

  RAISE NOTICE 'AI quality rules passed';
END $$;
ROLLBACK;
