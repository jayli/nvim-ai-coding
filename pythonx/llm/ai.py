#!/usr/bin/env python3
# encoding: utf-8
import json
#import vim
from typing import Any, List, Dict, Mapping, Optional
from langchain.llms.base import LLM
from langchain.llms import OpenAI
import threading
import requests

# 全局llm
llm = None

# 子进程
proc = None

# 超时时间，单位s
timeout = 13

class CustomLLM(LLM):
    logging: bool = False
    output_keys: List[str] = ["output"]
    custom_api: str = ""
    api_key: str = ""

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
            from langchain.requests import TextRequestsWrapper
            response = TextRequestsWrapper().post(self.custom_api, {
                "ask": prompt,
                "prompt": prompt,
                "temperature":0,
                "history": []
            })
            self.log('<--------custom---------')
            self.log(json.loads(response)["response"])
            return json.loads(response)["response"]

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
            response = requests.request("POST", url, data=json.dumps(payload), headers=headers)
            result = json.loads(response.text)
            if "error" in result:
                return result["error"]
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
            response = requests.request("POST", url, data=json.dumps(payload), headers=headers)
            result = json.loads(response.text)
            if "object" in result and result["object"] == "error":
                return result["message"]
            else:
                return result['choices'][0]["message"]["content"]

        # openai
        elif self._llm_type == "openai":
            api_key = self.api_key
            pass

    @property
    def _identifying_params(self) -> Mapping[str, Any]:
        """Get the identifying parameters."""
        return {"n": 10}


def llm_init(llm_type="", api_key="", custom_api=""):
    global llm
    if llm_type == "openai":
        llm = OpenAI(openai_api_key=api_key, temperature=0.9)
    else:
        llm = CustomLLM(llm_type=llm_type, api_key=api_key, custom_api=custom_api)

def llm_request(prompt, llm):
    prompts = "\n".join(prompt)
    result = llm(prompts)
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
    global timeout, llm
    thread = FooThread(prompt=prompt, llm=llm)
    thread.start()
    thread.join(timeout)

    if thread.is_alive():
        return '"{timeout}"'

    return thread.result

if __name__ == '__main__':
    llm_init(llm_type="custom", custom_api="http://127.0.0.1:8000")
    print(just_do_it("写一段简单的 python 代码，打印一个 helloworld"))

# vim:ts=4:sw=4:sts=4
