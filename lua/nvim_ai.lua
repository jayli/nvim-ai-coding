local Export = {}

local function setInterval(interval, callback)
  local timer = vim.loop.new_timer()
  timer:start(interval, interval, function ()
    callback()
  end)
  return timer
end

-- And clearInterval
local function clearInterval(timer)
  timer:stop()
  timer:close()
end

function loading()
  local count = 0

  local timer = setInterval(100, function()
    print('echomsg "' .. tostring(count) .. '"')
    count = count + 1
    if count > 50 then
      clearInterval(timer)
    end
  end)
end

function Export.test()
  loading()
  -- local thread = vim.loop.new_thread(loading)
  -- vim.loop.thread_join(thread)
end

function Export.print(msg)
  print(msg)
end

return Export 

-- vim:ts=2:sw=2:sts=2
