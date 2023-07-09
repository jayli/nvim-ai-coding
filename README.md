# ![nvim-ai-coding](https://github.com/jayli/nvim-ai-coding/assets/188244/88a28ce3-3240-4793-9637-ef046eaf269a)

基于 chatgpt 写代码的 nvim 插件

https://github.com/jayli/nvim-ai-coding/assets/188244/337f0f5c-78b5-4ea1-a276-2868b12562f7

## 一）安装：

### 1. 安装插件

基于 vim-plug 安装， 在 `~/.vimrc` 中添加：

```vim
Plug 'jayli/nvim-ai-coding'

" 快捷键绑定：你可以将 co 改成你的快捷键
nmap co <Plug>AICoding
xmap co <Plug>AICoding
```

然后执行`:PlugInstall`

### 2. 安装 python 依赖

本地 python 3.9 及以上版本，打开命令行执行

```shell
pip install requests langchain openai
```

或者在插件跟目录下执行:

```shell
pip install -r requirements.txt
```

### 3. 配置 API 类型和 api key

默认支持四类 API，根据你的需要四选一：

- OpenAI
- APISpace
- API2D
- 自定义 API

**1) OpenAI API key：**

```vim
let g:nvim_ai_llm = 'openai'
let g:nvim_ai_apikey = 'xxxx'
```

**2) APISpace API：**

```vim
let g:nvim_ai_llm = "apispace"
let g:nvim_ai_apikey = "xxx"
```

**3) API2D**

```vim
let g:nvim_ai_llm = 'api2d'
let g:nvim_ai_apikey = 'xxx'

" 流式输出
let g:nvim_ai_stream = 1
" 大模型配置
let g:nvim_ai_model = "gpt-4"
```

目前只有 API2D 实现了流式输出支持，配置`g:nvim_ai_stream = 1`，不配置的话默认非流式输出。

`g:nvim_ai_model`如果不配置则默认为`gpt-3.5-turbo-0613`，参考值可以配置`gpt-3.5-turbo`或者`gpt-4`。

**4) 自定义 API：**

```vim
let g:nvim_ai_llm = 'custom'
let g:nvim_ai_custom_api = 'http://127.0.0.1:8000'
```

确保自定义接口符合如下格式：接口提交格式 POST：

```json
{"prompt": "你是基于什么大模型回答问题", "history": []}
```

接口返回格式：

```json
{"response": "我是基于gpt4来回答你的问题。"}
```

## 二）使用

- 生成模式：Normal 模式下 `co` 唤起输入窗，回车后发送问题并返回结果，`<ESC>` 关闭输入窗。
- 修改模式：选中一段代码，`co` 唤起输入窗，输入指令后，则将针对你选中的代码根据你的指令进行返回。

插件内置了一个简单的 prompt 样板，如果你要新增 prompt，插件可以模糊匹配出你常用的 prompt，这样配置：

```
let g:nvim_ai_prompt = ["/file/path/to/your/prompt.txt", "/another/prompt.txt"]
```

也可以直接给一个字符串：

```
let g:nvim_ai_prompt = "/file/path/to/your/prompt.txt"
```

如果不想加载默认的 prompt 来避免干扰，你可以这样关掉：

```
let g:nvim_ai_default_prompt = 0
```

插件会默认自动记录你的 prompt 历史，可以配置`g:nvim_ai_history_prompt = 0`来关闭历史记录。prompt 历史位于 `~/.local/share/nvim/nvim-ai-coding/history.txt`。

## 三）LICENSE

MIT
