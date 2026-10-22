Bonaparte DSL
=============

Some DSLs to simplify API and persistence definition.
This project creates 3 plugins for Eclipse 4.x (Kepler and upwards), based on xtext.

## Purpose

The main DSL is the Bonaparte DSL. Its main purpose is to allow a very efficient definition
of external interfaces, and generate classes which allow very fast and low GC serialization and deserialization,
in a variety of formats.

The main DSL supports all Java primitive types, their wrapper classes, the JodaTime LocalTime, LocalDate, LocalDateTime and Instant classes,
as well as a couple of additional useful classes such as byte[], UUID, ByteArray (an immutable form of byte []) and enums. Except byte[], all supported types are immutable. Structures like Map, Set and List, or arrays of objects are also supported.
Using type adapters, similar to JAXB, also custom types can be used in objects.


The syntax is Java like, with some differences. The DSL supports typedefs as in C or C++.

The Bonaparte JPA DSL generates JPA 3.0 Entity classes for the specified types (JPA 2.2 is still supported, by changing the respective target setting in preferences).

The generated Java classes need support libraries. These are:

* bonaparte-java for the main Bonaparte DSL

* persistence-java for the Bonaparte JPA persistence DSL



## How to build

The project uses a multi module maven based build.

## Developing the TypeScript API generator

The TypeScript API generator is maintained in
`de.jpaw.bonaparte.dsl/src/de/jpaw/bonaparte/dsl/generator/tsapi`; its focused
tests are in `de.jpaw.bonaparte.dsl.tests`. Use Java 21 and install the Tycho
target definitions locally before running the generator test reactor:

```sh
mvn --batch-mode --no-transfer-progress \
  -pl de.jpaw.bonaparte.dsl.target,de.jpaw.bonaparte.jpa.dsl.target install

mvn --batch-mode --no-transfer-progress \
  -pl de.jpaw.bonaparte.dsl,de.jpaw.bonaparte.dsl.tests -am verify
```

After the tests pass, install the local JPA DSL and TypeScript plugin artifacts
so downstream t9t builds can resolve the generator version from the local Maven
repository:

```sh
mvn --batch-mode --no-transfer-progress \
  -pl de.jpaw.bonaparte.jpa.dsl -am install -DskipTests
mvn --batch-mode --no-transfer-progress \
  -pl de.jpaw.bonaparte.dsl.typescript.plugin -am install -DskipTests

export BONAPARTE_PLUGIN_VERSION="$(mvn -q -N help:evaluate \
  -Dexpression=project.version -DforceStdout)"
```

Pass `BONAPARTE_PLUGIN_VERSION` to the downstream t9t build as
`-Dbonaparte-plugin.version="$BONAPARTE_PLUGIN_VERSION"`; the default plugin
version in the t9t parent may not include local generator changes. The complete
t9t API build, local Verdaccio workflow, GitHub Packages snapshot publication,
and package-auth instructions are documented in
`t9t-api-ts/src/main/npm/README.md` in the t9t repository. GitHub package reads
require `read:packages`; snapshot publishing requires `write:packages`. Keep
tokens in environment variables or approved credential stores, never in
tracked files.

## How to install

Install the Eclipse plugins with the help of provided update sites.
You can find the list of available versions here: [https://arvato-systems-jacs.github.io/bonaparte-dsl/](https://arvato-systems-jacs.github.io/bonaparte-dsl/)

## Serialized forms

The Bonaparte generator creates code, which directly calls utility class for serialization and deserialization.
Two specific formats are provided, one which uses the full character set, but is able to survive transformations done
by ftp text format clients, such as change of encoding or change of line endings. The other format is a very compact binary
format intended to be used for off heap memory storage. Both formats provide a format which is upwards compatible to a certain extend,
for example changing an int to a long or a Long, or adding additional optional fields at the end of a class.
This means, data persisted with some older class will be readable with the parser generated from the enhanced class.

## More documentation

For more documentation on the Bonaparte DSL, please look at the modules bonaparte-tex, bonaparte-tutorial and bonaparte-tutorial-code in the bonaparte-java project.

You can find the PDFs at the following URLs:

* [https://github.com/jpaw/bonaparte-java/blob/master/bonaparte-tutorial/tutorial.pdf](https://github.com/jpaw/bonaparte-java/blob/master/bonaparte-tutorial/tutorial.pdf)

* [https://github.com/jpaw/bonaparte-java/blob/master/bonaparte-tex/bonaparte.pdf](https://github.com/jpaw/bonaparte-java/blob/master/bonaparte-tex/bonaparte.pdf)

## JPA DSL

The JPA DSL generates Java JPA 2.0 @Entity classes. Getters and setters for these classes normally work with the Bonaparte DSL data types (DTOs), with internal conversions donw for

* ElementCollections

* unrolling lists

* Embeddables

* Adapter data types

* User data types (depending on configuration)

The JPA DSL also generates SQL DDL statements for the database types Oracle, Postgres, MS SQL Server and (experimentally) MySQL.
