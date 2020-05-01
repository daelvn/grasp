-- grasp
-- Wrapper for the LuaSQLite3 API
-- By daelvn
import expect, typeset, typeof from require "grasp.util"
sqlite                            = require "lsqlite3"
unpack                          or= table.unpack

-- Constants
OPEN_READONLY     = sqlite.OPEN_READONLY
OPEN_READWRITE    = sqlite.OPEN_READWRITE
OPEN_CREATE       = sqlite.OPEN_CREATE
OPEN_URI          = sqlite.OPEN_URI
OPEN_MEMORY       = sqlite.OPEN_MEMORY
OPEN_NOMUTEX      = sqlite.OPEN_NOMUTEX
OPEN_FULLMUTEX    = sqlite.OPEN_FULLMUTEX
OPEN_SHAREDCACHE  = sqlite.OPEN_SHAREDCACHE
OPEN_PRIVATECACHE = sqlite.OPEN_PRIVATECACHE
OK                = sqlite.OK

-- Database :: (string, table) -> Database
-- Database {
--   db         :: userdata
--   attributes :: table
--   filename   :: string 
-- }
--
-- Attributes
--   readonly / ro :: boolean
--   readwrite / rw :: boolean
--   create :: boolean
--   uri :: boolean
--   memory :: boolean
--   mutex :: boolean
--   cache :: string [shared|private]
--   volatile :: boolean
Database = (filename, attr={create: true, rw: true}) ->
  expect 1, filename, {"string"}
  expect 2, attr,     {"table"}
  -- check that we're not trying to open :memory:
  if filename == ":memory:"
    return typeset {
      :filename
      db:         sqlite.open_memory!
      attributes: attr
    }, "Database"
  -- if we're trying to open a temporal one, do that
  if filename == ""
    filename      = os.tmpname!
    attr.volatile = true
  -- get attributes
  flags  = 0
  flags += OPEN_READONLY     if attr.readonly  or attr.ro
  flags += OPEN_READWRITE    if attr.readwrite or attr.rw
  flags += OPEN_CREATE       if attr.create
  flags += OPEN_URI          if attr.uri
  flags += OPEN_MEMORY       if attr.memory
  flags += OPEN_NOMUTEX      if not attr.mutex
  flags += OPEN_FULLMUTEX    if attr.mutex
  flags += OPEN_SHAREDCACHE  if attr.cache == "shared"
  flags += OPEN_PRIVATECACHE if attr.cache == "private"
  -- return object
  return typeset {
    :filename
    db:         sqlite.open filename, flags
    attributes: attr
  }, "Database"

-- Statement :: Database -> string -> Statement
-- Statement {
--   sql  :: string
--   stat :: userdata
-- }
-- Creates a new prepared statement
Statement ==>
  expect 1, @, {"Database"}
  return (sql) ->
    expect 2, sql, {"string"}
    -- complete with trailing semicolon if missing
    sql ..= ";" unless sql\match ";$"
    -- check that its valid
    error "Not a valid SQL statement: [[#{sql}]]" unless sqlite.complete sql
    -- prepare the statement
    stat = @db\prepare sql
    error "Could not prepare statement: [[#{sql}]], (#{stat})" if "userdata" != typeof stat
    return typeset {
      :sql, :stat
    }, "Statement"

-- Statement functions
--   bind (bind_names)
--   bindOne (bind+bind_parameter_name)
--   bindMany (bind_values)
--   finalize
--   isOpen (isopen)
--   query (nrows)
--   query1 (rows)
--   iquery (urows)
--   queryall -- table of all rows in query
--   queryone -- only the first row in query
--   execute (step)

-- finalize :: Statement -> (boolean, number)
finalize ==>
  expect 1, @, {"Statement"}
  ok = @stat\finalize!
  return (ok == OK), ok

-- isOpen :: Statement -> boolean
isOpen ==>
  expect 1, @, {"Statement"}
  return @stat\isopen!

-- bind :: Statement -> table -> (boolean, number)
bind ==>
  expect 1, @, {"Statement"}
  return (nametable) ->
    expect 2, nametable, {"table"}
    print (require "inspect") @ unless @stat
    ok = @stat\bind_names nametable
    return (ok == OK), ok

-- bindOne :: Statement -> (number|string, _) -> (boolean, number)
bindOne ==>
  expect 1, @, {"Statement"}
  return (n, value) ->
    expect 2, n, {"number", "string"}
    ok = @stat\bind n, value
    return (ok == OK), ok

-- bindMany :: Statement -> [_]
bindMany ==>
  expect 1, @, {"Statement"}
  return (list) ->
    ok = @stat\bind_values unpack list
    return (ok == OK), ok

-- query :: Statement -> (_ -> {string:_})
query ==>
  expect 1, @, {"Statement"}
  return @stat\nrows!

-- query1 :: Statement -> (_ -> [_])
query1 ==>
  expect 1, @, {"Statement"}
  return @stat\rows!

-- iquery :: Statement -> (_ -> ...)
iquery ==>
  expect 1, @, {"Statement"}
  return @stat\urows!

-- queryall :: Statement -> [table]
queryall ==>
  expect 1, @, {"Statement"}
  r = [row for row in @stat\nrows!]
  @stat\reset!
  return r

-- queryone :: Statement -> table
queryone ==>
  expect 1, @, {"Statement"}
  r = (queryall @)[1]
  @stat\reset!
  return r

-- execute :: Statement -> (boolean, number)
execute ==>
  expect 1, @, {"Statement"}
  status = @stat\step!
  @stat\reset!
  return (status == sqlite.DONE), status

-- Database functions
--   changesIn (changes)
--   allChangesIn (total_changes)
--   close
--   errorFor (errcode+errmsg)
--   update (exec)
--   isOpen (isopen)
--   query (nrows)
--   query1 (rows)
--   iquery (urows)
--   queryall -- table of all rows in query
--   queryone -- only the first row in query

-- close :: Database -> (boolean, number)
close ==>
  expect 1, @, {"Database"}
  ok = @db\close!
  -- if volatile, remove it
  if ok and @attributes.volatile and (filename != ":memory:")
    os.remove filename
  --
  return (ok == OK), ok

-- errorFor :: Database -> (number, string)
errorFor ==>
  expect 1, @, {"Database"}
  return (@db\errcode!), (@db\errmsg!)

-- changesIn :: Database -> number
changesIn ==>
  expect 1, @, {"Database"}
  return @db\changes!

-- allChangesIn :: Database -> number
allChangesIn ==>
  expect 1, @, {"Database"}
  return @db\total_changes!

-- isOpen :: Database -> boolean
_Statement_isOpen = isOpen
isOpen ==>
  return _Statement_isOpen @ if "Statement" == typeof @
  expect 1, @, {"Database"}
  return @stat\isopen!

-- update :: Database -> (string, table) -> (boolean, number)
update ==>
  expect 1, @, {"Database"}
  return (sql, bindt={}) ->
    expect 2, sql,   {"string"}
    expect 3, bindt, {"table"}
    stmt = (Statement @) sql
    unless (bind stmt) bindt
      error "update : Failed to bind to [[#{sql}]]"
    return execute stmt

-- query :: Database -> (string, table) -> (_ -> {string:_})
_Statement_query = query
query ==>
  return _Statement_query @ if "Statement" == typeof @
  expect 1, @, {"Database"}
  return (sql, bindt={}) ->
    expect 2, sql,   {"string"}
    expect 3, bindt, {"table"}
    stmt = (Statement @) sql
    unless (bind stmt) bindt
      error "query : Failed to bind to [[#{sql}]]"
    query stmt

-- query1 :: Database -> (string, table) -> (_ -> [_])
_Statement_query1 = query1
query1 ==>
  return _Statement_query1 @ if "Statement" == typeof @
  expect 1, @, {"Database"}
  return (sql, bindt={}) ->
    expect 2, sql,   {"string"}
    expect 3, bindt, {"table"}
    stmt = (Statement @) sql
    unless (bind stmt) bindt
      error "query1 : Failed to bind to [[#{sql}]]"
    query1 stmt

-- iquery :: Database -> (string, table) -> (_ -> ...)
_Statement_iquery = iquery
iquery ==>
  return _Statement_iquery @ if "Statement" == typeof @
  expect 1, @, {"Database"}
  return (sql, bindt={}) ->
    expect 2, sql,   {"string"}
    expect 3, bindt, {"table"}
    stmt = (Statement @) sql
    unless (bind stmt) bindt
      error "iquery : Failed to bind to [[#{sql}]]"
    iquery stmt

-- queryall :: Database -> (string, table) -> [table]
_Statement_queryall = queryall
queryall ==>
  return _Statement_queryall @ if "Statement" == typeof @
  expect 1, @, {"Database"}
  return (sql, bindt={}) ->
    expect 2, sql,   {"string"}
    expect 3, bindt, {"table"}
    stmt = (Statement @) sql
    unless (bind stmt) bindt
      error "queryall : Failed to bind to [[#{sql}]]"
    queryall stmt

-- queryone :: Database -> (string, table) -> table
_Statement_queryone = queryone
queryone ==>
  return _Statement_queryone @ if "Statement" == typeof @
  expect 1, @, {"Database"}
  return (sql, bindt={}) ->
    expect 2, sql,   {"string"}
    expect 3, bindt, {"table"}
    stmt = (Statement @) sql
    unless (bind stmt) bindt
      error "queryone : Failed to bind to [[#{sql}]]"
    queryone stmt

-- Transaction :: Database -> (Database -> boolean) -> boolean
Transaction ==>
  expect 1, @, {"Database"}
  upd = update @
  (fn) ->
    expect 2, fn, {"function"}
    unless upd "SAVEPOINT grasp_savepoint"
      error "Could not start transaction (grasp_savepoint)"
    ok = pcall -> fn @
    if ok
      upd "RELEASE grasp_savepoint"
    else
      upd "ROLLBACK TO grasp_savepoint"
    return ok

{
  :OPEN_CREATE, :OPEN_FULLMUTEX, :OPEN_MEMORY, :OPEN_NOMUTEX
  :OPEN_PRIVATECACHE, :OPEN_READONLY, :OPEN_READWRITE, :OPEN_SHAREDCACHE, :OPEN_URI,
  :OK
  
  :sqlite

  :Statement
  :finalize, :isOpen, :bind, :bindOne, :bindMany
  :query, :query1, :iquery, :queryall, :queryone
  :execute

  :Database
  :close, :errorFor, :changesIn, :allChangesIn, :update

  :Transaction
}