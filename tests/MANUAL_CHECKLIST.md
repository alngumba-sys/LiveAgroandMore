# Agro and More — Manual QA Checklist

Things automated tests can't (or shouldn't) check. Walk through this on a real Android device after every meaningful deploy. Estimated time end-to-end: **30–45 minutes**.

> **Tip:** Use a clean incognito Chrome window for every section. Hard-refresh (Cmd/Ctrl + Shift + R) between sections to make sure you're testing the latest deploy, not a cached version.

---

## A. First-time install / PWA experience

- [ ] Visit `https://agro-more-app.netlify.app` in **Chrome on Android**. Within 5 seconds the app loads and shows the splash → intro carousel.
- [ ] In Chrome, tap **⋮ menu → Install app** (or "Add to Home Screen"). The app icon appears on the home screen with the Agro & More logo, not a generic Chrome icon.
- [ ] Launch the installed PWA from the home screen. It opens **fullscreen** with no Chrome address bar, splash advances automatically.
- [ ] Repeat on **Safari on iOS**: Share → Add to Home Screen. Icon, name, and orientation behave the same.

## B. Onboarding visual + copy

- [ ] Splash screen images load (no broken-image icons). The wordmark is crisp at the size shown.
- [ ] Intro carousel scrolls smoothly; the three feature copy lines render fully on a 360px wide phone (no clipping).
- [ ] **All four role cards** on Role Select show: icon, name, description. No card looks broken or has weird spacing.
- [ ] The "Already have an account? Log in" link is visible immediately under Get Started — not buried.

## C. Signup form (Farmer) — visual + UX

- [ ] All form fields are labelled and tappable. Tapping a field doesn't zoom the page (`viewport` meta is set correctly).
- [ ] **District dropdown** opens a native picker on Android. The list contains Uganda districts including Mpigi, Wakiso, Mbarara, Kampala. No "undefined" option.
- [ ] **Sub-county dropdown** opens. (Future: should ideally filter by district.)
- [ ] **Age pills** — tapping one orange-fills it and unfills the other. Tap feels responsive (<150ms).
- [ ] **Crop pills** — tapping any toggles independently. Default selection (Matooke, Coffee, Maize, Beans on; Hass, Cassava off) is reasonable.
- [ ] **Farm size** dropdown contains all options (< 0.5 acres through 10+ acres).
- [ ] **Village/Parish** accepts arbitrary text.
- [ ] **Agreement checkbox** is checked by default. Tapping unchecks it. Trying to "Send OTP" with it unchecked shows a toast.
- [ ] **Phone field** — `+256` prefix is visible and read-only. Entering 9 digits leaves the field populated; entering 12 digits should be truncated or fail validation.

## D. Email + OTP flow (real delivery)

> **Use your own email here so you can read the inbox.**

- [ ] Sign up with a fresh email you control. Submit.
- [ ] Within 60 seconds you receive an email from **`noreply@agroandmorehub.com`** subject `Your Agro & More sign-in code` (or similar). Body shows a **6-digit code**.
- [ ] Code expires in 1 hour. (Email says "1 hour", not "10 minutes".)
- [ ] Enter the 6-digit code → you land on the home screen with greeting using your real first name.
- [ ] **Resend OTP** — wait the cooldown timer down. Click Resend. A new email arrives.
- [ ] **Rate limit** — try resending 3 times rapidly. Toast says "Please wait about XX seconds…" not the raw Supabase error.

## E. Home screen / Dashboard

- [ ] Greeting says **your name** (not "Akbert", "Andrew", "Nakato" — those are historical test data).
- [ ] Weather banner shows your district name at top.
- [ ] Four quick-action tiles (Shop inputs, Talk to expert, Today's prices, Hire a tractor) all open the right destination.
- [ ] Seasonal tip card shows a real-looking image, not a broken thumbnail.
- [ ] The "Trace my produce" input + Trace button render correctly.

## F. Shop tab

- [ ] **Category grid** shows 7 categories with real counts (Seeds 3, Fertilizers 3, Crop Protection 3+, Tools 1, Irrigation 1, Livestock 0, Post-harvest 1 — adjust if you've added products).
- [ ] **"All · N"** chip shows real total (≈ 12+ depending on your DB), not "1,248".
- [ ] **"In stock"** chip is NOT present.
- [ ] Tap **each category** in turn. List shows "Loading…" briefly then real products. NO flash of products from the previous category.
- [ ] **Livestock** (or any empty category) shows "No products in this category yet" not stale ones.
- [ ] "Showing 1–N of N" matches the actual product count.
- [ ] Each product row has: thumbnail (or coloured placeholder), name, brand, category, price, qty stepper.
- [ ] **+** and **−** steppers update the count and the sticky-foot total correctly.
- [ ] Tap **Next** at the bottom — goes to Cart with the right items + subtotal.

## G. Cart + checkout

- [ ] Cart screen shows each product with the quantity entered.
- [ ] Three delivery options visible: Drive-through, In-store pickup, Boda delivery. Tapping each selects it (radio fills) and updates the total.
- [ ] **Proceed to Pay** advances to Boda Delivery screen (or directly to payment if Drive-through).
- [ ] On the cart, **bottom-nav tabs are clickable** — tap Home, Shop, Advisory, Sell, Profile — each navigates correctly.
- [ ] **Back arrow** (top-left) returns to the previous screen.

## H. Advisory tab + AgroBot

- [ ] Advisory landing shows four tiles: Talk to Expert, Ask AgroBot, Watch Videos, Radio Recordings.
- [ ] Tap **Ask AgroBot**. Chat screen loads with a greeting using your first name.
- [ ] Four **suggested question pills** are clickable.
- [ ] Tap a suggestion. Bot shows "AgroBot is typing…" briefly, then answers with the matched KB article title + content.
- [ ] **👍 / 👎** appear under the answer. Tap one — it changes to "Thanks for the feedback!" and the click is logged to `bot_conversations`.
- [ ] Type a custom question like "How do I treat coffee leaf rust?" — bot finds a relevant article.
- [ ] Type a nonsense question like "asdf qwerty random". Bot replies "I don't have an answer to that yet" + "Talk to a Field Officer" escalation button.
- [ ] Tap **Talk to a Field Officer** → WhatsApp opens with a chat to **+256 763 785 822** and message body includes your name + district + the question you asked.

## I. Profile tab

- [ ] **Avatar** shows your initials (not "NN").
- [ ] **Name** is your real name.
- [ ] **FARMER** badge present.
- [ ] **Location** shows your district · sub-county.
- [ ] **Phone** shows your real +256 number, not "+256 772 456 123" mockup.
- [ ] Stats row: "Member since" shows the current month, Orders shows real count (likely 0 for new account).
- [ ] Tap **Edit Profile** → form pre-fills with your data.
- [ ] Change your name and save → returns to Profile with the new name.
- [ ] Tap **Log out** → confirmation → land on intro screen (onboarding-2) with **"Already have an account? Log in"** visible.

## J. Cross-system: admin adds product → mobile sees it

- [ ] On agroandmorehub.com (admin), Settings → Products → **+ Add Product**.
- [ ] Note: **"Show on shop"** toggle is **ON by default**.
- [ ] Fill name, category (e.g. Fertilizers), price; click **Save & Publish**.
- [ ] Open mobile in another tab → Shop → Fertilizers → the new product appears within 5 seconds.
- [ ] Now edit the product on admin, **uncheck** "Show on shop", save. Hard-refresh mobile → product disappears from Fertilizers list.

## K. Cross-system: admin invites farmer → farmer signs in

- [ ] Admin → Users → **Invite Member** → fill email/name → Save.
- [ ] Toast shows "6-digit sign-in code sent to …" (success) OR honest error if Resend rejects.
- [ ] Open mobile in another tab → tap **Log in** → enter the invited email → enter the OTP from the inbox → land on home with the admin-supplied name + role.

## L. Connectivity edge cases

- [ ] Turn airplane mode on, reload the PWA → it still opens (service worker serves cache).
- [ ] Try to sign in while offline → friendly toast ("Not connected — check internet"), NO crash.
- [ ] Turn airplane mode off → retry → succeeds.
- [ ] On a slow 3G connection (Chrome DevTools throttle): every screen still renders within 8s.

## M. Multi-user / concurrency

- [ ] Sign in on Phone A with farmer A. Then sign in on Phone B (or a fresh incognito) with farmer B.
- [ ] Place a test order on Phone A. Verify it does NOT appear in Phone B's orders.
- [ ] Sign out on Phone A. Phone B's session stays intact.
- [ ] Phone A signs back in as farmer A → can see their own order, NOT farmer B's.

## N. Accessibility quick pass

- [ ] All buttons are at least 44×44 px (tappable with thumb).
- [ ] Text on the orange CTAs is white and high-contrast.
- [ ] No important content relies on colour alone (icons + labels everywhere).
- [ ] Page works at 200% browser zoom (Cmd+ × a few times) — no overlap, no cut-off.

## O. Brand + content correctness

- [ ] All images load (no broken-image icons). Replace any Unsplash placeholders with licensed Ugandan photography before public launch.
- [ ] All currency is **UGX** with commas (e.g., `UGX 18,000`), never USD by accident.
- [ ] All phone numbers are formatted `+256 7XX XXX XXX`.
- [ ] No typos in body copy (run a quick read of: home, advisory, shop, profile, agrobot greeting).
- [ ] Language is consistent — Luganda phrases like "Wasuze otya" still rotate correctly with time of day.

## P. Stop-the-launch checks (none of these may be open before going live)

- [ ] Resend domain remains **Verified** (https://resend.com/domains).
- [ ] Supabase auth config: `mailer_otp_length = 6`, `smtp_admin_email = noreply@agroandmorehub.com`.
- [ ] All Personal Access Tokens previously issued to me are **revoked** (Supabase + Netlify).
- [ ] Test users (`qa-test-*`, `victim-*`, `invited-*`) are cleaned up — run `npm run cleanup` from `tests/`.
- [ ] No Test products with name "Test1/Test2/Test3" remain in the `products` table.

---

**Walkthrough record.** When you've completed a pass, save this file to `tests/runs/YYYY-MM-DD.md` with your initials and which boxes failed so we have a history.
