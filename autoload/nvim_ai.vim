let s:line1 = 0
let s:line2 = 0
let s:range = 0
" 临时变量，给 python 用的
let g:nvim_ai_range = 0

function! s:prepare_python()
  if get(g:, 'ai_python3_ready') == 2
    return v:true
  endif

  if get(g:, 'ai_python3_ready') == 1
    return v:false
  endif

  if !has("python3")
    let g:ai_python3_ready = 1
    return v:false
  else
    py3 import vim
    py3 import llm.ai as ai

    py3 ai.llm_init(llm_type=vim.eval("g:nvim_ai_llm"),
                  \ api_key=vim.eval("g:nvim_ai_apikey"),
                  \ custom_api=vim.eval("g:nvim_ai_custom_api"),
                  \ stream=vim.eval("g:nvim_ai_stream"))
    let g:ai_python3_ready = 2
    return v:true
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

  " 新输入
  if s:range == 0
    redraw
    if trim(question) == ""
      echom ""
      return
    endif
    let prompt = s:get_prompt_new(question)
    redraw
    echom "请等待 ChatGPT 的响应..."
    if g:nvim_ai_stream == 0
      py3 vim.command("let ret = %s"% ai.just_do_it(vim.eval("prompt")))
      if type(ret) == type("") && ret == ""
        return
      endif
      call nvim_ai#append(s:line1 + 1, ret)
      echom "done!"
    endif

    if g:nvim_ai_stream == 1
      py3 ai.just_do_it(vim.eval("prompt"))
    endif

    redraw

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
      py3 vim.command("let ret = %s"% ai.just_do_it(vim.eval("prompt")))
      if type(ret) == type("") && ret == "{timeout}"
        call s:handle_timeout()
        return
      endif
      call nvim_ai#delete_selected_lines()
      call nvim_ai#append(s:line1, ret)
      echom "done!"
    endif

    if g:nvim_ai_stream == 1
      py3 ai.just_do_it(vim.eval("prompt"))
    endif

    redraw
  endif

  let s:line1 = 0
  let s:line2 = 0
  let s:range = 0
endfunction

function! nvim_ai#delete_selected_lines()
  call deletebufline(bufnr(""), s:line1, s:line2)
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

function! nvim_ai#run(line1, line2, range) range
  if !s:llm_check() | return | endif
  let s:line1 = a:line1
  let s:line2 = a:line2
  let s:range = a:range
  let g:nvim_ai_range = a:range
  call nvim_ai#input#pop("", function("s:InputCallback"))
  redraw
  echom "等待 ChatGPT(" . g:nvim_ai_llm . ") 初始化..."
  call s:prepare_python()
  return
endfunction

function! s:llm_check()
  if g:nvim_ai_llm == ""
    redraw
    echom "g:nvim_ai_llm 为空，请配置 llm 类型"
    return v:false
  endif
  if g:nvim_ai_llm == "custom" && g:nvim_ai_custom_api == ""
    redraw
    echom "custom api 为空，请配置 g:nvim_ai_custom_api"
    return v:false
  endif
  if g:nvim_ai_llm == "apispace" && g:nvim_ai_apikey == ""
    redraw
    echom "apispace token 为空，请配置 g:nvim_ai_apikey"
    return v:false
  endif
  if g:nvim_ai_llm == "openai" && g:nvim_ai_apikey == ""
    redraw
    echom "openai api key 为空，请配置 g:nvim_ai_apikey"
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
    redraw
    sleep 60ms
  endfor
endfunction

function! nvim_ai#new_line()
  " 流式输出换行时判断是否为代码包裹所用的字符
  if s:is_code_warpper(getline(line(".")))
    call setbufline(bufnr(""), line("."), "")
  endif
  call appendbufline(bufnr(""), line("."), "")
  call cursor(line(".") + 1, 1)
  redraw
endfunction

function! nvim_ai#teardown()
  if s:is_code_warpper(getline(line(".")))
    call setbufline(bufnr(""), line("."), "")
  endif
endfunction

function! nvim_ai#insert(chunk)
  let curr_line = getline(line("."))
  let curr_line = curr_line . a:chunk
  call setline(line("."), curr_line)
  redraw
endfunction

function! s:is_code_warpper(line)
  if a:line == "```" . &filetype || a:line == "```" || a:line =~ "^```[a-zA-Z0-9]\\{,15}$"
    return v:true
  endif
endfunction

function! nvim_ai#root()
  let ret_path = ""
  for es_path in split(&rtp, ",")
    if stridx(es_path, "nvim-ai-coding") >= 0
      let ret_path = es_path
      break
    endif
  endfor
  return ret_path
endfunction

function! s:file_exists(filepath)
  if globpath(a:filepath, "") == ""
    return v:false
  else
    return v:true
  endif
endfunction

function! nvim_ai#get_all_prompt()
  let prompt_file = globpath(nvim_ai#root(),"prompt.txt")
  if g:nvim_ai_default_prompt == 1
    let all_prompt = readfile(prompt_file)
  else
    let all_prompt = []
  endif

  if type(g:nvim_ai_prompt) == type([])
    for item in g:nvim_ai_prompt
      if s:file_exists(item)
        call add(all_prompt, readfile(item))
      endif
    endfor
  elseif type(g:nvim_ai_prompt) == type("")
    if s:file_exists(g:nvim_ai_prompt)
      call add(all_prompt, readfile(g:nvim_ai_prompt))
    endif
  endif
  return all_prompt
endfunction


" vim:ts=2:sw=2:sts=2
