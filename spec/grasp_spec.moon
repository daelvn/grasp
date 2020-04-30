grasp            = require "grasp"
import typeof from require "grasp.util"

describe "grasp", ->
  import query from grasp
  local db

  setup ->
    import Database, update from grasp
    db = Database ":memory:"

    statements = {
      [[CREATE TABLE S
      (
      SNUM int NOT NULL PRIMARY KEY,
      SNAME varchar(16) NOT NULL UNIQUE,
      STATUS int NOT NULL,
      CITY varchar(20) NOT NULL
      );]]
      [[CREATE TABLE P
      (
      PNUM int NOT NULL PRIMARY KEY,
      PNAME varchar(18) NOT NULL,
      COLOR varchar(10) NOT NULL,
      WEIGHT decimal(4,1) NOT NULL,
      CITY varchar(20) NOT NULL,
      UNIQUE (PNAME, COLOR, CITY)
      );]]
      [[CREATE TABLE SP
      (
      SNUM int NOT NULL REFERENCES S,
      PNUM int NOT NULL REFERENCES P,
      QTY int NOT NULL,
      PRIMARY KEY (SNUM, PNUM)
      );]]
      [[INSERT INTO S VALUES (1, 'Smith', 20, 'London');]]
      [[INSERT INTO S VALUES (2, 'Jones', 10, 'Paris');]]
      [[INSERT INTO S VALUES (3, 'Blake', 30, 'Paris');]]
      [[INSERT INTO S VALUES (4, 'Clark', 20, 'London');]]
      [[INSERT INTO S VALUES (5, 'Adams', 30, 'Athens');]]
      [[INSERT INTO P VALUES (1, 'Nut', 'Red', 12, 'London');]]
      [[INSERT INTO P VALUES (2, 'Bolt', 'Green', 17, 'Paris');]]
      [[INSERT INTO P VALUES (3, 'Screw', 'Blue', 17, 'Oslo');]]
      [[INSERT INTO P VALUES (4, 'Screw', 'Red', 14, 'London');]]
      [[INSERT INTO P VALUES (5, 'Cam', 'Blue', 12, 'Paris');]]
      [[INSERT INTO P VALUES (6, 'Cog', 'Red', 19, 'London');]]
      [[INSERT INTO SP VALUES (1, 1, 300);]]
      [[INSERT INTO SP VALUES (1, 2, 200);]]
      [[INSERT INTO SP VALUES (1, 3, 400);]]
      [[INSERT INTO SP VALUES (1, 4, 200);]]
      [[INSERT INTO SP VALUES (1, 5, 100);]]
      [[INSERT INTO SP VALUES (1, 6, 100);]]
      [[INSERT INTO SP VALUES (2, 1, 300);]]
      [[INSERT INTO SP VALUES (2, 2, 400);]]
      [[INSERT INTO SP VALUES (3, 2, 200);]]
      [[INSERT INTO SP VALUES (4, 2, 200);]]
      [[INSERT INTO SP VALUES (4, 4, 300);]]
      [[INSERT INTO SP VALUES (4, 5, 400);]]
    }
    for stat in *statements
      (update db) stat

  teardown ->
    import close from grasp
    close db

  it "a simple query", ->
    for r in (query db) "select * from P"
      assert.is.truthy r.PNAME
      
  it "named parameters", ->
    for r in (query db) "select * from p where color = :color", color: "Red"
      assert.is.truthy r.PNAME

  it "positional parameters", ->
    for r in (query db) "select * from p where weight = ?2 AND color = ?1", {"Red", 12}
      assert.is.truthy r.PNAME

  describe "prepared statements", ->
    import Statement from grasp
    stmt  = (Statement db) "select * from p where color = :color"
    stmt2 = (Statement db) "select * from p where color = :color"

    it "binding", ->
      import bind from grasp
      do (bind stmt) color: "Red"
      for r in query stmt
        assert.is.truthy r.PNAME

    it "repeatedly", ->
      for r in query stmt2, color: "Red"
        assert.is.truthy r.PNAME
      for r in query stmt2, color: "Blue"
        assert.is.truthy r.PNAME

  it "transactions", ->
    import Transaction, queryone, update from grasp
    do (Transaction db) =>
      (update @) "insert into P values (7, 'Washer', 'Grey', 5, 'Helsinki')"
      (update @) "insert into P values (8, 'Washer', 'Black', 7, 'Helsinki')"
    assert.is.truthy (queryone db) "select * from P where city = 'Helsinki'"