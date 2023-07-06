#!/usr/bin/env python3
# encoding: utf-8
import json
from typing import Any, List, Dict, Mapping, Optional
from langchain.llms.base import LLM
from langchain.llms import OpenAI
import threading
import requests
import time
# https://github.com/roxma/nvim-ascript/blob/abc89587d6d6c83eb28d62669f0111bb77c00d07/autoload/ascript.vim#L32
import vim

# 全局llm
llm = None

# 是否支持流式输出
stream_output = False

def command_handler(script):
    global nvim

    if script == "[DONE]":
        vim.command("echom '[DONE]'")
    elif script.startswith("\n"):
        count = script.count("\n")
        for i in range(count):
            vim.command("normal! o")

        vim.command("redraw")
    else:
        vim.command("call nvim_ai#insert('" + script + "')")

class CustomLLM(LLM):
    logging: bool = False
    output_keys: List[str] = ["output"]
    custom_api: str = ""
    api_key: str = ""
    stream_output: bool = False
    timeout: int = 13

    # 支持 openai, apispace, api2d, custom
    llm_type: str = "apispace"

    @property
    def _llm_type(self) -> str:
        return self.llm_type

    def log(self, log_str):
        if self.logging:
            print(log_str)
        else:
            return

    def _call(
        self,
        prompt: str,
        stop: Optional[List[str]] = None,
        run_manager: any = None,
    ) -> str:

        self.log('----------' + self._llm_type + '----------> llm._call()')
        self.log(prompt)

        # custom llm
        if self._llm_type == "custom":
            payload = {
                "prompt": prompt,
                "temperature":0,
                "history": []
            }
            headers = {
                "Content-Type":"application/json"
            }
            try:
                response = requests.request("POST", self.custom_api, data=json.dumps(payload),
                                            headers=headers, timeout=self.timeout)
            except requests.exceptions.Timeout as e:
                vim.command("echom '调用超时'")
                return '{timeout}'

            self.log('<--------custom---------')
            self.log(json.loads(response.text)["response"])
            return json.loads(response.text)["response"]

        # apispace
        elif self._llm_type == "apispace":
            url = "https://eolink.o.apispace.com/ai-chatgpt/create"
            payload = {
                    "system":"你是一个代码生成器，你只会根据我的要求输出代码",
                    "message":["user:" + prompt],
                    "temperature":"0"
                }

            headers = {
                "X-APISpace-Token":self.api_key,
                "Authorization-Type":"apikey",
                "Content-Type":"application/json"
            }
            try:
                response = requests.request("POST", url, data=json.dumps(payload),
                                            headers=headers, timeout=self.timeout)
            except requests.exceptions.Timeout as e:
                vim.command("echom '调用超时'")
                return '{timeout}'

            result = json.loads(response.text)
            if "status" in result and result["status"] == "error":
                vim.command('echom \'' + result["msg"] + '\'')
                return "{error}"
            else:
                self.log('<--------apispace---------')
                self.log(result["result"])
                return result["result"]

        elif self._llm_type == "api2d":
            url = "https://oa.api2d.net/v1/chat/completions"
            payload = {
                    "model": "gpt-3.5-turbo-0613",
                    "messages": [
                        {
                            "role": "user",
                            "content": prompt
                        }
                    ],
                    "safe_mode": False
                    }

            headers = {
                'Authorization': "Bearer " + self.api_key,
                'Content-Type': 'application/json'
            }

            # 非流式输出
            if self.stream_output == False:
                # jayli
                try:
                    response = requests.request("POST", url, data=json.dumps(payload),
                                                headers=headers, timeout=self.timeout)
                except requests.exceptions.Timeout as e:
                    vim.command("echom '调用超时'")
                    return '{timeout}'

                result = json.loads(response.text)
                if "object" in result and result["object"] == "error":
                    vim.command('echom "' + result["message"] + '"')
                    return "{error}"
                else:
                    return result['choices'][0]["message"]["content"]

            # 流式输出
            else:
                url = "http://localhost:7001/test/chatgpt"
                payload["stream"] = "true"
                response = requests.request("POST", url, data=json.dumps(payload), headers=headers, stream=True)
                chunk_chars = ""
                try:
                    if vim.eval("g:nvim_ai_range") == "2":
                        vim.command("call nvim_ai#delete_selected_lines()")
                        
                    print('>>>>>>>>>>>>>>')
                    print(response.text)
                    print('>>>>>>>>>>>>>>')
                    for chunk in response.iter_content(chunk_size=500):
                        chunk_chars = self.get_chars_from_chunk(chunk)
                        print('--------')
                        print(chunk_chars)

                        if chunk_chars == "[DONE]":
                            vim.command("echom '[DONE]'")
                            return ""
                        else:
                            letters = chunk_chars.replace("\\'", "''")
                            command_handler(letters)
                    print("all done")
                except KeyboardInterrupt:
                    print('Interrupted')

                return ""

        # openai
        elif self._llm_type == "openai":
            api_key = self.api_key
            pass

    def parse_chunk_from_api2d(self, text):
        prefix = "data: "
        output = text
        if text.startswith(prefix):
            output = text[len(prefix):]
        return output.rstrip('\n')

    def get_chars_from_chunk(self, chunk):
        chunk_str = self.parse_chunk_from_api2d(chunk.decode("utf-8"))
        if chunk_str.rstrip() == "[DONE]":
            return "[DONE]"
        try:
            result = json.loads(chunk_str)
            return result["choices"][0]["delta"]["content"]
        except json.JSONDecodeError as e:
            print(e)


    @property
    def _identifying_params(self) -> Mapping[str, Any]:
        """Get the identifying parameters."""
        return {"n": 10}


def llm_init(llm_type="", api_key="", custom_api="", stream=0):
    global llm, stream_output

    if stream == "1":
        stream_output = True
    else:
        stream_output = False

    if llm_type == "openai":
        llm = OpenAI(openai_api_key=api_key, temperature=0.9)
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

class FooThread(threading.Thread):
    prompt: str = ""
    llm: any = None

    def __init__(self, prompt, llm):
        super().__init__(daemon=True)
        self.prompt = prompt
        self.llm = llm
        self.result = None

    def run(self):
        self.result = llm_request(self.prompt, self.llm)

# 调用入口
def just_do_it(prompt):
    global llm, vim
    result = llm_request(prompt, llm)
    if result == "{timeout}" or result == "{error}":
        return '""'
    else:
        return result

    # thread = FooThread(prompt=prompt, llm=llm)
    # thread.start()
    # thread.join(timeout)

    # if thread.is_alive():
    #     return '"{timeout}"'

    # return thread.result

if __name__ == '__main__':
    llm_init(llm_type="api2d", api_key="sdfsdfdsfsf", stream="1")
    print(just_do_it("写一段简单的 python 代码，打印一个 helloworld"))

# vim:ts=4:sw=4:sts=4
