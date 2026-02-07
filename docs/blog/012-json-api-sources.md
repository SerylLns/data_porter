---
title: "Building DataPorter #12 -- Au-dela du CSV : Sources JSON et API"
series: "Building DataPorter - A Data Import Engine for Rails"
part: 12
tags: [ruby, rails, rails-engine, gem-development, json, api, http, sources, dsl]
published: false
---

# Au-dela du CSV : Sources JSON et API

> Le CSV est le format roi de l'import de donnees -- mais dans la vraie vie, les donnees arrivent aussi en JSON depuis un fichier, ou directement depuis une API tierce. Voici comment DataPorter etend son architecture de sources pour absorber ces nouveaux formats sans rien casser.

## Contexte

Ceci est la partie 12 de la serie ou nous construisons **DataPorter**, un engine Rails montable pour les workflows d'import de donnees. Dans la [partie 11](#), nous avons construit les generateurs install et target pour que l'adoption du gem se fasse en une seule commande.

Jusqu'ici, DataPorter ne sait lire que du CSV. C'est suffisant pour beaucoup de cas, mais le monde reel est plus varie : un partenaire envoie un export JSON, un service interne expose une API REST, un front-end pousse du JSON brut dans un formulaire. Si chaque nouveau format demande de rearchitecturer le moteur, on a rate quelque chose. L'abstraction `Sources::Base` que nous avons posee dans la partie 6 va maintenant montrer sa valeur.

## Pourquoi plusieurs sources ?

Un moteur d'import qui ne parle que CSV force les utilisateurs a convertir leurs donnees avant de les importer. C'est de la friction inutile. En supportant JSON et API nativement, on couvre trois scenarios courants :

- **CSV** -- L'utilisateur uploade un fichier depuis son poste.
- **JSON** -- L'utilisateur uploade un fichier JSON, ou bien le systeme injecte du JSON brut via la configuration.
- **API** -- Le systeme va chercher les donnees directement sur un endpoint HTTP, avec authentification et parametres dynamiques.

Le point cle : chaque source doit respecter le meme contrat -- une methode `fetch` qui retourne un tableau de hashes avec des cles symboliques. Le reste du pipeline (validation, transformation, persistence) ne change pas.

## La source JSON

La source JSON doit gerer trois manieres de recevoir du contenu : injection directe (pour les tests ou l'usage programmatique), JSON brut stocke dans la configuration de l'import, et telechargement depuis un fichier ActiveStorage.

```ruby
# lib/data_porter/sources/json.rb
module DataPorter
  module Sources
    class Json < Base
      def initialize(data_import, content: nil)
        super(data_import)
        @content = content
      end

      def fetch
        parsed = ::JSON.parse(json_content)
        records = extract_records(parsed)

        Array(records).map do |hash|
          hash.transform_keys { |k| k.parameterize(separator: "_").to_sym }
        end
      end

      private

      def json_content
        @content || config_raw_json || download_file
      end

      def config_raw_json
        config = @data_import.config
        config["raw_json"] if config.is_a?(Hash)
      end

      def download_file
        @data_import.file.download
      end

      def extract_records(parsed)
        root = @target_class._json_root
        return parsed unless root

        parsed.dig(*root.split("."))
      end
    end
  end
end
```

Trois choses meritent attention.

**La cascade de `json_content`.** La methode essaie trois sources dans l'ordre : le contenu injecte au constructeur, la cle `raw_json` dans la configuration de l'import, et enfin le fichier ActiveStorage. Cette cascade permet une grande flexibilite sans parametrage explicite -- le bon chemin est choisi automatiquement selon ce qui est disponible.

**Le `json_root` pour les chemins imbriques.** Les API et les fichiers JSON du monde reel enveloppent souvent les donnees dans une structure : `{"data": {"guests": [...]}}`. Plutot que de forcer l'utilisateur a aplatir son JSON, on lui donne un DSL dans le Target :

```ruby
class GuestsTarget < DataPorter::Target
  label "Guests"
  model_name "Guest"
  json_root "data.guests"

  columns do
    column :name, type: :string
  end
end
```

La methode `extract_records` utilise `dig` en decoupant le chemin sur les points. `"data.guests"` devient `parsed.dig("data", "guests")`. Simple, lisible, et supporte n'importe quel niveau d'imbrication.

**La normalisation des cles.** Comme pour le CSV, chaque cle est transformee via `parameterize(separator: "_").to_sym`. `"First Name"` devient `:first_name`. Cela garantit que le reste du pipeline recoit toujours des cles au meme format, quel que soit le format source.

## La source API

La source API va chercher les donnees sur un endpoint HTTP. Elle doit supporter des endpoints statiques et dynamiques, des headers fixes et generes a la volee, et l'extraction de donnees depuis une cle de reponse.

```ruby
# lib/data_porter/sources/api.rb
module DataPorter
  module Sources
    class Api < Base
      def fetch
        api = @target_class._api_config
        response = perform_request(api)
        parsed = ::JSON.parse(response.body)
        records = extract_records(parsed, api)

        Array(records).map do |hash|
          hash.transform_keys { |k| k.parameterize(separator: "_").to_sym }
        end
      end

      private

      def perform_request(api)
        url = resolve_endpoint(api)
        headers = resolve_headers(api)
        uri = URI(url)

        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
          request = Net::HTTP::Get.new(uri)
          headers.each { |k, v| request[k] = v }
          http.request(request)
        end
      end

      def resolve_endpoint(api)
        params = @data_import.config.symbolize_keys
        api.endpoint.is_a?(Proc) ? api.endpoint.call(params) : api.endpoint
      end

      def resolve_headers(api)
        api.headers.is_a?(Proc) ? api.headers.call : (api.headers || {})
      end

      def extract_records(parsed, api)
        root = api.response_root
        root ? parsed[root.to_s] : parsed
      end
    end
  end
end
```

Le coeur de la logique se trouve dans `resolve_endpoint` et `resolve_headers`. Chacune de ces methodes accepte soit une valeur statique, soit un lambda. Cela ouvre deux modes d'utilisation :

```ruby
# Endpoint statique, headers fixes
api_config do
  endpoint "https://api.example.com/stays"
  headers({ "Authorization" => "Bearer abc123" })
  response_root :stays
end

# Endpoint dynamique, headers generes a la volee
api_config do
  endpoint ->(params) { "https://api.example.com/items?id=#{params[:item_id]}" }
  headers(-> { { "Authorization" => "Bearer #{Token.current}" } })
end
```

Dans le cas du lambda d'endpoint, les parametres proviennent de `@data_import.config.symbolize_keys`. L'utilisateur passe `config: { item_id: "42" }` au moment de la creation de l'import, et le lambda recoit ces parametres pour construire l'URL. Pour les headers, le lambda est appele sans argument -- il va chercher le token la ou il se trouve (variable d'environnement, modele, service externe).

Le `response_root` fonctionne comme le `json_root` de la source JSON, mais en plus simple : il extrait une seule cle du hash de reponse. `response_root :stays` sur une reponse `{"stays": [...]}` retourne directement le tableau. Si aucun `response_root` n'est defini, la reponse entiere est utilisee.

## Le pattern DSL d'ApiConfig

La configuration API utilise un objet DSL dedie plutot que de simples `attr_accessor` :

```ruby
# lib/data_porter/dsl/api_config.rb
module DataPorter
  module DSL
    class ApiConfig
      def endpoint(value = nil)
        return @endpoint if value.nil?

        @endpoint = value
      end

      def headers(value = nil)
        return @headers if value.nil?

        @headers = value
      end

      def response_root(value = nil)
        return @response_root if value.nil?

        @response_root = value
      end
    end
  end
end
```

Chaque methode joue un double role : appellee avec un argument, elle agit comme un setter ; appellee sans argument, elle agit comme un getter. Ce pattern evite de separer `attr_reader` et `attr_writer` et produit un DSL naturel :

```ruby
api_config do
  endpoint "https://api.example.com/data"   # setter
end

api.endpoint  # => "https://api.example.com/data"  (getter)
```

Dans le Target, `api_config` cree une instance d'`ApiConfig` et execute le bloc dans son contexte via `instance_eval` :

```ruby
# Dans DataPorter::Target
def api_config(&)
  @_api_config = DSL::ApiConfig.new
  @_api_config.instance_eval(&)
end
```

Ce pattern -- objet DSL + `instance_eval` -- est le meme que celui utilise pour le bloc `columns`. C'est un idiome Ruby classique qui donne une syntaxe propre tout en gardant l'implementation testable (l'objet `ApiConfig` est un PORO normal, facile a instancier et inspecter dans les specs).

## Le dispatch via Sources.resolve

L'ajout de nouvelles sources ne modifie rien au code existant. Le module `Sources` maintient un registre simple :

```ruby
# lib/data_porter/sources.rb
module DataPorter
  module Sources
    REGISTRY = {
      api: Api,
      csv: Csv,
      json: Json
    }.freeze

    def self.resolve(type)
      REGISTRY.fetch(type.to_sym) { raise Error, "Unknown source type: #{type}" }
    end
  end
end
```

L'Orchestrator appelle `Sources.resolve(import.source_type)` et recoit la bonne classe. Il instancie ensuite la source et appelle `fetch`. Ni l'Orchestrator ni les controllers ne savent quel type de source est utilise -- c'est le `source_type` stocke dans l'import qui decide. Ajouter une source XML ou Parquet demanderait : une classe heritant de `Base`, une entree dans le `REGISTRY`, et c'est tout.

## L'approche TDD

Les deux sources ont ete construites en TDD. La source JSON est testee avec trois scenarios :

```ruby
it "parses JSON array content" do
  json = '[{"first_name": "Alice", "last_name": "Smith"}]'
  source = described_class.new(import, content: json)
  records = source.fetch

  expect(records.first[:first_name]).to eq("Alice")
end

it "extracts records from a nested path" do
  json = '{"data": {"guests": [{"name": "Alice"}, {"name": "Bob"}]}}'
  source = described_class.new(import_with_root, content: json)

  expect(source.fetch.size).to eq(2)
end

it "reads from config raw_json when no content provided" do
  import.update!(config: { "raw_json" => '[{"first_name": "Config"}]' })
  source = described_class.new(import)

  expect(source.fetch.first[:first_name]).to eq("Config")
end
```

Chaque test couvre un chemin de la cascade : injection directe, `json_root`, et fallback `raw_json`. Pour la source API, on stubbe `Net::HTTP.start` pour eviter les vrais appels HTTP, et on teste les quatre axes : endpoint statique, endpoint lambda, headers lambda, et absence de `response_root` :

```ruby
it "fetches and parses records from response_root" do
  response_body = '{"stays": [{"name": "Beach House"}, {"name": "Mountain Cabin"}]}'
  stub_http_get(response_body)

  source = described_class.new(import)
  expect(source.fetch.size).to eq(2)
end

it "resolves the endpoint lambda with params" do
  response_body = '[{"title": "Item 42"}]'
  stub_http_get(response_body)

  source = described_class.new(import_with_lambda)
  expect(source.fetch.first[:title]).to eq("Item 42")
end
```

Le stub est minimal : `allow(Net::HTTP).to receive(:start).and_return(response)`. On ne teste pas que `Net::HTTP` fonctionne -- on teste que notre code compose correctement l'URL, les headers, et extrait les bonnes donnees de la reponse.

## Decisions et compromis

| Decision | Choix retenu | Alternative ecartee | Raison |
|----------|-------------|---------------------|--------|
| Client HTTP | `Net::HTTP` (stdlib) | Faraday, HTTParty | Zero dependance supplementaire ; suffisant pour des GET simples |
| Endpoint dynamique | Lambda recevant `params` | String avec interpolation | Le lambda permet toute logique (conditions, appels de service) sans eval de string |
| Headers dynamiques | Lambda sans argument | Callback avec contexte | Les headers viennent souvent d'un service global (ENV, token store), pas du contexte de l'import |
| Cascade JSON | `content` > `raw_json` > `file` | Argument obligatoire | Flexibilite maximale ; chaque cas d'usage trouve son chemin naturellement |
| Normalisation des cles | `parameterize` + `to_sym` | Mapping explicite | Coherent avec la source CSV ; le pipeline en aval recoit toujours le meme format |

## Recap

- **La source JSON** supporte trois modes d'entree (injection, config `raw_json`, fichier) via une cascade de fallbacks, et utilise `json_root` pour naviguer dans des structures imbriquees.
- **La source API** resout dynamiquement endpoints et headers grace a un systeme dual statique/lambda, et extrait les donnees via `response_root`.
- **Le DSL `ApiConfig`** utilise un pattern getter/setter sans `attr_reader`, evaluee dans un bloc `instance_eval` pour une syntaxe naturelle.
- **`Sources.resolve`** dispatche vers la bonne classe via un registre fige -- ajouter une source est une operation en deux lignes.
- **Les tests** couvrent chaque chemin de chaque source sans toucher le reseau, grace a l'injection de contenu et au stubbing HTTP.

## La suite

Les sources JSON et API completent le trio de formats supportes. Mais nous n'avons pas encore parle de la strategie de test globale de l'engine -- comment tester un moteur Rails sans application hote complete, comment organiser les specs entre tests unitaires et integration, comment mocker ActiveStorage et ActionCable. Dans la partie 13, nous plongeons dans le **testing d'un Rails Engine avec RSpec** et les patterns qui gardent la suite rapide et fiable.

---

*Ceci est la partie 12 de la serie "Building DataPorter - A Data Import Engine for Rails". [Precedent : Generators: Install & Target Scaffolding](#) | [Suivant : Testing a Rails Engine with RSpec](#)*
