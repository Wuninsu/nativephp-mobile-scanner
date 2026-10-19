<?php

namespace Wuninsu\NativeScanner\Events;

use Illuminate\Foundation\Events\Dispatchable;

/**
 * Sent by the phone when a scan ends.
 *
 * On success $value holds the code's text and $error is null. Otherwise $error is one of: cancelled, unavailable,
 * permission_denied, failed.
 */
class Scanned
{
    use Dispatchable;

    public const CANCELLED = 'cancelled';

    public const UNAVAILABLE = 'unavailable';

    public const PERMISSION_DENIED = 'permission_denied';

    public const FAILED = 'failed';

    public function __construct(
        public ?string $value = null,
        public ?string $format = null,
        public ?string $id = null,
        public ?string $error = null,
    ) {}

    public function successful(): bool
    {
        return $this->error === null && $this->value !== null;
    }

    public function cancelled(): bool
    {
        return $this->error === self::CANCELLED;
    }
}
