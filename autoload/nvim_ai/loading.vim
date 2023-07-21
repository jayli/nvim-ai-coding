let g:nvim_ai_loading_timer = -1
let g:nvim_ai_loading_status = -1
let g:nvim_ai_loading_job = -1
let g:nvim_ai_loading_chars = ['⋮','⋰','⋯','⋱']

" ----------------------------------------------{{
"  TODO 实现一个在 py3 import 的时候的 loading 效果
function! nvim_ai#loading#start(msg)
  let g:nvim_ai_loading_status = 0
  call call("s:Loading", [a:msg])
endfunction

function! s:Loading(msg)
  let msg = a:msg
  if g:nvim_ai_loading_status >= 0
    "------------render------------------
    echo "" . g:nvim_ai_loading_chars[g:nvim_ai_loading_status] . " " . msg
    " call v:lua.require("nvim_ai").print("" . g:nvim_ai_loading_chars[g:nvim_ai_loading_status] . " " . msg)
    let g:nvim_ai_loading_status += 1
    let g:nvim_ai_loading_status = g:nvim_ai_loading_status % len(g:nvim_ai_loading_chars)
    redraw
    "------------timer------------------
    call timer_stop(g:nvim_ai_loading_timer)
    let g:nvim_ai_loading_timer = timer_start(80, {
          \ -> call(function("s:Loading"), [msg])
          \ })
  else
    call timer_stop(g:nvim_ai_loading_timer)
    let g:nvim_ai_loading_timer = -1
  endif
endfunction

function! nvim_ai#loading#done()
  if !exists("g:nvim_ai_loading_status")
    let g:nvim_ai_loading_status = -1
  endif
  let g:nvim_ai_loading_status = -1
  call timer_stop(g:nvim_ai_loading_timer)
  let g:nvim_ai_loading_timer = -1
  call jobstop(g:nvim_ai_loading_job)
  let g:nvim_ai_loading_job = -1
  " call v:lua.require("nvim_ai").print("")
  echo ""
  redraw
endfunction
" ------------------------------------------}}
