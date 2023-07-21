" NVIM_AI
if !has('nvim')
  finish
endif

if !has('python3')
  finish
endif

command! -nargs=* -range -bang NvimAICoding call nvim_ai#run(<line1>, <line2>, <range>)

xnoremap <Plug>AICoding :NvimAICoding<CR>
nnoremap <Plug>AICoding :NvimAICoding<CR>

nmap co <Plug>AICoding
xmap co <Plug>AICoding

if has('vim_starting')
  augroup nvim_ai_start 
    autocmd!
    autocmd BufReadPost,BufNewFile * call nvim_ai#init()
  augroup END
endif

" 这个也不能保证100%好使
setlocal autowriteall

" openai, apispace, api2d, custom
if !exists("g:nvim_ai_llm")
  let g:nvim_ai_llm = ""
endif

if !exists("g:nvim_ai_prompt")
  let g:nvim_ai_prompt = []
endif

if !exists("g:nvim_ai_default_prompt")
  let g:nvim_ai_default_prompt = 1
endif

if !exists("g:nvim_ai_apikey")
  let g:nvim_ai_apikey = ""
endif

if !exists("g:nvim_ai_custom_api")
  let g:nvim_ai_custom_api = ""
endif

if !exists("g:nvim_ai_model")
  let g:nvim_ai_model = "gpt-3.5-turbo-0613"
endif

if !exists("g:nvim_ai_history_prompt")
  let g:nvim_ai_history_prompt = 1
endif

" api2d 默认用流式输出
if g:nvim_ai_llm == "api2d" && !exists("g:nvim_ai_stream")
  let g:nvim_ai_stream = 1
endif

if !exists("g:nvim_ai_stream")
  let g:nvim_ai_stream = 0
endif


" vim:ts=2:sw=2:sts=2
