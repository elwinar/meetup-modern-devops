class: center, middle

# tester avec des containers

???
- dire bonjour
- se présenter

---

# Synthesio
quelques chiffres pour se la péter

???
- nombre de services à Synthesio
- volumes de données

---

# les containers à Synthesio
nous les utilisons pour:

- compiler
- tester
- ~~deployer~~

???
- insister sur le contrepied de l'outil

---

# compiler avec des containers

- pas d'installation locale
- versions indépendantes
- outils embarqués

???
- pas grand chose de particulier à dire
- assez répandu

---

# tester avec des containers

- bases de données
- queue de messages
- api internes

???
- le gros du sujet
- toutes les dépendances dans des containers

---

# la théorie
pourquoi pas un mock ?

???
- il faut faker des données réalistes
- vérifier la validité des requêtes
- ignorer les détails d'implémentation

---

# la pratique
architecture d'un projet

```
$ tree . -I vendor
.
├── bin
│   └── sharmander
│       ├── config.go
│       ├── main.go
│       ├── service.go
│       ├── service_test.go
│       └── testdata
│           ├── poll_cold.sql
│           ├── poll_empty.sql
│           ├── poll_new.sql
│           └── poll_race.sql
├── CHANGELOG.md
├── docker-compose.yml
├── Gopkg.lock
├── Gopkg.toml
├── LICENSE
├── Makefile
└── README.md
```

???
- présentation générale d'un projet
- points intéressants: makefile, docker-compose, testdata

---

# la pratique
synthesio standard !

```
$ tree standard/
.
├── docker-compose.yml
├── base.mk
├── golang.mk
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
- définition de l'interface de compilation
- regroupement des schémas de base de données
- définition de containers génériques

---

# la pratique
docker-compose à la rescousse

```
version: "2.1"

services:
  sharmander:
    extends:
      file: ${STO_STDCOMPOSEFILE}
      service: golang-1.9
    links:
      - redbeard
    entrypoint: dockerize -timeout 2m -wait tcp://redbeard:3306 entrypoint.sh
  redbeard:
    extends:
      file: ${STO_STDCOMPOSEFILE}
      service: redbeard
```

???
- linker des services génériques
- mise à jour automatique

---

# la pratique

```
$ make help
build                          build the project
clean                          remove project's dependencies, cache, binaries and ci artifacts
dist-build                     dist build the project
down                           shut down docker composition
help                           print this message
lint-ci                        lint project's code for ci
lint                           lint project's code
prepare-build                  prepare dir for build
prepare-ci                     prepare dir for ci
prepare-doc                    prepare dir for doc
pull                           pull docker composition images
shell                          run project's shell
test-ci                        run ci test configuration
test-fast                      run minimal test configuration
test-image                     test docker image
test                           run complete test configuration
up                             start up docker composition
```

???
- interface de compilation et test
- cacher les détails

---

# trucs & astuces
créer des bases de données à la volée

```
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
controler `time.Now()`

```
// Monkey patch time.Now to make the poller believes
// that the current time is the reference time.
monkey.Patch(time.Now, func() time.Time {
	return ReferenceTime
})
defer monkey.Unpatch(time.Now)
```

???
- ne pas utiliser `NOW()`
- avoir un temps de référence dans les fixtures

---

# trucs & astuces
golden files

```
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
	golden.ReadJSON(t, fmt.Sprintf("%s.json", c.out), &expected, out)

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

- monodépôt
- services internes
- jeu de données global

???
- idées d'amélioration du système

---

class: center, middle

# questions ?

