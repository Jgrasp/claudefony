# Service Decoration — Full API Reference

Reference material for Symfony service decoration using PHP attributes.

## Configuration with attributes

```php
use Symfony\Component\DependencyInjection\Attribute\AsDecorator;

#[AsDecorator(decorates: Mailer::class)]
class DecoratingMailer
{
    public function __construct(
        private Mailer $inner,
    ) {
    }
}
```

`#[AutowireDecorated]` is only needed when the constructor has multiple parameters of the decorated type or when autowiring is disabled. See the main skill for details.

## Custom inner service name

By default, the original service is accessible via the ID `DecoratingServiceId.inner`. When using `#[AutowireDecorated]`, the variable name is free — no explicit inner name configuration is needed:

```php
#[AsDecorator(decorates: Mailer::class)]
class DecoratingMailer
{
    public function __construct(
        #[AutowireDecorated] private Mailer $originalMailer,
    ) {
    }
}
```

## Decoration priority

Controls the order when multiple decorators target the same service. Higher priority = applied earlier (inner decorator).

```php
#[AsDecorator(decorates: Foo::class, priority: 5)]
class Bar { /* ... */ }

#[AsDecorator(decorates: Foo::class, priority: 1)]
class Baz { /* ... */ }
```

Result: `new Baz(new Bar(new Foo()))`


## Tag behavior during decoration

- **Custom tags**: removed from the decorated service and added to the decorator.
- **Built-in Symfony tags preserved on the original**: `container.service_locator`, `container.service_subscriber`, `kernel.event_subscriber`, `kernel.event_listener`, `kernel.locale_aware`, `kernel.reset`.

## Compiler pass considerations

When decorating a service created dynamically by a compiler pass, the compiler pass must be registered with `PassConfig::TYPE_BEFORE_OPTIMIZATION` so the decoration pass finds the service definition.

## `#[AsDecorator]` attribute parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `decorates` | `string` | *(required)* | Service ID to decorate |
| `priority` | `int` | `0` | Order when multiple decorators target the same service |
