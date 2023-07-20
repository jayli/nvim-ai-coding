local Export = {}

local function set_interval(interval, callback)
  local timer = vim.loop.new_timer()
  timer:start(interval, interval, function ()
    callback()
  end)
  return timer
end

-- And clearInterval
local function clear_interval(timer)
  timer:stop()
  timer:close()
end

function loading()
  local count = 0

  local timer = set_interval(100, function()
    print('echomsg "' .. tostring(count) .. '"')
    count = count + 1
    if count > 50 then
      clear_interval(timer)
    end
  end)
end

function Export.test()
  loading()
end

local function remove_space(str)
  return string.gsub(str, "%s", "")
end


function Export.fuzzy_search(needle, haystack)
  local l_haystack = remove_space(haystack)
  local l_needle = remove_space(needle)
  local tlen = #l_haystack
  local qlen = #l_needle
  if qlen > tlen then
    return false
  end
  if qlen == tlen then
    if l_haystack == l_needle then
      return true
    else
      return false
    end
  end

  local needle_ls = string.lower(l_needle)
  local haystack_ls = string.lower(l_haystack)
  
  local cursor_n = 0
  local cursor_h = 0
  local matched = false

  while cursor_h < #haystack_ls do
    -- 在这里编写你的循环逻辑代码
    if haystack_ls:sub(cursor_h + 1, cursor_h + 1) == needle_ls:sub(cursor_n + 1, cursor_n + 1) then
      if cursor_n == #needle_ls - 1 then
        matched = true
        break
      end
      cursor_n = cursor_n + 1
    end
    cursor_h = cursor_h + 1
  end

  return matched
end

function Export.print(msg)
  print(msg)
end

return Export 

-- vim:ts=2:sw=2:sts=2
