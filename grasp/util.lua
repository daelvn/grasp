local typeof
typeof = function(v)
  local meta
  if "table" == type(v) then
    do
      local type_mt = getmetatable(v)
      if type_mt then
        meta = type_mt.__type
      end
    end
  end
  if meta then
    local _exp_0 = type(meta)
    if "function" == _exp_0 then
      return meta(v)
    elseif "string" == _exp_0 then
      return meta
    end
  elseif io.type(v) then
    return "io"
  else
    return type(v)
  end
end
local expect
expect = function(n, v, ts)
  for _index_0 = 1, #ts do
    local ty = ts[_index_0]
    if ty == typeof(v) then
      return true
    end
  end
  return error("bad argument #" .. tostring(n) .. " (expected " .. tostring(table.concat(ts, ' or ')) .. ", got " .. tostring(type(v)) .. ")", 2)
end
local typeset
typeset = function(v, ty)
  expect(1, v, {
    "table"
  })
  do
    local mt = getmetatable(v)
    if mt then
      mt.__type = ty
    else
      setmetatable(v, {
        __type = ty
      })
    end
  end
  return v
end
return {
  expect = expect,
  typeof = typeof,
  typeset = typeset
}
