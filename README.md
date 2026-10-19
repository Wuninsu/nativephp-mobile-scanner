# NativePHP Scanner

QR code and barcode scanning for NativePHP Mobile v4 apps.

- **Android:** Google code scanner (ML Kit through Play services). Play services shows the camera screen, so the app needs no camera permission.
- **iOS:** VisionKit `DataScannerViewController`.

> **Early release (0.x).** Testing on real phones is in progress, so the API may still change before 1.0.

## Requirements

- PHP 8.3+
- `nativephp/mobile` ^4.6
- Android 8 (API 26) or newer with Google Play services, iOS 18.2 or newer (an A12 chip or newer for VisionKit scanning)

## Install

```sh
composer require wuninsu/nativephp-scanner
```

NativePHP compiles only the plugins you register. If your app has no `app/Providers/NativeServiceProvider.php` yet, publish it first:

```sh
php artisan vendor:publish --tag=nativephp-plugins-provider
```

Then register the plugin and rebuild the native project:

```sh
php artisan native:plugin:register wuninsu/nativephp-scanner
php artisan native:install --force
```

The plugin adds `NSCameraUsageDescription` ("Use the camera to scan QR codes.") to the iOS Info.plist. Override it with the `permissions` block in `config/nativephp.php`.

On Android the scanner module downloads on first use. A scan started before the download finishes ends with the `unavailable` error. Try again a moment later.

## Use

The scanner runs on the phone's screen, so its result arrives later, as the `Wuninsu\NativeScanner\Events\Scanned` event.

```php
use Wuninsu\NativeScanner\Events\Scanned;
use Wuninsu\NativeScanner\Facades\Scanner;

if (Scanner::isAvailable()) {
    Scanner::scan()
        ->prompt('Scan the pairing code')     // iOS only
        ->formats(['qr'])                     // default; also ean13, ean8, upca, upce, code128, code39, code93, codabar, itf, pdf417, aztec, datamatrix
        ->scanned(function (Scanned $event) {
            if ($event->successful()) {
                // $event->value, $event->format
            }
        })
        ->start();
}
```

Or listen for the event anywhere (a Laravel listener, or `#[On]` / `#[OnNative]` in a component).

`$event->error` is `null` on success, otherwise one of `cancelled`, `unavailable`, `permission_denied` (iOS), `failed`.

`Scanner::isAvailable()` is false on a web server, in tests and under `native:jump`, where there is no camera bridge. Hide the scan button there.

## License

MIT
