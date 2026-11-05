# Phone sign-in with WhatsApp codes

Everything needed to run, configure and troubleshoot signing in to Kuphanda with
a mobile number and a six-digit code delivered by WhatsApp.

Written for the version in this repository (`1.2.0`). The code is done; what is
left is a Meta account, five environment variables, and a deploy.

---

## 1. What this does — and what it does not

**Does**

- `POST /api/v1/auth/otp/start` sends a code to a WhatsApp number.
- `POST /api/v1/auth/otp/verify` exchanges the code for a Sanctum token.
- Three purposes: sign in, sign up, and attach a number to an existing account.
- Numbers are normalised to E.164, one row, one account.
- Email + password and **Continue with Google** are untouched and still work.

**Does not**

- Replace email login. It is a second way in, and deliberately so: a learner with
  a flat phone, no data, or a number that changed hands must still reach their
  library.
- Send anything but the code. No marketing, no reminders on this channel.
- Work without Meta credentials — it answers `503 OTP_CHANNEL_UNAVAILABLE` and
  says why (`/api/v1/health` → `features.whatsapp_otp.configured`).

## 2. Why Meta directly, and not Mithenga

Mithenga is a WhatsApp Business Platform product with **its own workspace
login**. Its `send-otp` endpoint signs people into Mithenga; it is not a
documented outbound API for third-party applications, and using it would put
Kuphanda's learners inside someone else's tenant, on someone else's message log,
with a per-message margin attached and one more thing that can fail.

Kuphanda can own its own WhatsApp Business Account and call the Cloud API
directly. That is what this implementation does. The transport sits behind
`App\Contracts\OtpSender`, so if a provider is ever wanted — for billing in MWK,
or because they hold the WABA — only `CloudApiOtpSender` is replaced. Nothing in
the sign-in flow changes.

---

## 3. Part A — Meta setup (the only part that takes real time)

Do this first; template approval is the long pole.

### A1. Business portfolio and WhatsApp Business Account

1. Go to <https://business.facebook.com> → **Business settings**.
2. Confirm you have a business portfolio for Kuphanda. If not, create one with
   the school's or company's legal name and address — this is what appears in
   Meta's records and on invoices.
3. **Accounts → WhatsApp accounts → Add** → create a WhatsApp Business Account
   (WABA). Note the WABA id afterwards: it is a separate number from the phone
   number ID and is easy to lose.

   Confirmed on 5 Nov 2026: the portfolio in use is **Ultrashots**
   (`business_id=936951391726878`) and it holds **no** WABA yet, so this is the
   step that starts everything. The working URL is
   `business.facebook.com/latest/settings/whatsapp_business_presence?business_id=936951391726878`
   — the older `/latest/settings/whatsapp_accounts` path redirects to home.

### A2. A phone number for the business

The number must be able to receive an SMS or a voice call, and **must not
currently be registered to WhatsApp** (personal or Business app). A number used
in the WhatsApp Business app has to be deleted from that app first.

1. WABA → **Phone numbers → Add phone number**.
2. Enter the display name (e.g. `Kuphanda Library`) — Meta reviews this, and it is
   what recipients see.
3. Verify by SMS or voice.

### A3. Collect the two identifiers

**WhatsApp → API Setup** in the Meta app dashboard
(<https://developers.facebook.com/apps> → your app → WhatsApp):

| Value | Where | Goes into |
|---|---|---|
| **Phone number ID** (a long number, e.g. `123456789012345`) | "From" number dropdown | `WHATSAPP_PHONE_NUMBER_ID` |
| **WhatsApp Business Account ID** | API Setup page | keep for reference |

The Phone number ID is **not** the display number (`+265...`). Copying the
display number is the single most common setup mistake and produces a `404` from
Graph.

### A4. A permanent access token

The 24-hour token on the API Setup page is for testing only; it will expire and
take sign-in with it, at night, with no warning.

1. **Business settings → Users → System users → Add** — role *Admin* (or
   *Employee* with the assets below).
2. Assign assets: the **app** (full control) and the **WABA** (full control).
3. **Generate new token** → select the app → tick
   `whatsapp_business_messaging` and `whatsapp_business_management`.
4. Copy it once. It becomes `WHATSAPP_TOKEN`. Treat it as a password: it can send
   messages billed to the school.

### A5. Create the AUTHENTICATION template

**WhatsApp Manager → Message templates → Create template.**

- **Category**: `Authentication`. This is not cosmetic — Meta rejects login codes
  in Utility or Marketing templates.
- **Name**: `kuphanda_auth_code` (lowercase, underscores).
- **Language**: `English (US)` → `en_US`, unless the school writes in Chichewa,
  in which case add that language too and set `WHATSAPP_OTP_LANGUAGE`.
- **Body**, with exactly one variable:

  ```
  {{1}} is your Kuphanda verification code. For your security, do not share it.
  ```

  Meta's authentication templates normally also expect the standard
  expiry/security footer; keep the wording short and do not add marketing text,
  links, or a second variable.
- **Button**: add **Copy code**. This is the button the API targets at index `0`.
  If you build the template *without* it, set `WHATSAPP_OTP_CODE_BUTTON=false`,
  otherwise Meta rejects the send with a parameter-count error.
- Submit. Approval is usually minutes, occasionally a day.

**Or skip the console entirely.** The authentication body is not editable in the
UI, and its language picker mis-selects under automation, so the command below is
the reliable path — it posts Meta's documented shape and is safe to re-run:

```bash
php artisan whatsapp:template                 # idempotent; reports an existing one
php artisan whatsapp:template --language=en_GB
```

It sets `code_expiration_minutes` from the same TTL the backend enforces, so the
window WhatsApp applies and the window `OtpService` applies cannot drift apart.
If you raise `OTP_TTL_MINUTES`, recreate the template.

Write down the exact name and language — a mismatch with `.env` is `132001`.

### A6. Test the pipe before touching the app

With the test number that Meta provides (it can message up to five verified
recipients, free), run:

```bash
curl -s -X POST \
  "https://graph.facebook.com/v21.0/$WHATSAPP_PHONE_NUMBER_ID/messages" \
  -H "Authorization: Bearer $WHATSAPP_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "messaging_product": "whatsapp",
    "to": "265991234567",
    "type": "template",
    "template": {
      "name": "kuphanda_auth_code",
      "language": { "code": "en_US" },
      "components": [
        { "type": "body", "parameters": [{ "type": "text", "text": "123456" }] },
        { "type": "button", "sub_type": "url", "index": "0",
          "parameters": [{ "type": "text", "text": "123456" }] }
      ]
    }
  }'
```

`200` with `messages[0].id` means everything downstream will work. Anything else
— see §8.

### A7. Then let the app check itself

Once the five values are in `.env`, this replaces the curl above and checks each
layer in the order it can fail:

```bash
php artisan whatsapp:check                        # config, token, number, template
php artisan whatsapp:check --send=0991234567      # and one real message
```

It prints a checklist, never the token, and names the broken layer: a `404`
means the display number was pasted where the phone number ID belongs, `190`
means the token expired, a template that exists but is `PENDING` is called out as
such, and a rejected send prints Meta's code with one plain sentence about what
to do. Exit code is `0` only when every layer answered.

`--send` bills one authentication message. Use it once.



---

## 4. Part B — Server configuration

Add to `phanda_api/.env` on the server (values from Part A):

```dotenv
WHATSAPP_PHONE_NUMBER_ID=123456789012345
# WABA id — only read by `whatsapp:check` to verify template approval
WHATSAPP_BUSINESS_ACCOUNT_ID=987654321098765
WHATSAPP_TOKEN=EAAG...permanent-system-user-token
WHATSAPP_OTP_TEMPLATE=kuphanda_auth_code
WHATSAPP_OTP_LANGUAGE=en_US
WHATSAPP_API_VERSION=v21.0
WHATSAPP_OTP_CODE_BUTTON=true
```

Optional tuning (defaults are the ones that were reasoned about):

```dotenv
OTP_TTL_MINUTES=10      # how long a code lives
OTP_RESEND_SECONDS=60   # cooldown between sends to one number
OTP_HOURLY_LIMIT=5      # codes per number per hour
OTP_MAX_ATTEMPTS=5      # wrong guesses before the code is retired
```

`deploy/update.sh` will write the WhatsApp block for you if you export
`WHATSAPP_PHONE_NUMBER_ID_` and `WHATSAPP_TOKEN_` before running it; otherwise it
prints a warning that phone sign-in will answer 503. It never invents a token.

---

## 5. Part C — Deploy and verify

```bash
cd /home/kuphanda/kuphanda
bash phanda_api/deploy/update.sh
```

`update.sh` pulls, installs, migrates, syncs the catalogue and prints health.
The two migrations that matter here:

- `2026_11_05_000100_add_phone_to_users_table` — `phone_e164` (unique, nullable),
  `phone_verified_at`, and `email` made nullable;
- `2026_11_05_000200_create_otp_challenges_table` — the codes.

Then:

```bash
curl -s https://app.kuphanda.com/api/v1/health | python -m json.tool
```

Expect:

```json
"whatsapp_otp": { "configured": true, "transport": "whatsapp_cloud_api",
                  "template": "kuphanda_auth_code" }
```

`configured: false` means one of the five values is empty or the config cache is
stale:

```bash
php artisan config:clear && php artisan config:cache
```

---

## 6. Part D — What changed in the code

### API (`phanda_api`)

| File | Role |
|---|---|
| `app/Http/Controllers/Api/V1/AuthController.php` | `startOtp`, `verifyOtp` — the three purposes |
| `app/Services/OtpService.php` | issue/verify, hashing, cooldowns, attempt cap |
| `app/Contracts/OtpSender.php` | transport seam |
| `app/Services/WhatsApp/CloudApiOtpSender.php` | Graph API call, template components |
| `app/Services/WhatsApp/NullOtpSender.php` | refuses cleanly when unconfigured |
| `app/Support/PhoneNumber.php` | E.164 normalisation, masking |
| `app/Models/OtpChallenge.php` | one row per code sent |
| `app/Exceptions/OtpException.php` | reason codes + human sentences |
| `app/Http/Requests/Api/V1/StartOtpRequest.php`, `VerifyOtpRequest.php` | validation |
| `routes/api/v1.php` | the two routes, `throttle:otp` |
| `config/otp.php`, `config/services.php` | tuning and credentials |
| `app/Console/Commands/PruneOtpChallenges.php` | retention (`otp:prune` daily) |
| `tests/Feature/Api/V1/PhoneAuthTest.php` | 19 tests over the rules |

### App (`phanda_app`)

| File | Role |
|---|---|
| `lib/features/profile/phone_sign_in_sheet.dart` | two-step sheet, countdown, all three purposes |
| `lib/core/phone.dart` | same normalisation as the server |
| `lib/state/app_state.dart` | `startPhoneCode`, `signInWithPhoneCode`, `registerWithPhoneCode`, `verifyPhoneLink` |
| `lib/data/api/api_client.dart` | `startOtp`, `verifyOtp` |
| `lib/data/api/api_models.dart` | `OtpStart`, `AuthSession.phone` |
| `lib/features/onboarding/onboarding_screen.dart` | "Continue with phone" leads; email and Google remain |
| `lib/features/profile/sign_in_sheet.dart` | "Use my phone number instead" |
| `lib/features/profile/profile_screen.dart` | "Add a WhatsApp number" for existing accounts |
| `lib/core/widgets/common.dart` | `SheetBody` actions no longer scroll out of view |
| `test/phone_sign_in_test.dart` | normalisation + both sheet paths |

### Contract

```
POST /api/v1/auth/otp/start
  { "phone": "099 123 4567", "purpose": "login" | "signup" | "link" }
  200 { data: { exists, challenge, phone, masked, channel, expires_in, resend_after } }
  409 PHONE_TAKEN · 422 PHONE_INVALID · 429 OTP_RESEND_TOO_SOON | OTP_THROTTLED
  503 OTP_CHANNEL_UNAVAILABLE | OTP_NOT_DELIVERED

POST /api/v1/auth/otp/verify
  { "challenge": "...", "code": "123456", "name": "…(signup only)" }
  200 { data: { user, token } }        login / signup (201) / link (user only)
  422 OTP_INVALID | OTP_EXPIRED | NAME_REQUIRED · 429 OTP_ATTEMPTS_EXCEEDED
```

`exists: false` is the one field the UI branches on: no code was sent because no
account uses that number, so the sheet offers to create one instead of showing an
empty box.

---

## 7. Part E — Testing

### Automated

```bash
cd phanda_api && ./vendor/bin/pest            # 174 API tests, incl. 19 phone tests
cd phanda_app && flutter analyze && flutter test   # 181 app tests
```

The phone tests cover: every way a number is typed; a landline refused before a
send; a code that works once; five wrong guesses retiring it; expiry; the resend
cooldown; sign-up creating an account with no email and a verified number; a
second account refused for the same number; linking refused without a session;
503 when unconfigured; no usable challenge left behind when delivery fails; and
the code stored only as a hash.

### Manual, on a real phone

1. Sign in with email (an existing account).
2. **Profile → Add a WhatsApp number** → your own number → code arrives in
   WhatsApp → enter it. Profile should now read *WhatsApp number*.
3. Sign out.
4. **Continue with phone** → same number → new code → in. Confirm the library,
   classes and progress are yours, not empty.
5. Wrong code: type `000000`. Expect "That code is not right", and **no** session.
6. Resend twice quickly: the second is refused with a wait message.
7. Landline (`021…`) is refused before anything is sent.
8. **Continue with Google** still signs in. Email still signs in.
9. Large text: set the phone font to 1.3× and 2.0× and repeat step 4 — the code
   field and the buttons must stay reachable (the actions row is now pinned).

### On the server, without a phone

```bash
# send
curl -s -X POST https://app.kuphanda.com/api/v1/auth/otp/start \
  -H 'Content-Type: application/json' -H 'Accept: application/json' \
  -d '{"phone":"0991234567","purpose":"login"}'

# tail the log for the Graph reply
tail -n 40 phanda_api/storage/logs/laravel.log | grep -i whatsapp
```

A 200 with `exists: true` and a `challenge`, plus a WhatsApp message on the
number, is the end-to-end proof.

---

## 8. Part F — Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `503 OTP_CHANNEL_UNAVAILABLE` | one of the five env values empty | set them, `config:clear && config:cache` |
| `503 OTP_NOT_DELIVERED` | Graph said no | read the log line; see codes below |
| `404` from Graph | wrong `WHATSAPP_PHONE_NUMBER_ID` (display number, not ID) | copy the ID from API Setup |
| `190` | token expired (24-hour test token) | permanent system-user token |
| `132001` | template name or language does not exist | match `WHATSAPP_OTP_TEMPLATE` / `_LANGUAGE` exactly |
| `132000` | parameter count mismatch | template has no Copy-code button → `WHATSAPP_OTP_CODE_BUTTON=false` |
| `131030` | recipient not on WhatsApp, or not in the test number's 5-recipient list | add the recipient, or move to the production number |
| `131026` | undeliverable — handset offline too long, or number not on WhatsApp | ask them to use email this once |
| `130429` | throughput limit for the tier | complete business verification; back off |
| `368` / account restricted | policy: template reads as marketing, or opt-in missing | rewrite as a pure AUTHENTICATION template |
| Code arrives, app says wrong | server clock skew, or a second code replaced the first | check `date -u`; the newest code wins, deliberately |
| Everyone hits the cooldown | shared school IP behind one NAT | the per-IP limiter is 12/min; raise `throttle:otp` if a whole computer lab signs in at once |
| `exists:false` for a number that should exist | it was never verified — a typed number is not an identity | sign in with email once and link it |

Log line to look for:

```
WhatsApp OTP send failed {"status":400,"body":"{\"error\":{\"message\":...}}"}
```

---

## 9. Security, provider and compliance

### What the code enforces

- Six digits from `random_int`, stored as a password hash — the table is not a
  list of live codes, and the API never returns one.
- Ten minutes, single use, five wrong guesses then retired, 60-second resend
  cooldown, five per number per hour, 12 requests/minute per IP.
- Unknown numbers get `exists:false` and **no** message: the endpoint cannot be
  used to spam a stranger's WhatsApp at the school's expense.
- A number only becomes an identity when `phone_verified_at` is set. Nothing else
  may be treated as proof.
- One number, one account (`unique`), and a sign-in refuses if the number was
  moved off the account between sending and verifying.

### Known trade-off

`exists:false` reveals whether a number has a Kuphanda account. A sign-up attempt
reveals the same thing, so the alternative is a dead-end sign-up flow. If that
becomes unacceptable, remove the field and require the number to be entered in
the app before the sheet opens — the cost is a worse first-run experience.

### WhatsApp Business / Meta requirements

- **Opt-in.** Meta's Business Messaging Policy requires consent for
  business-initiated messages. Asking for a code is the consent for that message,
  and it is now recorded rather than assumed:
  - the sheet says so on the screen where the number is given — *"By continuing
    you agree to receive sign-in codes from Kuphanda on WhatsApp at this
    number"* — for sign-up and for linking;
  - `users.whatsapp_opt_in_at` is written the moment a code proves the number,
    never on a number that was merely typed;
  - `GET /api/v1/me` exposes `whatsapp_opt_in` and `whatsapp_opt_in_at`, so
    support can answer "when did they agree?" without opening the database.
  A number that is typed and abandoned leaves the column null — that is asserted
  in `PhoneAuthTest`.
- **Template category.** Authentication only. Mixing in a reminder or an offer
  gets the template rejected or the number restricted.
- **Number hygiene.** The business number cannot be one already on WhatsApp, and
  the display name is reviewed. Changing it re-enters review.
- **Billing.** Each authentication message is billable, at Meta's rate for Malawi,
  charged to the WABA's payment method. A failed send costs nothing; a sent code
  nobody enters still costs. The cooldown and hourly cap are the cost control.
- **Tiers.** A new, unverified business starts on the lowest messaging tier.
  Complete business verification in Meta Business Suite before a term start, not
  during it. Check the current tier in WhatsApp Manager — Meta changes the
  numbers.

### Malawi / data protection

- Kuphanda is the data controller for the numbers. Keep the minimum: MSISDN,
  timestamps, delivery id. Do not log the code, and do not log full Graph
  responses containing the recipient.
- Retention: `otp:prune` deletes codes after 7 days, daily at 03:10 Blantyre.
  Tighten with `--days=1` if the school's policy requires it.
- Subject access and correction: a learner can see and replace their number from
  Profile; keep that true, and answer deletion requests by clearing
  `phone_e164`/`phone_verified_at`.
- The applicable framework is Malawi's Electronic Transactions and Cyber Security
  Act (2016) for electronic records and personal data, plus Meta's Platform Terms
  and WhatsApp Business Solution Terms. If Kuphanda is used by a public school,
  check whether the Access to Information Act (2016) obligations reach the
  library records. This is a summary, not legal advice — have the school's
  counsel confirm before launch.

### Google

Unchanged, and deliberately so. `/auth/google` still matches a verified Google
email to an existing account, links rather than duplicating, and never invents a
phone number: an account created that way has `phone_e164 = null` until someone
links one. That is why Google can coexist with phone sign-in without creating a
second identity for the same person.

---

## 10. Rollout

1. Deploy with the env values **empty** first — everything else ships, phone
   sign-in answers 503, email and Google carry on. Confirm `/health` and a normal
   sign-in.
2. Add the WhatsApp values, `config:cache`, confirm
   `whatsapp_otp.configured: true`.
3. Test with the Meta test number and your own phone.
4. Move to the production number, then ask two teachers and two learners to link
   their numbers.
5. Watch the log for `WhatsApp OTP send failed` and the `otp_challenges` count for
   a week before promoting the button anywhere else in the app.

### Rollback

Remove `WHATSAPP_TOKEN` (or set it empty) and `config:cache`. Phone sign-in
answers 503 with a sentence that points at email; accounts that already linked a
number keep it, and nothing else changes. No migration has to be reversed.

---

## 11. Cost, in one place

- Meta charges per **authentication** message delivered, at the Malawi rate on
  the WABA's rate card.
- A code nobody enters still bills. The hourly cap and cooldown are what stop a
  stuck learner from costing a term's budget.
- The test number's five recipients are free, which is enough to prove the flow
  before any spend.
