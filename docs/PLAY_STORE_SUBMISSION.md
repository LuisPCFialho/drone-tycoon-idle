# Play Store Submission Checklist — Drone Tycoon: Sky Fleet

This is a working reference for filling in the Google Play Console forms.
Everything here is **content you paste into the Play Console web UI** — I
cannot submit these forms myself (they require your Google account login),
but every answer below is drafted from what the app actually does, so you
should be able to copy-paste through the whole flow quickly.

## 1. App details

- **App name:** Drone Tycoon: Sky Fleet
- **Short description** (80 chars max):
  `Constrói o teu império de entregas por drone. Idle tycoon vertical!`
- **Full description** (4000 chars max, PT — translate/duplicate for EN listing once localization ships):

  ```
  Constrói o maior império de entregas por drone do mundo! 🚁

  Drone Tycoon: Sky Fleet é um jogo idle/tycoon onde compras drones,
  melhoras rotas e expandes o teu negócio por 40 países reais — de
  Portugal aos Estados Unidos, com cidades e mapas geograficamente
  precisos.

  ✈️ ENTREGAS AUTOMÁTICAS — os teus drones voam sozinhos, entregam
  encomendas e geram lucro mesmo offline.

  🌍 40 PAÍSES REAIS — expande a tua rede por um mapa-mundo com
  contornos e cidades geograficamente exatos.

  🏆 PRESTÍGIO E CONQUISTAS — reinicia com multiplicadores permanentes,
  desbloqueia mais de 40 conquistas e sobe na Loja de Prestígio.

  🎯 MISSÕES DIÁRIAS E SEMANAIS — completa desafios para ganhar
  créditos e gemas bónus.

  💎 PROGRESSÃO JUSTA — gemas ganham-se a jogar (anúncios opcionais,
  login diário), nunca é preciso pagar para progredir.

  Descarrega grátis e começa a construir a tua frota hoje!
  ```

- **App icon:** `appicon.png` (already in repo, 512×512 required for the
  store listing — verify current size with `identify appicon.png`; Play
  Console wants a distinct 512×512 hi-res icon separate from the launcher
  mipmaps already bundled in the APK).
- **Feature graphic (1024×500):** not yet generated — needs a wide banner
  crop of the map + logo wordmark. Can be produced with `tools/gen_art.py`'s
  Pillow pipeline the same way other art was generated.
- **Screenshots:** use `tools/shoot_node.gd` (see comment in that file for
  how to run it) — captures real 540×960 in-game screenshots per tab.
  Play Console wants at least 2, ideally 4-8, portrait 16:9-ish. The ones
  in `export/shots/` from this session are usable directly after a resize
  check (Play accepts down to ~320px, up to 3840px on the long edge).
- **Category:** Simulation (already set via `package/app_category=2` in
  export_presets.cfg, which maps to Godot's category enum — double check
  against Play Console's own category list, they don't map 1:1).
- **Contact details:** email + (optional) website — needs your real support
  address, not a placeholder.
- **Privacy Policy URL:** publish `docs/legal/privacy-policy.html` (see
  below for hosting) and paste that URL here.

## 2. Hosting the Privacy Policy

Two zero-cost options, pick one:

**A. GitHub Pages (recommended, already have the repo):**
```bash
git checkout --orphan gh-pages
git rm -rf .
cp docs/legal/privacy-policy.html index.html
git add index.html && git commit -m "Privacy policy page"
git push origin gh-pages
```
Then in the GitHub repo Settings → Pages, set source to the `gh-pages`
branch. URL will be `https://luispcfialho.github.io/drone-tycoon-idle/`.
**Note:** the source repo is private — GitHub Pages requires a PAID plan to
publish from a private repo, OR make this one page public via the existing
public releases repo pattern (you already do this for OpenViewIPTV: source
private, a separate public repo for what needs to be public). Simplest fix:
add `docs/legal/privacy-policy.html` to a small dedicated public repo (or
reuse an existing public one you own) and enable Pages there instead.

**B. Any static host** (Netlify/Vercel free tier, Cloudflare Pages) — drag
the single HTML file in, get a URL instantly, no git branch juggling.

## 3. Data Safety form (Play Console → App content → Data safety)

Answer key based on what the app *actually* does once real AdMob + Play
Billing are wired in (see `scripts/ads.gd` / `scripts/billing.gd`):

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes** |
| Data types collected | **Device or other IDs** (advertising ID, via AdMob) |
| Is data collection required or optional? | Optional for gameplay — ads are opt-in (rewarded), but AdMob SDK presence means the ID is technically accessible whenever an ad loads |
| Purpose | Advertising or marketing, Analytics |
| Is data shared with third parties? | **Yes** — Google (AdMob) for ad serving; Google (Play Billing) for purchase processing |
| Is data encrypted in transit? | **Yes** (handled by Google SDKs) |
| Can users request data deletion? | Not applicable — no account/server-side data exists; local save is deleted on uninstall |
| Financial info (purchase history) | Collected **by Google Play**, not by this app directly — the app never sees card details |

You'll click through checkboxes for each category (Location, Personal info,
Financial info, Health, Messages, Photos/Videos, Audio, Files/docs, Calendar,
Contacts, App activity, Web browsing, App info/performance, Device/other
IDs) — for this app, only **Device or other IDs** and (once billing is live)
**Financial info → Purchase history** should be checked. Everything else:
**not collected**.

## 4. Content rating questionnaire

Answer the IARC questionnaire honestly — for this game:
- No violence, no sexual content, no gambling-simulation mechanics beyond
  a standard idle-game prestige loop (not a real-money gambling mechanic).
- Contains **in-app purchases** — must be flagged "Yes".
- Contains **ads** — must be flagged "Yes".
- Expected outcome: **PEGI 3 / ESRB Everyone**-equivalent rating.

## 5. Target audience & ads declaration

- Target age group: general audience, not primarily children. Do **not**
  mark this as "designed for children" — that triggers Families Policy
  requirements (COPPA-style restrictions on ad personalization) that would
  require reworking the AdMob integration to force non-personalized ads.
- "Contains ads": Yes.

## 6. Build to upload

Play Console requires an **AAB (Android App Bundle)**, not an APK, for new
apps. `export_presets.cfg` currently has `gradle_build/export_format=0`
(APK). Switch to `1` (AAB) for the Play Console upload — keep a separate
APK export for direct/sideload distribution (GitHub releases) since that
flow already works and players expect a `.apk` there.

## 7. What I cannot do for you

- Create the Play Console developer account (one-time $25 fee, needs your
  identity/payment info).
- Create the AdMob account + ad units (needs your Google account).
- Fill in and submit the Data Safety / content rating / store listing forms
  (Google requires this be done by a logged-in account holder).
- Upload the signed AAB and submit for review.
- Generate the feature graphic image (I can if asked — just wasn't in this
  pass's scope; say the word and I'll run it through `tools/gen_art.py`).

Everything else above is drafted and ready to paste in.
