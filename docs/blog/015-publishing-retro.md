---
title: "Building DataPorter #15 -- Publication et retrospective"
series: "Building DataPorter - A Data Import Engine for Rails"
part: 15
tags: [ruby, rails, rails-engine, gem-development, rubygems, retrospective, open-source]
published: false
---

# Publication et retrospective

> De `bundle gem` a `gem push` : retour sur 14 articles, 20 composants, et les lecons apprises en construisant un Rails engine de A a Z avec TDD.

## Context

This is the final article in the series where we build **DataPorter**, a mountable Rails engine for data import workflows. In [part 14](#), we added Dry Run mode -- the last safety net before data touches the database.

We started this series with a question: why do we keep rebuilding the same import workflow in every Rails app? Fourteen articles later, we have a published gem that answers it. This article covers the last mile -- publishing to RubyGems -- then steps back to look at what we built, what we learned, and what we would do differently.

## Publishing the gem

### Le gemspec final

The gemspec is the identity card of a Ruby gem. Everything RubyGems needs to index, display, and resolve dependencies lives here. Here is ours in its final form:

```ruby
# data_porter.gemspec
Gem::Specification.new do |spec|
  spec.name = "data_porter"
  spec.version = DataPorter::VERSION
  spec.authors = ["Seryl Lounis"]
  spec.email = ["seryllounis@outlook.fr"]

  spec.summary = "Rails engine for multi-step data imports with preview"
  spec.description = "A mountable Rails engine providing a complete data import workflow: " \
                     "upload/configure, preview with validation, and import. " \
                     "Supports CSV, JSON, and API sources with a simple DSL for defining import targets."
  spec.homepage = "https://github.com/SerylLns/data_porter"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/SerylLns/data_porter"
  spec.metadata["changelog_uri"] = "https://github.com/SerylLns/data_porter/blob/master/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # ...

  spec.add_dependency "csv"
  spec.add_dependency "phlex", ">= 1.0"
  spec.add_dependency "rails", ">= 7.0"
  spec.add_dependency "store_model", ">= 2.0"
  spec.add_dependency "turbo-rails", ">= 1.0"
end
```

Quelques points a noter. `rubygems_mfa_required` force l'authentification multi-facteur pour publier -- c'est devenu un standard pour tout gem open source serieux. Le `required_ruby_version` a `>= 3.2.0` exclut les versions de Ruby qui ne sont plus maintenues. Les dependances runtime sont volontairement larges (`>= 1.0`, `>= 7.0`) pour eviter de bloquer les host apps sur des versions specifiques.

Le filtre `spec.files` exclut les fichiers de dev (`spec/`, `bin/`, `.github/`) pour que le gem publie ne contienne que le code de production. C'est important -- personne ne veut telecharger 2 Mo de specs quand il installe un gem.

### Versioning

DataPorter suit le semantic versioning :

- **0.1.0** : premiere release. Le `0.x` indique clairement que l'API peut encore evoluer.
- **0.x.y** : chaque nouvelle feature (un nouveau type de source, un nouveau composant) incremente le minor. Chaque bugfix incremente le patch.
- **1.0.0** : viendra quand l'API sera stabilisee et testee en production sur plusieurs apps.

Le numero de version vit dans un seul fichier :

```ruby
# lib/data_porter/version.rb
module DataPorter
  VERSION = "0.1.0"
end
```

Un seul endroit a modifier. Le gemspec le lit avec `require_relative`. Le CHANGELOG le reference. Le tag Git le reprend. Pas de duplication.

### Le workflow de publication

```bash
# 1. Mettre a jour la version
# lib/data_porter/version.rb -> VERSION = "0.1.0"

# 2. Mettre a jour le CHANGELOG
# CHANGELOG.md -> ## [0.1.0] - 2026-02-06

# 3. Commit, tag, push
git add -A && git commit -m "Release v0.1.0"
git tag v0.1.0
git push origin master --tags

# 4. Build et push
gem build data_porter.gemspec
gem push data_porter-0.1.0.gem
```

Ou, si le Rakefile est configure avec `bundler/gem_tasks` :

```bash
bundle exec rake release
```

Cette commande fait tout d'un coup : build, tag Git, push Git, push RubyGems. C'est la methode recommandee parce qu'elle garantit que le tag et le gem sont synchronises.

## Documentation

Un gem sans documentation est un gem que personne n'utilisera. DataPorter s'appuie sur trois niveaux de doc :

**Le README** : point d'entree. Installation en une commande (`rails generate data_porter:install`), un exemple de Target en 15 lignes, le diagramme du workflow en trois etapes. Un developpeur doit pouvoir comprendre ce que fait le gem et l'installer en moins de 5 minutes.

**Le CHANGELOG** : chaque release documentee avec ce qui a change, ce qui a ete ajoute, ce qui a casse. Format [Keep a Changelog](https://keepachangelog.com/) -- c'est un standard que la communaute Ruby connait.

**Les commentaires inline** : chaque methode publique documentee avec YARD. Le DSL est le point le plus critique -- `column`, `sources`, `csv_mapping`, `persist` doivent etre documentes avec des exemples, parce que c'est ce que les utilisateurs liront le plus.

## Ce qu'on a construit

Voici la liste complete des composants qui forment DataPorter, dans l'ordre ou on les a construits :

| # | Composant | Role |
|---|-----------|------|
| 1 | **Engine + isolate_namespace** | Structure du gem, isolation des noms |
| 2 | **Configuration DSL** | `DataPorter.configure`, defaults, `context_builder` |
| 3 | **StoreModels (ImportRecord, Error, Report)** | Structures JSONB typees sans tables supplementaires |
| 4 | **TypeValidator** | Validation de types (email, phone, url) sur les colonnes |
| 5 | **Target DSL** | `label`, `model`, `columns`, `sources`, `persist` |
| 6 | **Registry** | Auto-decouverte et resolution des targets |
| 7 | **Source::Base + Source::CSV** | Abstraction de sources, parsing CSV avec mapping |
| 8 | **DataImport model** | ActiveRecord, enum status, polymorphic user |
| 9 | **Orchestrator** | Coordination parse/import, gestion d'erreurs par record |
| 10 | **RecordValidator** | Validations generiques (required, type) |
| 11 | **ParseJob + ImportJob** | Background processing via ActiveJob |
| 12 | **Broadcaster + ImportChannel** | Progression temps reel via ActionCable |
| 13 | **7 composants Phlex** | StatusBadge, SummaryCards, PreviewTable, ProgressBar, ResultsSummary, FailureAlert |
| 14 | **Stimulus controller** | Animation de la barre de progression cote client |
| 15 | **ImportsController** | Heritage dynamique, 7 actions, Turbo integration |
| 16 | **Install generator** | Migration, initializer, routes, repertoire importers |
| 17 | **Target generator** | Scaffold de target avec parsing de colonnes |
| 18 | **Source::JSON** | Import depuis fichier JSON ou texte brut |
| 19 | **Source::API** | Import depuis endpoint HTTP avec auth et params |
| 20 | **Dry Run** | Transaction + rollback, enrichissement des records avec erreurs DB |

Vingt composants. Chacun avec ses specs. Chacun avec un article qui explique pourquoi il existe et comment il fonctionne.

## L'architecture : le flux complet

Voici ce qui se passe quand un utilisateur importe un fichier CSV, du debut a la fin :

```
Upload (Controller#create)
  |
  v
Parse (ParseJob -> Orchestrator#parse!)
  |-- Source::CSV.fetch -> raw rows
  |-- Target.transform(record) -> transformation
  |-- RecordValidator.validate(record) -> required, types
  |-- Target.validate(record) -> business rules
  |-- record.determine_status! -> complete/partial/missing
  |-- Broadcaster -> ActionCable -> Stimulus -> progress bar
  |
  v
Preview (Controller#show)
  |-- PreviewTable(columns, records) -> tableau dynamique
  |-- SummaryCards(report) -> compteurs par statut
  |-- StatusBadge(status) -> badge "previewing"
  |
  v
Dry Run (DryRunJob -> Orchestrator dans transaction + rollback)
  |-- Enrichit les records avec les erreurs DB
  |-- Broadcaster -> progression
  |
  v
Import (ImportJob -> Orchestrator#import!)
  |-- Target.persist(record, context:) -> par record
  |-- rescue -> record.add_error, continue
  |-- Target.after_import(results, context:)
  |-- Broadcaster -> "completed"
  |
  v
Results (Controller#show)
  |-- ResultsSummary(report) -> imported/errored counts
  |-- PreviewTable avec erreurs inline
```

Le gem possede l'infrastructure. La host app possede la logique metier. La separation est nette : un seul fichier Target et un initializer, c'est tout ce que la host app doit fournir.

## Lecons apprises

### TDD sans dummy app

La decision la plus structurante de la serie : tester le engine sans creer d'application Rails dans `spec/dummy/`. Un `spec_helper.rb` de 60 lignes qui bootstrap SQLite en memoire, configure les load paths, et stub `ApplicationController`. Ca marche, et ca marche bien -- le suite tourne en moins d'une seconde.

L'avantage inattendu : cette contrainte force a garder chaque composant decouple. Si un composant a besoin d'un router pour etre teste, c'est un signal qu'il est trop couple au framework. Les tests structurels sur les controllers (verifier l'heritage, les callbacks, les methodes) semblaient etranges au debut. Avec le recul, ils testent exactement ce que le gem possede -- le cablage -- et laissent les tests d'integration a la host app.

Le piege a eviter : la duplication entre le schema dans `spec_helper.rb` et la migration template. Si les deux divergent, les tests passent mais la migration generee ne correspond pas a ce qui est teste. Un commentaire explicite dans le spec_helper rappelle cette dependance.

### StoreModel : les gotchas

StoreModel est puissant, mais il a ses subtilites :

**Dirty tracking** : quand on modifie un objet a l'interieur d'un attribut `store_model`, ActiveRecord ne detecte pas le changement. On peut modifier `data_import.records.first.status = "complete"` et appeler `save` -- rien ne sera persiste. La solution : appeler `records_will_change!` avant de modifier, ou reassigner l'attribut entier avec `data_import.records = modified_records`.

**Serialisation round-trip** : les cles symboles deviennent des cles string apres un save/reload. `{ name: "Alice" }` revient en `{ "name" => "Alice" }`. Il faut le savoir et coder en consequence -- soit toujours utiliser des string keys, soit appeler `symbolize_keys` a la sortie. DataPorter fait le second dans `ImportRecord#attributes`.

**SQLite vs PostgreSQL** : en test, les colonnes StoreModel sont des `text`. En production, elles sont `jsonb`. StoreModel gere la difference de facon transparente, mais certaines requetes JSONB (indexes, contains) ne sont pas testables en SQLite. C'est un compromis acceptable pour la vitesse du feedback loop.

### Phlex dans un engine : `plain` vs `text`

Un piege specifique a Phlex : pour emettre du texte brut a l'interieur d'un element, il faut utiliser `plain` (pas `text`). Dans les premieres versions de Phlex, `text` existait mais a ete renomme. Si vous utilisez `text` avec une version recente, vous obtenez un `NoMethodError` cryptique. La SummaryCards le montre bien :

```ruby
def card(css_class, count, label)
  div(class: "dp-card #{css_class}") do
    strong { count.to_s }
    plain " #{label}"   # pas text, pas p, juste du texte brut
  end
end
```

L'autre subtilite : appeler `super()` dans le `initialize` de chaque composant. Phlex l'exige, et l'oublier produit des erreurs silencieuses ou des rendus vides.

### Patterns de test : controllers, channels, JS

Tester du JavaScript depuis Ruby en lisant le fichier comme du texte et en assertant sur les strings -- ca semble hacky. En pratique, ca detecte la categorie de bugs la plus frequente dans un engine : le desalignement entre le code Ruby et le code JS. Le channel s'appelle `DataPorter::ImportChannel` en Ruby et `"DataPorter::ImportChannel"` en JS. Si l'un change et pas l'autre, le test echoue. Pour un seul fichier Stimulus de 30 lignes, ca vaut mieux que d'ajouter Jest et `node_modules` au projet.

Les tests structurels de controllers (`_process_action_callbacks`, `instance_method`, `superclass`) forment un contrat : le gem garantit que le controller a la bonne forme. La host app garantit qu'il se comporte correctement dans son contexte. C'est une separation de responsabilites propre.

## Et apres ?

DataPorter 0.1.0 couvre le workflow standard. Voici ce qui pourrait venir dans les versions suivantes :

**Batch imports** : pour les fichiers de 100k+ lignes, importer par lots de 1000 avec `insert_all` au lieu de `create!` record par record. Ca necessite de repenser le contrat de `persist` -- au lieu d'un record a la fois, le target recevrait un batch.

**Streaming de progression** : remplacer ActionCable par Server-Sent Events (SSE) pour les apps qui n'ont pas besoin de WebSocket bidirectionnel. Plus leger, pas de Redis en dependance.

**Validateurs custom** : permettre aux targets de declarer des validateurs avec un DSL :

```ruby
columns do
  column :email, type: :email, required: true, validate: ->(val) {
    "already exists" if User.exists?(email: val)
  }
end
```

**Export** : le chemin inverse. Si on sait parser et valider des records, on sait aussi les serialiser en CSV/JSON. Le Target a deja toute l'information necessaire (colonnes, types, labels).

**Support Excel** : un `Source::Xlsx` qui s'appuie sur `roo` ou `creek` pour parser les fichiers `.xlsx`. Le pattern Source est la, il suffit d'implementer `fetch`.

## Reflexion finale

Construire DataPorter a ete un exercice de discipline autant que de code. La methode -- Taskmaster pour planifier, TDD pour implementer, un article pour documenter chaque etape -- force a prendre des decisions explicites. Pas de "on verra plus tard". Chaque composant existe parce qu'un test l'exige, et chaque test existe parce qu'un comportement a ete specifie.

Le choix de ne pas utiliser de dummy app etait un pari. Il a paye : les tests sont rapides, les composants sont decouples, et le gem est testable sans infrastructure Rails. Mais il a un cout -- certains bugs d'integration ne seront detectes que dans la host app. C'est un tradeoff assume : le gem teste son cablage, la host app teste son comportement.

StoreModel, Phlex, Stimulus -- chaque dependance a apporte sa part de surprises. Le dirty tracking de StoreModel, le `plain` vs `text` de Phlex, le nommage a double tiret de Stimulus pour les engines. Ces gotchas n'apparaissent dans aucune documentation. Ils apparaissent quand un test echoue a 23h et qu'on lit le code source du gem pour comprendre pourquoi. C'est ca, le vrai avantage du TDD : on decouvre les problemes dans le terminal, pas en production.

DataPorter est maintenant un gem publie sur RubyGems. Un `bundle add data_porter`, un `rails generate data_porter:install`, un Target de 15 lignes, et n'importe quelle app Rails a un systeme d'import complet avec preview, validation, progression temps reel et dry run.

C'etait le plan depuis le debut. Il aura fallu 15 articles pour y arriver.

---

*This is part 15 of the series "Building DataPorter - A Data Import Engine for Rails". [Previous: Dry Run: Validate Before You Persist](#)*
