# Twig Component — Full API Reference

## Table of contents
1. [ExposeInTemplate](#exposeintemplate)
2. [Events](#events)
3. [YAML Configuration](#yaml-configuration)
4. [Third-party bundle components](#third-party-bundles)
5. [Higher-Order Components](#higher-order-components)

---

## ExposeInTemplate

Make private/protected properties or public methods directly accessible in the template:

```php
use Symfony\UX\TwigComponent\Attribute\ExposeInTemplate;

#[AsTwigComponent]
class Alert
{
    // Private property exposed under its own name
    #[ExposeInTemplate]
    private string $message;

    // Property exposed under an alias
    #[ExposeInTemplate('alert_type')]
    private string $type = 'success';

    // Property exposed with a custom getter
    #[ExposeInTemplate(name: 'ico', getter: 'fetchIcon')]
    private string $icon = 'warning';

    // Getters are required for properties
    public function getMessage(): string { return $this->message; }
    public function getType(): string { return $this->type; }
    public function fetchIcon(): string { return $this->icon; }

    // Public method exposed
    #[ExposeInTemplate]
    public function getActions(): array { return [...]; }

    // Public method exposed under an alias
    #[ExposeInTemplate('dismissable')]
    public function canBeDismissed(): bool { return true; }
}
```

**Warning**: methods marked with `#[ExposeInTemplate]` are called **before** rendering (eagerly). Do not combine with `computed.` (double execution).

---

## Events

The component system dispatches several Symfony events:

| Event | When | Key methods |
|---|---|---|
| `PreRenderEvent` | Before rendering | `getComponent()`, `getTemplate()`, `setTemplate()`, `getVariables()`, `setVariables()` |
| `PostRenderEvent` | After rendering | Contains the `MountedComponent` |
| `PreCreateForRenderEvent` | Before component creation | Access name, props. Can short-circuit by setting HTML. Not triggered on re-render. |
| `PreMountEvent` | Before mounting | |
| `PostMountEvent` | After mounting | |

### Example: dynamically modify the template
```php
use Symfony\UX\TwigComponent\Event\PreRenderEvent;

class MyListener
{
    public function onPreRender(PreRenderEvent $event): void
    {
        $component = $event->getComponent();
        if ($component instanceof Alert && $component->type === 'critical') {
            $event->setTemplate('components/Alert/critical.html.twig');
        }
    }
}
```

---

## YAML Configuration

```yaml
# config/packages/twig_component.yaml
twig_component:
    anonymous_template_directory: 'components/'
    defaults:
        # Short form
        App\Twig\Components\: components/

        # Long form with name prefix
        App\Pizza\Components\:
            template_directory: components/pizza
            name_prefix: Pizza
```

### Name resolution with prefix
- `App\Pizza\Components\Alert` → component `Pizza:Alert`
- `App\Pizza\Components\Button\Primary` → component `Pizza:Button:Primary`

### #[AsTwigComponent] options

| Option | Type | Description |
|---|---|---|
| `name` | `string` | Custom name (default: derived from class) |
| `template` | `string\|FromMethod` | Template path or dynamic resolution |
| `exposePublicProps` | `bool` | Expose public props as variables (default: `true`) |
| `attributesVar` | `string` | Attributes variable name (default: `'attributes'`) |

---

## Third-party bundles

Bundle components use the bundle's Twig namespace:
```twig
<twig:Acme:Button type="primary">Click</twig:Acme:Button>
```

Discover available namespaces:
```bash
php bin/console debug:twig
```

---

## Higher-Order Components

Create wrapper components with spread and outerBlocks:

```twig
{# templates/components/Modal/Confirm.html.twig #}
{% props confirmText = 'Confirm', cancelText = 'Cancel' %}

<twig:Modal {{ ...attributes.defaults({class: 'modal-confirm'}) }}>
    {{ block(outerBlocks.content) }}

    <div class="modal-actions">
        <button type="button" class="btn-secondary">{{ cancelText }}</button>
        <button type="submit" class="btn-primary">{{ confirmText }}</button>
    </div>
</twig:Modal>
```

Usage:
```twig
<twig:Modal:Confirm confirmText="Delete" cancelText="No">
    Are you sure you want to delete this item?
</twig:Modal:Confirm>
```

---

## Maker command

```bash
php bin/console make:twig-component Alert          # Component with class
php bin/console make:twig-component --live EditPost # Live component
```

Generates both the PHP class and the template.
