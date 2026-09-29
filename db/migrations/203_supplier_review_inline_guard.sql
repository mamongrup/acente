-- The application DB role owns these functions. A wrapper cannot hide an
-- unchecked owner function from that same role, so move the guard into the
-- decision functions themselves and remove the bypass entirely.
DROP FUNCTION agency.decide_supplier_application(uuid,uuid,uuid,text,text);
DROP FUNCTION agency.decide_supplier_application_document(uuid,uuid,uuid,text,text);

ALTER FUNCTION agency.decide_supplier_application_unchecked(uuid,uuid,uuid,text,text)
  RENAME TO decide_supplier_application;
ALTER FUNCTION agency.decide_supplier_application_document_unchecked(uuid,uuid,uuid,text,text)
  RENAME TO decide_supplier_application_document;

-- Migration user is also the function owner; its EXECUTE privilege was
-- revoked by the wrapper migration and is needed while replacing the body.
GRANT EXECUTE ON FUNCTION agency.decide_supplier_application(uuid,uuid,uuid,text,text) TO agency_app;
GRANT EXECUTE ON FUNCTION agency.decide_supplier_application_document(uuid,uuid,uuid,text,text) TO agency_app;

DO $$
DECLARE
  signature regprocedure;
  definition text;
BEGIN
  FOREACH signature IN ARRAY ARRAY[
    'agency.decide_supplier_application(uuid,uuid,uuid,text,text)'::regprocedure,
    'agency.decide_supplier_application_document(uuid,uuid,uuid,text,text)'::regprocedure
  ] LOOP
    definition := pg_get_functiondef(signature);
    IF position('BEGIN' IN definition) = 0 THEN
      RAISE EXCEPTION 'supplier review function body is missing';
    END IF;
    definition := regexp_replace(
      definition,
      'BEGIN',
      E'BEGIN\n  IF NOT agency.supplier_review_actor_allowed(p_tenant,p_reviewer) THEN\n    RETURN ''forbidden'';\n  END IF;',
      'i'
    );
    EXECUTE definition;
  END LOOP;
END $$;

REVOKE ALL ON FUNCTION agency.decide_supplier_application(uuid,uuid,uuid,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION agency.decide_supplier_application_document(uuid,uuid,uuid,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.decide_supplier_application(uuid,uuid,uuid,text,text) TO agency_app;
GRANT EXECUTE ON FUNCTION agency.decide_supplier_application_document(uuid,uuid,uuid,text,text) TO agency_app;
