# Enabling real AdMob & Google Play Billing

The shipped build uses **fake** `Ads` and `Billing` singletons so the game is fully playable with no
accounts. To monetize for real, swap them for the actual SDKs. Gameplay code only ever calls
`Ads.show_rewarded(...)` / `Billing.buy(...)`, so nothing else needs to change.

> Both real SDKs require a **Gradle (custom) Android build** in Godot. Enable it in the Android export
> preset: `Gradle Build → Use Gradle Build = On` (then *Project → Install Android Build Template…*).

---

## 1. AdMob (rewarded / interstitial / banner)

Recommended plugin: **Godot AdMob Plus** / **Poing Studios AdMob** (Godot 4.x compatible). Install the
addon under `addons/` and enable it.

1. Create an [AdMob](https://admob.google.com) account → register the app → create ad units
   (Rewarded, Rewarded Interstitial, Interstitial, Banner).
2. Put the **AdMob App ID** in the Android manifest (the plugin exposes a setting for this).
3. **During development always use Google's official test ad unit IDs** — never click live ads (ban risk).
4. Replace the body of `scripts/ads.gd`:

```gdscript
# Pseudocode — adapt to your plugin's API.
var _rewarded

func _ready():
    MobileAds.initialize()
    _load_rewarded()

func is_rewarded_ready() -> bool:
    return _rewarded != null and _rewarded.is_loaded()

func show_rewarded(kind: String, on_reward := Callable()) -> void:
    if not is_rewarded_ready():
        if on_reward.is_valid(): on_reward.call()   # fail-open so players aren't punished
        return
    _rewarded.user_earned_reward.connect(func(_r):
        if on_reward.is_valid(): on_reward.call()
        reward_granted.emit(kind), CONNECT_ONE_SHOT)
    _rewarded.show()
    _rewarded = null
    _load_rewarded()
```

Frequency-cap interstitials (e.g. ≥4 min apart, max 4–6/day, quiet period on first sessions, never mid-run).
Respect `Billing.ads_removed` for banner/interstitial.

## 2. Google Play Billing (IAP)

Use the **GodotGooglePlayBilling** plugin (Billing Library v6/v7).

1. In Play Console create the products with IDs that match `Billing.PRODUCTS` keys
   (`gems_s`, `gems_m`, `gems_l`, `remove_ads`, `perm_x2`, `starter`).
2. Upload a signed build to a testing track and add license testers.
3. Replace `scripts/billing.gd` `buy()` to call `startConnection()` → `queryPurchases()` →
   `purchase(id)`, and **grant only after** `purchases_updated` + acknowledge/consume:
   - consumables (`gems_*`): consume after granting.
   - non-consumables (`remove_ads`, `perm_x2`, `starter`): acknowledge; restore on launch via `queryPurchases()`.
4. Keep `ads_removed` / `perm_mult` in sync and persist via `SaveSystem.save_game()`.

## 3. Consent (UE/GDPR)

Integrate the **Google UMP SDK** (User Messaging Platform) to show the consent form before requesting
ads in the EEA/UK. Only request personalized ads after consent.

## 4. Play Console checklist (high level)

- Closed testing (personal accounts: ≥12 testers / ≥14 days) before production *(verify current policy)*.
- Data Safety form (AdMob/analytics collect the Advertising ID).
- Privacy Policy URL.
- Content rating (IARC). If you add random chests/loot boxes, disclose odds.
- AAB upload (not APK) for the store; APK here is for sideload/testing.

See `../deep-core-plano/PLANO-DEEP-CORE.md` (Secções 4 & 6) for the full monetization & compliance plan.
