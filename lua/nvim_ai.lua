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

-- v:lua.require("nvim_ai").test()
local function treesitter_message()
  vim.cmd [[message clear]]
  vim.cmd [[let @a = '']]
  vim.cmd [[redir @a]]
  vim.cmd [[TSConfigInfo]]
  vim.cmd [[redir END]]
  vim.cmd [[let g:nvim_ai_treesitter_msg = @a]]
  vim.cmd [[message clear]]
  return vim.g.nvim_ai_treesitter_msg
end

-- v:lua.require("nvim_ai").treesitter_is_on()
function Export.treesitter_is_on()
  if not vim.fn['nvim_ai#treesitter_available']() then
    return false
  end
  local msg = treesitter_message()
  msg = string.gsub(msg, "[%s\n]+", "")
  msg = string.gsub(msg, "<function%d+>", "true")
  local success, result = pcall(function()
    local evalue = "return " .. msg
    local func = loadstring(evalue)
    local obj = func()
    local result = obj.modules.highlight.enable
    return result
  end)
  if success then
    return result
  else
    return false
  end
end

-----------------------copilot---------------------------

local code_block = [[
for line in code_block:gmatch("[^\r\n]+") do
  table.insert(lines, {{line, "Comment"}})
end
]]


-- split text into a list




local copilot_ns = vim.api.nvim_create_namespace('copilot_ns')

-- code_block 是一个字符串，有可能包含回车符
function Export.copilot_block_hint()
  local lines = {}
  for line in code_block:gmatch("[^\r\n]+") do
    table.insert(lines, {{line, "Comment"}})
  end

  local virt_text = lines[1]
  local virt_lines

  print(#lines)
  if #lines >= 2 then
    table.remove(lines, 1)
    virt_lines = lines
  else
    virt_lines = nil
  end

  vim.api.nvim_buf_set_extmark(0, copilot_ns, vim.fn.line('.') - 1, vim.fn.col('.') - 1, {
    id = 1,
    virt_text_pos = "overlay",
    virt_text = virt_text,
    virt_lines = virt_lines
  })

end

function Export.copilot_delete_hint()
  vim.api.nvim_buf_del_extmark(0, copilot_ns, 1)
end

-- copilot
-- call v:lua.require("nvim_ai").test()
function Export.test()
  print('---begin---')
  local lines = {}
  for line in code_block:gmatch("[^\r\n]+") do
    table.insert(lines, {{line, "Comment"}})
  end
  local virt_lines = lines
  local cur_line = vim.fn.line('.')
  vim.api.nvim_buf_set_extmark(0, copilot_ns, cur_line - 1, vim.fn.col('.') - 1, {
    id = 1,
    virt_text_pos = "overlay",
    virt_text = {
      {"xxxxxxxxxxxxxxxxx", "Comment"}
    },
    virt_lines = {{}}
  })
end

return Export

-- vim:ts=2:sw=2:sts=2
