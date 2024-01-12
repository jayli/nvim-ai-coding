let g:chatbox = {}
let g:chatbox.log_bufinfo = 0
let g:chatbox.log_winid = 0
let g:chatbox.log_winnr = 0
let g:chatbox.log_bufnr = 0
let g:chatbox.input_bufnr = 0
let g:chatbox.input_winid = 0
let g:chatbox.input_winnr = 0

function! s:init()
  if !has('nvim')
    return
  endif
  let g:chatbox = {}
  let g:chatbox.original_winnr = winnr()
  let g:chatbox.original_bufinfo = getbufinfo(bufnr(''))
  let g:chatbox.original_winid = bufwinid(bufnr(""))
  let g:chatbox.init_msg = [
        \ "  ┄┄┄┄┄┄┄  Chatbox Window ┄┄┄┄┄┄┄",
        \ "┌────────────────────────────────────┐",
        \ "│ Use <C-C> to close chatbox window. │",
        \ "│ Authored by Jayli bachi@taobao.com │",
        \ "└────────────────────────────────────┘"]
  call s:flush()
  augroup chatbox_init
    autocmd!
    autocmd QuitPre * call nvim_ai#chatbox#quit()
  augroup END
endfunction

function! s:flush()
  let g:chatbox.log_bufinfo = 0
  let g:chatbox.log_winid = 0
  let g:chatbox.log_winnr = 0
  let g:chatbox.log_bufnr = 0
  let g:chatbox.log_winid = 0
  let g:chatbox.log_winnr = 0
  let g:chatbox.log_bufnr = 0
endfunction

function! s:is_terminal()
  let wininfo = getwininfo(bufwinid(bufnr("")))[0]
  if wininfo['terminal'] == 1 | return v:true | endif
  return v:false
endfunction

function! nvim_ai#chatbox#open()
  if !has('nvim')
    echom "仅支持 nvim"
    return
  endif
  if s:is_terminal()
    return
  endif
  call s:init()
  if s:chatbox_running()
    " do nothing
    return
  else
    call s:flush()
  endif
  call s:init_chatbox_window()
  call s:insert_chunk("asdfa")
  call s:goto_original_window()
endfunction

" chunk 是一个字符串类型或者数组类型
function! s:insert_chunk(chunk)
  call s:goto_log_window()
  let max_line = line('$')
  call cursor(line("$"), 1)
  let curr_line = getline(line("."))
  let curr_line = curr_line . a:chunk
  call setbufline(bufnr(""), line("."), curr_line)
  silent! redraw
endfunction

function! s:goto_log_bottom()
  call s:goto_log_window()
  let max_line = line('$')
  call cursor(line("$"), 1)
  call s:goto_original_window()
endfunction

" str 是字符串
function! s:insert(str)
  call s:goto_log_window()
  let curr_line = getline(line("."))
  let curr_line = curr_line . a:str
  call setbufline(bufnr(""), line("."), curr_line)
endfunction

function! s:nr()
  call s:goto_log_window()
  call appendbufline(bufnr(""), line("."), "")
  call cursor(line(".") + 1, 1)
endfunction

function! s:goto_original_window()
  call s:goto_window(g:chatbox.original_winid)
endfunction

function! s:goto_log_window()
  call s:goto_window(g:chatbox.log_winid)
endfunction

function! s:goto_input_window()
  call s:goto_window(g:chatbox.input_winid)
endfunction

function! s:goto_window(winid) abort
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

function! s:init_chatbox_window()
  if s:chatbox_running()
    return
  endif
  if g:chatbox.original_winid != bufwinid(bufnr(""))
    return
  endif
  echom "init new chatbox window"
  let g:chatbox.original_bufinfo = getbufinfo(bufnr(''))
  let g:chatbox.original_winid = bufwinid(bufnr(""))

  " ---------------- 创建 input 窗口 ----------------
  vertical botright new
  setlocal nonu
  setlocal signcolumn=no
  setlocal filetype=none
  setlocal buftype=nofile
  setlocal wrap
  setlocal nocursorline
  exec 'setl statusline=%1*\ Input\ Prompt\ %*\ %r%=Depth\ :\ %L\ '
  let g:chatbox.input_winnr = winnr()
  let g:chatbox.input_bufnr = bufnr("")
  let g:chatbox.input_winid = bufwinid(bufnr(""))
  inoremap <buffer><expr> <CR> nvim_ai#chatbox#request()

  " ---------------- 创建 log 窗口 ----------------
  split new
  setlocal buftype=nofile
  setlocal filetype=nofile
  setlocal signcolumn=no
  setlocal nocursorline
  setlocal wrap
  setlocal nonu
  let stitle = ""
  exec 'setl statusline=' . stitle . "" . repeat("—", winwidth(0) - strdisplaywidth(stitle))
  hi StatusLine guibg=NONE guifg=#666666
  hi StatusLineNC guibg=NONE guifg=#666666
  let g:chatbox.log_winnr = winnr()
  let g:chatbox.log_bufnr = bufnr("")
  let g:chatbox.log_winid = bufwinid(bufnr(""))

  " ---------------- 初始化input窗口大小 ----------------
  call s:goto_input_window()
  resize 2
  call s:goto_original_window()
  return

  call s:append_msg(copy(get(g:chatbox, 'init_msg')))
  call s:GotoOriginalWindow()
endfunction

function! nvim_ai#chatbox#request()
  call feedkeys("\<ESC>", "i")
  call timer_start(20, { -> s:insert_chunk('iii') })
  return ""
endfunction

function! s:chatbox_running()
  let window_status = g:chatbox.log_winid == 0 ? v:false : v:true
  return window_status
endfunction

function! nvim_ai#chatbox#quit()

endfunction
