---
name: symfony-service-decoration
description: Guide for decorating Symfony services using the Decorator pattern. This skill should be used when the user wants to decorate a service, wrap an existing service, override a service while keeping the original, use `#[AsDecorator]`, `#[AutowireDecorated]`, stack multiple decorators, set decoration priority, or control behavior when a decorated service does not exist (`onInvalid`). Also relevant when the user mentions `.inner`, `decorates`, `decoration_priority`, or wants to extend service behavior without replacing it entirely.
---

# Symfony Service Decoration

**Prerequisite**: apply all rules from the `symfony-conventions` skill when writing PHP code.

Service decoration applies the Decorator pattern in the Symfony DI container: wrap an existing service to extend its behavior while keeping access to the original. The decorated service ID remains unchanged for consumers — they receive the decorator transparently.

## When to decorate vs. replace

```
Need to change a service's behavior?
├── Keep original behavior + add/modify around it → Decoration (this skill)
├── Completely replace with a new implementation → Override the service definition
└── Add behavior to multiple services at once → Compiler pass + tags
```

## Basic decoration with `#[AsDecorator]`

Start by defining an interface that both the original service and the decorator will implement:

```php
// src/Service/MailerInterface.php
namespace App\Service;

interface MailerInterface
{
    public function send(Email $email): void;
}
```

```php
// src/Service/Mailer.php
namespace App\Service;

class Mailer implements MailerInterface
{
    public function send(Email $email): void
    {
        // Send the email
    }
}
```

When adding a decorator, the decorator becomes a second implementation of the interface. At that point, add `#[AsAlias]` on the original class so the container knows which concrete service the interface alias points to:

```php
// src/Service/Mailer.php — updated when a decorator is added
namespace App\Service;

use Symfony\Component\DependencyInjection\Attribute\AsAlias;

#[AsAlias(MailerInterface::class)]
class Mailer implements MailerInterface
{
    public function send(Email $email): void
    {
        // Send the email
    }
}
```

Then create the decorator — it implements the same interface and uses `#[AsDecorator]`:

```php
// src/Service/DecoratingMailer.php
namespace App\Service;

use Symfony\Component\DependencyInjection\Attribute\AsDecorator;

#[AsDecorator(decorates: MailerInterface::class)]
class DecoratingMailer implements MailerInterface
{
    public function send(Email $email): void
    {
        // ...
    }
}
```

This tells the container that `DecoratingMailer` replaces `MailerInterface` as the service consumers receive, while keeping the original instance accessible. Consumers type-hinting `MailerInterface` get the decorator transparently.

Multiple `#[AsDecorator]` attributes can be applied to the same class to decorate multiple services (Symfony 7.4+).

### `#[AsAlias]` — only when needed for decorating an interface

`#[AsDecorator(decorates: SomeInterface::class)]` requires an alias `SomeInterface::class` to exist in the container, pointing to the concrete service. Without this alias, Symfony throws a `ServiceNotFoundException`.

**Do NOT add `#[AsAlias]`** when:
- Autowiring is enabled AND there is only one implementation of the interface — Symfony creates the alias automatically

**Add `#[AsAlias(Interface::class)` explicitly** only when:
- Multiple implementations of the same interface exist (the decorator counts as a second implementation)
- The concrete service is defined by a third-party bundle (Sylius, etc.) without an alias on the interface
- Manual service configuration disables autowiring

## Injecting the decorated (inner) service

With autowiring enabled, Symfony injects the original (inner) service **automatically** into the decorator's constructor when the parameter is type-hinted with the decorated interface. **`#[AutowireDecorated]` is NOT required in most cases.**

```php
// src/Service/DecoratingMailer.php
namespace App\Service;

use Symfony\Component\DependencyInjection\Attribute\AsDecorator;

#[AsDecorator(decorates: MailerInterface::class)]
class DecoratingMailer implements MailerInterface
{
    public function __construct(
        private MailerInterface $inner,
        private LoggerInterface $logger,
    ) {
    }

    public function send(Email $email): void
    {
        $this->logger->info('Sending email...');
        $this->inner->send($email);
        $this->logger->info('Email sent.');
    }
}
```

### When `#[AutowireDecorated]` IS needed

Use it **only** when autowiring alone cannot resolve which parameter receives the inner service:
- The constructor has **multiple parameters** type-hinted with the decorated interface
- Autowiring is **disabled**

```php
use Symfony\Component\DependencyInjection\Attribute\AsDecorator;
use Symfony\Component\DependencyInjection\Attribute\AutowireDecorated;

#[AsDecorator(decorates: MailerInterface::class)]
class DecoratingMailer implements MailerInterface
{
    public function __construct(
        #[AutowireDecorated] private MailerInterface $inner,
        private MailerInterface $fallback,
    ) {
    }
}
```

Unlike YAML/XML configuration where the inner service is named `$inner` by convention, with attributes the variable name is free — `#[AutowireDecorated]` handles the wiring.

## Multiple decorators and priority

When several decorators target the same service, control execution order with `priority`. Higher priority = applied earlier (closer to the outside of the chain).

```php
// src/Service/FooInterface.php
namespace App\Service;

interface FooInterface
{
    public function execute(): string;
}
```

```php
use Symfony\Component\DependencyInjection\Attribute\AsDecorator;

#[AsDecorator(decorates: FooInterface::class, priority: 5)]
class Bar implements FooInterface
{
    public function __construct(
        private FooInterface $inner,
    ) {
    }

    public function execute(): string { /* ... */ }
}

#[AsDecorator(decorates: FooInterface::class, priority: 1)]
class Baz implements FooInterface
{
    public function __construct(
        private FooInterface $inner,
    ) {
    }

    public function execute(): string { /* ... */ }
}
```

Result: `Baz( Bar( Foo() ) )` — `Bar` (priority 5) is applied first, then `Baz` (priority 1) wraps it.

Default priority is `0`.

## Typical decorator pattern

```php
// src/Service/NotifierInterface.php
namespace App\Service;

interface NotifierInterface
{
    public function notify(Notification $notification): void;
}
```

```php
// src/Service/Notifier.php
namespace App\Service;

class Notifier implements NotifierInterface
{
    public function notify(Notification $notification): void
    {
        // Send the notification
    }
}
```

```php
// src/Service/LoggingNotifier.php
namespace App\Service;

use Symfony\Component\DependencyInjection\Attribute\AsDecorator;

#[AsDecorator(decorates: NotifierInterface::class)]
class LoggingNotifier implements NotifierInterface
{
    public function __construct(
        private NotifierInterface $inner,
        private LoggerInterface $logger,
    ) {
    }

    public function notify(Notification $notification): void
    {
        $this->logger->info('Sending notification: ' . $notification->getSubject());

        $this->inner->notify($notification);

        $this->logger->info('Notification sent.');
    }
}
```

The decorator implements the same interface as the decorated service — this guarantees the contract is respected and substitution is transparent for consumers.

## Common pitfalls

1. **Missing `#[AsAlias]` when decorating**: `decorates: Interface::class` fails with `ServiceNotFoundException` if no alias maps the interface to the concrete service. When adding a decorator (which is a second implementation), add `#[AsAlias(Interface::class)]` on the original concrete class — **never** work around this by changing `decorates` to the concrete class. Conversely, do NOT add `#[AsAlias]` preemptively on a service that has only one implementation and no decorator.

2. **Service visibility**: the visibility (public/private) of the original service is preserved. The decorator does not change it.

3. **Tags are moved**: custom service tags from the decorated service are removed and added to the decorator. Built-in Symfony tags (`kernel.event_subscriber`, `kernel.event_listener`, etc.) are kept on the original.

4. **Dynamic services from compiler passes**: when decorating a service created dynamically by a compiler pass, the compiler pass must be registered with `PassConfig::TYPE_BEFORE_OPTIMIZATION` so the decoration pass can find it.

5. **Do not decorate a service without implementing its interface** — consumers type-hinting the interface will get a broken injection.

## Full reference

For alternative configuration formats (YAML, XML, PHP Configurator), stacked decorators, custom inner service naming, and advanced stack composition, see `references/service-decoration-api.md`.
