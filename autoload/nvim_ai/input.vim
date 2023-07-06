let s:input_winid = 0
let s:input_buf = 0
let s:input_width = 68
let s:input_height = 4
let b:Callbag = v:null
let s:old_text = ""
let s:input_title = "What do you want?"
let s:current_winid = 0
let s:text_winid = 0 " for nvim only
let s:prompt_list = nvim_ai#get_all_prompt()
let s:global_menu = []
let g:async_timer = -1

function! s:input_callback(...)
  call s:flush()
endfunction

function! s:reset_buf(buf)
  let buf = a:buf
  call setbufvar(buf, '&signcolumn', 'no')
  call setbufvar(buf, '&filetype', 'none')
  call setbufvar(buf, '&buftype', "nofile")
  call setbufvar(buf, '&modifiable', 1)
  call setbufvar(buf, '&buflisted', 0)
  call setbufvar(buf, '&swapfile', 0)
  call setbufvar(buf, '&undolevels', -1)
  call setbufvar(buf, 'easycomplete_enable', 0)
endfunction

function! s:create_nvim_input_window(old_text, callback) abort
  let width = s:input_width
  let height = s:input_height
  let screen_pos_row= (win_screenpos(win_getid())[0] - 1)
  let screen_pos_col = (win_screenpos(win_getid())[1] - 1)
  let s:current_winid = win_getid()
  if winline() == winheight(win_getid()) - 1 - (s:input_height - 3)
    let bdr_row_offset = -2
    let txt_row_offset = 0
  elseif winline() == winheight(win_getid()) - (s:input_height - 3)
    let bdr_row_offset = 0
    let txt_row_offset = 0
    let screen_pos_row -= (2 + (s:input_height - 3))
  elseif winline() == winheight(win_getid())
    let bdr_row_offset = 0
    let txt_row_offset = 0
    let screen_pos_row -= (2 + (s:input_height - 3))
  else
    let bdr_row_offset = 0
    let txt_row_offset = 0
  endif
  if wincol() + width > winwidth(win_getid())
    let bdr_col_offset = -1 * (wincol() + width - winwidth(win_getid()))
    let txt_col_offset = 0
  else
    let bdr_col_offset = 0
    let txt_col_offset = 0
  endif
  let opts = {
    \ 'relative':  'editor',
    \ 'row':       screen_pos_row + winline() + bdr_row_offset,
    \ 'col':       screen_pos_col + wincol() + bdr_col_offset,
    \ 'width':     width,
    \ 'height':    height,
    \ 'style':     'minimal',
    \ 'focusable': v:false
    \ }

  let title = s:input_title
  let top = "┌─" . title . repeat("─", width - strlen(title) - 3) . "┐"
  let mid = "│" . repeat(" ", width - 2) . "│"
  let bot = "└" . repeat("─", width - 2) . "┘"

  let lines = [top] + repeat([mid], height - 2) + [bot]
  let border_bufnr = nvim_create_buf(v:false, v:true)
  call nvim_buf_set_lines(border_bufnr, 0, -1, v:true, lines)
  let s:border_winid = nvim_open_win(border_bufnr, v:true, opts)
  let border_window_pos = nvim_win_get_position(s:border_winid)

  let opts.row += (1 + txt_row_offset)
  let opts.height -= 2
  let opts.col += (2 + txt_col_offset)
  let opts.width -= 4
  let opts.focusable = v:true

  let text_bufnr = nvim_create_buf(v:false, v:true)
  call s:reset_buf(text_bufnr)
  let text_winid = nvim_open_win(text_bufnr, v:true, opts)
  call setwinvar(s:border_winid, '&winhl', "Normal:Question")
  call setwinvar(text_winid,     '&winhl', "Normal:Normal")
  call setwinvar(s:border_winid, '&list', 0)
  call setwinvar(s:border_winid, '&number', 0)
  call setwinvar(s:border_winid, '&relativenumber', 0)
  call setwinvar(s:border_winid, '&cursorcolumn', 0)
  call setwinvar(s:border_winid, '&colorcolumn', 0)
  call setwinvar(s:border_winid, '&wrap', 1)
  let s:text_winid = text_winid
  au WinClosed * ++once :q | call nvim_ai#input#teardown()
  call nvim_ai#input#exec(text_winid, [
        \ 'setlocal wrap',
        \ 'setlocal completeopt+=menuone',
        \ 'setlocal completeopt-=menu',
        \ 'setlocal completeopt+=noinsert',
        \ 'setlocal completeopt+=noselect',
        \ 'setlocal completeopt-=longest',
        \ 'inoremap <buffer><expr> <CR> nvim_ai#input#handle_cr()',
        \ 'inoremap <buffer><expr> <ESC> nvim_ai#input#handle_esc()',
        \ 'inoremap <buffer><silent><expr> <Tab> nvim_ai#input#clever_tab()',
        \ 'inoremap <silent><expr> <S-Tab> nvim_ai#input#shift_clever_tab()',
        \ 'autocmd TextChangedI <buffer> call nvim_ai#input#fuzzy_match()',
        \ 'autocmd TextChangedP <buffer> call nvim_ai#input#fuzzy_match()',
        \ ])
  call nvim_ai#input#exec(text_winid, [
        \ 'call feedkeys("i","n")'
        \ ])
  return [text_bufnr, text_winid]
endfunction

function! nvim_ai#input#clever_tab()
  if pumvisible()
    return "\<Down>"
  endif
  return "\<Tab>"
endfunction

function! nvim_ai#input#shift_clever_tab()
  if pumvisible()
    return "\<Up>"
  endif
  return "\<S-Tab>"
endfunction

function! nvim_ai#input#fuzzy_match()
  if len(s:global_menu) > 0
    call complete(1, s:global_menu)
  endif
  call s:async_run(function("s:fuzzy_match"), [], 70)
endfunction

function! s:fuzzy_match()
  let current_line = s:get_current_line()
  if len(current_line) == 0
    call s:close_menu()
    return
  endif
  let menu_list = []
  for item in s:prompt_list
    if matchstr(trim(item), "^\-*") != "" | continue | endif
    if trim(item) == "" | continue | endif
    if s:fuzzy_search(current_line, item)
      call add(menu_list, item)
    endif
  endfor

  if len(menu_list) == 0
    call s:close_menu()
  else
    call complete(1, menu_list)
    call s:menu_cache(menu_list)
  endif
endfunction

function! s:get_current_line()
  let current_line = trim(getbufline(bufnr(""), line("."))[0])
  return current_line
endfunction

function! s:menu_cache(menu_list)
  let s:global_menu = a:menu_list
endfunction

function! s:menu_clear()
  let s:global_menu = []
endfunction

function! s:async_run(...)
  let Method = a:1
  let args = exists('a:2') ? a:2 : []
  let delay = exists('a:3') ? a:3 : 0
  if g:async_timer > 0
    call timer_stop(g:async_timer)
  endif
  let g:async_timer = timer_start(delay, { -> nvim_ai#input#call(Method, args)})
  return g:async_timer
endfunction

function! s:close_menu()
  " 关闭menu
  if pumvisible()
    silent! noa call feedkeys("\<C-X>\<C-Y>", "in")
    " silent! noa call feedkeys("a", "n")
    call s:menu_clear()
  endif
endfunction

" 判断 pum 是否是选中状态
function! s:complete_selected()
  if !pumvisible()
    return v:false
  endif
  return complete_info()['selected'] == -1 ? v:false : v:true
endfunction

function! s:fuzzy_search(needle, haystack)
  let tlen = strlen(a:haystack)
  let qlen = strlen(a:needle)
  if qlen > tlen
    return v:false
  endif
  if qlen == tlen
    return a:needle ==? a:haystack ? v:true : v:false
  endif

  let needle_ls = s:str2list(tolower(a:needle))
  let haystack_ls = s:str2list(tolower(a:haystack))

  let cursor_n = 0
  let cursor_h = 0
  let matched = v:false

  while cursor_h < len(haystack_ls)
    if haystack_ls[cursor_h] == needle_ls[cursor_n]
      if cursor_n == len(needle_ls) - 1
        let matched = v:true
        break
      endif
      let cursor_n += 1
    endif
    let cursor_h += 1
  endwhile
  return matched
endfunction

function! s:str2list(expr)
  if exists("*str2list")
    return str2list(a:expr)
  endif
  if type(a:expr) ==# v:t_list
    return a:expr
  endif
  let l:index = 0
  let l:arr = []
  while l:index < strlen(a:expr)
    call add(l:arr, char2nr(a:expr[l:index]))
    let l:index += 1
  endwhile
  return l:arr
endfunction

function! nvim_ai#input#teardown()
  call nvim_win_close(s:border_winid, v:true)
endfunction


function! nvim_ai#input#handle_cr()
  if s:complete_selected()
    call timer_start(100, { -> s:close_menu() })
    return "\<cr>"
  endif

  let new_text_line = get(getbufline(s:input_buf, 1, 1), 0, "")
  if empty(new_text_line) || empty(trim(new_text_line))
    call s:close()
    call timer_start(20, { -> s:log("Your input is empty.") })
    return ""
  endif
  let new_text = trim(new_text_line)
  let Callbag = b:Callbag
  let old_text = s:old_text
  call s:close()
  call timer_start(60, { -> nvim_ai#input#call(Callbag, [old_text, new_text]) })
  return ""
endfunction

function! nvim_ai#input#handle_esc()
  call s:close()
  call timer_start(20, { -> nvim_ai#input#goto_window(s:current_winid) })
  return ""
endfunction

function! s:close()
  if s:input_winid
    call nvim_ai#input#exec(s:input_winid, [
          \ "silent noa call feedkeys('\<C-C>')",
          \ "silent noa call feedkeys(':silent! close!\<CR>', 'n')",
          \ ])
    let s:input_winid = 0
  endif
endfunction

function! s:flush()
  call s:close()
  let s:input_winid = 0
  let s:input_buf = 0
  let s:old_text = ""
  let b:Callbag = v:null
endfunction

function! nvim_ai#input#pop(old_text, callbag)
  let input_obj = s:create_nvim_input_window(a:old_text, a:callbag)
  let s:input_winid = input_obj[1]
  let s:input_buf = input_obj[0]
  let b:Callbag = a:callbag
  let s:old_text = a:old_text
endfunction

function! s:log(str)
  echom a:str
endfunction

function! nvim_ai#input#exec(winid, command, ...) abort
  if exists('*win_execute')
    if type(a:command) == v:t_string
      keepalt call win_execute(a:winid, a:command, get(a:, 1, ''))
    elseif type(a:command) == v:t_list
      keepalt call win_execute(a:winid, join(a:command, "\n"), get(a:, 1, ''))
    endif
  elseif has('nvim')
    if !nvim_win_is_valid(a:winid)
      return
    endif
    let curr = nvim_get_current_win()
    noa keepalt call nvim_set_current_win(a:winid)
    if type(a:command) == v:t_string
      exe get(a:, 1, '').' '.a:command
    elseif type(a:command) == v:t_list
      for cmd in a:command
        exe get(a:, 1, '').' '.cmd
      endfor
    endif
    noa keepalt call nvim_set_current_win(curr)
  else
    echom "Your VIM version is old. Please update your vim"
  endif
endfunction

function! nvim_ai#input#call(method, args) abort
  try
    if type(a:method) == 2 " 是函数
      let TmpCallback = function(a:method, a:args)
      call TmpCallback()
    endif
    if type(a:method) == type("string") " 是字符串
      call call(a:method, a:args)
    endif
    let g:async_timer = -1
  catch /.*/
    return 0
  endtry
endfunction

function! nvim_ai#input#goto_window(winid) abort
  if a:winid == bufwinid(bufnr(""))
    return
  endif
  for window in range(1, winnr('$'))
    call s:goto_winnr(window)
    if a:winid == bufwinid(bufnr(""))
      break
    endif
  endfor
endfunction

function! s:goto_winnr(winnr) abort
  let cmd = type(a:winnr) == type(0) ? a:winnr . 'wincmd w'
        \ : 'wincmd ' . a:winnr
  noautocmd execute cmd
  call execute('redraw','silent!')
endfunction

" vim:ts=2:sw=2:sts=2
