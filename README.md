# Grasp

Grasp is a wrapper around the [LuaSQLite3](https://lua.sqlite.org/index.cgi/index) binding for sqlite3. Designed to be fairly similar to [Clutch](https://github.com/akojo/clutch), while having a more functional approach.

Ok, I admit it, the only reason I made this is because Clutch wouldn't run on 5.1, ok?! Really, go use that instead, it's a genius library. I guess you can use this as a last resort or if you really, really hate yourself.

As such, this README will be a close-looking copy of the clutch one, but in MoonScript, and with my syntax.

## Table of contents

- [Grasp](#grasp)
  - [Table of contents](#table-of-contents)
  - [Opening a database](#opening-a-database)
  - [Querying the database](#querying-the-database)
  - [Binding parameters](#binding-parameters)
    - [Named parameters](#named-parameters)
    - [Anonymous/positional parameters](#anonymouspositional-parameters)
  - [Updating the database](#updating-the-database)
  - [Preparing statements](#preparing-statements)
    - [Resets](#resets)
  - [Transactions](#transactions)
  - [Error handling](#error-handling)
  - [Query building](#query-building)
    - [Supported statements](#supported-statements)
      - [explain](#explain)
      - [Transactions and Savepoints](#transactions-and-savepoints)
      - [create](#create)
      - [insert and replace](#insert-and-replace)
      - [select](#select)
      - [delete](#delete)
      - [drop](#drop)
  - [Installing](#installing)
  - [Tests](#tests)
  - [License](#license)

## Opening a database

```moon
import Database from require "grasp"
db = Database "my.db"
```

It optionally takes a table of attributes, defined like this:

```
readonly / ro :: boolean
readwrite / rw :: boolean
create :: boolean
uri :: boolean
memory :: boolean
mutex :: boolean
cache :: string [shared|private]
volatile :: boolean
```

All of them, except for `volatile`, correspond to a `SQLITE_OPEN_*` open [flag](https://www.sqlite.org/c3ref/open.html). I think it's pretty easy to figure it out. `volatile` will remove the file (if it is not `:memory:`) on close. The default attributes table is `create=true, rw=true`.

As with Clutch, the filename `:memory:` will open an in-memory volatile database. This doesn't have anything to do with the `volatile` attribute. An empty filename will create a temporal on-disk database with `volatile` set to true. It uses `os.tmpname` to get a temporal filename, and you can get it with `db.filename`.

## Querying the database

You use the `query`, `query1` and `iquery` functions to make a query to the database. They're all iterators, but they iterate in different ways. Here are the signatures:

```
query :: Database -> (string, table) -> (_ -> {string:_})
query1 :: Database -> (string, table) -> (_ -> [_])
iquery :: Database -> (string, table) -> (_ -> ...)
```

This might mean nothing to you, so let's see a practical example:

```moon
import query, query1, iquery from require "grasp"
for row in (query db) "select * from t"
  print row.col1, row.col2

for row in (query1 db) "select * from t"
  print row[1], row[2]

for col1, col2 in (iquery db) "select * from t"
  print col1, col2
```

These are all equivalent, so it's all up to preference. There's `queryone` and `queryall` shorthands too, but they might behave a bit differently.

- `queryone db sql`: returns the first row out of all results.
- `queryall db sql`: returns a table of all rows returned.

## Binding parameters

### Named parameters

The `query*` functions take an optional table to provide parameters. It uses prepare/bind functions internally so you can use `:`, `$` and `@` just as you would with Clutch and sqlite3.

```moon
(query db) "select * from t where value = :value", value: "example"
```

### Anonymous/positional parameters

Just sqlite3's `?` and `?n`.

```moon
(query db) "select * from t where value = ?", {"example"}
(query db) "select * from t where value = ?1 eulav = ?2", {"example", "elpmaxe"}
```

## Updating the database

`update(db)(sql)` is your function to pipe straight SQL to your database. It's signature is `update :: Database -> (string, table) -> (boolean, number)`, where the first string is the query, and it returns both a boolean (`sqlite.DONE` or not) and the result code.

It also prepares the statement behind the scenes, so you can pass a table to bind arguments.

## Preparing statements

This library also lets you prepare statements manually via `Statement`, which has the signature `Statement :: Database -> string -> Statement`. You can know the SQL you passed to it with `stmt.sql`.

```moon
import Statement from require "grasp"

stmt = Statement "select * from t where value = :value"
```

You can then call `query*` functions with an extra bindtable argument.

```moon
(query stmt) value: "example"
```

Of course, you can also bind them manually, with the several `bind*` functions:

```
bind :: Statement -> table -> (boolean, number)
bindOne :: Statement -> (number|string, _) -> (boolean, number)
bindMany :: Statement -> [_]
```

Which is better explained visually like this:

```moon
import bind, bindOne, bindMany from require "grasp"
(bind stmt) value: "example"
(bindOne stmt) "value", "example"
(bindMany stmt) 1, 2, 3, 4, 5
```

All about preference!

### Resets

Similarly to Clutch, calling `execute` and `query*` functions on a statement will cause it to be reset.

## Transactions

The `Transaction` method takes a function which will run inside a transaction, built using savepoints. A very graphical example:

```moon
import Transaction from require "grasp"
(Transaction db) =>
  (update @) "some sql statement"
  (update @) "another sql statement"
```

## Error handling

Unlike Clutch, this will not error on user-called functions, but instead return a boolean status and the error code.

## Query building

Grasp 1.2 implements a query builder for SQL. It ain't much, but it's honest work. You use it by importing the `sql` function in `grasp.query`. It takes a function, and a lot of magic happens there, just see for yourself!

```moon
sql ->
  create "tbl", -> columns:
    ee: "TEXT NOT NULL"
```

### Supported statements

#### explain

Takes any SQL builder, and precedes it with `EXPLAIN` or `EXPLAIN QUERY PLAN`.

```moon
sql -> explain queryplan, -> ...
sql -> explain -> ...
```

#### Transactions and Savepoints

```moon
sql ->
  -- begin transaction
  begin!
  begin deferred
  begin immediate
  begin exclusive
  -- rollback transaction
  rollback!
  -- end transaction
  commit!
  End!

sql ->
  -- savepoints
  savepoint "name"
  release   "name"
  rollback  "name
```

#### create

Well, more like `CREATE TABLE`:

```moon
sql -> create "tablename", ->
  temporary!     -- TEMPORARY
  always!        -- removes IF NOT EXISTS
  without_rowid! -- adds WITHOUT ROWID
  columns:
    whatever: "TEXT NOT NULL" -- and such
```

#### insert and replace

`replace` works pretty much the same, but emitting `REPLACE` instead

```moon
sql ->
  insert ->
    replace!   -- OR REPLACE
    rollback!  -- OR ROLLBACK
    abort!     -- OR ABORT
    fail!      -- OR FAIL
    ignore!    -- OR IGNORE
    into "tablename"
    alias "whatever" -- AS whatever
    values:
      column: value
  -- alternatively
  insert into "tablename", -> values:
    column: value
```

#### select

```moon
sql ->
  select "*", ->
    distinct!
    all!
    From "tablename"
    where "expr"
    where a: v     -- WHERE a = v
    order: "expr"  -- ORDER BY expr
    limit: "expr"  -- LIMIT expr
    offset: "expr" -- OFFSET expr
  -- alternatively
  select "*", From "tablename", ->
```

#### delete

```moon
sql ->
  delete ->
    From "tablename"
    where "expr"
    where a: v     -- WHERE a = v
  -- alternatively
  delete From "tablename", -> where a: v
```

#### drop

```moon
sql ->
  drop "tablename"
  drop "tablename", -> ifexists!
```

## Installing

You can get Grasp on LuaRocks:

```sh
$ luarocks install grasp
```

If building from source:
```sh
$ moonc grasp
$ luarocks make
```

## Tests

You can run the tests with `busted` (you will need MoonScript).

```
$ luarocks install busted
$ luarocks install moonscript
$ busted
```

## License

`lsqlite3` uses the MIT license. Grasp is released onto the public domain.

```
This is free and unencumbered software released into the public domain.

Anyone is free to copy, modify, publish, use, compile, sell, or
distribute this software, either in source code form or as a compiled
binary, for any purpose, commercial or non-commercial, and by any
means.

In jurisdictions that recognize copyright laws, the author or authors
of this software dedicate any and all copyright interest in the
software to the public domain. We make this dedication for the benefit
of the public at large and to the detriment of our heirs and
successors. We intend this dedication to be an overt act of
relinquishment in perpetuity of all present and future rights to this
software under copyright law.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

For more information, please refer to <http://unlicense.org/>
```