# Android

Play Store listing material. How to set the machine up and produce a build is in
[../docs/build/android.md](../docs/build/android.md).

```
android/
├── icons/    launcher icons for the export preset
└── README.md
```

## Icons

Godot's Android preset takes three, all PNG:

| File | Size | Notes |
|---|---|---|
| `main_192x192.png` | 192 x 192 | Legacy launcher icon |
| `adaptive_foreground_432x432.png` | 432 x 432 | Adaptive icon foreground |
| `adaptive_background_432x432.png` | 432 x 432 | Adaptive icon background |

Adaptive icons get masked into whatever shape the launcher uses, and the outer
~1/6 of each edge can be cropped. Keep the badge well inside the middle third.

Drop them in `icons/` and point the preset's `launcher_icons/*` fields at them.

## Play Store listing

| Asset | Size |
|---|---|
| App icon | 512 x 512, 32-bit PNG |
| Feature graphic | 1024 x 500 |
| Phone screenshots | at least 2, 16:9 or taller |
| 7" and 10" tablet screenshots | recommended |
| Promo video | YouTube URL, optional |

Plus: short description (80 chars), full description (4000 chars), category,
content rating questionnaire, privacy policy URL, and the data safety form.

The game collects nothing and sends nothing anywhere, which makes the data
safety form quick — but it is still required, and it is checked.

## Before the first upload

- **Change the package name.** It is `com.example.officerchoi` in
  `game/export_presets.cfg` and it is permanent for the life of the listing.
- **Back up the release keystore.** It lives in `C:\temp\_secrets` and it is the
  only thing that can ever update this app.
