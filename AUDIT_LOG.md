# Security & Bug Audit Log

**Date:** 2026-05-29
**Auditor:** Claude Opus 4.6 (automated)

---

## Module 1: app.html (Mobile Farmer App)

| # | File | Bug | Fix | Reason |
|---|------|-----|-----|--------|
| 1 | app.html:10983 | XSS: `p.name`, `p.brand`, `p.category` rendered via innerHTML without sanitization | Added `escHtml()` helper; wrapped all user-data interpolations | Malicious product names could inject scripts |
| 2 | app.html:11435 | XSS: cart `item.name` in innerHTML | Wrapped with `escHtml()` | Same XSS vector via cart items |
| 3 | app.html:12083 | XSS: `item.product_name` in order detail innerHTML | Wrapped with `escHtml()` | DB-sourced product names could contain HTML |
| 4 | app.html:13611 | XSS: user email interpolated into innerHTML | Wrapped with `escHtml()` | Email input could contain HTML |
| 5 | app.html:14817 | XSS: `u.full_name` in customer card innerHTML | Wrapped with `escHtml()` | User-controlled name field |
| 6 | app.html:10924 | NaN propagation in `cartTotal()` if price/qty are strings or undefined | Added `parseFloat`/`parseInt` guards | Prevents cart showing "UGX NaN" |

## Module 2: Platform/admin.html (Admin Dashboard)

| # | File | Bug | Fix | Reason |
|---|------|-----|-----|--------|
| 7 | admin.html:3507 | Runtime crash: `getElementById('sbCollapseBtn').addEventListener()` throws if element missing | Added null guard | Element may not exist on all pages |
| 8 | admin.html:3122 | XSS: context menu used `fn.toString()` in onclick attributes | Replaced with handler registry (`_ctxHandlers[]`) + `escHtml()` on labels | Function serialization allowed code injection |
| 9 | admin.html:12 locations | Null dereference: `.full_name.split(' ')` crashes when full_name is null | Added `(x.full_name\|\|'?').split(...)` guard to all 12 instances | Staff/user profiles can have null names |

## Module 3: Platform Auth Pages

| # | File | Bug | Fix | Reason |
|---|------|-----|-----|--------|
| 10 | password-reset.html:123-124 | Weak recovery detection: `document.referrer.includes('index.html')` allowed bypassing recovery flow | Removed referrer check, rely only on Supabase `PASSWORD_RECOVERY` event | Anyone navigating from login could reset passwords without a valid token |
| 11 | password-reset.html:166 | No password strength enforcement | Added validation requiring uppercase + number | Users could set trivially weak passwords |

## Module 4: Netlify Serverless Functions

| # | File | Bug | Fix | Reason |
|---|------|-----|-----|--------|
| 12 | send-admin-invite.js:155 | Hardcoded portal URL ignores caller's `loginUrl` parameter | Use `loginUrl \|\| fallback` | Emails pointed to wrong environment in staging/dev |
| 13 | admin-reset-password.js:121 | Same hardcoded portal URL bug | Same fix | Same reason |
| 14 | verify-sms-otp.js:66,113 | Information disclosure: DB schema and error details leaked to client | Log details server-side, return generic messages | Attackers could map internal DB structure |
| 15 | send-sms-otp.js:74,99,103,143 | Same info disclosure across 4 error paths | Same fix pattern | Same reason |

## Module 5: USSD Module

| # | File | Bug | Fix | Reason |
|---|------|-----|-----|--------|
| 16 | adminHandler.js:21 | Weak session tokens using `Math.random()` | Replaced with `crypto.randomBytes(32).toString('hex')` | Math.random is predictable; session hijacking risk |
| 17 | index.js:167-178 | Unhandled promise rejection on `/chat` endpoint crashes server | Added try-catch with 500 response | Any chatHandler error killed the Express process |
| 18 | index.js:181-184 | Same issue on `/chat/categories` | Added try-catch | Same crash risk |
| 19 | adminHandler.js:103,181 | XSS: error messages rendered without escaping | Wrapped with `esc()` | Reflected XSS via error parameter |

## Module 6: Service Worker

| # | File | Bug | Fix | Reason |
|---|------|-----|-----|--------|
| 20 | service-worker.js:102 | Non-HTML assets (API calls, images) fall back to `index.html` on network failure | Return `504 Offline` response instead | API calls received HTML responses, causing silent data corruption |

## Module 7: Database Migrations

| # | File | Issue | Fix | Severity |
|---|------|-------|-----|----------|
| 21 | db/2026-05-29_fk_indexes.sql | Missing indexes on FK columns across 15+ tables | Dynamic DO block creates indexes for all FK columns missing them | High (perf) |
| 22 | db/2026-05-29_rls_fixes.sql | Settings table writable by any authenticated staff (payment codes, API keys exposed) | Dropped blanket `staff_write`; new `admin_write_settings` policy restricts writes to `md` + `it_admin` only | Medium |
| 23 | db/2026-05-29_rls_fixes.sql | app_sessions missing DELETE policy — stale sessions could never be pruned | Added `staff_delete_sessions` policy FOR DELETE | Medium |

---

## Summary

- **Total issues resolved:** 23
- **Critical (XSS/injection):** 8
- **High (crashes, security bypass, missing indexes):** 7
- **Medium (info disclosure, weak crypto, RLS gaps):** 8
- **Code commits:** 6 (main repo) + 1 (USSD sub-repo)
- **DB migrations applied:** 2 (2026-05-29)
