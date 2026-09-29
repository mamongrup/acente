#!/usr/bin/env node
/*
 * Local NEXUS <-> Acente approval/feed harness.
 * Uses the production HTTP shapes, but deliberately keeps state in memory so
 * it can run on a clean checkout with only Node.js installed.
 */
import assert from "node:assert/strict";
import http from "node:http";

const nexusKey = "local-nexus-key";
const agencyKey = "local-agency-key";
const tenants = {
  "tenant-a": { name: "Acente A", listings: new Map() },
  "tenant-b": { name: "Acente B", listings: new Map() },
};
const nexusListings = [
  { id: "listing-a", title: "A Hotel", locality: "Antalya", region: "TR", category: "hotel", capacity: "2", price: "12500", currency: "TRY", description: "A", shortDescription: "A", images_json: "[]", contractFieldsJson: "{}", priceUnit: "night", availabilityMode: "calendar", contactPolicy: "direct", cancellationPolicy: "standard", agencies: ["tenant-a"] },
  { id: "listing-b", title: "B Villa", locality: "Bodrum", region: "TR", category: "holiday_home", capacity: "4", price: "22000", currency: "TRY", description: "B", shortDescription: "B", images_json: "[]", contractFieldsJson: '{"property_type":"villa"}', priceUnit: "night", availabilityMode: "calendar", contactPolicy: "direct", cancellationPolicy: "standard", agencies: ["tenant-b"] },
];
const callbackAttempts = new Map();
const connectionRequests = new Map();
const checks = [];
let requestCounter = 0;

function json(res, status, body) { res.writeHead(status, { "content-type": "application/json" }); res.end(JSON.stringify(body)); }
function body(req) { return new Promise((resolve, reject) => { let raw = ""; req.on("data", c => raw += c); req.on("end", () => { try { resolve(raw ? JSON.parse(raw) : {}); } catch (e) { reject(e); } }); }); }
function auth(req, key) { return req.headers.authorization === `Bearer ${key}`; }

const nexus = http.createServer(async (req, res) => {
  const url = new URL(req.url, "http://127.0.0.1");
  if (req.method === "POST" && url.pathname === "/v1/agency/connection-request") {
    assert.equal(auth(req, agencyKey), true, "connection request must use agency bearer key");
    const agencyId = url.searchParams.get("agency_id");
    assert.ok(tenants[agencyId], "unknown tenant must not be accepted");
    const requestId = `req-${++requestCounter}`;
    connectionRequests.set(requestId, { agencyId, status: "pending" });
    return json(res, 200, { ok: true, request_id: requestId, status: "pending" });
  }
  if (req.method === "GET" && url.pathname === "/api/v1/feed/listings") {
    assert.equal(auth(req, agencyKey), true, "feed must use agency bearer key");
    const agencyId = url.searchParams.get("agency_id");
    const listings = nexusListings.filter(x => x.agencies.includes(agencyId)).map(({ agencies, ...x }) => x);
    return json(res, 200, { listings });
  }
  json(res, 404, { ok: false, error: "not_found" });
});

const agency = http.createServer(async (req, res) => {
  if (req.method !== "POST" || req.url !== "/v1/nexus/connection-approved") return json(res, 404, { ok: false });
  assert.equal(auth(req, nexusKey), true, "callback must use NEXUS callback key");
  const payload = await body(req);
  assert.ok(tenants[payload.agency_id], "callback tenant must exist");
  const attempts = (callbackAttempts.get(payload.agency_id) ?? 0) + 1;
  callbackAttempts.set(payload.agency_id, attempts);
  // The first delivery is transiently unavailable. The retry must be safe.
  if (attempts === 1) return json(res, 503, { ok: false, error: "transient" });
  tenants[payload.agency_id].approved = true;
  tenants[payload.agency_id].apiKey = payload.api_key;
  return json(res, 200, { ok: true });
});

async function request(url, options = {}) {
  const response = await fetch(url, options);
  const data = await response.json();
  return { status: response.status, data };
}
async function deliverWithRetry(tenantId, apiKey, maxAttempts = 3) {
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    const result = await request(`${agencyUrl}/v1/nexus/connection-approved`, {
      method: "POST", headers: { authorization: `Bearer ${nexusKey}`, "content-type": "application/json" },
      body: JSON.stringify({ agency_id: tenantId, api_key: apiKey }),
    });
    if (result.status >= 200 && result.status < 300) return result;
    if (result.status < 500 || attempt === maxAttempts) throw new Error(`callback failed: ${result.status}`);
    await new Promise(resolve => setTimeout(resolve, 10 * 2 ** (attempt - 1)));
  }
}
async function approveRequest(requestId, apiKey) {
  const connection = connectionRequests.get(requestId);
  assert.ok(connection, "approval must reference a real connection request");
  assert.equal(connection.status, "pending");
  connection.status = "approved";
  return deliverWithRetry(connection.agencyId, apiKey);
}
async function syncFeed(tenantId) {
  const result = await request(`${nexusUrl}/api/v1/feed/listings?agency_id=${tenantId}`, { headers: { authorization: `Bearer ${agencyKey}` } });
  assert.equal(result.status, 200);
  for (const listing of result.data.listings) tenants[tenantId].listings.set(listing.id, listing);
}

let nexusUrl, agencyUrl;
await new Promise(resolve => nexus.listen(0, "127.0.0.1", resolve));
await new Promise(resolve => agency.listen(0, "127.0.0.1", resolve));
nexusUrl = `http://127.0.0.1:${nexus.address().port}`;
agencyUrl = `http://127.0.0.1:${agency.address().port}`;
try {
  const connection = await request(`${nexusUrl}/v1/agency/connection-request?agency_id=tenant-a&agency_name=Acente%20A&agency_endpoint=${encodeURIComponent(agencyUrl)}`, { method: "POST", headers: { authorization: `Bearer ${agencyKey}` } });
  assert.equal(connection.status, 200); assert.equal(connection.data.ok, true); assert.equal(connection.data.status, "pending");
  checks.push("connection request: pending");
  await approveRequest(connection.data.request_id, "issued-a");
  checks.push("approval + callback: accepted");
  await deliverWithRetry("tenant-a", "issued-a"); // idempotent duplicate delivery
  assert.equal(callbackAttempts.get("tenant-a"), 3);
  checks.push("callback retry + idempotency: 3 deliveries, one final state");
  assert.equal(tenants["tenant-a"].apiKey, "issued-a");
  await syncFeed("tenant-a"); await syncFeed("tenant-a"); // idempotent upsert
  assert.deepEqual([...tenants["tenant-a"].listings.keys()], ["listing-a"]);
  checks.push("tenant-a feed sync: one listing, repeat-safe");
  await syncFeed("tenant-b");
  assert.deepEqual([...tenants["tenant-b"].listings.keys()], ["listing-b"]);
  assert.equal(tenants["tenant-a"].listings.has("listing-b"), false, "tenant isolation violated");
  checks.push("tenant isolation: tenant-a cannot see tenant-b listing");
  console.log("PASS local NEXUS connection harness");
  for (const check of checks) console.log(`  [OK] ${check}`);
} finally { nexus.close(); agency.close(); }
