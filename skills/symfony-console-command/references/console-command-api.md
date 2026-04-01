# Console Command — Full API Reference

Reference material for Symfony console commands. Covers `#[Argument]`/`#[Option]` attributes in detail, `__invoke()` injection, output helpers, and advanced features.

## `#[AsCommand]` attribute

```php
#[AsCommand(
    name: 'app:create-user',
    description: 'Creates a new user.',
    help: 'This command creates a user in the database and sends a welcome email.',
    usages: ['john', 'jane --admin'],
)]
```

| Parameter | Type | Required | Description |
|---|---|---|---|
| `name` | `string` | yes | Command name. Supports aliases via pipe: `'app:create-user\|app:add-user'` |
| `description` | `string` | no | Short description shown in `bin/console list`. Retrieved without instantiating the class (performance). |
| `help` | `string` | no | Detailed help text shown with `--help` |
| `usages` | `string[]` | no | Usage examples (command name omitted) |

## `__invoke()` — injectable parameters

The `__invoke()` method supports automatic injection of console objects, attributes, and services:

```php
use Symfony\Component\Console\Attribute\Argument;
use Symfony\Component\Console\Attribute\AsCommand;
use Symfony\Component\Console\Attribute\Option;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;
use Symfony\Component\Console\Style\SymfonyStyle;

#[AsCommand(name: 'app:create-user', description: 'Creates a new user.')]
class CreateUserCommand
{
    public function __construct(
        private UserManager $userManager,
    ) {
    }

    public function __invoke(
        // Console objects (auto-injected)
        OutputInterface $output,
        InputInterface $input,
        SymfonyStyle $io,              // Auto-constructed from $input + $output

        // Arguments and options (via attributes)
        #[Argument(description: 'The username')] string $username,
        #[Option(description: 'Set user as admin')] bool $admin = false,
    ): int {
        $this->userManager->create($username);
        $io->success('User created!');

        return Command::SUCCESS;
    }
}
```

`SymfonyStyle` can be type-hinted directly — no need to construct it manually from `$input` and `$output`.

## `#[Argument]` attribute

Positional values passed after the command name.

```php
public function __invoke(
    #[Argument(description: 'The username')] string $username,

    // Optional with default
    #[Argument(description: 'The email')] string $email = 'default@example.com',

    // Array argument (captures multiple values, must be last)
    #[Argument(description: 'List of roles')] array $roles = [],

    OutputInterface $output,
): int {
```

```bash
$ php bin/console app:create-user john john@example.com ROLE_ADMIN ROLE_USER
```

**Behavior rules:**
- Parameter name becomes the argument name (`$username` → `username`)
- No default value = required argument
- Default value set = optional argument
- `array` type = accepts multiple values (must be the last argument)
- Order of `#[Argument]` parameters in the method signature defines the positional order

## `#[Option]` attribute

Named values prefixed with `--`.

```php
public function __invoke(
    // Flag (bool with default false)
    #[Option(description: 'Set user as admin')] bool $admin = false,

    // Option with required value
    #[Option(description: 'The user password')] ?string $password = null,

    // Option with shortcut
    #[Option(name: 'role', shortcut: 'r', description: 'User role')] string $role = 'user',

    // Array option (repeatable)
    #[Option(description: 'User tags')] array $tags = [],

    OutputInterface $output,
): int {
```

```bash
$ php bin/console app:create-user --admin --password=secret -r editor --tags=vip --tags=premium
```

**Behavior rules:**
- `bool` with default `false` → flag (`--admin`, no value needed)
- `?string` with default `null` → option with required value, not passed = `null`
- `string` with default → option with required value, not passed = default
- `array` with default `[]` → repeatable option (`--tags=a --tags=b`)
- `shortcut` parameter → single-letter alias (`-r` for `--role`)

## SymfonyStyle — output helper methods

### Messages

```php
$io->title('Command Title');
$io->section('Section Name');
$io->text('Regular text');
$io->text(['Line 1', 'Line 2']);
$io->listing(['Item 1', 'Item 2', 'Item 3']);
$io->newLine(2);  // Add blank lines
```

### Status messages

```php
$io->success('Done!');
$io->error('Something went wrong.');
$io->warning('Be careful.');
$io->note('This is a note.');
$io->caution('This is important.');
$io->info('FYI.');
```

### Table

```php
$io->table(
    ['Name', 'Email'],
    [
        ['John', 'john@example.com'],
        ['Jane', 'jane@example.com'],
    ]
);

// Horizontal table
$io->horizontalTable(
    ['Name', 'Email'],
    [
        ['John', 'john@example.com'],
    ]
);

// Definition list
$io->definitionList(
    ['Name' => 'John'],
    ['Email' => 'john@example.com'],
);
```

### Interactive prompts

```php
$name = $io->ask('What is your name?', 'default');
$password = $io->askHidden('Password?');
$confirm = $io->confirm('Continue?', true);
$color = $io->choice('Pick a color', ['red', 'blue', 'green'], 'blue');
```

### Progress bar

```php
$io->progressStart(100);
for ($i = 0; $i < 100; $i++) {
    $io->progressAdvance();
}
$io->progressFinish();
```

For more control, use `ProgressBar` directly:

```php
use Symfony\Component\Console\Helper\ProgressBar;

$progressBar = new ProgressBar($output, 100);
$progressBar->start();
for ($i = 0; $i < 100; $i++) {
    $progressBar->advance();
}
$progressBar->finish();
$output->writeln('');
```

## Output sections

Create independent console regions that can be updated individually:

```php
use Symfony\Component\Console\Output\ConsoleOutputInterface;

public function __invoke(OutputInterface $output): int
{
    if (!$output instanceof ConsoleOutputInterface) {
        throw new \LogicException('This command requires ConsoleOutputInterface.');
    }

    $section1 = $output->section();
    $section2 = $output->section();

    $section1->writeln('Hello');
    $section2->writeln('World!');

    $section1->overwrite('Goodbye');   // Replace all section content
    $section2->clear();                // Delete section content
    $section1->clear(2);               // Delete last N lines
    $section1->setMaxHeight(2);        // Limit visible lines

    return Command::SUCCESS;
}
```

| Method | Description |
|---|---|
| `writeln($text)` | Write to section |
| `overwrite($text)` | Replace all section content |
| `clear($lines = null)` | Delete all or n lines |
| `setMaxHeight($height)` | Set max visible lines |

Useful for multiple independent progress bars or updating tables in place.

## Verbosity levels

| Flag | Constant | Method |
|---|---|---|
| *(none)* | `OutputInterface::VERBOSITY_NORMAL` | — |
| `-q` | `OutputInterface::VERBOSITY_QUIET` | `isQuiet()` |
| `-v` | `OutputInterface::VERBOSITY_VERBOSE` | `isVerbose()` |
| `-vv` | `OutputInterface::VERBOSITY_VERY_VERBOSE` | `isVeryVerbose()` |
| `-vvv` | `OutputInterface::VERBOSITY_DEBUG` | `isDebug()` |

```php
if ($output->isVerbose()) {
    $output->writeln('Detailed info...');
}
```

## Testing commands

### CommandTester

```php
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

### ApplicationTester (for testing console events)

```php
use Symfony\Component\Console\Application;
use Symfony\Component\Console\Tester\ApplicationTester;

$application = new Application();
$application->setAutoExit(false);

$tester = new ApplicationTester($application);
$tester->run(['command' => 'app:create-user', 'username' => 'john']);
```

`CommandTester` does NOT dispatch console events. Use `ApplicationTester` when testing event listeners.

### Testing with stderr

```php
$commandTester->execute([], ['capture_stderr_separately' => true]);
$errorOutput = $commandTester->getErrorOutput();
```

## Profiling commands

```bash
$ php bin/console --profile app:my-command
$ php bin/console --profile -vvv app:my-command   # With timing and memory
```

Requires debug mode and profiler enabled.

## Error logging

Symfony automatically logs:
- Exceptions thrown during command execution (with full details)
- Non-zero exit statuses (via `ConsoleEvents::TERMINATE` event listener)

## Legacy note: configure() + execute()

In older codebases, arguments and options are defined in `configure()` and read from `InputInterface`. This approach still works but invokable commands with `#[Argument]` / `#[Option]` attributes are the recommended pattern. When encountering legacy code, prefer migrating to invokable style.
