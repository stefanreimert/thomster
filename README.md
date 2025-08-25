# thomster

A new Flutter project.


## App icon and splash setup

This project is preconfigured to generate an app icon and a splash screen using:
- flutter_launcher_icons
- flutter_native_splash

Add your images here:
- assets/branding/app_icon.png — 1024×1024 PNG, square, no rounded corners.
- assets/branding/splash_logo.png — Transparent PNG (recommended 256–384 px square).

Brand colors used by the configuration:
- Electric Purple: #A259FF
- Neon Cyan: #00FFE0
- Splash background (dark): #0B0F1A

How to generate locally after adding the images:
1. flutter pub get
2. dart run flutter_launcher_icons
3. dart run flutter_native_splash:create

Notes:
- If the Android icon doesn’t update, uninstall the app to clear launcher cache.
- Android 12 splash uses OS-mandated centered icon with solid background; images are set accordingly.
- You can tweak sizes/colors by editing pubspec.yaml in the flutter_launcher_icons and flutter_native_splash sections.
