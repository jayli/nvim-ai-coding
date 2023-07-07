#!/usr/bin/env python3
# encoding: utf-8
import json
from typing import Any, List, Dict, Mapping, Optional
from langchain.llms.base import LLM
from langchain.llms import OpenAI
import requests
import re
import vim

# 全局llm
llm = None

# 默认都不支持流式输出，目前只实现了 api2d 的流式输出
stream_output = False

def contains_nr(s):
    return '\n' in s or '\r\n' in s

def is_all_nr(s):
    if s.count("\n") == len(s) or s.count("\r") == len(s):
        return True
    else:
        return False


def vim_command_handler(script):
    global nvim

    if script == "[DONE]":
        vim.command("call nvim_ai#teardown()")
        vim.command("echom '[DONE]'")
    # elif script == "\n":
    #     vim.command("call nvim_ai#new_line()")
    elif is_all_nr(script):
        for i in range(len(script)):
            vim.command("call nvim_ai#new_line()")
    elif contains_nr(script):
        script_items= script.split("\n")
        tmp_count = 0
        for item in script_items:
            if item == "":
                vim.command("call nvim_ai#new_line()")
            else:
                if tmp_count > 0:
                    vim.command("call nvim_ai#new_line()")

                vim.command("call nvim_ai#insert('" + script.strip() + "')")
                tmp_count = tmp_count + 1
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
            gpt_model = vim.eval("g:nvim_ai_model")
            payload = {
                    "model": gpt_model,
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
                    self.log('<--------apispace---------')
                    self.log(result['choices'][0]["message"]["content"])
                    return result['choices'][0]["message"]["content"]

            # 流式输出
            else:
                # url = "http://localhost:7001/test/chatgpt"
                payload["stream"] = "true"
                try:
                    response = requests.request("POST", url, data=json.dumps(payload),
                                                headers=headers, stream=True, timeout=self.timeout)
                except requests.exceptions.Timeout as e:
                    vim.command("echom '调用超时'")
                    return '{timeout}'

                chunk_chars = ""
                try:
                    # 如果是选中一个范围时
                    if vim.eval("g:nvim_ai_range") == "2":
                        vim.command("call nvim_ai#delete_selected_lines()")

                    count = 0
                    for chunk in response.iter_content(chunk_size=1500):
                        count = count + 1
                        chunk_chars = self.get_chars_from_chunk(chunk)

                        if chunk_chars == "[DONE]":
                            vim.command("call nvim_ai#teardown()")
                            vim.command("echom '[DONE]'")
                            return ""
                        elif chunk_chars.endswith("[DONE]"):
                            letters = chunk_chars.replace("[DONE]", "")
                            vim_command_handler(letters)
                            vim_command_handler("[DONE]")
                        else:
                            letters = chunk_chars.replace("'", "''")
                            vim_command_handler(letters)

                except KeyboardInterrupt:
                    print('Interrupted')
                except Exception as e:
                    print(">>:" + str(e))

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
            tmp_data = chunk_str.split("\n")
            curr_letter = ""
            for item in tmp_data:
                if item.strip() == "":
                    continue
                if item.startswith("data:"):
                    line = re.sub(r"^data:", "", item).strip()
                else:
                    line = item

                if line == "[DONE]":
                    curr_letter = curr_letter + "[DONE]"
                    break

                res = json.loads(line)
                delta = res["choices"][0]["delta"]
                if "content" in delta:
                    curr_letter = curr_letter + delta["content"]

            return curr_letter


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

# 调用入口
def just_do_it(prompt):
    global llm, vim
    result = llm_request(prompt, llm)
    if result == "{timeout}" or result == "{error}":
        return '""'
    else:
        return result

if __name__ == '__main__':
    llm_init(llm_type="api2d", api_key="fk209055-QCO1ChYkdCcPi1OnTWss7UlAjifaQ5RU", stream="1")
    print(just_do_it("基于 python 写一段代码，实现一个 helloworld"))

# vim:ts=4:sw=4:sts=4
