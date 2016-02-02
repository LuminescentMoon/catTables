--- A library that makes tables which dynamically inherit the fields of the tables they contain (child tables). Exports a factory function.
-- @script catTable
-- @license MIT
-- @copyright Howard Nguyen, 2016

local string = require('string')

--- Module table holding constants. Calling this table is equivalent to calling @{create}.
-- @tfield string _NAME Name.
-- @tfield string __VERSION Version following SemVer specs.
-- @tfield boolean log Determines whether or not to ouput what it's doing to the console.
-- @tfield string defaultCatMarker The default prefix used to detect a category.
-- @tfield symbol categoriesKey The key in which a catTable's categories list is stored. A table is used as a key to prevent namespace collisions.
-- @tfield symbol catMarkerKey The key in which a catTable's subcategory indicator is stored.
-- @tfield symbol cacheKey The key in which a catTable's cache is stored.
-- @table catTables
local catTables = {
  _NAME = 'catTable',
  _VERSION = '0.9.0',
  log = false,
  defaultShouldCache = true,
  defaultCatMarker = '_',
  categoriesKey = {},
  catMarkerKey = {},
  cacheKey = {}
}

local print = function(...)
  if catTables.log then
    return print(...)
  end
end

local defaultShouldCache = catTables.defaultShouldCache
local defaultCatMarker = catTables.defaultCatMarker
local categoriesKey = catTables.categoriesKey
local catMarkerKey = catTables.catMarkerKey
local cacheKey = catTables.cacheKey

--- The recursive key lookup function.
-- @TODO: Recurse in order of levels.
-- @tparam table t The table to perform the lookup in.
-- @param field The field to lookup.
-- @param[opt] table Cache to check for the field before performing the lookup.
-- @function lookup
-- @local
local function lookup(t, field, cache, stack, stacklvl)
  print('looking for:', field)
  -- Check direct subcategories.
  if t[field] ~= nil then
    return t[field], stack
  end

  -- Check cache.
  if cache and cache[field] then
    print('checking cache')
    local result = rawget(cache[field], field)
    if result ~= nil then
      print('cache hit')
      return result
    else
      print('cache fail')
      cache[field] = nil
    end
  end

  -- Iterate through fields of direct subcategories.
  for _, v in pairs(t) do
    local result = rawget(v, field)
    if result ~= nil then
      stack[stacklvl + 1] = v
      return result, stack
    end
  end

  -- Iterate through subcategories' subcategories.
  stacklvl = stacklvl or 0
  print('recurse lvl', stacklvl)
  stack = stack or {}
  for k, v in pairs(t) do
    local categories = rawget(v, categoriesKey)
    if type(categories) == 'table' then
      stack[stacklvl + 1] = k
      print('search branch at', unpack(stack))
      local result = lookup(categories, field, cache, stack, stacklvl + 1)
      if result ~= nil then
        print('lookup successful')
        return result, stack
      end
    end
  end
  print('lookup fail')
end

local function isCategory(t, k, catMarker)
  if type(catMarker) == 'string' then
    return string.sub(k, 1, 1) == catMarker or catMarker == ''
  elseif type(catMarker) == 'function' then
    return catMarker(t, k)
  else
    return false
  end
end

local catMT = {}

local function isCatTable(t)
  return getmetatable(t) == catMT
end

catMT.__newindex = function(t, k, v)
  print('__newindex', t, k, v)
  local catMarker = t[catMarkerKey]
  catMarker = catMarker ~= nil and catMarker or defaultCatMarker
  if type(v) == 'table' and isCategory(t, k, catMarker) then
    local categories = rawget(t, categoriesKey)
    if type(categories) ~= 'table' then -- This table is lazily made so if its catTable is used as a regular table, an unnecessary allocation won't be made.
      categories = {}
      rawset(t, categoriesKey, categories)
    end
    local shouldCache = type(t[cacheKey]) == 'table'
    local category = isCatTable(v) and v or catTables.create(v, catMarker, shouldCache)
    print('end: created cat', category)
    categories[k] = category
  else
    print('end: rawset', t, k, v)
    rawset(t, k, v)
  end
end

catMT.__index = function(t, k)
  local result = nil
  local categories = rawget(t, categoriesKey)
  if type(categories) == 'table' then
    local cache, stack = t[cacheKey]
    result, stack = lookup(categories, k, cache)
    if cache and stack then
      print('caching result')
      cache[k] = stack[#stack]
    end
  end
  return result
end

--- Creates a new catTable. Optionally accepts a table to inherit.
-- @tparam[opt] table inheritable A table to inherit values from. A shallow copy is performed.
-- @tparam[opt='_'] ?string|function catMarker A prefix to use as an indicator for a subcategory. If a function is passed, it'll call that function, passing the table and key as arguments, to check if the key is a subcategory. Said function should return true to indicate a valid subcategory key. If an empty string is passed, all tables will count as subcategories.
-- @tparam[opt=true] boolean shouldCache Determines whether or not to cache fields indexed from nested tables (categories).
-- @treturn catTable A brand new spankin' catTable.
-- @function create
function catTables.create(inheritable, catMarker, shouldCache)
  print('arg types', type(inheritable), 'catMarker : ' .. type(catMarker) .. '<' .. tostring(catMarker) .. '>', 'shouldCache : ' .. type(shouldCache) .. '<' .. tostring(shouldCache) .. '>')
  -- print('inspection: ' .. inspect(inheritable))
  if type(shouldCache) ~= 'boolean' then -- Can't use binary operators as a ternary operator if both of the possible return values can be false.
    shouldCache = defaultShouldCache
  end

  local newTable = setmetatable({}, catMT)

  if catMarker ~= nil and catMarker ~= defaultCatMarker and (type(catMarker) == 'string' or type(catMarker) == 'function') then
    rawset(newTable, catMarkerKey, catMarker)
  else
    rawset(newTable, catMarkerKey, defaultCatMarker)
  end
  rawset(newTable, cacheKey, shouldCache and {}) -- Return false if shouldCache is falsey, else return table.

  if type(inheritable) == 'table' then
    for k, v in pairs(inheritable) do
      print('new pair', 'key', k, 'val', v)
      newTable[k] = v -- Note we don't use rawset() here.
    end
  end

  print('created catTable')
  return newTable
end

setmetatable(catTables, {
  __call = function(_, ...)
    return catTables.create(...)
  end
})

return catTables
