---
name: symfony-twig-component
description: Guide for creating and modifying Symfony Twig Components (reusable PHP + Twig components). Use this skill whenever the user wants to create a Twig component, an anonymous component, work with props, blocks/slots, HTML attributes, or organize reusable components in a Symfony/Sylius project. Also relevant when the user mentions component templates, `<twig:Component>`, `#[AsTwigComponent]`, or wants to refactor Twig templates into components. Do NOT use this skill for interactive/real-time components — see the `symfony-live-component` skill for that.
---

# Symfony UX Twig Component

**Prerequisite**: apply all rules from the `symfony-conventions` skill when writing PHP code.

This skill guides the creation of reusable Twig components in a Symfony project. A Twig Component = a PHP class + a Twig template, or just a template (anonymous component).

## Decision tree: which component type?

```
Does the component need PHP logic?
├── No → Anonymous component (template only, `{% props %}`)
│   Examples: button, badge, icon, card layout
└── Yes → Component with PHP class
    ├── Does it need real-time interactivity? → See `symfony-live-component` skill
    └── No → #[AsTwigComponent] (this skill)
        Examples: product list, user card, dynamic menu
```

## Creating a component with a PHP class

### 1. The PHP class

```php
// src/Twig/Components/Alert.php
namespace App\Twig\Components;

use Symfony\UX\TwigComponent\Attribute\AsTwigComponent;

#[AsTwigComponent]
class Alert
{
    public string $message;
    public string $type = 'success';
}
```

The class is a Symfony service (autowiring available). Each render creates a fresh instance (`shared: false`).

### 2. The template

```twig
{# templates/components/Alert.html.twig #}
<div class="alert alert-{{ type }}">
    {{ message }}
</div>
```

Public properties are directly accessible as variables in the template. To access methods, use `this.methodName`.

### 3. Usage

Three syntaxes — pick whichever fits the context:

```twig
{# HTML syntax (preferred for readability) #}
<twig:Alert message="Well done!" type="success" />

{# Function syntax (for components without content) #}
{{ component('Alert', {message: 'Well done!', type: 'success'}) }}

{# Tag syntax (for components with blocks) #}
{% component Alert with {type: 'success'} %}
    {% block content %}Content here{% endblock %}
{% endcomponent %}
```

## Naming conventions

| PHP Class | Component Name | Template |
|---|---|---|
| `App\Twig\Components\Alert` | `Alert` | `templates/components/Alert.html.twig` |
| `App\Twig\Components\Button\Primary` | `Button:Primary` | `templates/components/Button/Primary.html.twig` |

Use `index.html.twig` for a parent component within a directory:
```
templates/components/Menu/index.html.twig    → Menu
templates/components/Menu/Item.html.twig     → Menu:Item
```

## Creating an anonymous component (no PHP class)

For purely visual components with no business logic. The template file alone is enough:

```twig
{# templates/components/Button.html.twig #}
{% props icon, type = 'primary' %}

<button {{ attributes.defaults({class: 'btn btn-' ~ type}) }}>
    {% block content %}{% endblock %}
    {% if icon %}
        <span class="fa-solid fa-{{ icon }}"></span>
    {% endif %}
</button>
```

- `{% props %}` declares props (no default value = required)
- Non-prop attributes are accessible via `attributes`

Usage: `<twig:Button icon="save" class="mt-2">Save</twig:Button>`

## Blocks and slots

Blocks allow injecting content into a component:

```twig
{# templates/components/Card.html.twig #}
<div {{ attributes.defaults({class: 'card'}) }}>
    <div class="card-header">
        {% block header %}Default title{% endblock %}
    </div>
    <div class="card-body">
        {% block content %}{% endblock %}
    </div>
    <div class="card-footer">
        {% block footer %}{% endblock %}
    </div>
</div>
```

```twig
<twig:Card class="shadow">
    <twig:block name="header">
        <h2>My title</h2>
    </twig:block>

    <p>Main content (goes into the "content" block)</p>

    <twig:block name="footer">
        <twig:Button icon="save">Save</twig:Button>
    </twig:block>
</twig:Card>
```

Content between tags (outside `<twig:block>`) goes into the `content` block.

## HTML attributes system

Any passed attribute that does NOT match a public property becomes an HTML attribute:

```twig
{# Component #}
<div {{ attributes.defaults({class: 'alert alert-' ~ type}) }}>
    {{ message }}
</div>

{# Usage #}
<twig:Alert message="Hello" id="main-alert" class="mt-3" />

{# Output: default class + passed class merged #}
<div class="alert alert-success mt-3" id="main-alert">Hello</div>
```

### Merging rules
- **`class`**: default values are PREPENDED, passed values APPENDED
- **Other attributes**: passed values OVERRIDE defaults

### Useful methods
```twig
{{ attributes.only('class') }}                {# Only class #}
{{ attributes.without('class') }}             {# Everything except class #}
{{ attributes.render('style') }}              {# Extract a value (before {{ attributes }}) #}
{{ attributes.nested('title') }}              {# Attributes prefixed with title:xxx #}
{{ attributes.defaults(stimulus_controller('my-ctrl')) }}  {# Stimulus integration #}
```

### Nested attributes
To target non-root elements:
```twig
{# Dialog component template #}
<div {{ attributes }}>
    <div {{ attributes.nested('header') }}>{% block header %}{% endblock %}</div>
    <div {{ attributes.nested('body') }}>{% block content %}{% endblock %}</div>
</div>

{# Usage #}
<twig:Dialog class="modal" header:class="modal-header" body:class="modal-body">
    Content
</twig:Dialog>
```

## Lifecycle hooks

### mount() — initialization with props
```php
public function mount(bool $isError = false): void
{
    if ($isError) {
        $this->type = 'danger';
    }
}
```
Can receive parameters that don't match any property.

### #[PreMount] — validate/transform raw data
```php
use Symfony\UX\TwigComponent\Attribute\PreMount;

#[PreMount]
public function preMount(array $data): array
{
    // Validate/transform data BEFORE mounting
    $resolver = new OptionsResolver();
    $resolver->setIgnoreUndefined(true);  // Important!
    $resolver->setDefaults(['type' => 'success']);
    $resolver->setAllowedValues('type', ['success', 'danger', 'warning']);
    return $resolver->resolve($data) + $data;  // + $data to preserve extras
}
```

### #[PostMount] — logic after mounting
```php
use Symfony\UX\TwigComponent\Attribute\PostMount;

#[PostMount]
public function postMount(): void
{
    // All properties are already initialized here
}
```

## Computed properties

Automatic caching to avoid multiple calls:
```twig
{# Use computed. for caching #}
{% for product in computed.products %}
    {{ product.name }}
{% endfor %}
```

The `getProducts()` method will only be called once, even if `computed.products` is used multiple times.

## Dynamic props and expressions

```twig
{# Static value #}
<twig:Alert message="Hello" />

{# Twig expression (: prefix or {{ }}) #}
<twig:Alert :message="user.name" />
<twig:Alert message="{{ user.name }}" />

{# Boolean — watch the trap! #}
<twig:Alert withCloseButton />              {# true #}
<twig:Alert :withCloseButton="false" />     {# false #}
<twig:Alert withCloseButton="{{ false }}" /> {# false #}
<twig:Alert withCloseButton="false" />      {# string 'false' = TRUTHY! #}

{# Spread operator (Twig 3.7+) #}
<twig:Alert {{ ...alertProps }} />
```

## Common pitfalls to avoid

1. **Do NOT mix Twig and HTML syntax in nested components**
```twig
{# WRONG #}
<twig:Card>
    {% block footer %}
        <twig:Button>Save</twig:Button>
    {% endblock %}
</twig:Card>

{# CORRECT — all HTML syntax #}
<twig:Card>
    <twig:block name="footer">
        <twig:Button>Save</twig:Button>
    </twig:block>
</twig:Card>
```

2. **Do NOT make the class `readonly`** if it has public props
```php
// Props cannot be assigned
#[AsTwigComponent]
final readonly class Alert { public string $message; }

// Correct
#[AsTwigComponent]
final class Alert { public string $message; }
```

3. **Do NOT use `#[ExposeInTemplate]` on a computed method** (double execution)

4. **`_self` for macros does not work** inside component content. Use the full template path.

## Dynamic templates

To choose the template at runtime:
```php
use Symfony\UX\TwigComponent\Attribute\FromMethod;

#[AsTwigComponent(template: new FromMethod('getTemplate'))]
class SearchResults
{
    public string $layout = 'grid';

    public function getTemplate(): string
    {
        return 'components/SearchResults/' . $this->layout . '.html.twig';
    }
}
```

## Context variables inside blocks

```twig
{# outerScope to access variables from the parent template #}
{% set name = 'Fabien' %}
<twig:Alert :name="'Bart'">
    {{ name }}              {# Bart (from the component) #}
    {{ outerScope.name }}   {# Fabien (from the parent template) #}
</twig:Alert>

{# outerBlocks to access blocks from the parent template #}
{% extends 'base.html.twig' %}
{% block body %}
    <twig:Alert>
        {{ block(outerBlocks.call_to_action) }}
    </twig:Alert>
{% endblock %}
```

## Testing

```php
use Symfony\UX\TwigComponent\Test\InteractsWithTwigComponents;

class AlertTest extends KernelTestCase
{
    use InteractsWithTwigComponents;

    public function testRender(): void
    {
        $rendered = $this->renderTwigComponent('Alert', ['message' => 'Hello']);
        $this->assertStringContainsString('Hello', (string) $rendered);
        $this->assertCount(1, $rendered->crawler()->filter('.alert-success'));
    }
}
```

## Debugging

```bash
php bin/console debug:twig-component          # List all components
php bin/console debug:twig-component Alert     # Details of a component
```

## Full reference

For the detailed API (ExposeInTemplate, PreRender/PostRender events, CVA, advanced configuration), see `references/twig-component-api.md`.
