#### UI UX

- Phlex
- Tailwind

```json
  // tailwind.config.js (dans la gem, au build)
 module.exports = {
   prefix: 'dp-',
   important: '.data-porter',
   content: [
     './app/views/data_porter/**/*.erb',
     './lib/data_porter/components/**/*.rb',
     './app/javascript/data_porter/**/*.js'
   ],
   corePlugins: {
     preflight: false  // pas de reset global, on ne touche pas au host
   },
   theme: {
     extend: {
       colors: {
         complete: 'var(--dp-color-complete, #16a34a)',
         partial:  'var(--dp-color-partial, #ca8a04)',
         missing:  'var(--dp-color-missing, #dc2626)',
         primary:  'var(--dp-color-primary, #6366f1)',
       }
     }
   }
 }
```

---
