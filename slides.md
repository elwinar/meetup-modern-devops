class: center, middle

# tester avec des containers

???
- bonjour
- romain, developpeur chez synthesio depuis 2.5 ans

---

# Synthesio
quelques chiffres pour se la péter

- ré-écriture en Go depuis 2 ans
- 35+ services juste en Go
- quelques services node, java, python

???
- backend entièrement en php (et début de Scala)
- besoin de sortir une API très très vite, j'ai fait du Go
- depuis, tout en Go, environ 40 services et api à l'heure actuelle
- et un peu de node, java, python pour les besoins spécifiques

---

# les containers à Synthesio
nous les utilisons pour

- compiler
- tester
- ~~deployer~~

???
- contrepied de l'usage d'origine du container
- plus léger que Vagrant (en ressources et en configuration)
- pas besoin d'installer les outils de compilation en local
- plusieurs versions concurrentes des outils de compilation
- outils standards embarqués dans une image custom

---

# la théorie
comme dans les livres, mais en simple

???
- le gros du sujet
- toutes les dépendances dans des containers
- utiliser ou générer un jeu de données
- compatible avec des tests unitaires, d'intégration, end-to-end, etc
- simple à vérifier

---

# la théorie
pourquoi pas un mock ?

???
- pas besoin de connaître les détails d'implémentation
- pas de code non-fonctionnel
- compatibilité totale avec la version utilisée

---

# la pratique
docker-compose à la rescousse

```yaml
version: "2.1"

services:
  sharmander:
    extends:
      file: ${STO_STDCOMPOSEFILE}
      service: golang-1.9
    links:
      - redbeard
  redbeard:
    extends:
      file: ${STO_STDCOMPOSEFILE}
      service: redbeard
```

???
- linker des services génériques
- mise à jour automatique
- freeze de la version des containers via des alias

---

# la pratique
synthesio standard !

```bash
$ tree .
.
├── conda.mk
├── docker-compose.yml
├── base.mk
├── golang.mk
├── node.mk
├── php.mk
├── etc
│   ├── elasticsearch
│   │   ├── elasticsearch.yml
│   │   └── jvm.options
│   └── mysql
│       └── my.cnf
└── schemas
    ├── ...
    ├── crumble-1.0.0.cql
    ├── crumble-2.0.0.cql
    ├── crumble-migration-1.0.0-2.0.0.cql
    ├── reiatsu-1.0.0.sql
    ├── reiatsu-1.1.0.sql
    ├── reiatsu-1.2.0.sql
    ├── reiatsu-migration-1.0.0-1.1.0.sql
    ├── reiatsu-migration-1.1.0-1.2.0.sql
    └── ...
```

???
- Makefile de base extensible par langage
- regroupement des schémas de base de données
- définition de containers génériques & configuration

---

# la pratique
one Makefile to rule them all, one Makefile to find them,

```make
export STO_STDDIRNAME     ?= standard
export STO_STDPATH        ?= $(realpath $(PWD)/../$(STO_STDDIRNAME))
export STO_STDMAKEFILE    ?= $(STO_STDPATH)/golang.mk
export STO_STDCOMPOSEFILE ?= $(STO_STDPATH)/docker-compose.yml

include $(STO_STDMAKEFILE)
```

```
$ make help
build                          build the project
clean                          remove project's dependencies, cache, binaries and ci artifacts
dist-build                     dist build the project
down                           shut down docker composition
help                           print this message
lint-ci                        lint project's code for ci
lint                           lint project's code
prepare-build                  prepare for build
prepare-ci                     prepare for ci
pull                           pull docker composition images
shell                          run project's shell
test-ci                        run ci test configuration
test-fast                      run minimal test configuration
test                           run complete test configuration
up                             start up docker composition
```

???
- commandes standard par langage
- possibilité d'étendre les cibles par projet

---

# trucs & astuces
créer des bases de données à la volée

```go
func TestPoll_Cold(t *testing.T) {
	redbeard, clean := mysqltest.Spawn(t, zmysql.NewRedbeard, "redbeard:3306",
		mysqltest.Fixture{Path: "${STO_STDPATH}/schemas/redbeard-0.2.0.sql"},
		mysqltest.Fixture{Path: "poll_cold.sql"},
	)
	defer clean()

	// Add test code here.
}
```

???
- nom de base de données aléatoires pour la parallelisation
- fixtures parsées et chargées automatiquement
- `testing.T` en paramètre pour la gestion d'erreur
- `defer clean()` pour nettoyer

---

# trucs & astuces
dompter `time.Now()`

```go
func TestCreate(t *testing.T) {
	// …

	n := time.Now()

	Create(db, Entity{
		ID: 1,
	})

	var res Entity
	db.Get(&res, `SELECT * FROM entities`)

	if res.CreatedAt.Before(n) || res.CreatedAt.After(time.Now()) {
		t.Errorf("unexpected created_at: got %v, wanted %v", res.CreatedAt, n)
	}
	res.CreatedAt = n

	expected := Entity{
		ID: 1,
		CreatedAt: n,
	}

	if !reflect.DeepEqual(res, expected) {
		t.Errorf("unexpected output: got %v, wanted %v", res, expected)
	}

	// …
}
```

---

# trucs & astuces
dompter `time.Now()`

```go
var ReferenceDate = time.Date(2006, 01, 02, 15, 04, 05, 000, time.UTC)

func init() {
	monkey.Patch(time.Now, func() time.Time {
		return ReferenceDate
	})
	defer monkey.Unpatch(time.Now)
}

func TestCreate(t *testing.T) {
	// …

	Create(db, Entity{
		ID: 1,
	})

	var res Entity
	db.Get(&res, `SELECT * FROM entities`)

	expected := Entity{
		ID: 1,
		CreatedAt: ReferenceDate,
	}

	if !reflect.DeepEqual(res, expected) {
		t.Errorf("unexpected output: got %v, wanted %v", res, expected)
	}

	// …
}
```

???
- `NOW()` et `time.Now()` posent des problèmes
- cas spécial pour gérer les dates qui ne font pas partie de l'input
- code compliqué, échecs aléatoires
- avoir un temps de référence simplifie globalement le code
- les fixtures deviennent plus simples à raisonner

---

# trucs & astuces
golden files

```go
t.Run(c.name, func(t *testing.T) {
	service, clean := NewTestService(t, ...)
	defer clean()

	out, err := service.generate(c.job)
	if (err != nil) != c.err {
		t.Fatalf("unexpected error calling generate: got %v", err)
	}

	if c.err {
		return
	}

	var expected Presentation
	golden.ReadJSON(t, c.out, &expected, out)

	if !jsonEqual(out, expected) {
		t.Errorf("unexpected output: %v", ztesting.Diff(out, expected))
	}
})
```

???
- "fixtures de sortie"
- mise à jour automatique via flag

# la suite
vers l'infini et au-dela

???
- idées d'amélioration du système
- monodépôt
- services internes
- jeu de données global

---

class: center, middle

# questions ?

