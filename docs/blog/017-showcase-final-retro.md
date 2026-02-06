---
title: "Building DataPorter #17 -- Showcase & Final Retrospective"
series: "Building DataPorter - A Data Import Engine for Rails"
part: 17
tags: [ruby, rails, rails-engine, gem-development, retrospective, showcase, open-source]
published: false
---

# Showcase & Final Retrospective

> 17 articles, 22 composants, un gem complet. Voici DataPorter en action -- et ce que cette serie m'a appris sur la construction de Rails engines.

## Context

This is the final article in the series where we build **DataPorter**, a mountable Rails engine for data import workflows. In [part 16](#), we connected the last pieces -- ERB view templates composing Phlex components into full pages, a CSS stylesheet, and the ActiveStorage file attachment.

DataPorter is now feature-complete. Every layer works: the DSL defines import targets, the sources parse files, the orchestrator coordinates the workflow, ActionCable pushes progress in real time, Phlex components render the UI, and ERB templates tie it all together. In this article, we walk through the full workflow in a real application, then look back at the entire series.

## DataPorter in action

### Installation

A host app gets DataPorter running in three commands:

```bash
bundle add data_porter
rails generate data_porter:install
rails db:migrate
```

The install generator creates everything: the migration for the `data_porter_imports` table, an initializer with sensible defaults, the route mount, and an empty `app/importers/` directory for target classes.

### Defining a target

One file, one import type. Here is a target that imports guests from a CSV:

```ruby
# app/importers/guest_target.rb
class GuestTarget < DataPorter::Target
  label "Guests"
  model_name "Guest"
  icon "fas fa-users"

  sources :csv, :json
  dry_run_enabled

  columns do
    column :first_name, type: :string, required: true
    column :last_name,  type: :string, required: true
    column :email,      type: :email,  required: true
    column :phone,      type: :phone
    column :company,    type: :string
  end

  csv_mapping do
    map "Prenom" => :first_name
    map "Nom" => :last_name
    map "Email" => :email
    map "Telephone" => :phone
    map "Entreprise" => :company
  end

  deduplicate_by :email

  def persist(record, context:)
    Guest.create!(record.attributes)
  end

  def after_import(results, context:)
    GuestMailer.import_complete(results).deliver_later
  end
end
```

15 lines of DSL, 2 methods. The target declares its columns, maps CSV headers to attribute names, enables deduplication by email, and defines how each record is persisted. Everything else -- parsing, validation, progress tracking, UI rendering -- is handled by the engine.

### The workflow

<!-- TODO: Add screenshots here -->

**Step 1: Create a new import**

The user visits `/data_porter/imports/new`, selects "Guests" as the target, chooses "CSV" as the source type, uploads a file, and clicks "Start Import".

<!-- SCREENSHOT: new import form with target dropdown, source select, and file upload -->

**Step 2: Parsing and preview**

The ParseJob runs in the background. ActionCable pushes progress to the browser via the Stimulus-powered progress bar. When parsing completes, the import transitions to `previewing` and the page shows:

- **Summary cards**: 142 ready, 3 incomplete, 1 missing, 2 duplicates
- **Preview table**: every row with its status, data, and any errors highlighted in red

<!-- SCREENSHOT: preview page with summary cards and preview table showing mixed statuses -->

The user sees exactly what will happen before anything touches the database.

**Step 3: Dry run (optional)**

For targets that enable it, a "Dry Run" button appears. Clicking it runs every record through the actual `persist` method inside a transaction, captures any database-level errors (uniqueness violations, foreign key constraints), then rolls back. The preview table updates with a green check or red cross for each record.

<!-- SCREENSHOT: preview after dry run, showing dry_run_passed indicators -->

**Step 4: Confirm and import**

The user clicks "Confirm Import". The ImportJob processes each importable record, calling the target's `persist` method for real this time. Progress updates flow through ActionCable. When it finishes, the results summary shows the final counts.

<!-- SCREENSHOT: completed import with results summary showing imported/errored counts -->

**Step 5: Handle failures**

If something goes catastrophically wrong, the import transitions to `failed`. The FailureAlert component shows the error messages, and a "Retry" button lets the user re-parse from scratch.

<!-- SCREENSHOT: failed import with error alert and retry button -->

## The architecture at a glance

```
Host App                          DataPorter Engine
---------                         -----------------
app/importers/                    lib/data_porter/
  guest_target.rb                   target.rb (DSL)
                                    registry.rb (discovery)
config/initializers/                configuration.rb (config)
  data_porter.rb
                                  app/models/
                                    data_import.rb (state + storage)

                                  lib/data_porter/sources/
                                    csv.rb, json.rb, api.rb

                                  lib/data_porter/
                                    orchestrator.rb (parse/import/dry_run)
                                    record_validator.rb (type checks)
                                    broadcaster.rb (ActionCable)

                                  app/jobs/
                                    parse_job.rb, import_job.rb, dry_run_job.rb

                                  lib/data_porter/components/
                                    status_badge.rb, summary_cards.rb,
                                    preview_table.rb, progress_bar.rb,
                                    results_summary.rb, failure_alert.rb

                                  app/views/data_porter/imports/
                                    index.html.erb, new.html.erb, show.html.erb

                                  app/assets/stylesheets/
                                    data_porter/application.css
```

La host app fournit un fichier Target et un initializer. Le gem fournit tout le reste. La frontiere est nette : la logique metier vit dans le Target, l'infrastructure vit dans le engine.

## Ce que la serie a construit

| # | Article | Composant |
|---|---------|-----------|
| 1 | Why build a data import engine? | Motivation, problem statement |
| 2 | Scaffolding a Rails Engine gem | Engine, isolate_namespace |
| 3 | Configuration DSL | `DataPorter.configure`, defaults |
| 4 | StoreModel & JSONB | ImportRecord, Error, Report |
| 5 | Target DSL | `label`, `columns`, `persist` |
| 6 | Parsing CSV sources | Source::CSV, ActiveStorage |
| 7 | The Orchestrator | parse!, import!, error handling |
| 8 | ActionCable & Stimulus | Broadcaster, ImportChannel, progress bar |
| 9 | Phlex UI components | 7 components, dp- prefix |
| 10 | Controllers & Routing | ImportsController, engine routes |
| 11 | Generators | Install + Target generators |
| 12 | JSON & API sources | Source::JSON, Source::API |
| 13 | Testing a Rails Engine | spec_helper, structural specs |
| 14 | Dry Run | Transaction rollback, enrichment |
| 15 | Publishing & Retrospective | Gemspec, versioning, lessons |
| 16 | ERB View Templates | ERB + Phlex composition, CSS |
| 17 | Showcase & Final Retro | This article |

17 articles. Chacun avec du code reel, des tests, et une decision expliquee. Pas un tutoriel theorique -- un gem qui marche, construit etape par etape.

## Les chiffres

```
Specs:    216 examples, 0 failures
Rubocop:  80 files, 0 offenses
Runtime:  < 1 second (full suite)
```

216 specs qui couvrent chaque couche : modeles, store models, sources, orchestrator, jobs, channels, composants Phlex, controllers, routes, generators, vues. Tout tourne sur SQLite en memoire, sans dummy app, en moins d'une seconde.

## Reflexion sur l'approche

### TDD sur un gem : le bon compromis

Le cycle rouge-vert-refactor a ete applique strictement sur chaque feature. Ecrire les specs d'abord force a definir l'API avant l'implementation. Ca parait lent au debut -- on ecrit du code qui ne compile meme pas. Mais ca raccourcit le cycle total parce que les decisions d'API sont prises une fois, pas trois.

Le piege : TDD ne remplace pas les tests d'integration dans la host app. Les specs du gem verifient que chaque composant fonctionne en isolation. Elles ne verifient pas que l'ensemble fonctionne avec la vraie config de l'app, les vrais modeles, et le vrai middleware. Le gem teste son cablage. La host app teste son comportement. Les deux sont necessaires.

### Rails 8 et les engines : les surprises

Rails 8 a change des choses subtiles pour les engines :

**`ActionView::Base`** refuse d'etre instancie directement. Il faut passer par `with_empty_template_cache`. Ca n'est documente nulle part dans les guides Rails -- on le decouvre quand le test leve `NotImplementedError`.

**`belongs_to` required by default** s'applique meme quand on n'appelle pas `initialize!` dans les anciens tests. Mais des qu'on bootstrap une vraie app Rails (necessaire pour ActiveStorage), la validation s'active et casse tous les tests qui creent un DataImport avec `user_type: "User", user_id: 1` sans avoir un User reel en base. La solution : `optional: true` sur l'association.

**Les URL helpers des engines** necessitent le controller de l'engine (pas un `ActionController::Base` generique) pour resoudre les routes. Le view delègue `_routes` a son controller. Si le controller n'a pas les routes de l'engine, `import_path` leve une erreur cryptique sur `data_porter_path`.

### Phlex sans phlex-rails : ca marche

Le choix de ne pas dependre de phlex-rails etait delibere. Chaque composant est un objet Ruby pur dans `lib/`. On le rend avec `.call`. On le teste avec `.call`. On l'integre dans ERB avec `raw component.call`. Pas de helpers magiques, pas de resolution de templates, pas de conflits avec le systeme de vues de la host app.

Le cout : chaque appel est un peu verbeux. `<%= raw DataPorter::Components::StatusBadge.new(status: @import.status).call %>` est plus long que `<%= render StatusBadge.new(status: @import.status) %>`. Mais la clarte vaut le compromis. En lisant le template, on sait exactement ce qui se passe.

### La stylesheet plain CSS : sous-estime

Pas de Tailwind build, pas de PostCSS, pas de Sass. Un fichier CSS avec des classes prefixees `dp-`. Ca marche sur n'importe quelle app Rails, que la host utilise Sprockets, Propshaft, ou importmap. Pas de configuration, pas de compatibilite a gerer.

Le `dp-` prefix empeche les collisions. La host app peut override n'importe quelle classe. Elle peut aussi ignorer completement la stylesheet et fournir la sienne. La convention est simple et suffisante.

## Et apres ?

DataPorter 0.1.0 couvre le workflow complet : upload, parse, preview, dry run, import. Voici les pistes pour les versions suivantes :

**Batch imports** -- Pour les fichiers de 100k+ lignes, `insert_all` par lots au lieu de `create!` par record. Ca necessite de repenser le contrat de `persist`.

**Turbo Streams** -- Remplacer le rechargement complet de la page apres un changement de statut par des Turbo Stream updates cibles. Le show template pourrait se mettre a jour sans rechargement.

**Theming** -- Exposer des CSS custom properties (`--dp-primary`, `--dp-danger`) pour permettre a la host app de themer DataPorter sans reecrire les styles.

**Export** -- Le chemin inverse. Si on sait parser et valider des records, on sait aussi les serialiser. Le Target a deja toute l'information necessaire.

**Dashboard** -- Une page d'overview avec des stats agregees : imports par jour, taux d'erreur, temps moyen de traitement. Les donnees sont deja dans la table `data_porter_imports`.

## Le mot de la fin

DataPorter est ne d'un constat simple : on reconstruit le meme workflow d'import dans chaque app Rails. 17 articles plus tard, c'est un gem publie avec un DSL propre, une UI complete, et 216 tests.

La methode -- TDD strict, un article par feature, des decisions documentees -- force a construire quelque chose de solide. Pas de raccourcis, pas de "on verra plus tard". Chaque composant existe parce qu'un test l'exige, et chaque test existe parce qu'un besoin a ete identifie.

Le resultat : un `bundle add data_porter`, un generator, un Target de 15 lignes, et n'importe quelle app Rails a un systeme d'import complet avec preview, validation temps reel, dry run, et progression live.

C'etait le plan. Il aura fallu 17 articles pour y arriver. Et ca valait le coup.

---

*This is part 17 and the final article of the series "Building DataPorter - A Data Import Engine for Rails". [Previous: ERB View Templates](#)*
