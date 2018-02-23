class: center, middle

# tester avec des containers

---

# Synthesio
quelques chiffres pour faire le malin

---

# les containers à Synthesio
nous les utilisons pour:

- compiler
- tester
- ~~deployer~~

---

# compiler avec des containers

- pas d'installation locale
- versions indépendantes
- outils embarqués

---

# tester avec des containers

- bases de données
- queue de messages
- api internes

---

# la théorie
pourquoi pas un mock ?

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
│           ├── poll_coldest.sql
│           ├── poll_cold.sql
│           ├── poll_empty.sql
│           ├── poll_new.sql
│           ├── poll_race.sql
│           ├── poll_warm.sql
│           └── push.sql
├── CHANGELOG.md
├── docker-compose.yml
├── Gopkg.lock
├── Gopkg.toml
├── LICENSE
├── Makefile
└── README.md
```

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

# la suite
vers l'infini et au-dela

- monodépôt
- services internes
- jeu de données global
