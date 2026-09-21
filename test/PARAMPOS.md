# ParamPOS regression checks

Run from the project root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-parampos.ps1
gleam test
```

The focused script loads PG connection settings from `.env` without printing
them. It requires the current schema through migration 071, Node, PostgreSQL
and Gleam. Port 18089 must be free. Run it against a development database.
The test applies migration 073 inside transactions and rolls back all DDL,
fixtures and payment changes. No real ParamPOS account/card or bank is called.

Coverage:

- Server-priced reservation creation and reuse of order/session on retry;
  conflicting idempotency payloads rejected without extra reservations.
- Duplicate start and callback claims; one SOAP Pay call across successful,
  failed and expired 3D attempts and repeated requests.
- Expired sessions blocked, obsolete pending attempts closed on replacement.
- Signed unsuccessful 3D callbacks close the attempt without a charge;
  tampered hashes cannot mutate it.
- Successful payment atomically confirms payment, order and reservation;
  an injected reservation failure rolls back the payment update.
- A paid order cannot open another session. An ambiguous in-flight payment
  cannot be replaced after expiry.
- Padded SHA1 callback hash, SOAP namespaces/CDATA/entities, bank result field
  names, missing fields, failed/zero receipts and XML declaration rejection.

## Deployment and recovery

Apply `073_parampos_lifecycle.sql` via the usual migration runner before running
the updated application. Previous migration files are unchanged. The new
functions run with caller privileges, not SECURITY DEFINER.

`starting` means a start request has been claimed; `authorized` means the Pay
request has been claimed, **not** that settlement is confirmed. Network errors,
malformed successful responses and persistence failures retain these states.
Do not reset them or retry Pay blindly. Reconcile the order and transaction GUID
with ParamPOS first; then repair local state using the verified result. Automatic
bank reconciliation and a live bank/browser OTP test are not included here.

The SHA2B64 start hash is obtained from ParamPOS's documented SOAP method; it
must not be replaced by the callback SHA1 algorithm. Charge amounts use a comma
decimal separator. References:

- https://dev.param.com.tr/tr/api/odeme
- https://github.com/PARAMPOS/Dotnet-Ornek-Kod/blob/main/src/ParamApi.Sdk/Helpers/HashHelper.cs
- https://github.com/PARAMPOS/Dotnet-Ornek-Kod/blob/main/src/ParamApi.Sdk/Models/Responses/TP_WMD_PAY_Response.cs
