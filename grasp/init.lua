local expect, typeset, typeof
do
  local _obj_0 = require("grasp.util")
  expect, typeset, typeof = _obj_0.expect, _obj_0.typeset, _obj_0.typeof
end
local sqlite = require("lsqlite3")
local unpack = unpack or table.unpack
local OPEN_READONLY = sqlite.OPEN_READONLY
local OPEN_READWRITE = sqlite.OPEN_READWRITE
local OPEN_CREATE = sqlite.OPEN_CREATE
local OPEN_URI = sqlite.OPEN_URI
local OPEN_MEMORY = sqlite.OPEN_MEMORY
local OPEN_NOMUTEX = sqlite.OPEN_NOMUTEX
local OPEN_FULLMUTEX = sqlite.OPEN_FULLMUTEX
local OPEN_SHAREDCACHE = sqlite.OPEN_SHAREDCACHE
local OPEN_PRIVATECACHE = sqlite.OPEN_PRIVATECACHE
local OPEN_NOFOLLOW = sqlite.OPEN_NOFOLLOW
local OK = sqlite.OK
local Database
Database = function(filename, attr)
  if attr == nil then
    attr = {
      create = true,
      rw = true
    }
  end
  expect(1, filename, {
    "string"
  })
  expect(2, attr, {
    "table"
  })
  if filename == ":memory:" then
    return typeset({
      filename = filename,
      db = sqlite.open_memory(),
      attributes = attr
    }, "Database")
  end
  if filename == "" then
    filename = os.tmpname()
    attr.volatile = true
  end
  local flags = 0
  if attr.readonly or attr.ro then
    flags = flags + OPEN_READONLY
  end
  if attr.readwrite or attr.rw then
    flags = flags + OPEN_READWRITE
  end
  if attr.create then
    flags = flags + OPEN_CREATE
  end
  if attr.uri then
    flags = flags + OPEN_URI
  end
  if attr.memory then
    flags = flags + OPEN_MEMORY
  end
  if not attr.mutex then
    flags = flags + OPEN_NOMUTEX
  end
  if attr.mutex then
    flags = flags + OPEN_FULLMUTEX
  end
  if attr.cache == "shared" then
    flags = flags + OPEN_SHAREDCACHE
  end
  if attr.cache == "private" then
    flags = flags + OPEN_PRIVATECACHE
  end
  if not attr.follow then
    flags = flags + OPEN_NOFOLLOW
  end
  return typeset({
    filename = filename,
    db = sqlite.open(filename, flags),
    attributes = attr
  }, "Database")
end
local Statement
Statement = function(self)
  expect(1, self, {
    "Database"
  })
  return function(sql)
    expect(2, sql, {
      "string"
    })
    if not (sql:match(";$")) then
      sql = sql .. ";"
    end
    if not (sqlite.complete(sql)) then
      error("Not a valid SQL statement: [[" .. tostring(sql) .. "]]")
    end
    local stat = self.db:prepare(sql)
    if "userdata" ~= typeof(stat) then
      error("Could not prepare statement: [[" .. tostring(sql) .. "]], (" .. tostring(stat) .. ")")
    end
    return typeset({
      sql = sql,
      stat = stat
    }, "Statement")
  end
end
local finalize
finalize = function(self)
  expect(1, self, {
    "Statement"
  })
  local ok = self.stat:finalize()
  return (ok == OK), ok
end
local isOpen
isOpen = function(self)
  expect(1, self, {
    "Statement"
  })
  return self.stat:isopen()
end
local bind
bind = function(self)
  expect(1, self, {
    "Statement"
  })
  return function(nametable)
    expect(2, nametable, {
      "table"
    })
    if not (self.stat) then
      print((require("inspect"))(self))
    end
    local ok = self.stat:bind_names(nametable)
    return (ok == OK), ok
  end
end
local bindOne
bindOne = function(self)
  expect(1, self, {
    "Statement"
  })
  return function(n, value)
    expect(2, n, {
      "number",
      "string"
    })
    local ok = self.stat:bind(n, value)
    return (ok == OK), ok
  end
end
local bindMany
bindMany = function(self)
  expect(1, self, {
    "Statement"
  })
  return function(list)
    local ok = self.stat:bind_values(unpack(list))
    return (ok == OK), ok
  end
end
local query
query = function(self)
  expect(1, self, {
    "Statement"
  })
  return self.stat:nrows()
end
local query1
query1 = function(self)
  expect(1, self, {
    "Statement"
  })
  return self.stat:rows()
end
local iquery
iquery = function(self)
  expect(1, self, {
    "Statement"
  })
  return self.stat:urows()
end
local queryall
queryall = function(self)
  expect(1, self, {
    "Statement"
  })
  local r
  do
    local _accum_0 = { }
    local _len_0 = 1
    for row in self.stat:nrows() do
      _accum_0[_len_0] = row
      _len_0 = _len_0 + 1
    end
    r = _accum_0
  end
  self.stat:reset()
  return r
end
local queryone
queryone = function(self)
  expect(1, self, {
    "Statement"
  })
  local r = (queryall(self))[1]
  self.stat:reset()
  return r
end
local execute
execute = function(self)
  expect(1, self, {
    "Statement"
  })
  local status = self.stat:step()
  self.stat:reset()
  return (status == sqlite.DONE), status
end
local close
close = function(self)
  expect(1, self, {
    "Database"
  })
  local ok = self.db:close()
  if ok and self.attributes.volatile and (filename ~= ":memory:") then
    os.remove(filename)
  end
  return (ok == OK), ok
end
local errorFor
errorFor = function(self)
  expect(1, self, {
    "Database"
  })
  return (self.db:errcode()), (self.db:errmsg())
end
local changesIn
changesIn = function(self)
  expect(1, self, {
    "Database"
  })
  return self.db:changes()
end
local allChangesIn
allChangesIn = function(self)
  expect(1, self, {
    "Database"
  })
  return self.db:total_changes()
end
local _Statement_isOpen = isOpen
isOpen = function(self)
  if "Statement" == typeof(self) then
    return _Statement_isOpen(self)
  end
  expect(1, self, {
    "Database"
  })
  return self.stat:isopen()
end
local update
update = function(self)
  expect(1, self, {
    "Database"
  })
  return function(sql, bindt)
    if bindt == nil then
      bindt = { }
    end
    expect(2, sql, {
      "string"
    })
    expect(3, bindt, {
      "table"
    })
    local stmt = (Statement(self))(sql)
    if not ((bind(stmt))(bindt)) then
      error("update : Failed to bind to [[" .. tostring(sql) .. "]]")
    end
    return execute(stmt)
  end
end
local _Statement_query = query
query = function(self)
  if "Statement" == typeof(self) then
    return _Statement_query(self)
  end
  expect(1, self, {
    "Database"
  })
  return function(sql, bindt)
    if bindt == nil then
      bindt = { }
    end
    expect(2, sql, {
      "string"
    })
    expect(3, bindt, {
      "table"
    })
    local stmt = (Statement(self))(sql)
    if not ((bind(stmt))(bindt)) then
      error("query : Failed to bind to [[" .. tostring(sql) .. "]]")
    end
    return query(stmt)
  end
end
local _Statement_query1 = query1
query1 = function(self)
  if "Statement" == typeof(self) then
    return _Statement_query1(self)
  end
  expect(1, self, {
    "Database"
  })
  return function(sql, bindt)
    if bindt == nil then
      bindt = { }
    end
    expect(2, sql, {
      "string"
    })
    expect(3, bindt, {
      "table"
    })
    local stmt = (Statement(self))(sql)
    if not ((bind(stmt))(bindt)) then
      error("query1 : Failed to bind to [[" .. tostring(sql) .. "]]")
    end
    return query1(stmt)
  end
end
local _Statement_iquery = iquery
iquery = function(self)
  if "Statement" == typeof(self) then
    return _Statement_iquery(self)
  end
  expect(1, self, {
    "Database"
  })
  return function(sql, bindt)
    if bindt == nil then
      bindt = { }
    end
    expect(2, sql, {
      "string"
    })
    expect(3, bindt, {
      "table"
    })
    local stmt = (Statement(self))(sql)
    if not ((bind(stmt))(bindt)) then
      error("iquery : Failed to bind to [[" .. tostring(sql) .. "]]")
    end
    return iquery(stmt)
  end
end
local _Statement_queryall = queryall
queryall = function(self)
  if "Statement" == typeof(self) then
    return _Statement_queryall(self)
  end
  expect(1, self, {
    "Database"
  })
  return function(sql, bindt)
    if bindt == nil then
      bindt = { }
    end
    expect(2, sql, {
      "string"
    })
    expect(3, bindt, {
      "table"
    })
    local stmt = (Statement(self))(sql)
    if not ((bind(stmt))(bindt)) then
      error("queryall : Failed to bind to [[" .. tostring(sql) .. "]]")
    end
    return queryall(stmt)
  end
end
local _Statement_queryone = queryone
queryone = function(self)
  if "Statement" == typeof(self) then
    return _Statement_queryone(self)
  end
  expect(1, self, {
    "Database"
  })
  return function(sql, bindt)
    if bindt == nil then
      bindt = { }
    end
    expect(2, sql, {
      "string"
    })
    expect(3, bindt, {
      "table"
    })
    local stmt = (Statement(self))(sql)
    if not ((bind(stmt))(bindt)) then
      error("queryone : Failed to bind to [[" .. tostring(sql) .. "]]")
    end
    return queryone(stmt)
  end
end
local Transaction
Transaction = function(self)
  expect(1, self, {
    "Database"
  })
  local upd = update(self)
  return function(fn)
    expect(2, fn, {
      "function"
    })
    if not (upd("SAVEPOINT grasp_savepoint")) then
      error("Could not start transaction (grasp_savepoint)")
    end
    local ok = pcall(function()
      return fn(self)
    end)
    if ok then
      upd("RELEASE grasp_savepoint")
    else
      upd("ROLLBACK TO grasp_savepoint")
    end
    return ok
  end
end
return {
  OPEN_CREATE = OPEN_CREATE,
  OPEN_FULLMUTEX = OPEN_FULLMUTEX,
  OPEN_MEMORY = OPEN_MEMORY,
  OPEN_NOFOLLOW = OPEN_NOFOLLOW,
  OPEN_NOMUTEX = OPEN_NOMUTEX,
  OPEN_PRIVATECACHE = OPEN_PRIVATECACHE,
  OPEN_READONLY = OPEN_READONLY,
  OPEN_READWRITE = OPEN_READWRITE,
  OPEN_SHAREDCACHE = OPEN_SHAREDCACHE,
  OPEN_URI = OPEN_URI,
  OK = OK,
  sqlite = sqlite,
  Statement = Statement,
  finalize = finalize,
  isOpen = isOpen,
  bind = bind,
  bindOne = bindOne,
  bindMany = bindMany,
  query = query,
  query1 = query1,
  iquery = iquery,
  queryall = queryall,
  queryone = queryone,
  execute = execute,
  Database = Database,
  close = close,
  errorFor = errorFor,
  changesIn = changesIn,
  allChangesIn = allChangesIn,
  update = update,
  Transaction = Transaction
}
