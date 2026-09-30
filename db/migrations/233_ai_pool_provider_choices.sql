-- Keep the tenant scoped key pool usable when OpenAI is out of credit.
ALTER TABLE agency.ai_key_pool
  DROP CONSTRAINT IF EXISTS ai_key_pool_provider_check;

ALTER TABLE agency.ai_key_pool
  ADD CONSTRAINT ai_key_pool_provider_check
  CHECK (provider IN ('openai', 'deepseek', 'google', 'gemini', 'glm'));
