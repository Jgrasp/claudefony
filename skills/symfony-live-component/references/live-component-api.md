# Live Component — Advanced API Reference

## Table of contents
1. [Advanced hydration](#advanced-hydration)
2. [LiveProp modifier](#liveprop-modifier)
3. [Advanced URL mapping](#advanced-url-mapping)
4. [Custom routes](#custom-routes)
5. [File uploading](#file-uploading)
6. [File downloading](#file-downloading)
7. [Advanced configuration](#advanced-configuration)

---

## Advanced hydration

### Custom HydrationExtension

For types not natively supported:

```php
use Symfony\UX\LiveComponent\Hydration\HydrationExtensionInterface;

class MoneyHydrationExtension implements HydrationExtensionInterface
{
    public function supports(string $className): bool
    {
        return $className === Money::class;
    }

    public function hydrate(mixed $value, string $className): ?object
    {
        return new Money($value['amount'], new Currency($value['currency']));
    }

    public function dehydrate(object $object): mixed
    {
        return [
            'amount' => $object->getAmount(),
            'currency' => $object->getCurrency()->getCode(),
        ];
    }
}
```

Automatically tagged `live_component.hydration_extension` via autoconfiguration.

### Hydration via Symfony Serializer

```php
#[LiveProp(useSerializerForHydration: true, serializationContext: ['groups' => ['live']])]
public ComplexDto $dto;
```

### Custom hydration methods (on the component)

```php
#[LiveProp(hydrateWith: 'hydrateAddress', dehydrateWith: 'dehydrateAddress')]
public AddressDto $address;

public function dehydrateAddress(AddressDto $address): array
{
    return ['street' => $address->street, 'city' => $address->city];
}

public function hydrateAddress(array $data): AddressDto
{
    return new AddressDto($data['street'], $data['city']);
}
```

### Entity collections

```php
/** @var Product[] */
#[LiveProp]
public array $products = [];
```
Requires `phpdocumentor/reflection-docblock`.

---

## LiveProp modifier

Dynamically modify LiveProp options at runtime:

```php
#[LiveProp(writable: true, modifier: 'modifyDateProp')]
public ?\DateTimeImmutable $date = null;

#[LiveProp]
public string $dateFormat = 'Y-m-d';

public function modifyDateProp(LiveProp $prop): LiveProp
{
    return $prop->withFormat($this->dateFormat);
}
```

Immutable methods available on `LiveProp`:
- `withFormat(string $format): LiveProp`
- `withUrl(UrlMapping $url): LiveProp`
- All `with*` methods are immutable (return a new instance)

---

## Advanced URL mapping

### Dynamic parameter name (multiple instances)

```php
#[LiveProp(writable: true, url: true, modifier: 'modifyQueryProp')]
public string $query = '';

#[LiveProp]
public ?string $alias = null;

public function modifyQueryProp(LiveProp $liveProp): LiveProp
{
    if ($this->alias) {
        return $liveProp->withUrl(new UrlMapping(as: $this->alias));
    }
    return $liveProp;
}
```

```twig
<twig:SearchModule alias="q1" />
<twig:SearchModule alias="q2" />
{# URL: ?q1=foo&q2=bar #}
```

### Map to route path (v2.28+)

```php
#[LiveProp(writable: true, url: new UrlMapping(mapPath: true))]
public string $query = '';
```
With route `/search/{query}`, URL becomes `/search/my+query+string`.

### URL representations

| JS value | URL |
|---|---|
| `'some string'` | `prop=some+string` |
| `42` | `prop=42` |
| `['foo', 'bar']` | `prop[0]=foo&prop[1]=bar` |
| `{foo: 'bar'}` | `prop[foo]=bar` |

---

## Custom routes

### Define a specific route for a component

```yaml
# config/routes.yaml
live_component_admin:
    path: /admin/_components/{_live_component}/{_live_action}
    defaults:
        _live_action: 'get'
```

```php
#[AsLiveComponent(route: 'live_component_admin')]
class AdminDashboard { ... }
```

### Localized routes

```yaml
# config/routes/ux_live_component.yaml
live_component:
    resource: '@LiveComponentBundle/config/routes.php'
    prefix: /{_locale}/_components
```

### Absolute URLs

```php
use Symfony\Component\Routing\Generator\UrlGeneratorInterface;

#[AsLiveComponent(urlReferenceType: UrlGeneratorInterface::ABSOLUTE_URL)]
class MyComponent { ... }
```

### Fetch credentials (v2.33+)

```php
#[AsLiveComponent(fetchCredentials: 'include')]  // same-origin (default), include, omit
class MyComponent { ... }
```

---

## File uploading

```twig
<input type="file" name="my_file" />

{# Send a specific file with the action #}
<button data-action="live#action"
    data-live-action-param="files(my_file)|processUpload">
    Upload
</button>

{# Send all pending files #}
<button data-action="live#action"
    data-live-action-param="files|processUpload">
    Upload all
</button>

{# Chain multiple files #}
<button data-action="live#action"
    data-live-action-param="files(photo)|files(document)|save">
    Save
</button>
```

```php
#[LiveAction]
public function processUpload(Request $request): void
{
    $file = $request->files->get('my_file');
    $multiple = $request->files->all('multiple');
}
```

---

## File downloading

No native support for file responses. Use a redirect:

```php
#[LiveAction]
public function download(UrlGeneratorInterface $urlGenerator): RedirectResponse
{
    return new RedirectResponse(
        $urlGenerator->generate('app_file_download', ['id' => $this->fileId])
    );
}
```

Add `data-turbo="false"` on the button if Turbo is enabled.

---

## Advanced configuration

### #[AsLiveComponent] options

| Option | Type | Description |
|---|---|---|
| `name` | `string` | Component name |
| `template` | `string\|FromMethod` | Template path |
| `route` | `string` | Custom route |
| `urlReferenceType` | `int` | URL reference type |
| `fetchCredentials` | `string` | Fetch credentials (`same-origin`, `include`, `omit`) |

### Backward compatibility

The public PHP API and the public JavaScript API (documented features and exports from the main JS file) are protected by Symfony's BC promise. Internal JS exports are NOT protected.
