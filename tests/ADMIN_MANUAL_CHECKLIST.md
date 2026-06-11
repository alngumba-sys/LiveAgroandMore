# Admin Platform — Manual QA Checklist

Walk through this on a desktop browser (Chrome / Firefox / Safari) and a tablet width for responsive checks. Estimated time: **45–60 minutes**. URL: `https://agroandmorehub.com`.

> Hard-refresh before each section (Cmd/Ctrl + Shift + R) to make sure you're testing the latest deploy.

---

## A. Login + session

- [ ] Visit `https://agroandmorehub.com` (root). Lands on the **login page**, not anywhere else.
- [ ] Login form shows: email field, password field, "Sign in" button, "Forgot password?" link, login background image (from `settings.login_bg_url`).
- [ ] Empty email + Sign in → red error: "Please enter your email and password."
- [ ] Wrong password → red error: "Incorrect email or password."
- [ ] Correct password → redirects to `/admin.html`.
- [ ] Hard refresh while logged in → stays on `/admin.html`, no re-auth needed.
- [ ] Open `/admin.html` directly in an incognito tab → bounces back to `/index.html`.
- [ ] **Logout** (from Settings → Password & security → "Sign out of this session", OR the user menu in the top bar) → returns to login, session cleared.
- [ ] After logout, hitting Back in browser does NOT take you back into the admin.
- [ ] **"Forgot password"** → enter email → click → green confirmation banner: "Password reset email sent."

## B. MFA (Two-Factor Authentication)

- [ ] Settings → Password & security → scroll down to "Two-Factor Authentication" card.
- [ ] Click "Enable two-factor authentication" → QR code + secret + verify input appear.
- [ ] Scan QR with Google Authenticator (or paste secret manually).
- [ ] Enter the current 6-digit code → green "Two-factor authentication is ON" badge appears.
- [ ] **Backup**: copy the secret and save in a password manager. Do this NOW before testing disable.
- [ ] Sign out → sign back in → after email+password, the OTP screen appears with "Open your authenticator app…".
- [ ] Enter the current 6-digit TOTP code → land in admin.
- [ ] Enter a wrong code → red error "That code didn't match…", input clears, focus returns to first digit box.
- [ ] In admin, Settings → Password & security → "Turn off 2FA" → confirm dialog → green toast → state returns to "Enable two-factor authentication" button.

## C. Dashboard

- [ ] Dashboard is the default landing page (top of sidebar).
- [ ] Four KPI cards visible: Sales today, Orders today, Pending payments, Active agents.
- [ ] Numbers reflect real Supabase data (not the demo placeholders). Pending banner is **not** shown if you have real orders.
- [ ] Date-range picker (Today / 7d / 30d) works without crashing.
- [ ] No errors in browser DevTools console.

## D. Products & Shop

- [ ] Products list shows all products from the `products` table (12 rows currently — Mancozeb, Rocket, DAP, etc).
- [ ] Filter by **category** (Seeds, Fertilizers, etc) narrows the list correctly.
- [ ] Search by product name updates the list in <500ms.
- [ ] **+ Add Product** → drawer opens.
  - [ ] Required-field validation: empty name → toast; no category → toast; price ≤ 0 → toast.
  - [ ] "Show on shop" toggle defaults **ON** for new products (we explicitly fixed this).
  - [ ] Agent price > retail price → blocked with friendly toast.
  - [ ] Invalid SKU chars (spaces, !@#) → blocked.
  - [ ] Duplicate SKU → "SKU already in use by …" toast.
  - [ ] Save & Publish → row appears in the list immediately with status=active.
  - [ ] Open mobile app in another tab → product visible on the matching category page within 5s.
- [ ] **Edit** an existing product → drawer pre-fills with current values → save → changes reflect on mobile.
- [ ] **Save as Draft** → status=draft, NOT visible on mobile shop.
- [ ] **Archive** a product → row disappears from default list; toggle "Archived" filter to see it.
- [ ] **Restore** an archived product → status reverts to active.
- [ ] **Bulk delete** (if you select multiple rows and use the action menu) → confirmation required.
- [ ] **Product images** — paste a URL, save, refresh — image appears in the row thumbnail.

## E. Produce Prices

- [ ] List shows current prices per crop per region.
- [ ] Edit a price → save → mobile Sell My Produce tab reflects within 30s.

## F. Traceability

- [ ] Batch list renders with crop, stage, district, weight columns.
- [ ] Create a new batch → assign to a farmer → save.
- [ ] Advance stage (harvested → warehoused → processing → in_transit → exported) — each advance is logged in `traceability_stages`.

## G. Orders

- [ ] Order list paginates without crashing.
- [ ] Filter by status chips (Pending, Confirmed, Dispatched, Delivered, Completed, Cancelled) updates the list.
- [ ] Tap an order row → detail drawer shows items, customer, delivery info, payment.
- [ ] Update order status (e.g., Confirmed → Dispatched) → row badge updates, customer notification fires (if push wired up).
- [ ] **Diaspora Orders** tab → list shows only Diaspora orders (filtered by customer role).
- [ ] Cancel an order → status → cancelled, refund flow if payment_method=visa.

## H. Agents & Leaderboard

- [ ] Leaderboard tab → top performers sorted by total commission this month.
- [ ] All agents tab → full list with phone, district, total sales.
- [ ] Pending approval tab → shows agents with status=pending_approval; **Approve** button switches to active; **Reject** archives.
- [ ] Commissions tab → month picker → CSV export of commission report.

## I. Field Officers

- [ ] Officer list with district + total visits.
- [ ] Drill into officer profile → see their `farm_visits` records (filtered by `fo_id`).
- [ ] Mark officer as verified → status changes.

## J. Advisory Content

- [ ] Videos + Radio recordings list.
- [ ] **+ Add** → URL + language + crop tag + thumbnail.
- [ ] Mark inactive → mobile Advisory tab stops showing it within 30s.

## K. AI Chatbot logs

- [ ] List of `bot_conversations` rows: question, matched article title, helpful 👍/👎, fallback_used.
- [ ] Sort by created_at desc by default.
- [ ] **Look for gaps**: filter `fallback_used=true` to see questions the bot couldn't answer — add KB articles for those topics.

## L. Push Notifications

- [ ] Compose form: title, body, audience selector (All / Farmers / Agents / FOs / Diaspora), schedule.
- [ ] Schedule a draft → appears in the list with status=scheduled.
- [ ] Cancel a scheduled push before send → status=draft.
- [ ] Send immediately → status=sent.
- [ ] (Push notifications won't actually reach mobile devices until you wire up Firebase — but the DB row should exist.)

## M. Analytics & Reports

- [ ] Page loads with **no "Illustrative data — connect Supabase" banner** (we fixed this).
- [ ] Four KPI cards: Total Revenue, Completed Orders, Avg Order Value, Top District.
- [ ] Month picker (‹ Apr 2026 ›) navigates without errors.
- [ ] Empty months show "No data yet for this month" friendly messages, not fake data.
- [ ] **Export CSV** downloads a real .csv file with the displayed month's data.
- [ ] **Export PDF** opens a PDF preview / download with the same data.
- [ ] Sales by district reflects real `orders.customer.district` join (was a known issue we fixed).

## N. Finance

- [ ] Finance page loads.
- [ ] Odoo connection state visible (likely "Not connected" by default).

## O. Users & Roles

- [ ] Staff list shows all `staff_profiles` rows with role badge.
- [ ] Active 2FA shows a green ✓ in the 2FA column.
- [ ] **Invite Member** → drawer with email, name, optional phone (we added this), role, outlet.
  - [ ] Phone validation: empty allowed; if filled, must match Uganda 9-digit format.
  - [ ] Submit → toast "Invite sent to {email}. They'll appear in the user list once they sign in."
  - [ ] Invited user gets the OTP email and can sign in via the mobile app.
- [ ] **Farmer / Agent / FO / Diaspora** tabs → list users from `app_users`.

## P. Settings — all sub-tabs

- [ ] **Organization profile** — name, registration number, contact info save and persist.
- [ ] **Branding & palette** — color pickers, logo URL, tagline save.
- [ ] **Commission rate** — number input, save, reflects in Agents page commission calculations.
- [ ] **Payment methods** — MTN merchant code, Airtel pay code save without breaking checkout on mobile.
- [ ] **FX rate (USD → UGX)** — saves; Diaspora checkout uses this rate on mobile.
- [ ] **SMS provider** — Africa's Talking / Twilio toggle.
- [ ] **WhatsApp Business** — phone number field; saving updates `settings.whatsapp_number` which the mobile AgroBot escalation button reads.
- [ ] **Odoo connection** — endpoint URL, credentials; status indicator.
- [ ] **Data export schedule** — daily / weekly / monthly toggles.
- [ ] **Audit log** — list of admin actions; filterable by user, action type, date.
- [ ] **Knowledge Base** — 64 articles listed; filter by category; **+ Add Article** opens drawer; search articles by title.
- [ ] **Password & security** — covered in section A + B above.

## Q. Cross-system sanity

- [ ] Admin product changes show up on mobile shop within 30s.
- [ ] Admin price changes show up on mobile produce prices within 30s.
- [ ] Admin invite → mobile login with that email → farmer signs in → appears in Users list.
- [ ] Mobile AgroBot conversation → admin AI Chatbot logs page shows it.
- [ ] Mobile order completion → admin Orders shows it with correct status.

## R. Browser & device matrix

- [ ] Chrome desktop (latest) — primary, works fully.
- [ ] Firefox desktop — sidebar nav, modals, drawers all work.
- [ ] Safari desktop — same.
- [ ] Tablet (iPad / 1024px wide) — sidebar collapses or stays open; tables scroll horizontally; drawers don't get cut off.
- [ ] Phone (375px wide) — admin is **not** designed for phones. Confirm with a brief check it doesn't crash; full mobile workflows happen in the PWA.

## S. Performance / robustness

- [ ] Open DevTools → Network tab → reload `/admin.html` — no failing requests (no 4xx / 5xx).
- [ ] DevTools → Console — no errors or warnings on page load.
- [ ] Throttle to "Slow 3G" → admin still becomes interactive within 10s.
- [ ] Pages with large lists (Products, Orders) — open one, leave for 5 minutes, click into a detail; session is still valid.
- [ ] Multi-tab — open admin in two tabs, log out in one, the other should detect and redirect on next nav.

## T. Security spot-checks

- [ ] Browser DevTools → Console: try `sb.from('app_users').delete().eq('id', 'other-user-id')` — should be denied by RLS (we hardened this).
- [ ] DevTools → Application → Local Storage → confirm the only Supabase key stored is the session JWT (no plaintext password, no service-role key).
- [ ] View page source of `/admin.html` → confirm NO mention of the service-role key. Only the anon key should appear.
- [ ] Open Network tab while logging in → confirm the password is sent over HTTPS (the URL bar shows https://).

---

When done, save this completed checklist as `tests/runs/admin-YYYY-MM-DD.md` for your records.
