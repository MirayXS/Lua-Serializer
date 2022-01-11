-- This version is built for the roblox platform.

local format   = string.format;
local rep      = string.rep;
local Type     = type;
local Pairs    = pairs;
local gsub     = string.gsub;
local sub      = string.sub;
local byte     = string.byte;
local char     = string.char;
local Tostring = tostring;
local concat   = table.concat;
local Tab      = rep(" ", 4);

local Serialize;
local function formatIndex(idx, scope)
  local indexType = Type(idx);
  local finishedFormat = idx;
  if indexType == "string" then
    finishedFormat = format("\27[32m\"%s\"\27[0m", idx); 
  elseif indexType == "table" then
    scope = scope + 1;
    finishedFormat = Serialize(idx, scope);
  elseif indexType == "number" then
    finishedFormat = format("\27[33m%s\27[0m", idx);
  end;
  return format("[%s]", finishedFormat);
end;

local function serializeArgs(...) 
  local Serialized = {}; -- For performance reasons

  for i,v in Pairs({...}) do
    local valueType = Type(v);
    local SerializeIndex = #Serialized + 1;
    if valueType == "string" then
      Serialized[SerializeIndex] = format("\27[32m\"%s\"\27[0m", v);
    elseif valueType == "table" then
      Serialized[SerializeIndex] = Serialize(v, 0);
    else
      Serialized[SerializeIndex] = Tostring(v);
    end;
  end;

  return concat(Serialized, ", ");
end;

-- Very scuffed method I know

local function formatString(str) 
  local Pos = 1;
  local String = {};
  while Pos <= #str do
    local Key = sub(str, Pos, Pos);
    if Key == "\n" then
      String[Pos] = "\\n";
    elseif Key == "\t" then
      String[Pos] = "\\t";
    elseif Key == "\"" then
      String[Pos] = "\\\"";
    else
      local Code = byte(Key);
      if Code < 32 or Code > 126  then
        String[Pos] = format("\\%d", Code);
      else
        String[Pos] = Key;
      end;
    end;
    Pos++;
  end;
  return concat(String);
end;

Serialize = function(tbl, scope) 
  scope = scope or 0;

  local Serialized = {}; -- For performance reasons
  local scopeTab = rep(Tab, scope);
  local scopeTab2 = rep(Tab, scope+1);

  local tblLen = 0;
  for i,v in Pairs(tbl) do
    local formattedIndex = formatIndex(i, scope);
    local valueType = Type(v);
    local SerializeIndex = #Serialized + 1;
    if valueType == "string" then -- Could of made it inline but its better to manage types this way.
      Serialized[SerializeIndex] = format("%s%s = \27[32m\"%s\"\27[0m,\n", scopeTab2, formattedIndex, formatString(v));
    elseif valueType == "number" or valueType == "boolean" then
      Serialized[SerializeIndex] = format("%s%s = \27[33m%s\27[0m,\n", scopeTab2, formattedIndex, Tostring(v));
    elseif valueType == "table" then
      Serialized[SerializeIndex] = format("%s%s = %s,\n", scopeTab2, formattedIndex, Serialize(v, scope+1));
    elseif valueType == "userdata" then
      Serialized[SerializeIndex] = format("%s%s = newproxy(),\n", scopeTab2, formattedIndex);
    else
      Serialized[SerializeIndex] = format("%s%s = \"%s\",\n", scopeTab2, formattedIndex, Tostring(valueType)); -- Unsupported types.
    end;
    tblLen = tblLen + 1; -- # messes up with nil values
  end;

  -- Remove last comma
  local lastValue = Serialized[#Serialized];
  if lastValue then
    Serialized[#Serialized] = sub(lastValue, 0, -3) .. "\n";
  end;

  if tblLen > 0 then
    if scope < 1 then
      return format("{\n%s}", concat(Serialized));  
    else
      return format("{\n%s%s}", concat(Serialized), scopeTab);
    end;
  else
    return "{}";
  end;
end;

local SerializeL = {
  formatIndex = formatIndex,
  formatString = formatString,
  serializeArgs = serializeArgs,
  config = config
}

return setmetatable(SerializeL, {
  __call = function(self, ...)
    return Serialize(...);
  end
});
