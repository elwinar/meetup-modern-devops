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
- versions concurrentes
- outils embarqués

---

# tester avec des containers

- bases de données
- queue de messages
- api internes

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
      service: golang
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
bases de données jetables

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

```
mysql> show databases;
+----------------------+
| Database             |
+----------------------+
| ba7bge1tfvsg2tl6mi60 |
+----------------------+
12 rows in set (0.01 sec)
```
