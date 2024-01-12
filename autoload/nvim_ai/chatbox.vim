let g:chatbox.log_bufinfo = 0
let g:chatbox.log_winid = 0
let g:chatbox.log_winnr = 0
let g:chatbox.log_bufnr = 0
let g:chatbox.log_term_winid = 0
let g:chatbox.status = 'stop'

function! nvim_ai#chatbox#init()
  if exists("g:chatbox")
    return
  endif
  if s:is_terminal()
    return
  endif
  let g:chatbox = {}
  let g:chatbox.logfile = 0
  let g:chatbox.status = 'stop'
  let g:chatbox.original_winnr = winnr()
  let g:chatbox.original_bufinfo = getbufinfo(bufnr(''))
  let g:chatbox.original_winid = bufwinid(bufnr(""))
  let g:chatbox.init_msg = [
        \ "  ┄┄┄┄┄┄┄  Log Window ┄┄┄┄┄┄┄",
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


function! s:is_terminal()
  let wininfo = getwininfo(bufwinid(bufnr("")))[0]
  if wininfo['terminal'] == 1 | return v:true | endif
  return v:false
endfunction

function! nvim_ai#chatbox#open()


endfunction

function! nvim_ai#chatbox#quit()

endfunction
