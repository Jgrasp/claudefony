---
name: symfony-console-command
description: Guide for creating Symfony console commands. This skill should be used when the user wants to create a console command, add a CLI command, use `#[AsCommand]`, define command arguments or options, write to console output, or mentions `bin/console`, `Command::SUCCESS`, `CommandTester`, invokable commands, or command lifecycle methods (`initialize`, `interact`, `execute`).
---

# Symfony Console Command

**Prerequisite**: apply all rules from the `symfony-conventions` skill when writing PHP code.

This skill guides the creation of console commands in a Symfony project. A command is a PHP class with `#[AsCommand]` that runs via `php bin/console`.

## Creating a command

### Invokable command (recommended)

```php
// src/Command/CreateUserCommand.php
namespace App\Command;

use Symfony\Component\Console\Attribute\AsCommand;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Output\OutputInterface;

#[AsCommand(
    name: 'app:create-user',
    description: 'Creates a new user.',
)]
class CreateUserCommand
{
    public function __invoke(OutputInterface $output): int
    {
        $output->writeln('User created!');

        return Command::SUCCESS;
    }
}
```

The class does NOT need to extend `Command`. The `__invoke()` method is the entry point. Symfony auto-registers and auto-configures the command.

### `#[AsCommand]` parameters

| Parameter | Type | Description |
|---|---|---|
| `name` | `string` | Command name (what users type after `bin/console`) |
| `description` | `string` | Short description shown in `list` |
| `help` | `string` | Detailed help shown with `--help` |
| `usages` | `string[]` | Usage examples (command name omitted) |

```php
#[AsCommand(
    name: 'app:create-user',
    description: 'Creates a new user.',
    help: 'This command creates a user in the database and sends a welcome email.',
    usages: ['john', 'jane --admin'],
)]
```

### Command aliases

Use pipe (`|`) separator in the name:

```php
#[AsCommand(name: 'app:create-user|app:add-user')]
```

The first name is the primary command, others are aliases.

### Return codes

Always return an integer exit code from `__invoke()`:

| Constant | Value | Meaning |
|---|---|---|
| `Command::SUCCESS` | `0` | Command executed successfully |
| `Command::FAILURE` | `1` | An error occurred |
| `Command::INVALID` | `2` | Incorrect usage (invalid options or missing arguments) |

## Arguments and options

### Using `#[Argument]` and `#[Option]` attributes

```php
use Symfony\Component\Console\Attribute\Argument;
use Symfony\Component\Console\Attribute\AsCommand;
use Symfony\Component\Console\Attribute\Option;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Output\OutputInterface;

#[AsCommand(name: 'app:create-user')]
class CreateUserCommand
{
    public function __invoke(
        OutputInterface $output,
        #[Argument(description: 'The username of the user')] string $username,
        #[Option(description: 'Set the user as admin')] bool $admin = false,
    ): int {
        $output->writeln('Username: ' . $username);

        if ($admin) {
            $output->writeln('Admin: yes');
        }

        return Command::SUCCESS;
    }
}
```

```bash
$ php bin/console app:create-user john --admin
```

- **Argument**: positional, defined by parameter order. Required if no default value, optional if one is set.
- **Option**: prefixed with `--`, always optional. A `bool` option with default `false` acts as a flag (no value needed).

### Optional argument with default

```php
public function __invoke(
    OutputInterface $output,
    #[Argument(description: 'The username')] string $username = 'admin',
): int {
```

### Array argument (multiple values)

```php
public function __invoke(
    OutputInterface $output,
    #[Argument(description: 'List of usernames')] array $usernames = [],
): int {
```

```bash
$ php bin/console app:create-user john jane bob
```

### Option with required value

```php
public function __invoke(
    OutputInterface $output,
    #[Option(description: 'The user password')] ?string $password = null,
): int {
```

```bash
$ php bin/console app:create-user --password=secret
```

## Console output

### Writing output

```php
public function __invoke(OutputInterface $output): int
{
    // Single line with newline
    $output->writeln('User created!');

    // Multiple lines
    $output->writeln([
        'User Creator',
        '============',
        '',
    ]);

    // Without trailing newline
    $output->write('Processing... ');
    $output->writeln('done.');

    return Command::SUCCESS;
}
```

## Dependency injection

Commands are services — inject dependencies via the constructor:

```php
use App\Service\UserManager;

#[AsCommand(name: 'app:create-user')]
class CreateUserCommand
{
    public function __construct(
        private UserManager $userManager,
    ) {
    }

    public function __invoke(
        OutputInterface $output,
        #[Argument(description: 'The username')] string $username,
    ): int {
        $this->userManager->create($username);
        $output->writeln('User created!');

        return Command::SUCCESS;
    }
}
```

## Lifecycle methods

For advanced control, extend `Command` to access lifecycle hooks. Execution order: `initialize()` → `interact()` → `__invoke()`.

```php
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;

#[AsCommand(name: 'app:create-user')]
class CreateUserCommand extends Command
{
    protected function initialize(InputInterface $input, OutputInterface $output): void
    {
        // Runs first — initialize variables used in other methods
    }

    protected function interact(InputInterface $input, OutputInterface $output): void
    {
        // Runs after initialize — ask for missing arguments interactively
        // Skipped when --no-interaction is used
    }

    public function __invoke(OutputInterface $output): int
    {
        // Main command logic
        return Command::SUCCESS;
    }
}
```

Extend `Command` only when lifecycle methods are needed. For simple commands, the plain invokable class is sufficient.

## Testing

```php
// tests/Command/CreateUserCommandTest.php
namespace App\Tests\Command;

use Symfony\Bundle\FrameworkBundle\Console\Application;
use Symfony\Bundle\FrameworkBundle\Test\KernelTestCase;
use Symfony\Component\Console\Tester\CommandTester;

class CreateUserCommandTest extends KernelTestCase
{
    public function testExecute(): void
    {
        self::bootKernel();
        $application = new Application(self::$kernel);

        $command = $application->find('app:create-user');
        $commandTester = new CommandTester($command);
        $commandTester->execute([
            'username' => 'john',
            '--admin' => true,
        ]);

        $commandTester->assertCommandIsSuccessful();

        $output = $commandTester->getDisplay();
        $this->assertStringContainsString('john', $output);
    }
}
```

Passing input to `execute()`:
- Arguments: `'argument_name' => 'value'`
- Options: `'--option-name' => 'value'`
- Flags: `'--flag' => true`

`CommandTester` does NOT dispatch console events. Use `ApplicationTester` when testing event listeners.

## Common pitfalls

1. **Missing return code**: `__invoke()` must return an integer. Always use `Command::SUCCESS`, `Command::FAILURE`, or `Command::INVALID`.

2. **Naming convention**: command names follow the pattern `namespace:action` (e.g., `app:create-user`, `app:import-products`). Always prefix with `app:` to avoid collisions with framework commands.

3. **Heavy constructor logic**: the constructor runs even for `bin/console list`. Keep it lightweight — defer heavy initialization to `initialize()` or `__invoke()`.

4. **Extending Command unnecessarily**: only extend `Command` when lifecycle methods (`initialize`, `interact`) are needed. Plain invokable classes are simpler and sufficient for most cases.

## Full reference

For output sections, console helpers (progress bar, table, question), output formatting, verbosity levels, and signal handling, see `references/console-command-api.md`.