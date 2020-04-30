sqlite = require "lsqlite3"
db     = sqlite.open ":memory:"
db\exec [[CREATE TABLE P
(
PNUM int NOT NULL PRIMARY KEY,
PNAME varchar(18) NOT NULL,
COLOR varchar(10) NOT NULL,
WEIGHT decimal(4,1) NOT NULL,
CITY varchar(20) NOT NULL,
UNIQUE (PNAME, COLOR, CITY)
);]]
db\exec [[insert into P values (7, 'Washer', 'Grey', 5, 'Helsinki')]]

stmt = db\prepare [[select * from P where city = 'Helsinki';]]
for r in stmt\nrows!
  for k, v in pairs r do print k, v
db\close!