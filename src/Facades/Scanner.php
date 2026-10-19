<?php

namespace Wuninsu\NativeScanner\Facades;

use Illuminate\Support\Facades\Facade;
use Wuninsu\NativeScanner\PendingScan;

/**
 * @method static bool isAvailable()
 * @method static PendingScan scan()
 *
 * @see \Wuninsu\NativeScanner\Scanner
 */
class Scanner extends Facade
{
    protected static function getFacadeAccessor(): string
    {
        return \Wuninsu\NativeScanner\Scanner::class;
    }
}
