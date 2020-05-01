-- grasp.query
-- SQLite Query Builder
-- By daelvn
import expect from require "grasp.util"
inspect = require "inspect"
unpack or= table.unpack

-- Run with environment
runwith = (fn, env, ...) ->
  setfenv fn, env
  return fn ...
-- quickcopy
quickcopy = (t) -> {unpack t}

-- emitting function
emit = (t) -> (add) ->
  t.str ..= add

-- normalize a value
norm = (v) ->
  return 1               if v == true
  return 0               if v == false
  return "NULL"          if v == nil
  return ("%q")\format v if "string" == type v
  return v.date          if ("table" == type v) and v.date
  return v

-- sql environments
local env
env = {
  -- reset!
  reset: ->
    resettable = {
      "temp", "always", "without_rowid", "replace", "rollback"
      "abort", "fail", "ignore", "name", "alias", "distinct", "all"
      "where", "order", "limit", "off"
    }
    env[rr] = false for rr in *resettable
  -- sql
  sql: {
    -- date
    date: (str) -> date: "date('#{str}')"
    -- query plan
    queryplan: "QUERY PLAN"
    -- explain
    explain: (attr, fn) ->
      if fn
        error "sql.explain: Attribute is not QUERY PLAN" unless attr == "QUERY PLAN"
        expect 2, fn, {"function"}
      else
        fn = attr
        expect 1, fn, {"function"}
      --
      resl     = str: ""
      oldemit  = env.emit
      env.emit = emit resl
      retv     = runwith fn, env.sql
      env.emit = oldemit
      --
      if attr == "QUERY PLAN"
        env.emit "EXPLAIN QUERY PLAN " .. resl.str
      else
        env.emit "EXPLAIN " .. resl.str
    -- savepoint
    savepoint: (name) ->
      expect 1, name, {"string"}
      env.emit "SAVEPOINT #{name};"
    -- release
    release: (name) ->
      expect 1, name, {"string"}
      env.emit "RELEASE #{name};"
    -- rollback
    rollback: (name) ->
      expect 1, name, {"string", "nil"}
      if name
        env.emit "ROLLBACK TO #{name};"
      else
        env.emit "ROLLBACK TRANSACTION;"
    -- begin
    deferred:  "DEFERRED"
    immediate: "IMMEDIATE"
    exclusive: "EXCLUSIVE"
    begin: (attr="") ->
      expect 1, attr, {"string", "nil"}
      env.emit "BEGIN #{attr} TRANSACTION"
    -- commit/end
    commit: -> env.emit "COMMIT TRANSACTION;"
    End:    -> env.emit "END TRANSACTION;" 
    -- create
    create: (name, fn) ->
      expect 1, name, {"string"}
      expect 2, fn,   {"function"}
      retv   = runwith fn, env.create
      --
      this   = "CREATE"
      this ..= " TEMPORARY" if env.temp
      this ..= " TABLE"
      this ..= " IF NOT EXISTS" unless env.always
      this ..= " #{name}"
      this ..= "(\n"
      this ..= "  #{name} #{value},\n" for name, value in pairs retv.columns
      this ..= ")"
      this ..= " WITHOUT ROWID" if env.without_rowid
      this ..= ";"
      --
      env.emit this
      env.reset!
    -- insert
    insert: (fn, into, replace=false) ->
      expect 1, fn,      {"function"}
      expect 2, into,    {"string", "nil"}
      expect 3, replace, {"boolean"}
      retv       = runwith fn, env.insert
      values     = retv.values
      keys       = [k for k, _ in pairs values]
      env.name or= into
      --
      this   = replace and "REPLACE" or "INSERT"
      this ..= " OR REPLACE"       if env.replace
      this ..= " OR ROLLBACK"      if env.rollback
      this ..= " OR ABORT"         if env.abort
      this ..= " OR FAIL"          if env.fail
      this ..= " OR IGNORE"        if env.ignore
      this ..= " INTO #{env.name}" if env.name or into else error "sql.insert: Expected 'into <name>'"
      this ..= " AS #{env.alias}"  if env.alias
      this ..= "("
      this ..= "#{k}, " for k in *keys[,#keys-1]
      this ..= "#{keys[#keys]}"
      this ..= ")"
      this ..= " VALUES (\n"
      this ..= "  #{norm values[k]},\n" for k in *keys[,#keys-1]
      this ..= "  #{norm values[keys[#keys]]}\n"
      this ..= ");"
      --
      env.emit this
      env.reset!
    -- replace
    replace: (fn, into) -> env.sql.insert fn, into, true
    -- into hack
    into: (a, b) -> b, a
    -- select
    select: (res, fn, fr) ->
      expect 1, res, {"string"}
      expect 2, fn,  {"function"}
      expect 3, fr,  {"string", "nil"}
      retv       = runwith fn, env.select
      env.name or= fr
      --
      this   = "SELECT"
      this ..= " DISTINCT" if env.distinct
      this ..= " ALL"      if env.all
      this ..= " #{res}"
      this ..= " FROM #{env.name}"    if env.name or fr else error "sql.select: Expected 'From <name>'"
      this ..= " WHERE #{env.where}"  if env.where
      this ..= " ORDER BY #{env.ord}" if env.ord
      this ..= " LIMIT #{env.limit}"  if env.limit
      this ..= " OFFSET #{env.off}"   if env.off
      this ..= ";"
      --
      env.emit this
      env.reset!
    -- from hack
    From: (a, b) -> b, a
    -- delete
    delete: (fn, fr) ->
      expect 1, fn,  {"function"}
      expect 2, fr,  {"string", "nil"}
      retv       = runwith fn, env.delete
      env.name or= fr
      --
      this   = "DELETE FROM #{env.name}" if env.name else error "sql.delete: Expected 'From <name>'"
      this ..= " WHERE #{env.where}"     if env.where
      this ..= ";"
      --
      env.emit this
      env.reset!
    -- drop table
    drop: (name, fn) ->
      expect 1, name, {"string"}
      expect 2, fn,   {"function", "nil"}
      retv = runwith fn, env.drop if fn
      --
      this   = "DROP TABLE"
      this ..= " IF EXISTS" unless env.always
      this ..= " #{name};"
      --
      env.emit this
      env.reset!
  }
  -- create
  create: {
    temporary:     -> env.temp          = true
    always:        -> env.always        = true
    without_rowid: -> env.without_rowid = true
  }
  -- insert
  insert: {
    replace:  -> env.replace  = true
    rollback: -> env.rollback = true
    abort:    -> env.abort    = true
    fail:     -> env.fail     = true
    ignore:   -> env.ignore   = true
    --
    into:  (name) -> env.name  = name
    alias: (name) -> env.alias = name
    date:  (str)  -> date: "date('#{str}')"
  }
  -- select
  select: {
    distinct: -> env.distinct = true
    all:      -> env.all      = true
    --
    From:  (name) -> env.name  = name
    order:  (ord) -> env.order = ord
    limit:  (lim) -> env.limit = lim
    offset: (off) -> env.off   = off
    where:  (any) ->
      if "table" == type any
        this = ""
        for k, v in pairs any
          this ..= "#{k} = #{norm v} AND"
        env.where = this\match "(.+) AND"
      else env.where = any
  }
  -- delete
  delete: {
    From:  (name) -> env.name  = name
    where:  (any) ->
      if "table" == type any
        this = ""
        for k, v in pairs any
          this ..= "#{k} = #{norm v} AND"
        env.where = this\match "(.+) AND"
      else env.where = any
  }
  -- drop
  drop: {
    ifexists: -> env.always = true
  }
}

-- Main
sql = (fn) ->
  result   = str: ""
  env.emit = emit result
  runwith fn, env.sql
  return result.str

{
  :sql, :norm
}