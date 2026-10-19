<?php

namespace Wuninsu\NativeScanner;

use Illuminate\Support\ServiceProvider;

class ScannerServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->singleton(Scanner::class);
    }
}
