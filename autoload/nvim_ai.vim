let s:line1 = 0
let s:line2 = 0
let s:range = 0
let s:bufnr = 0
" 临时变量，给 python 用的
let g:nvim_ai_range = 0
let g:nvim_ai_updatetime = &updatetime
let g:treesitter_is_on = v:false
let g:synmaxcol = &synmaxcol

function! s:prepare_python()
  if get(g:, 'ai_python3_ready') == 2
    echom ""
    redraw
    return v:true
  endif

  if get(g:, 'ai_python3_ready') == 1
    echom ""
    redraw
    return v:false
  endif

  if !has("python3")
    let g:ai_python3_ready = 1
    echom "当前 vim 版本不支持 python3"
    redraw
    return v:false
  else
    py3 import vim
    py3 import llm.coding as coding

    py3 coding.llm_init(llm_type=vim.eval("g:nvim_ai_llm"),
                  \ api_key=vim.eval("g:nvim_ai_apikey"),
                  \ custom_api=vim.eval("g:nvim_ai_custom_api"),
                  \ stream=vim.eval("g:nvim_ai_stream"))
    let g:ai_python3_ready = 2
    call s:init_prompt_history()
    call s:init_error_log()
    echom ""
    redraw
    return v:true
  endif
endfunction

function! s:is_win()
  return has('win32') || has('win64')
endfunction

function! s:config_root()
  if s:is_win()
    return resolve($HOME.'/AppData/Local/nvim/nvim-ai-coding/')
  else
    return expand('~/.local/share/nvim/nvim-ai-coding/')
  endif
endfunction

function! s:history_file()
  return resolve(s:config_root() . '/history.txt')
endfunction

function! s:errlog_file()
  return resolve(s:config_root() . '/errlog.txt')
endfunction

function! nvim_ai#errlog_file()
  return s:errlog_file()
endfunction

function! s:init_prompt_history()
  let history_prompt_file = s:history_file()
  call s:create_dir(s:get_file_directory(history_prompt_file))
  if !s:file_exists(history_prompt_file)
    call writefile(["----- Prompt History ------"], history_prompt_file, "a")
  endif
endfunction

function! s:init_error_log()
  let errlog_file = s:errlog_file()
  call s:create_dir(s:get_file_directory(errlog_file))
  if !s:file_exists(errlog_file)
    call writefile(["----- Errlog ------"], errlog_file, "a")
  endif
endfunction

function! s:get_file_directory(filepath)
  let l:filedir = fnamemodify(a:filepath, ':h')
  return l:filedir
endfunction

function! s:recording_prompt(prompt)
  if g:nvim_ai_history_prompt == 0 | return | endif
  let current_prompt_list = nvim_ai#input#get_current_all_prompt()
  let contained = v:false

  for item in current_prompt_list
    if nvim_ai#remove_spaces(item) == nvim_ai#remove_spaces(a:prompt)
      let contained = v:true
      break
    endif
  endfor

  if contained == v:true
    return
  endif

  let history_prompt_file = s:history_file()
  let old_content = readfile(history_prompt_file, "", -1 * 500)
  let new_content = old_content + [a:prompt]
  call writefile(new_content, history_prompt_file, "S")
endfunction

function! nvim_ai#remove_spaces(input)
  let output = substitute(a:input, ' ', '', 'g')
  return output
endfunction

function! s:create_dir(dir)
  if !isdirectory(a:dir)
    let l:parent = fnamemodify(a:dir, ':h')
    call s:create_dir(l:parent)
    execute 'silent! !mkdir -p' a:dir
  endif
endfunction

function! s:get_prompt_modify(lines, question)
  if len(a:lines) != 0
    let prefix = [
          \ '你是一个代码生成器，你只会根据我的要求输出代码。这是一段' . &filetype . '代码: ',
          \ ' '
          \ ]
    let sufix = [
          \ ' ',
          \ '我的要求是：' . a:question . '',
          \ '根据上面的要求，请只输出一段' . &filetype . '代码，除了注释之外，不要输出其他内容，包括代码的解释说明',
          \ '再次强调一下，请不要输出代码片段之外的内容，而且不要以 Markdown 格式输出。不要输出"```"这类包裹代码块的字符。'
          \ ]
    let prompt = prefix + a:lines + sufix
    return prompt
  endif
endfunction

function! s:get_prompt_new(question)
  let prompt = [
        \ '你是一个代码生成器，你只会根据我的要求输出代码。',
        \ '我需要你帮我写一段' . &filetype . '代码，我的要求是：' . a:question . '',
        \ '根据上面的要求，请只输出一段' . &filetype . '代码，除了注释之外，不要输出其他内容，包括代码的解释说明',
        \ '再次强调一下，请不要输出代码片段之外的内容，而且不要以 Markdown 格式输出，不要输出"```"这类包裹代码块的字符。'
        \ ]
  return prompt
endfunction

function! s:InputCallback(old_text, new_text)
  let question = a:new_text
  call s:return_original_window()

  " 新输入
  if s:range == 0
    redraw
    if trim(question) == ""
      echom ""
      return
    endif
    if &filetype == ""
      let prompt = question
    else
      let prompt = s:get_prompt_new(question)
    endif
    echom "请等待 ChatGPT 的响应..."
    redraw

    if g:nvim_ai_stream == 1 && g:nvim_ai_llm == "api2d"
      py3 coding.just_do_it(vim.eval("prompt"))

    else
      py3 vim.command("let ret = %s"% coding.just_do_it(vim.eval("prompt")))
      if type(ret) == type("") && ret == ""
        return
      endif
      call nvim_ai#append(s:line1 + 1, ret)
      echom "done!"
    endif
    redraw
    call s:recording_prompt(question)

  " 原文修改
  elseif s:range == 2
    let l:lines = getline(s:line1, s:line2)
    redraw
    if trim(question) == ""
      echom ""
      redraw
      return
    endif
    let prompt = s:get_prompt_modify(l:lines, question)
    redraw
    echom "请等待 ChatGPT 的响应..."
    if g:nvim_ai_stream == 0
      py3 vim.command("let ret = %s"% coding.just_do_it(vim.eval("prompt")))
      if type(ret) == type("") && ret == "{timeout}"
        call s:handle_timeout()
        return
      endif
      call nvim_ai#delete_selected_lines()
      call nvim_ai#append(s:line1, ret)
      echom "done!"
    endif

    if g:nvim_ai_stream == 1
      py3 coding.just_do_it(vim.eval("prompt"))
    endif

    redraw
  endif

  let s:line1 = 0
  let s:line2 = 0
  let s:range = 0
endfunction

function! nvim_ai#delete_selected_lines()
  call deletebufline(s:bufnr, s:line1, s:line2)
endfunction

function! s:str2list(str)
  if type(a:str) ==# v:t_list
    return a:str
  endif
  let l:index = 0
  let l:arr = []
  while l:index < strlen(a:str)
    call add(l:arr, a:str[l:index])
    let l:index += 1
  endwhile
  return l:arr
endfunction

function! nvim_ai#init()
  py3 import llm.coding as coding
  py3 coding.import_deps_async()
endfunction

function! nvim_ai#run(line1, line2, range) range
  if !s:llm_check() | return | endif
  if &modifiable == 0 || &readonly == 1
    echom "当前 buffer 是只读的"
    return
  endif
  let s:line1 = a:line1
  let s:line2 = a:line2
  let s:range = a:range
  let s:bufnr = bufnr("")
  let g:nvim_ai_range = a:range
  call nvim_ai#input#pop("", function("s:InputCallback"))
  echom "等待 ChatGPT(" . g:nvim_ai_llm . ") 初始化..."
  redraw
  call s:prepare_python()
endfunction

function! s:llm_check()
  if g:nvim_ai_llm == ""
    echom "g:nvim_ai_llm 为空，请配置 llm 类型"
    redraw
    return v:false
  endif
  if g:nvim_ai_llm == "custom" && g:nvim_ai_custom_api == ""
    echom "custom api 为空，请配置 g:nvim_ai_custom_api"
    redraw
    return v:false
  endif
  if g:nvim_ai_llm == "apispace" && g:nvim_ai_apikey == ""
    echom "apispace token 为空，请配置 g:nvim_ai_apikey"
    redraw
    return v:false
  endif
  if g:nvim_ai_llm == "openai" && ( g:nvim_ai_apikey == "" && getenv("OPENAI_API_KEY") == v:null )
    echom "openai api key 为空，请配置 g:nvim_ai_apikey 或者 $OPENAI_API_KEY"
    redraw
    return v:false
  endif
  return v:true
endfunction

function! nvim_ai#append(start_line, lines)
  let cursor_line = a:start_line

  for line in a:lines
    if s:is_code_warpper(line)
      continue
    endif
    call appendbufline(bufnr(""), cursor_line - 1, line)
    let cursor_line = cursor_line + 1
    call cursor(cursor_line, 1)
    redraw
    sleep 60ms
  endfor
endfunction

function! nvim_ai#new_line()
  " 流式输出换行时判断是否为代码包裹所用的字符
  if s:is_code_warpper(getline(line(".")))
    call setbufline(bufnr(""), line("."), "")
  endif
  call s:nr()
  " redraw
endfunction

function! nvim_ai#stream_first_rendering()
  let g:nvim_ai_updatetime = &updatetime
  if !exists('g:treesitter_is_on')
    let g:treesitter_is_on = nvim_ai#treesitter_is_on()
  endif
  if g:treesitter_is_on
    call s:disable_treesitter()
  endif
  set synmaxcol=60
  set updatetime=100
  call s:return_original_window()
  if s:range == 2
    call nvim_ai#delete_selected_lines()
    call execute("normal O")
  endif

  if s:range == 0
    if trim(getline(line("."))) == ""
      call setbufline(s:bufnr, line("."), "")
      return
    else
      call s:nr()
      return
    endif
  endif
endfunction

function! s:treesitter_available()
  try
    call execute("TSConfigInfo")
  catch /^Vim\%((\a\+)\)\=:\(E492\)/
    return v:false
  endtry
  return v:true
endfunction

function! nvim_ai#treesitter_available()
  return s:treesitter_available()
endfunction

function! nvim_ai#treesitter_is_on()
  return v:lua.require("nvim_ai").treesitter_is_on()
endfunction

" TODO: 这里要记录 treesitter
" 的原始状态，根据原始状态来恢复，现在是简单粗暴的处理
function! s:disable_treesitter()
  if s:treesitter_available()
    call execute("TSDisable highlight")
  endif
endfunction

function! s:enable_treesitter()
  if s:treesitter_available()
    call execute("TSEnable highlight")
  endif
endfunction

function! s:return_original_window()
  let winid = bufwinid(s:bufnr)
  call nvim_ai#input#goto_window(winid)
endfunction

" new line
function! s:nr()
  call appendbufline(bufnr(""), line("."), "")
  call cursor(line(".") + 1, 1)
endfunction

function! nvim_ai#teardown()
  if s:is_code_warpper(getline(line(".")))
    call setbufline(bufnr(""), line("."), "")
  endif
  exec "set updatetime=" . string(g:nvim_ai_updatetime)
  if g:treesitter_is_on
    call s:enable_treesitter()
  endif
  exec "set synmaxcol=" . string(g:synmaxcol)
endfunction

function! nvim_ai#insert(chunk)
  let curr_line = getline(line("."))
  let curr_line = curr_line . a:chunk
  " setbufline 不会有渲染卡顿，用 setline 会有卡顿，原因未知
  call setbufline(bufnr(""), line("."), curr_line)
  redraw
endfunction

function! s:is_code_warpper(line)
  if a:line == "```" . &filetype || a:line == "```" || a:line =~ "^```[a-zA-Z0-9]\\{,15}$"
    return v:true
  endif
endfunction

function! nvim_ai#root()
  let plugin_root = substitute(expand('<sfile>'), "^\\(.\\+nvim-ai-coding\\)\\(.\\{\-}\\)$","\\1","g")
  let plugin_root = substitute(plugin_root, "^\\(.\\+script\\s\\)\\(.\\{\-}\\)$", "\\2", "g")
  return plugin_root
endfunction

function! s:file_exists(filepath)
  try
    let content = readfile(a:filepath, 1)
  catch /484/
    " File is not exists or can not open
    return v:false
  endtry
  return v:true
endfunction

function! nvim_ai#get_all_prompt()
  let prompt_file = globpath(nvim_ai#root(),"prompt.txt")
  if prompt_file == ""
    return []
  endif
  if g:nvim_ai_default_prompt == 1
    let all_prompt = readfile(prompt_file)
  else
    let all_prompt = []
  endif

  if type(g:nvim_ai_prompt) == type([])
    for item in g:nvim_ai_prompt
      if s:file_exists(item)
        call extend(all_prompt, readfile(item))
      endif
    endfor
  elseif type(g:nvim_ai_prompt) == type("")
    if s:file_exists(g:nvim_ai_prompt)
      call extend(all_prompt, readfile(g:nvim_ai_prompt))
    endif
  endif

  return all_prompt
endfunction

function! nvim_ai#get_history_prompt()
  let history_prompt = []
  if g:nvim_ai_history_prompt == 1
    let history_prompt_file = s:history_file()
    if s:file_exists(history_prompt_file)
      call extend(history_prompt, readfile(history_prompt_file))
    endif
  endif
  return history_prompt
endfunction

function! nvim_ai#test()
  call v:lua.require("nvim_ai").test()
endfunction

" vim:ts=2:sw=2:sts=2
