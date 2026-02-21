---
title: Views & Theming
icon: material/palette
---

# Views & Theming

DataPorter ships a complete UI out of the box. Two customization layers let you adapt it to your design system without forking.

## View Generator

Copy the engine's ERB templates into your app for structural customization:

```bash
# Copy everything (views + layout)
bin/rails generate data_porter:views

# Copy only a specific scope
bin/rails generate data_porter:views imports            # index, new, show
bin/rails generate data_porter:views mapping_templates  # index, new, edit, _form
bin/rails generate data_porter:views layout             # application.html.erb
```

Rails resolves host app views before engine views -- copied files override automatically, no configuration needed. Views you don't copy keep using the gem's defaults.

### Copied files

| Scope | Files | Destination |
|---|---|---|
| `imports` | `index.html.erb`, `new.html.erb`, `show.html.erb` | `app/views/data_porter/imports/` |
| `mapping_templates` | `index.html.erb`, `new.html.erb`, `edit.html.erb`, `_form.html.erb` | `app/views/data_porter/mapping_templates/` |
| `layout` | `application.html.erb` | `app/views/layouts/data_porter/` |

## CSS Theming

All styles use `--dp-*` CSS custom properties. Override them in your own stylesheet to match your design system -- no ERB changes needed:

```css
:root {
  --dp-primary: #e11d48;
  --dp-primary-hover: #be123c;
  --dp-radius-md: 0.25rem;
}
```

### Semantic variables

These high-level variables control surfaces and text across all components:

| Variable | Default (light) | Description |
|---|---|---|
| `--dp-bg` | `white` | Page background |
| `--dp-bg-elevated` | `white` | Cards, forms, modals |
| `--dp-bg-subtle` | `--dp-gray-50` | Subtle backgrounds (table headers, hover) |
| `--dp-text` | `--dp-gray-800` | Body text |
| `--dp-text-heading` | `--dp-gray-900` | Headings |
| `--dp-text-muted` | `--dp-gray-500` | Secondary text, labels |
| `--dp-border` | `--dp-gray-200` | Default borders |
| `--dp-border-strong` | `--dp-gray-300` | Emphasized borders |

### Color palette

| Variable | Default | Usage |
|---|---|---|
| `--dp-primary` | `#4f46e5` | Buttons, links, focus rings |
| `--dp-success` | `#059669` | Success states |
| `--dp-warning` | `#d97706` | Warning states |
| `--dp-danger` | `#dc2626` | Error states, delete buttons |
| `--dp-info` | `#2563eb` | Informational badges |

Each color has `-light` (background) and `-border` variants.

## Dark Mode

DataPorter includes a built-in dark mode with a toggle button.

### How it works

- A theme toggle button (bottom-right corner) switches between light and dark
- The selected theme is persisted in `localStorage` (`dp-theme` key)
- On first visit, the theme follows the user's OS preference (`prefers-color-scheme`)

### CSS classes

| Class | Behavior |
|---|---|
| `.dp-dark` | Force dark mode |
| `.dp-auto` | Follow OS preference via `@media (prefers-color-scheme: dark)` |

### Disabling the toggle

If you copy the layout (`rails g data_porter:views layout`), remove the toggle button from `app/views/layouts/data_porter/application.html.erb`:

```erb
<%# Delete this line to remove the toggle button %>
<button class="dp-theme-toggle" ...>
```

### Force a specific theme

To always use dark mode, add the class to the body in your copied layout:

```erb
<body class="dp-dark" data-controller="data-porter--theme">
```

Or remove the Stimulus controller entirely and set the class statically.

### Custom dark palette

Override the dark variables in your own stylesheet:

```css
.dp-dark {
  --dp-bg: #0a0a0a;
  --dp-bg-elevated: #171717;
  --dp-primary: #818cf8;
}
```
