---
name: symfony-live-component
description: Guide for creating Symfony Live Components — interactive components with real-time server-side updates via Ajax without writing JavaScript. Use this skill whenever the user wants server-side interactivity (real-time search, dynamic forms, live validation, polling, sorting/filtering without page reload), or mentions `#[AsLiveComponent]`, `LiveProp`, `LiveAction`, `data-model`, `data-loading`, `ComponentWithFormTrait`, `emit`, `emitUp`. Also relevant when the user wants to convert a static component to interactive, or create a component that reacts to user actions. This skill complements the `symfony-twig-component` skill — Twig Component fundamentals (props, blocks, attributes) also apply to Live Components.
---

# Symfony UX Live Component

**Prerequisite**: apply all rules from the `symfony-conventions` skill when writing PHP code.

A Live Component = a Twig Component enriched with server-side interactivity. Each interaction (click, input, etc.) triggers an Ajax call that re-renders the component with its new state. No JavaScript required.

**Prerequisite**: understand Twig Components (`symfony-twig-component` skill). A Live Component inherits all their features (props, blocks, attributes, hooks).

## Key differences with a Twig Component

| Twig Component | Live Component |
|---|---|
| Rendered once server-side | Re-rendered via Ajax on each interaction |
| `#[AsTwigComponent]` | `#[AsLiveComponent]` |
| Simple public properties | `#[LiveProp]` for persistent state |
| No actions | `#[LiveAction]` for backend actions |
| No binding | `data-model` for two-way binding |

## Creating a Live Component

### 1. The PHP class

```php
namespace App\Twig\Components;

use Symfony\UX\LiveComponent\Attribute\AsLiveComponent;
use Symfony\UX\LiveComponent\Attribute\LiveProp;
use Symfony\UX\LiveComponent\DefaultActionTrait;

#[AsLiveComponent]
class SearchProducts
{
    use DefaultActionTrait;  // Required

    #[LiveProp(writable: true)]
    public string $query = '';

    public function getProducts(): array
    {
        // Called on every re-render
        return $this->productRepository->search($this->query);
    }

    public function __construct(private ProductRepository $productRepository) {}
}
```

### 2. The template — critical rule: `{{ attributes }}` on the root element

```twig
{# templates/components/SearchProducts.html.twig #}
<div {{ attributes }}>
    <input type="text" data-model="query" placeholder="Search...">

    <div data-loading="addClass(opacity-50)">
        {% for product in this.products %}
            <div>{{ product.name }}</div>
        {% endfor %}
    </div>
</div>
```

`{{ attributes }}` is **mandatory** on the single root element. It contains the metadata required for the system to work.

### 3. Usage

```twig
<twig:SearchProducts />
{# or #}
{{ component('SearchProducts') }}
```

## LiveProp — persistent state across re-renders

Without `#[LiveProp]`, a property loses its value on re-render. `#[LiveProp]` makes it "stateful".

### Read-only vs. writable properties

```php
#[LiveProp]                    // Read-only — user cannot modify it
public int $productId;

#[LiveProp(writable: true)]    // Writable — can be changed via data-model or LiveAction
public string $query = '';
```

### Doctrine entity props

```php
#[LiveProp]
public Product $product;  // Dehydrated to ID, rehydrated via DB query

// Allow changing the entity itself (security risk: user can pass ANY ID)
#[LiveProp(writable: true)]
public Product $product;

// Allow modifying specific entity properties
#[LiveProp(writable: ['title', 'content'])]
public Post $post;
```

### URL-bound props (query string)

```php
use Symfony\UX\LiveComponent\Metadata\UrlMapping;

#[LiveProp(writable: true, url: true)]
public string $query = '';  // Synced with ?query=xxx in the URL

// Custom URL parameter name
#[LiveProp(writable: true, url: new UrlMapping(as: 'q'))]
public string $query = '';  // ?q=xxx
```

### onUpdated hook

```php
#[LiveProp(writable: true, onUpdated: 'onQueryUpdated')]
public string $query = '';

public function onQueryUpdated($previousValue): void
{
    // $this->query = new value
    // $previousValue = old value
    $this->page = 1;  // Reset pagination when search changes
}
```

### Supported types
- Scalars: `int`, `float`, `string`, `bool`, `null`
- Arrays of scalars
- PHP enums
- `DateTime` / `DateTimeImmutable`
- Doctrine entities
- DTOs (via PropertyAccess or Serializer)

### Custom date format
```php
#[LiveProp(writable: true, format: 'Y-m-d')]
public ?\DateTime $publishOn = null;
```

### Custom hydration (complex DTOs)
```php
#[LiveProp(useSerializerForHydration: true)]
public AddressDto $address;

// Or manually:
#[LiveProp(hydrateWith: 'hydrateAddress', dehydrateWith: 'dehydrateAddress')]
public AddressDto $address;
```

See `references/live-component-api.md` for HydrationExtensions and advanced cases.

## Data Binding — `data-model`

### Basic binding
```twig
<input type="text" data-model="query">       {# Re-renders after 150ms pause (debounce) #}
<input data-model="on(change)|email">        {# Re-renders only on blur/change #}
<input data-model="debounce(300)|query">     {# Custom debounce #}
<input data-model="norender|query">          {# Updates value WITHOUT re-rendering #}
```

### Form binding
```twig
<form data-model="*">
    <input name="firstName">    {# Auto-binding via name attribute #}
    <input name="lastName">
</form>
```

### Object binding (dot notation)
```twig
<input data-model="post.title">
<textarea data-model="post.content"></textarea>
```

### Checkboxes, radio, select
```twig
{# Boolean #}
<input type="checkbox" data-model="agreeToTerms">

{# Array of values #}
<input type="checkbox" data-model="foods[]" value="pizza">
<input type="checkbox" data-model="foods[]" value="tacos">

{# Radio #}
<input type="radio" data-model="meal" value="breakfast">
<input type="radio" data-model="meal" value="lunch">

{# Multi-select #}
<select data-model="foods" multiple>
    <option value="pizza">Pizza</option>
</select>
```

### Manual model update
```twig
<button data-model="mode" data-value="edit" data-action="live#update">
    Switch to edit mode
</button>
```

### Validation modifiers (v2.28+)
```twig
<input data-model="min_length(3)|username" type="text">
<input data-model="min_value(0)|max_value(100)|quantity" type="number">
```

## LiveAction — backend actions

```php
use Symfony\UX\LiveComponent\Attribute\LiveAction;
use Symfony\UX\LiveComponent\Attribute\LiveArg;

#[LiveAction]
public function save(): void
{
    // Business logic here
}

#[LiveAction]
public function addItem(#[LiveArg] int $id, #[LiveArg('itemName')] string $name): void
{
    // Arguments come from the frontend
}
```

```twig
{# Simple syntax #}
<button data-action="live#action" data-live-action-param="save">
    Save
</button>

{# Twig helper (more readable) #}
<button {{ live_action('save') }}>Save</button>

{# With arguments #}
<button {{ live_action('addItem', {id: item.id, itemName: 'Custom'}) }}>
    Add
</button>

{# With debounce #}
<button {{ live_action('save', {}, {debounce: 300}) }}>Save</button>
```

### Redirect after action
```php
#[LiveAction]
public function save(): Response
{
    // ... save ...
    $this->addFlash('success', 'Saved!');
    return $this->redirectToRoute('app_list');
}
```
The component must extend `AbstractController` for redirects and flash messages.

### Service injection in actions
```php
#[LiveAction]
public function save(EntityManagerInterface $em, LoggerInterface $logger): void
{
    $em->persist($this->post);
    $em->flush();
    $logger->info('Post saved');
}
```

## Loading states

```twig
{# Show/hide during loading #}
<span data-loading>Loading...</span>
<span data-loading="hide">Content visible when not loading</span>

{# Add/remove classes #}
<div data-loading="addClass(opacity-50)">...</div>
<div data-loading="addClass(opacity-50 blur)">...</div>

{# Add attributes #}
<button data-loading="addAttribute(disabled)">Save</button>

{# Delay before showing #}
<span data-loading="delay(300)|show">Loading...</span>

{# Target a specific action #}
<span data-loading="action(save)|show">Saving...</span>

{# Target a specific model #}
<span data-loading="model(email)|show">Checking...</span>

{# Combine directives #}
<div data-loading="action(save)|delay|addClass(opacity-50) addAttribute(disabled)">
```

## Deferred / lazy loading

```twig
{# defer: loads via Ajax as soon as the page is ready #}
<twig:HeavyComponent loading="defer" />

{# lazy: loads via Ajax when the element enters the viewport #}
<twig:HeavyComponent loading="lazy" />
```

### Loading placeholder
```twig
{# Via a loadingContent block #}
<twig:HeavyComponent loading="defer">
    <twig:block name="loadingContent">
        <div class="skeleton">Loading...</div>
    </twig:block>
</twig:HeavyComponent>

{# Via a dedicated template #}
<twig:HeavyComponent loading="defer" loading-template="skeleton.html.twig" />
```

### Placeholder via macro (in the component template)
```twig
{# templates/components/HeavyComponent.html.twig #}
<div {{ attributes }}>
    {% for item in this.items %}
        <div>{{ item.name }}</div>
    {% endfor %}
</div>

{% macro placeholder(props) %}
    {% for i in 1..5 %}
        <div class="skeleton-line"></div>
    {% endfor %}
{% endmacro %}
```

**defer vs lazy**: use `defer` for content that is heavy to compute but needed as soon as the page loads. Use `lazy` for content not initially visible (below the fold).

## Events — component communication

### Emitting an event

```php
use Symfony\UX\LiveComponent\ComponentToolsTrait;

#[AsLiveComponent]
class ProductForm
{
    use ComponentToolsTrait;

    #[LiveAction]
    public function save(): void
    {
        // ... save ...
        $this->emit('productSaved', ['id' => $product->getId()]);
    }
}
```

```twig
{# From Twig #}
<button data-action="live#emit" data-live-event-param="productAdded"
        data-live-id-param="{{ product.id }}">
```

### Listening to an event
```php
use Symfony\UX\LiveComponent\Attribute\LiveListener;

#[LiveListener('productSaved')]
public function onProductSaved(#[LiveArg] int $id): void
{
    // This component will be re-rendered after execution
}
```

### Event scoping
```php
$this->emit('event');              // All components on the page
$this->emitUp('event');            // Parents only
$this->emitSelf('event');          // This component only
$this->emit('event', componentName: 'ProductList');  // A specific component type
```

### Browser events (for external JavaScript)
```php
$this->dispatchBrowserEvent('modal:close');
$this->dispatchBrowserEvent('product:created', ['id' => $product->getId()]);
```
```javascript
window.addEventListener('product:created', (e) => console.log(e.detail.id));
```

## Nested components (Parent/Child)

**Fundamental rule: each component is its own isolated universe.**

### updateFromParent — sync a prop from parent to child
```php
// Child component
#[LiveProp(updateFromParent: true)]
public int $count = 0;
```
When the parent re-renders and `count` changes, the child makes a second Ajax request.

### dataModel — sync child back to parent
```twig
{# In the parent template #}
{{ component('TextareaField', { dataModel: 'content' }) }}
{# When the child modifies "value", the parent updates "content" #}

{# Custom child:parent mapping #}
{{ component('TextareaField', { dataModel: 'content:value' }) }}
```

### Keys for lists
```twig
{% for item in items %}
    {{ component('ItemCard', { item: item, key: item.id }) }}
{% endfor %}
```
The `key` helps the morphing algorithm identify elements correctly.

### Blocks in nested components
Variables from the outer template are NOT available during re-render. Only use local variables inside blocks:
```twig
{% component Alert %}
    {% block content %}
        {# Local variable — works on re-render #}
        {% set msg = 'Hello' %}
        {{ msg }}
    {% endblock %}
{% endcomponent %}
```

## Polling

```twig
{# Re-renders every 2 seconds (default) #}
<div {{ attributes }} data-poll>

{# Custom delay #}
<div {{ attributes }} data-poll="delay(5000)|$render">

{# Call a specific action #}
<div {{ attributes }} data-poll="delay(3000)|checkStatus">
```

`data-poll` goes on the component's **root** element.

## Forms

See `references/live-forms.md` for full form handling with `ComponentWithFormTrait`, `LiveCollectionType`, and submission patterns.

## Validation (without Symfony Form)

```php
use Symfony\Component\Validator\Constraints as Assert;
use Symfony\UX\LiveComponent\ValidatableComponentTrait;

#[AsLiveComponent]
class EditUser
{
    use ValidatableComponentTrait;

    #[LiveProp(writable: ['email', 'plainPassword'])]
    #[Assert\Valid]
    public User $user;

    #[LiveProp(writable: true)]
    #[Assert\IsTrue(message: 'You must agree to the terms')]
    public bool $agreeToTerms = false;

    #[LiveAction]
    public function save(): void
    {
        $this->validate();  // Throws exception if invalid → re-renders with errors
    }
}
```

```twig
{% if _errors.has('user.email') %}
    <div class="error">{{ _errors.get('user.email') }}</div>
{% endif %}
<input type="email" data-model="on(change)|user.email"
    class="{{ _errors.has('user.email') ? 'is-invalid' : '' }}">
```

Automatic validation only triggers for fields modified on the frontend — not for all fields on every re-render.

## Lifecycle hooks

```php
use Symfony\UX\LiveComponent\Attribute\PostHydrate;
use Symfony\UX\LiveComponent\Attribute\PreDehydrate;
use Symfony\UX\LiveComponent\Attribute\PreReRender;

#[PostHydrate]    // After loading state from the client
public function afterHydrate(): void {}

#[PreDehydrate]   // Before sending state to the client
public function beforeDehydrate(): void {}

#[PreReRender]    // Before re-render (not on initial render)
public function beforeReRender(): void {}
```

## Security

- **CSRF**: automatic via `Accept` header + `same-origin`/CORS policy. Do NOT use `Access-Control-Allow-Origin: *`.
- **Access control**: components ARE Symfony controllers. Use `#[IsGranted]` on the class or individual actions.
- **Writable props**: only `writable: true` props can be modified by the user. An entity with `writable: true` allows the user to pass ANY existing ID.

## JavaScript integration

```javascript
import { getComponent } from '@symfony/ux-live-component';

// In a Stimulus controller
async initialize() {
    this.component = await getComponent(this.element);
}

// API
this.component.set('mode', 'editing');     // Modify a LiveProp
this.component.render();                    // Force a re-render
this.component.action('save', {arg: 'val'}); // Call a LiveAction
this.component.emit('eventName');           // Emit an event
```

### JavaScript hooks
```javascript
this.component.on('render:started', (html, response, controls) => {
    controls.shouldRender = false;  // Prevent rendering
});
this.component.on('render:finished', (component) => {});
this.component.on('model:set', (model, value, component) => {});
this.component.on('response:error', (response, controls) => {
    controls.displayError = false;  // Suppress default error
});
```

### Adding a Stimulus controller to the component
```twig
<div {{ attributes.defaults(stimulus_controller('my-controller', {someValue: 'foo'})) }}>
```

## Morphing and `data-live-ignore`

Re-rendering uses a "morphing" algorithm that intelligently updates the DOM. To exclude an element from morphing:
```html
<input name="color" data-live-ignore>
```

To force full replacement instead of morphing:
```html
<select data-skip-morph>...</select>
```

## Testing

```php
use Symfony\UX\LiveComponent\Test\InteractsWithLiveComponents;

class SearchProductsTest extends KernelTestCase
{
    use InteractsWithLiveComponents;

    public function testSearch(): void
    {
        $component = $this->createLiveComponent('SearchProducts');

        $component->set('query', 'iPhone');
        $rendered = $component->render();
        $this->assertStringContainsString('iPhone', $rendered);

        $component->call('resetFilters');
        $component->emit('productAdded', ['id' => 1]);

        // Test redirects
        $response = $component->call('save')->response();
        $this->assertSame(302, $response->getStatusCode());

        // Authentication
        $component->actingAs($user);
    }
}
```

## Detailed references

- `references/live-component-api.md` — Full API (hydration, HydrationExtension, custom routes, fetchCredentials)
- `references/live-forms.md` — Forms with ComponentWithFormTrait, LiveCollectionType, submission
