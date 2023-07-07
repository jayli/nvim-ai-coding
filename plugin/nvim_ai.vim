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

" 这个也不能保证100%好使
setlocal autowriteall

" openai, apispace, custom
if !exists("g:nvim_ai_llm")
  let g:nvim_ai_llm = "openai"
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

if !exists("g:nvim_ai_stream")
  let g:nvim_ai_stream = 0
endif

if !exists("g:nvim_ai_model")
  let g:nvim_ai_model = "gpt-3.5-turbo-0613"
endif

" vim:ts=2:sw=2:sts=2
