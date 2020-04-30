-- grasp.util
-- Util functions for grasp
-- By daelvn

typeof = (v) ->
  -- get metatable
  local meta
  if "table" == type v
    if type_mt = getmetatable v
      meta = type_mt.__type
  -- check how to obtain type
  -- __type
  if meta
    switch type meta
      when "function" then return meta v
      when "string"   then return meta
  -- io.type()
  elseif io.type v
    return "io"
  -- type()
  else
    return type v

expect = (n, v, ts) ->
  for ty in *ts
    return true if ty == typeof v
  error "bad argument ##{n} (expected #{table.concat ts, ' or '}, got #{type v})", 2

typeset = (v, ty) ->
  expect 1, v, {"table"}
  if mt = getmetatable v
    mt.__type = ty
  else
    setmetatable v, __type: ty
  return v

{
  :expect, :typeof, :typeset
}