---
name: symfony-conventions
description: Symfony PHP coding rules — final/readonly classes, constructor property promotion, interface segregation, attributes over YAML, framework constants over magic values, early returns, naming suffixes, directory conventions. Apply when creating or modifying any service, controller, entity, command, repository, event listener, voter, form type, twig extension, or twig component.
when_to_use: |
  Apply automatically when:
  - About to Write or Edit any .php file under src/ or tests/
  - The user asks to create, add, generate, or refactor a service, controller, entity, command, repository, event listener, event subscriber, voter, form type, twig extension, twig component, live component, message handler, factory, resolver, calculator, or any other PHP class
  - The user mentions: autowire, autowiring, dependency injection, service decoration, AsAlias, AsDecorator, AutowireDecorated, readonly class, final class, constructor injection, interface segregation, attribute routing, AsCommand, AsTwigComponent, AsLiveComponent
paths:
  - "src/**/*.php"
  - "tests/**/*.php"
---

# Symfony Conventions

Mandatory rules for all PHP code in Symfony projects. These apply globally — every other claudefony skill inherits them.

## SOLID principles

All code MUST follow SOLID principles:

- **Single Responsibility**: one class = one reason to change. Split classes that handle multiple concerns.
- **Open/Closed**: extend behavior through decoration, composition, or events — not by modifying existing classes.
- **Liskov Substitution**: any implementation of an interface must be substitutable without breaking consumers.
- **Interface Segregation**: prefer small, focused interfaces over large ones. A consumer should not depend on methods it does not use.
- **Dependency Inversion**: depend on abstractions (interfaces), not concrete implementations. Inject dependencies via the constructor.

These principles are not guidelines — they are constraints. Every class, interface, and service must be designed with them in mind.

## Class design

1. **All services MUST be `final`** unless they are explicitly designed to be extended.

```php
// Correct
final class OrderProcessor { }

// Correct — abstract class meant to be extended
abstract class AbstractOrderProcessor { }

// Wrong — non-final concrete service
class OrderProcessor { }
```

2. **Use `readonly` on final classes** when all properties are set in the constructor and never reassigned.

```php
final readonly class OrderProcessor
{
    public function __construct(
        private OrderRepository $orderRepository,
        private LoggerInterface $logger,
    ) {
    }
}
```

3. **Constructor property promotion** is mandatory for dependency injection.

```php
// Correct
public function __construct(
    private OrderRepository $orderRepository,
) {
}

// Wrong
private OrderRepository $orderRepository;

public function __construct(OrderRepository $orderRepository)
{
    $this->orderRepository = $orderRepository;
}
```

4. **Declare `strict_types`** in every PHP file.

```php
<?php

declare(strict_types=1);

namespace App\Service;
```

## Typing

5. **All method parameters and return types MUST be typed.** Use union types or `mixed` only when genuinely needed.

6. **Use nullable syntax** (`?Type`) over union with null (`Type|null`) for single-type nullable parameters.

```php
// Correct
public function find(?int $id): ?Product

// Wrong
public function find(int|null $id): Product|null
```

## Control flow

7. **Use early returns (guard clauses) instead of compound conditions.** When a method has preconditions, check each one separately and return early. This keeps the code flat and readable — avoid deeply nested `if` blocks or long `&&` chains.

```php
// Correct — early returns
public function adjustTotal(UserInterface $user, ?int $total): ?int
{
    if (!$user instanceof PlanAwareInterface) {
        return $total;
    }

    if (Plan::Demo !== $user->getPlan()) {
        return $total;
    }

    if (null === $total) {
        return $total;
    }

    return intval($total * $this->demoSalesMultiplierProvider->getMultiplier());
}

// Wrong — compound condition
public function adjustTotal(UserInterface $user, ?int $total): ?int
{
    if ($user instanceof PlanAwareInterface && Plan::Demo === $user->getPlan() && null !== $total) {
        return intval($total * $this->demoSalesMultiplierProvider->getMultiplier());
    }

    return $total;
}
```

## Configuration style

8. **Prefer PHP attributes over YAML/XML** for service configuration, routing, validation, and ORM mapping.

```php
// Correct
#[Route('/orders/{id}', name: 'order_show', methods: [Request::METHOD_GET])]
#[IsGranted('ROLE_USER')]
public function show(Order $order): Response

// Wrong — same config in routes.yaml
```

9. **Use framework constants** instead of raw strings or magic values whenever available.

```php
// Correct
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;

#[Route('/orders', methods: [Request::METHOD_GET])]
public function list(): Response
{
    return new Response('', Response::HTTP_NO_CONTENT);
}

// Wrong — magic strings/values
#[Route('/orders', methods: ['GET'])]
public function list(): Response
{
    return new Response('', 204);
}
```

Common constants to use:
- `Request::METHOD_GET`, `METHOD_POST`, `METHOD_PUT`, `METHOD_DELETE`, `METHOD_PATCH`
- `Response::HTTP_OK`, `HTTP_CREATED`, `HTTP_NO_CONTENT`, `HTTP_NOT_FOUND`, `HTTP_FORBIDDEN`...
- `InputArgument::REQUIRED`, `InputArgument::OPTIONAL`
- `ContainerInterface::IGNORE_ON_INVALID_REFERENCE`, `NULL_ON_INVALID_REFERENCE`

10. **Use named arguments** in attributes when there are 2+ parameters for readability.

```php
// Correct
#[AsCommand(name: 'app:import', description: 'Import products')]

// Acceptable for single parameter
#[Route('/orders')]
```

## Service design

11. **Every service MUST implement an interface.** The interface defines the contract, the class provides the implementation. Consumers always type-hint the interface, never the concrete class.

```php
// Correct
interface OrderProcessorInterface
{
    public function process(Order $order): void;
}

final readonly class OrderProcessor implements OrderProcessorInterface
{
    public function process(Order $order): void
    {
        // ...
    }
}

// Wrong — service without interface
final readonly class OrderProcessor
{
    public function process(Order $order): void { }
}
```

12. **Do NOT add `#[AsAlias]` on a service that is the only implementation of its interface.** Symfony's autowiring creates the alias automatically. Only add `#[AsAlias(Interface::class)]` when multiple implementations of the same interface exist (e.g., when adding a decorator or a second concrete implementation).

```php
// Correct — single implementation, no #[AsAlias] needed
final readonly class OrderProcessor implements OrderProcessorInterface { }

// Wrong — unnecessary #[AsAlias] with only one implementation
#[AsAlias(OrderProcessorInterface::class)]
final readonly class OrderProcessor implements OrderProcessorInterface { }
```

13. **One class per file.** No exceptions.

14. **Follow Symfony's directory conventions:**

| Type | Location |
|---|---|
| Commands | `src/Command/` |
| Controllers | `src/Controller/` |
| Entity | `src/Entity/` |
| Repository | `src/Repository/` |
| Services | `src/Service/` |
| Twig Components | `src/Twig/Components/` |
| Event/Listener | `src/EventListener/` or `src/EventSubscriber/` |
| Form | `src/Form/` |
| DTO | `src/DTO/` |

## Naming

15. **Suffix classes by their role**: `Controller`, `Command`, `Repository`, `Type` (forms), `Voter`, `Listener`, `Subscriber`, `Extension`, `Provider`.

16. **Commands** follow the `app:verb-noun` pattern: `app:import-products`, `app:send-newsletter`.

17. **Events** use past tense: `OrderPlaced`, `UserRegistered`, `PaymentFailed`.
