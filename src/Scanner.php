<?php

namespace Wuninsu\NativeScanner;

use ReflectionFunction;

/**
 * QR code and barcode scanning (Android: Google code scanner, iOS: VisionKit).
 */
class Scanner
{
    public const BRIDGE = 'WuninsuScanner';

    /**
     * True only inside a built app that contains this plugin.
     *
     * On a web server, in tests and under `native:jump`, `nativephp_call()` is NativePHP's PHP stand-in, not the
     * device's native function, so this returns false there.
     */
    public function isAvailable(): bool
    {
        if (! function_exists('nativephp_call') || ! (new ReflectionFunction('nativephp_call'))->isInternal()) {
            return false;
        }

        return ! function_exists('nativephp_can') || nativephp_can(self::BRIDGE.'.Scan');
    }

    public function scan(): PendingScan
    {
        return new PendingScan;
    }
}
