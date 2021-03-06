local expect
expect = require("grasp.util").expect
local runwith
runwith = function(fn, env, ...)
  setfenv(fn, env)
  return fn(...)
end
local emit
emit = function(t)
  return function(add)
    t.str = t.str .. add
  end
end
local dquote
dquote = function(txt)
  return ("%q"):format(txt)
end
local squote
squote = function(txt)
  return "'" .. (tostring(txt)) .. "'"
end
local norm
norm = function(v)
  if v == true then
    return 1
  end
  if v == false then
    return 0
  end
  if v == nil then
    return "NULL"
  end
  if "string" == type(v) then
    return squote(v)
  end
  if ("table" == type(v)) and v.date then
    return v.date
  end
  if ("table" == type(v)) and v.raw then
    return v.raw
  end
  return v
end
local env
env = {
  reset = function()
    local resettable = {
      "temp",
      "always",
      "without_rowid",
      "replace",
      "rollback",
      "abort",
      "fail",
      "ignore",
      "name",
      "alias",
      "distinct",
      "all",
      "where",
      "order",
      "limit",
      "off"
    }
    for _index_0 = 1, #resettable do
      local rr = resettable[_index_0]
      env[rr] = false
    end
  end,
  sql = {
    date = function(str)
      return {
        date = "date('" .. tostring(str) .. "')"
      }
    end,
    raw = function(str)
      return {
        raw = str
      }
    end,
    queryplan = "QUERY PLAN",
    explain = function(attr, fn)
      if fn then
        if not (attr == "QUERY PLAN") then
          error("sql.explain: Attribute is not QUERY PLAN")
        end
        expect(2, fn, {
          "function"
        })
      else
        fn = attr
        expect(1, fn, {
          "function"
        })
      end
      local resl = {
        str = ""
      }
      local oldemit = env.emit
      env.emit = emit(resl)
      runwith(fn, env.sql)
      env.emit = oldemit
      if attr == "QUERY PLAN" then
        return env.emit("EXPLAIN QUERY PLAN " .. resl.str)
      else
        return env.emit("EXPLAIN " .. resl.str)
      end
    end,
    savepoint = function(name)
      expect(1, name, {
        "string"
      })
      return env.emit("SAVEPOINT " .. tostring(name) .. ";")
    end,
    release = function(name)
      expect(1, name, {
        "string"
      })
      return env.emit("RELEASE " .. tostring(name) .. ";")
    end,
    rollback = function(name)
      expect(1, name, {
        "string",
        "nil"
      })
      if name then
        return env.emit("ROLLBACK TO " .. tostring(name) .. ";")
      else
        return env.emit("ROLLBACK TRANSACTION;")
      end
    end,
    deferred = "DEFERRED",
    immediate = "IMMEDIATE",
    exclusive = "EXCLUSIVE",
    begin = function(attr)
      if attr == nil then
        attr = ""
      end
      expect(1, attr, {
        "string",
        "nil"
      })
      return env.emit("BEGIN " .. tostring(attr) .. " TRANSACTION")
    end,
    commit = function()
      return env.emit("COMMIT TRANSACTION;")
    end,
    End = function()
      return env.emit("END TRANSACTION;")
    end,
    create = function(name, fn)
      expect(1, name, {
        "string"
      })
      expect(2, fn, {
        "function"
      })
      local retv = runwith(fn, env.create)
      local keys
      do
        local _accum_0 = { }
        local _len_0 = 1
        for k, _ in pairs(retv.columns) do
          _accum_0[_len_0] = k
          _len_0 = _len_0 + 1
        end
        keys = _accum_0
      end
      local this = "CREATE"
      if env.temp then
        this = this .. " TEMPORARY"
      end
      this = this .. " TABLE"
      if not (env.always) then
        this = this .. " IF NOT EXISTS"
      end
      this = this .. " " .. tostring(dquote(name))
      this = this .. "(\n"
      local _max_0 = #keys - 1
      for _index_0 = 1, _max_0 < 0 and #keys + _max_0 or _max_0 do
        local k = keys[_index_0]
        this = this .. "  " .. tostring(dquote(k)) .. " " .. tostring(norm(retv.columns[k])) .. ",\n"
      end
      this = this .. "  " .. tostring(dquote(keys[#keys])) .. " " .. tostring(norm(retv.columns[keys[#keys]]))
      this = this .. ")"
      if env.without_rowid then
        this = this .. " WITHOUT ROWID"
      end
      this = this .. ";"
      env.emit(this)
      return env.reset()
    end,
    insert = function(fn, into, replace)
      if replace == nil then
        replace = false
      end
      expect(1, fn, {
        "function"
      })
      expect(2, into, {
        "string",
        "nil"
      })
      expect(3, replace, {
        "boolean"
      })
      local retv = runwith(fn, env.insert)
      local values = retv.values
      local keys
      do
        local _accum_0 = { }
        local _len_0 = 1
        for k, _ in pairs(values) do
          _accum_0[_len_0] = k
          _len_0 = _len_0 + 1
        end
        keys = _accum_0
      end
      env.name = env.name or into
      local this = replace and "REPLACE" or "INSERT"
      if env.replace then
        this = this .. " OR REPLACE"
      end
      if env.rollback then
        this = this .. " OR ROLLBACK"
      end
      if env.abort then
        this = this .. " OR ABORT"
      end
      if env.fail then
        this = this .. " OR FAIL"
      end
      if env.ignore then
        this = this .. " OR IGNORE"
      end
      if env.name or into then
        this = this .. " INTO " .. tostring(dquote(env.name))
      else
        error("sql.insert: Expected 'into <name>'")
      end
      if env.alias then
        this = this .. " AS " .. tostring(dquote(env.alias))
      end
      this = this .. "("
      local _max_0 = #keys - 1
      for _index_0 = 1, _max_0 < 0 and #keys + _max_0 or _max_0 do
        local k = keys[_index_0]
        this = this .. tostring(dquote(k)) .. ", "
      end
      this = this .. tostring(dquote(keys[#keys]))
      this = this .. ")"
      this = this .. " VALUES (\n"
      local _max_1 = #keys - 1
      for _index_0 = 1, _max_1 < 0 and #keys + _max_1 or _max_1 do
        local k = keys[_index_0]
        this = this .. "  " .. tostring(norm(values[k])) .. ",\n"
      end
      this = this .. "  " .. tostring(norm(values[keys[#keys]])) .. "\n"
      this = this .. ");"
      env.emit(this)
      return env.reset()
    end,
    replace = function(fn, into)
      return env.sql.insert(fn, into, true)
    end,
    into = function(a, b)
      return b, a
    end,
    select = function(res, fn, fr)
      expect(1, res, {
        "string"
      })
      expect(2, fn, {
        "function"
      })
      expect(3, fr, {
        "string",
        "nil"
      })
      runwith(fn, env.select)
      env.name = env.name or fr
      local this = "SELECT"
      if env.distinct then
        this = this .. " DISTINCT"
      end
      if env.all then
        this = this .. " ALL"
      end
      this = this .. " " .. tostring(res)
      if env.name then
        this = this .. " FROM " .. tostring(dquote(env.name))
      else
        error("sql.select: Expected 'From <name>'")
      end
      if env.where then
        this = this .. " WHERE " .. tostring(env.where)
      end
      if env.ord then
        this = this .. " ORDER BY " .. tostring(env.ord)
      end
      if env.limit then
        this = this .. " LIMIT " .. tostring(env.limit)
      end
      if env.off then
        this = this .. " OFFSET " .. tostring(env.off)
      end
      this = this .. ";"
      env.emit(this)
      return env.reset()
    end,
    From = function(a, b)
      return b, a
    end,
    delete = function(fn, fr)
      expect(1, fn, {
        "function"
      })
      expect(2, fr, {
        "string",
        "nil"
      })
      runwith(fn, env.delete)
      env.name = env.name or fr
      local this
      if env.name then
        this = "DELETE FROM " .. tostring(dquote(env.name))
      else
        error("sql.delete: Expected 'From <name>'")
      end
      if env.where then
        this = this .. " WHERE " .. tostring(env.where)
      end
      this = this .. ";"
      env.emit(this)
      return env.reset()
    end,
    drop = function(name, fn)
      expect(1, name, {
        "string"
      })
      expect(2, fn, {
        "function",
        "nil"
      })
      if fn then
        runwith(fn, env.drop)
      end
      local this = "DROP TABLE"
      if not (env.always) then
        this = this .. " IF EXISTS"
      end
      this = this .. " " .. tostring(dquote(name)) .. ";"
      env.emit(this)
      return env.reset()
    end,
    update = function(name, fn)
      expect(1, name, {
        "string"
      })
      expect(2, fn, {
        "function"
      })
      local retv = runwith(fn, env.update)
      local values = retv.values
      local keys
      do
        local _accum_0 = { }
        local _len_0 = 1
        for k, _ in pairs(values) do
          _accum_0[_len_0] = k
          _len_0 = _len_0 + 1
        end
        keys = _accum_0
      end
      local this = "UPDATE"
      if env.replace then
        this = this .. " OR REPLACE"
      end
      if env.rollback then
        this = this .. " OR ROLLBACK"
      end
      if env.abort then
        this = this .. " OR ABORT"
      end
      if env.fail then
        this = this .. " OR FAIL"
      end
      if env.ignore then
        this = this .. " OR IGNORE"
      end
      this = this .. " " .. tostring(dquote(name))
      this = this .. " SET"
      local _max_0 = #keys - 1
      for _index_0 = 1, _max_0 < 0 and #keys + _max_0 or _max_0 do
        local k = keys[_index_0]
        this = this .. " " .. tostring(dquote(k)) .. " = " .. tostring(norm(values[k])) .. ","
      end
      this = this .. " " .. tostring(dquote(keys[#keys])) .. " = " .. tostring(norm(values[keys[#keys]]))
      if env.where then
        this = this .. " WHERE " .. tostring(env.where)
      end
      this = this .. ";"
      env.emit(this)
      return env.reset()
    end
  },
  create = {
    temporary = function()
      env.temp = true
    end,
    always = function()
      env.always = true
    end,
    without_rowid = function()
      env.without_rowid = true
    end,
    date = function(str)
      return {
        date = "date('" .. tostring(str) .. "')"
      }
    end,
    raw = function(str)
      return {
        raw = str
      }
    end
  },
  insert = {
    replace = function()
      env.replace = true
    end,
    rollback = function()
      env.rollback = true
    end,
    abort = function()
      env.abort = true
    end,
    fail = function()
      env.fail = true
    end,
    ignore = function()
      env.ignore = true
    end,
    into = function(name)
      env.name = norm(name)
    end,
    alias = function(name)
      env.alias = name
    end,
    date = function(str)
      return {
        date = "date('" .. tostring(str) .. "')"
      }
    end,
    raw = function(str)
      return {
        raw = str
      }
    end
  },
  update = {
    replace = function()
      env.replace = true
    end,
    rollback = function()
      env.rollback = true
    end,
    abort = function()
      env.abort = true
    end,
    fail = function()
      env.fail = true
    end,
    ignore = function()
      env.ignore = true
    end,
    date = function(str)
      return {
        date = "date('" .. tostring(str) .. "')"
      }
    end,
    raw = function(str)
      return {
        raw = str
      }
    end,
    where = function(any)
      local oldwhere = env.where
      if "table" == type(any) then
        local this = ""
        for k, v in pairs(any) do
          this = this .. tostring(dquote(k)) .. " = " .. tostring(norm(v)) .. " AND"
        end
        env.where = this:match("(.+) AND")
      else
        env.where = any
      end
      if oldwhere then
        env.where = tostring(oldwhere) .. " AND " .. tostring(env.where)
      end
    end
  },
  select = {
    distinct = function()
      env.distinct = true
    end,
    all = function()
      env.all = true
    end,
    date = function(str)
      return {
        date = "date('" .. tostring(str) .. "')"
      }
    end,
    raw = function(str)
      return {
        raw = str
      }
    end,
    From = function(name)
      env.name = name
    end,
    order = function(ord)
      env.order = ord
    end,
    limit = function(lim)
      env.limit = lim
    end,
    offset = function(off)
      env.off = off
    end,
    where = function(any)
      local oldwhere = env.where
      if "table" == type(any) then
        local this = ""
        for k, v in pairs(any) do
          this = this .. tostring(dquote(k)) .. " = " .. tostring(norm(v)) .. " AND"
        end
        env.where = this:match("(.+) AND")
      else
        env.where = any
      end
      if oldwhere then
        env.where = tostring(oldwhere) .. " AND " .. tostring(env.where)
      end
    end
  },
  delete = {
    date = function(str)
      return {
        date = "date('" .. tostring(str) .. "')"
      }
    end,
    raw = function(str)
      return {
        raw = str
      }
    end,
    From = function(name)
      env.name = name
    end,
    where = function(any)
      local oldwhere = env.where
      if "table" == type(any) then
        local this = ""
        for k, v in pairs(any) do
          this = this .. tostring(dquote(k)) .. " = " .. tostring(norm(v)) .. " AND"
        end
        env.where = this:match("(.+) AND")
      else
        env.where = any
      end
      if oldwhere then
        env.where = tostring(oldwhere) .. " AND " .. tostring(env.where)
      end
    end
  },
  drop = {
    ifexists = function()
      env.always = true
    end
  }
}
local sql
sql = function(fn)
  local result = {
    str = ""
  }
  env.emit = emit(result)
  runwith(fn, env.sql)
  return result.str
end
return {
  sql = sql,
  norm = norm
}
