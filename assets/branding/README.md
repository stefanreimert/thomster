# Branding assets

Place your images here to enable app icon and splash generation.

Required files:
- app_icon.png (1024×1024 PNG)
  - Square, no rounded corners.
  - Keep important artwork centered. Transparent background is OK, but Android legacy icons will rasterize onto a solid background.
  - We configured Android adaptive icon background color to Electric Purple (#A259FF).
- splash_logo.png (recommended 256–384 px square PNG, transparent background)
  - Simple mark or glyph. Avoid thin strokes.

Configured colors (from app theme):
- Electric Purple: #A259FF
- Neon Cyan: #00FFE0
- Splash background: #0B0F1A (dark)

How to generate locally after adding the images:
1) Fetch packages
   flutter pub get

2) Generate app icons
   dart run flutter_launcher_icons

3) Generate splash screen
   dart run flutter_native_splash:create

Tips:
- If Android icon doesn’t update, uninstall the app from the device to clear launcher cache.
- For iOS, open Runner workspace in Xcode to verify the AppIcon and LaunchScreen if needed.
- You can tweak sizes later by replacing the images and re-running the commands.
