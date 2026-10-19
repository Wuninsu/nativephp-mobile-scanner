<?php

namespace Wuninsu\NativeScanner;

use Illuminate\Support\Str;
use InvalidArgumentException;
use Native\Mobile\Concerns\HandlesNativeCallbacks;
use Wuninsu\NativeScanner\Events\Scanned;

/**
 * A scan being configured. Call start() to open the scanner; the result arrives as a Scanned event (or the callback
 * given to scanned()).
 *
 * @method $this scanned(\Closure|array|string $callback)
 */
class PendingScan
{
    use HandlesNativeCallbacks;

    public const FORMATS = ['qr', 'ean13', 'ean8', 'upca', 'upce', 'code128', 'code39', 'code93', 'codabar', 'itf', 'pdf417', 'aztec', 'datamatrix'];

    protected ?string $id = null;

    protected string $eventClass = Scanned::class;

    protected ?string $prompt = null;

    /** @var list<string> */
    protected array $formats = ['qr'];

    protected bool $started = false;

    public function id(string $id): static
    {
        $this->id = $id;

        return $this;
    }

    public function getId(): string
    {
        return $this->id ??= (string) Str::uuid();
    }

    /** Text shown on the scanner screen (iOS; Android's scanner shows its own). */
    public function prompt(string $prompt): static
    {
        $this->prompt = $prompt;

        return $this;
    }

    /** @param  list<string>  $formats  any of self::FORMATS; default ['qr'] */
    public function formats(array $formats): static
    {
        $unknown = array_diff($formats, self::FORMATS);
        if ($formats === [] || $unknown !== []) {
            throw new InvalidArgumentException('Unknown scan format: '.implode(', ', $unknown ?: ['(none)']));
        }

        $this->formats = array_values($formats);

        return $this;
    }

    /** Send the result as another event class (constructor: ?string $value, ?string $format, ?string $id, ?string $error). */
    public function event(string $eventClass): static
    {
        if (! class_exists($eventClass)) {
            throw new InvalidArgumentException("Event class {$eventClass} does not exist.");
        }

        $this->eventClass = $eventClass;

        return $this;
    }

    /**
     * Open the scanner. True when the phone started it; the outcome arrives later as the event.
     */
    public function start(): bool
    {
        if ($this->started || ! function_exists('nativephp_call')) {
            return false;
        }

        $this->started = true;

        $response = nativephp_call(Scanner::BRIDGE.'.Scan', json_encode(array_filter([
            'id' => $this->getId(),
            'event' => $this->eventClass,
            'prompt' => $this->prompt,
            'formats' => $this->formats,
        ], fn ($value) => $value !== null), JSON_THROW_ON_ERROR));

        $decoded = is_string($response) ? json_decode($response, true) : null;

        return is_array($decoded) && ($decoded['started'] ?? false) === true;
    }
}
