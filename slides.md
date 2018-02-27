class: center, middle

# tester avec des containers

???
- bonjour
- romain, developpeur chez synthesio depuis 2.5 ans

---

# Synthesio
qui sommes nous ?

- plateforme d'analyse sociale
- enrichissement de documents
- analyse démographique
- analyse de sentiment

---

# Synthesio
coté technique

- ré-écriture en Go depuis 2 ans
- ~40 services juste en Go
- quelques services node, java, python, php

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

class: bigpicture

![containers](assets/containers.jpg)

---

# la théorie
comme dans les livres, mais en simple

> A test is not a unit test if:
> - It talks to the database
> - It communicates across the network
> - It touches the file system
> - It can't run at the same time as any of your other unit tests
> - You have to do special things to your environment (such as editing config files) to run it. 

???
- le gros du sujet
- toutes les dépendances dans des containers
- utiliser ou générer un jeu de données
- compatible avec des tests unitaires, d'intégration, end-to-end, etc
- simple à vérifier

---

# la théorie
pourquoi pas un mock ?

```go
func TestShouldUpdateStats(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("an error '%s' was not expected when opening a stub database connection", err)
	}
	defer db.Close()

	mock.ExpectBegin()
	mock.ExpectExec("UPDATE products").WillReturnResult(sqlmock.NewResult(1, 1))
	mock.ExpectExec("INSERT INTO product_viewers").WillReturnResult(sqlmock.NewResult(1, 1))
	mock.ExpectCommit()

	// now we execute our method
	if err = recordStats(db, 2, 3); err != nil {
		t.Errorf("error was not expected while updating stats: %s", err)
	}

	// we make sure that all expectations were met
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Errorf("there were unfulfilled expectations: %s", err)
	}
}
```

???
- pas besoin de connaître les détails d'implémentation
- pas de code non-fonctionnel
- compatibilité totale avec la version utilisée

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

background-image: url(assets/ring.png)

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

# la pratique
docker-compose à la rescousse

```yaml
version: "2.1"

services:
  service:
    extends:
      file: ${STO_STDCOMPOSEFILE}
      service: golang-1.9
    entrypoint: dockerize -timeout 20s -wait tcp://elasticsearch:9200 -wait tcp://kafka:9092 entrypoint.sh
    links:
      - elasticsearch
      - kafka
  elasticsearch:
    extends:
      file: ${STO_STDCOMPOSEFILE}
      service: elasticsearch-2.3
  kafka:
    extends:
      file: ${STO_STDCOMPOSEFILE}
      service: kafka-0.10
    links:
      - zookeeper
  zookeeper:
    extends:
      file: ${STO_STDCOMPOSEFILE}
      service: zookeeper-3.4 
```

???
- linker des services génériques
- mise à jour automatique
- freeze de la version des containers via des alias
- dépendances complexes

---

# la pratique
créer des bases de test à la volée

```go
func TestService_poll(t *testing.T) {
	var c Case{
		Name:    "poll new trigger",
		Fixture: "poll_new",
		Out: Trigger{
			ID:          1,
			DashboardID: 1,
		},
	}

	redbeard, clean := mysqltest.Spawn(t, zmysql.NewRedbeard, "redbeard:3306",
		mysqltest.Fixture{Path: "${STO_STDPATH}/schemas/redbeard-0.2.0.sql"},
		mysqltest.Fixture{Path: "testdata/" + c.Fixture + ".sql"},
	)
	defer clean()

	service := NewService(redbeard)
	out, err := service.poll()

	if (err != nil) != c.Err || err != c.ErrValue {
		t.Errorf("unexpected error: got %v", err)
	}

	if !reflect.DeepEqual(c.Out, out) {
		t.Errorf("unexpected output: %s", ztesting.Diff(out, c.Out))
	}
}
```

???
- nom de base de données aléatoires pour la parallelisation
- fixtures parsées et chargées automatiquement
- `testing.T` en paramètre pour la gestion d'erreur
- `defer clean()` pour nettoyer

---

# la pratique
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

# la pratique
golden files, pour les sorties complexes

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

---

background-image: url(assets/buzz.png)

# la suite
vers l'infini et au-dela

- containers avec les schémas pré-chargés
- containers avec les services internes
- jeu de données commun

???
- idées d'amélioration du système
- monodépôt
- services internes
- jeu de données global

---

class: center, middle
background-image: url(assets/riddler.png)

# questions ?
romain.baugue@elwinar.com

