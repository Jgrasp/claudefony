# Live Component — Forms

## Table of contents
1. [ComponentWithFormTrait](#componentwithformtrait)
2. [Form submission](#form-submission)
3. [Dynamic value manipulation](#dynamic-value-manipulation)
4. [CollectionType](#collectiontype)
5. [LiveCollectionType](#livecollectiontype)
6. [Common issues](#common-issues)

---

## ComponentWithFormTrait

The `ComponentWithFormTrait` connects a standard Symfony form to a Live Component:

```php
use Symfony\UX\LiveComponent\Attribute\AsLiveComponent;
use Symfony\UX\LiveComponent\ComponentWithFormTrait;
use Symfony\UX\LiveComponent\DefaultActionTrait;

#[AsLiveComponent]
class PostForm extends AbstractController
{
    use DefaultActionTrait;
    use ComponentWithFormTrait;

    #[LiveProp]
    public ?Post $initialFormData = null;

    protected function instantiateForm(): FormInterface
    {
        return $this->createForm(PostType::class, $this->initialFormData);
    }
}
```

### Template

```twig
<div {{ attributes }}>
    {{ form_start(form) }}
        {{ form_row(form.title) }}
        {{ form_row(form.slug) }}
        {{ form_row(form.content) }}
        <button type="submit">Save</button>
    {{ form_end(form) }}
</div>
```

### How it works

1. `ComponentWithFormTrait` creates a writable `$formValues` LiveProp containing all field values
2. When the user modifies a field → the corresponding key in `$formValues` is updated → Ajax re-render
3. The form is submitted with `$formValues` and re-rendered with validation errors

### Disable re-render on each field change (norender)

By default, each field change triggers a re-render. To only re-render on submission:

```php
private function getDataModelValue(): ?string
{
    return 'norender|*';
}
```

Or individually:
```twig
<input data-model="on(change)|*" name="title">
```

---

## Form submission

### Via LiveAction (recommended)

```php
#[LiveAction]
public function save(EntityManagerInterface $em): Response
{
    // IMPORTANT: the form is NOT automatically submitted in a LiveAction
    $this->submitForm();

    $form = $this->getForm();
    if (!$form->isValid()) {
        return; // Component re-renders with errors
    }

    $post = $form->getData();
    $em->persist($post);
    $em->flush();

    $this->addFlash('success', 'Post saved!');
    return $this->redirectToRoute('app_post_show', ['id' => $post->getId()]);
}
```

```twig
{{ form_start(form, {
    attr: {
        'data-action': 'live#action:prevent',
        'data-live-action-param': 'save'
    }
}) }}
    {{ form_row(form.title) }}
    {{ form_row(form.content) }}
    <button type="submit">Save</button>
{{ form_end(form) }}
```

The `:prevent` prevents the native HTTP form submission.

### Via a standard controller

For cases where you want to submit the form via a standard route (not Ajax):

```twig
{# In the controller, pass the pre-submitted form to the component #}
{{ component('PostForm', { initialFormData: post, form: form }) }}
```

Passing the `form` variable prevents the component from creating a fresh form (which would lose validation errors).

---

## Dynamic value manipulation

To modify form values from a LiveAction, manipulate `$this->formValues` directly:

```php
#[LiveAction]
public function generateSlug(): void
{
    $title = $this->formValues['title'] ?? '';
    $this->formValues['slug'] = Str::slug($title);
}

#[LiveAction]
public function setAuthor(#[LiveArg] int $authorId): void
{
    // For entity fields, use the ID
    $this->formValues['author'] = $authorId;
}
```

**Important**: values in `$formValues` are **raw scalars** (string, int...), not objects. For an `EntityType` field, it's the ID; for a `ChoiceType`, it's the choice value.

---

## CollectionType

To add/remove items in a standard `CollectionType`:

```php
#[LiveAction]
public function addComment(): void
{
    $this->formValues['comments'][] = [];
}

#[LiveAction]
public function removeComment(#[LiveArg] int $index): void
{
    unset($this->formValues['comments'][$index]);
}
```

```twig
{% for key, commentForm in form.comments %}
    {{ form_row(commentForm) }}
    <button {{ live_action('removeComment', {index: key}) }}>
        Remove
    </button>
{% endfor %}

<button {{ live_action('addComment') }}>Add a comment</button>
```

---

## LiveCollectionType

A specialized field type that provides add/remove buttons automatically:

### Form configuration

```php
use Symfony\UX\LiveComponent\Form\Type\LiveCollectionType;

// In the FormType
$builder->add('comments', LiveCollectionType::class, [
    'entry_type' => CommentFormType::class,
    'allow_add' => true,
    'allow_delete' => true,
]);
```

### Component

```php
use Symfony\UX\LiveComponent\LiveCollectionTrait;

#[AsLiveComponent]
class BlogPostForm extends AbstractController
{
    use LiveCollectionTrait;   // Instead of ComponentWithFormTrait
    use DefaultActionTrait;

    #[LiveProp]
    public BlogPost $initialFormData;

    protected function instantiateForm(): FormInterface
    {
        return $this->createForm(BlogPostFormType::class, $this->initialFormData);
    }
}
```

### Template

```twig
<div {{ attributes }}>
    {{ form_start(form) }}
        {{ form_row(form.title) }}

        {# LiveCollectionType handles add/remove buttons #}
        {{ form_row(form.comments) }}

        <button type="submit">Save</button>
    {{ form_end(form) }}
</div>
```

### Button customization

```php
->add('comments', LiveCollectionType::class, [
    'entry_type' => CommentFormType::class,
    'button_delete_options' => [
        'label' => 'Remove',
        'attr' => ['class' => 'btn btn-danger btn-sm'],
    ],
    'button_add_options' => [
        'label' => 'Add a comment',
        'attr' => ['class' => 'btn btn-outline-primary'],
    ],
])
```

### Form theming

Twig blocks for theming use the `live_collection_` prefix:

```twig
{% block live_collection_widget %}
    {# Customize collection rendering #}
{% endblock %}

{% block live_collection_button_add_widget %}
    {# Customize add button #}
{% endblock %}

{% block live_collection_button_delete_widget %}
    {# Customize delete button #}
{% endblock %}
```

---

## Common issues

### Trailing spaces in text inputs

Symptom: trailing spaces are stripped from input.
Solution: add `'trim' => false` on the form field.

### Password field always empty

Symptom: the password field is cleared on re-render.
Solution: `'always_empty' => false` on the `PasswordType`.

### Form submitted in LiveAction but data is empty

Symptom: `$form->getData()` returns empty values.
Cause: the form is not automatically submitted in a LiveAction.
Solution: call `$this->submitForm()` before `$this->getForm()`.

### Resetting the form

```php
// After a successful save, to reset the form
$this->resetForm();
```

### Testing a Live form

```php
$component = $this->createLiveComponent('PostForm', [
    'initialFormData' => $post,
]);

// Add collection items
$component->call('addCollectionItem', ['name' => 'comments']);

// Submit the form
$component->submitForm([
    'post_form' => [
        'title' => 'My title',
        'content' => 'My content',
    ]
]);

$rendered = $component->render();
$this->assertStringNotContainsString('error', $rendered);
```
