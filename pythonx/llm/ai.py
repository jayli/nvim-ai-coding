#!/usr/bin/env python3
# encoding: utf-8
from .langchan_llm import CustomLLM
from .langchan_llm import OpenAI

# 全局llm
llm = None

# 默认都不支持流式输出，目前只实现了 api2d 的流式输出
stream_output = False

def llm_init(llm_type="", api_key="", custom_api="", stream=0):
    global llm, stream_output

    if stream == "1":
        stream_output = True
    else:
        stream_output = False

    if llm_type == "openai":
        open_api_key = os.getenv('OPENAI_API_KEY') or safe_vim_eval('g:nvim_ai_apikey')
        if open_api_key == "":
            print("OpenAI APIKEY 未定义，请定义 OPENAI_API_KEY")
            return
        llm = OpenAI(openai_api_key=open_api_key, temperature=0.9)
    else:
        llm = CustomLLM(llm_type=llm_type,
                        api_key=api_key,
                        custom_api=custom_api,
                        stream_output=stream_output)

def llm_request(prompt, llm):
    prompts = "\n".join(prompt)
    result = llm(prompts)
    if result == "{error}" or result == "{timeout}":
        return result

    results = result.split("\n")
    return_str = str(results).replace("\\'", "''")
    return return_str

# 调用入口
def just_do_it(prompt):
    global llm
    result = llm_request(prompt, llm)
    if result == "{timeout}" or result == "{error}":
        return '""'
    else:
        return result

if __name__ == '__main__':
    llm_init(llm_type="api2d", api_key="fk209055-QCO1ChYkdCcPi1OnTWss7UlAjifaQ5RU", stream="1")
    print(just_do_it("基于 python 写一段代码，实现一个 helloworld"))

# vim:ts=4:sw=4:sts=4
