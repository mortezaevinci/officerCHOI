# Steam

Everything for the Steam release that is not the game itself. How to actually
build and upload is in [../docs/build/steam.md](../docs/build/steam.md).

```
steam/
├── app_id.txt        the App ID, once Valve issues one
├── depot/            SteamPipe upload scripts (fill in the IDs)
└── store-assets/     capsule art, screenshots, trailer, store text
```

## Store assets Valve asks for

Sizes as of writing; check the Steamworks docs before commissioning any of it.

| Asset | Size | Notes |
|---|---|---|
| Header capsule | 920 x 430 | The one everyone sees. Readable as a thumbnail. |
| Small capsule | 462 x 174 | Search results. The title must survive this size. |
| Main capsule | 1232 x 706 | Front page features. |
| Vertical capsule | 748 x 896 | Seasonal sales. |
| Page background | 1438 x 810 | Optional |
| Library capsule | 600 x 900 | In the player's library |
| Library header | 460 x 215 | |
| Library hero | 3840 x 1240 | |
| Library logo | 1280 x 720 | Transparent PNG |
| Screenshots | 1920 x 1080 | At least 5. Take them with the game, not a mockup. |
| Trailer | 1920 x 1080 | Gameplay in the first five seconds. |

Capture screenshots from the real build so the store shows the real game:

```powershell
build\windows\OfficerChoi.exe -- --screenshot=C:\temp\_samples\store_01.png --shot-after=200
```

## Store text to write

- Short description (max 300 characters). This is the one that sells it.
- About This Game (long description, with images).
- Tags. Realistic ones: Visual Novel, Story Rich, Choices Matter, Detective,
  Indie, 2D, Singleplayer.
- System requirements. Godot 2D on `gl_compatibility` is undemanding; do not
  copy someone else's inflated requirements.
- Age rating and content descriptors.

## Before release day

- The store page must be live at least two weeks before launch. Valve requires
  it, and the wishlists it collects are most of your launch-day visibility.
- Both the page and the build get reviewed by Valve, separately, and neither is
  instant.
