local config   = { spaces = 4 };
local str      = string;
local sub      = str.sub;
local format   = str.format;
local rep      = str.rep;
local byte     = str.byte;
local match    = str.match;
local dump     = str.dump or dumpstring;
local gsub     = str.gsub;
local info     = debug.getinfo;
local huge     = math.huge; -- just like your mother
local Type     = type;
local Pairs    = pairs;
local Assert   = assert;
local Tostring = tostring;
local concat   = table.concat;
local Tab      = rep(" ", config.spaces or 4);
local Serialize, SerializeCompress;

local function serializeArgs(...) 
  local Serialized = {}; -- For performance reasons

  for i,v in Pairs({...}) do
    local valueType = Type(v);
    local SerializeIndex = #Serialized + 1;
    if valueType == "string" then
      Serialized[SerializeIndex] = format("\"%s\"", v);
    elseif valueType == "table" then
      Serialized[SerializeIndex] = Serialize(v, 0);
    else
      Serialized[SerializeIndex] = Tostring(v);
    end;
  end;

  return concat(Serialized, ", ");
end;

local function ByteString(k) 
  return "\\" .. byte(k);
end;

local function formatFunction(func)
  if dump and info and info(func).what ~= "C" then
    return format("function(...) return loadstring(\"%s\")(...); end", gsub(dump(func), ".", ByteString));
  end;

  if info then -- Creates function prototypes
    local proto = info(func);
    local params = {};

    if proto.nparams then
      for i=1, proto.nparams do
        params[i] = format("p%d", i);
      end;
      if proto.isvararg then
        params[#params+1] = "...";
      end;
    end;

    return format("function(%s) --[[ Function Name: \"%s\", Type: %s ]] end", concat(params, ", "), proto.namewhat or proto.name or "", proto.what);
  end;

  return "function()end"; -- we cannot create a prototype
end;

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
      if Code < 32 or Code > 126 then
        String[Pos] = format("\\%d", Code);
      else
        String[Pos] = Key;
      end;
    end;
    Pos = Pos + 1;
  end;
  return concat(String);
end;

-- We can do a little trolling and use this for booleans too
local function formatNumber(numb) 
  if numb == huge then
    return "math.huge";
  elseif numb == -huge then
    return "-math.huge";
  end;
  return Tostring(numb);
end;

local function formatIndex(idx, scope)
  local indexType = Type(idx);
  local finishedFormat = idx;

  if indexType == "string" then
    if match(idx, "[^_%a%d]+") then
      finishedFormat = format("\"%s\"", formatString(idx));
    else
      return idx;
    end;
  elseif indexType == "table" then
    if not scope then
      finishedFormat = SerializeCompress(idx);
    else
      scope = scope + 1;
      finishedFormat = Serialize(idx, scope);
    end;
  elseif indexType == "number" or indexType == "boolean" then
    finishedFormat = formatNumber(idx);
  elseif indexType == "function" then
    finishedFormat = formatFunction(idx);
  end;

  return format("[%s]", finishedFormat);
end;

SerializeCompress = function(tbl, checked)
  checked = checked or {};
  
  if checked[tbl] then
    return format("\"%s -- recursive table\"", Tostring(tbl));
  end;
  checked[tbl] = true;

  local Serialized = {};

  for i,v in Pairs(tbl) do
    local formattedIndex = formatIndex(i);
    local valueType = Type(v);
    local SerializeIndex = #Serialized + 1;
    if valueType == "string" then -- Could of made it inline but its better to manage types this way.
      Serialized[SerializeIndex] = format("%s=\"%s\",", formattedIndex, formatString(v));
    elseif valueType == "number" or valueType == "boolean" then
      Serialized[SerializeIndex] = format("%s=%s,", formattedIndex, formatNumber(v));
    elseif valueType == "table" then
      Serialized[SerializeIndex] = format("%s=%s,", formattedIndex, SerializeCompress(v, checked));
    elseif valueType == "userdata" then
      Serialized[SerializeIndex] = format("%s=newproxy(),", formattedIndex);
    elseif valueType == "function" then
      Serialized[SerializeIndex] = format("%s=%s,", formattedIndex, formatFunction(v));
    else
      Serialized[SerializeIndex] = format("%s=%s,", formattedIndex, Tostring(valueType)); -- Unsupported types.
    end;
  end;

    -- Remove last comma
  local lastValue = Serialized[#Serialized];
  if lastValue then
    Serialized[#Serialized] = sub(lastValue, 0, -2);
  end;

  return format("{%s}", concat(Serialized));
end;

Serialize = function(tbl, scope, checked) 
  checked = checked or {};

  if checked[tbl] then
    return format("\"%s -- recursive table\"", Tostring(tbl));
  end;
  checked[tbl] = true;

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
      Serialized[SerializeIndex] = format("%s%s = \"%s\",\n", scopeTab2, formattedIndex, formatString(v));
    elseif valueType == "number" or valueType == "boolean" then
      Serialized[SerializeIndex] = format("%s%s = %s,\n", scopeTab2, formattedIndex, formatNumber(v));
    elseif valueType == "table" then
      Serialized[SerializeIndex] = format("%s%s = %s,\n", scopeTab2, formattedIndex, Serialize(v, scope+1, checked));
    elseif valueType == "userdata" then
      Serialized[SerializeIndex] = format("%s%s = newproxy(),\n", scopeTab2, formattedIndex);
    elseif valueType == "function" then
      Serialized[SerializeIndex] = format("%s%s = %s,\n", scopeTab2, formattedIndex, formatFunction(v));
    else
      Serialized[SerializeIndex] = format("%s%s = %s,\n", scopeTab2, formattedIndex, Tostring(valueType)); -- Unsupported types.
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

local Serializer = {};

function Serializer.Serialize(tbl)
  Assert(Type(tbl) == "table", "invalid argument #1 to 'Serialize' (table expected)");
  return Serialize(tbl);
end;

function Serializer.SerializeCompress(tbl) 
  Assert(Type(tbl) == "table", "invalid argument #1 to 'SerializeCompress' (table expected)");
  return SerializeCompress(tbl);
end;

function Serializer.FormatArguments(...) 
  return serializeArgs(...);
end;

function Serializer.FormatString(str) 
  Assert(Type(str) == "string", "invalid argument #1 to 'FormatString' (string expected)");
  return formatString(str);
end;

function Serializer.UpdateConfig(options) 
  Assert(Type(options) == "table", "invalid argument #1 to 'UpdateConfig' (table expected)");
  config.spaces = options.spaces or 4;
  Tab = rep(" ", config.spaces);
end;

return Serializer;
