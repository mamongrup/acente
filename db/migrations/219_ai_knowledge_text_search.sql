-- Search the chunks actually created by the knowledge worker. The tenant is
-- enforced on both document and chunk so a mismatched reference cannot leak.
CREATE INDEX IF NOT EXISTS agency_ai_knowledge_chunks_text_idx
  ON agency.ai_knowledge_chunks USING gin (to_tsvector('simple', content));

CREATE OR REPLACE FUNCTION agency.ai_knowledge_search(
  p_tenant_id uuid,
  p_query text,
  p_limit integer DEFAULT 10
) RETURNS TABLE (
  document_id uuid,
  title text,
  chunk_index integer,
  excerpt text,
  relevance real
)
LANGUAGE sql STABLE
AS $$
  SELECT c.document_id, d.title, c.chunk_index,
         left(c.content, 800),
         ts_rank(to_tsvector('simple', c.content), plainto_tsquery('simple', p_query))
  FROM agency.ai_knowledge_chunks c
  JOIN agency.ai_knowledge_documents d
    ON d.id = c.document_id AND d.tenant_id = c.tenant_id
  WHERE c.tenant_id = p_tenant_id
    AND d.status = 'indexed'
    AND length(btrim(p_query)) > 0
    AND to_tsvector('simple', c.content) @@ plainto_tsquery('simple', p_query)
  ORDER BY 5 DESC, c.document_id, c.chunk_index
  LIMIT least(greatest(coalesce(p_limit, 10), 1), 50);
$$;

GRANT EXECUTE ON FUNCTION agency.ai_knowledge_search(uuid, text, integer) TO agency_app;
