# Info.plist Configuration

Add these keys to your Info.plist to properly configure FalconShot:

## Required Keys

### 1. Screen Recording Permission
```xml
<key>NSScreenCaptureUsageDescription</key>
<string>FalconShot needs permission to capture your screen to take screenshots.</string>
```

### 2. Hide Dock Icon (Menu Bar Only App)
```xml
<key>LSUIElement</key>
<true/>
```

## Full Info.plist Example

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>$(MACOSX_DEPLOYMENT_TARGET)</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSScreenCaptureUsageDescription</key>
    <string>FalconShot needs permission to capture your screen to take screenshots.</string>
</dict>
</plist>
```

## How to Add to Your Project

1. In Xcode, select your project in the navigator
2. Select your app target
3. Go to the "Info" tab
4. Click the "+" button to add new keys
5. Add each key listed above with their corresponding values

Alternatively, you can:
1. Right-click Info.plist in the project navigator
2. Select "Open As" → "Source Code"
3. Add the keys directly in XML format
