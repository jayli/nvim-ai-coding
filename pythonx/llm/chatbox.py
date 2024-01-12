#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from typing import Any, List, Dict, Mapping, Optional
import requests
import re
import vim
import json
import traceback
import time

def contains_nr(s):
    ascii_list = [ord(c) for c in s]
    return 10 in ascii_list or 13 in ascii_list

def is_all_nr(s):
    if s.count("\n") == len(s) or s.count("\r") == len(s):
        return True
    else:
        return False

def vim_command_handler(script):
    if script == "[DONE]":
        vim.command("call nvim_ai#teardown()")
        vim.command("echom '[DONE]'")
        return
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

                # vim.command("call nvim_ai#insert('" + item + "')")
                vim.eval("nvim_ai#insert('" + item + "')")
                tmp_count = tmp_count + 1
    else:
        # vim.command("call nvim_ai#insert('" + script + "')")
        vim.eval("nvim_ai#insert('" + script + "')")

    time.sleep(0.012)

# 获取 chat 结果的主函数，要求流式输出
def fetch(prompts, callback):
    # TODO here --------------------------- 这里还未调通
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

    payload["stream"] = "true"
    try:
        response = requests.request("POST", url, data=json.dumps(payload),
                                    headers=headers, stream=True, timeout=self.timeout)
    except requests.exceptions.Timeout as e:
        vim.command("echom '调用超时'")
        return '{timeout}'

    chunk_chars = ""
    try:
        vim.command("call nvim_ai#stream_first_rendering()")

        for chunk in response.iter_content(chunk_size=3000):
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
        traceback.print_exc(file=open(vim.eval("nvim_ai#errlog_file()"),'a'))

    return ""
    # callback(res.text)

def get_delta_from_res(res):
    try:
        delta = res["choices"][0]["delta"]
        return delta
    except TypeError as e:
        errfile = vim.eval("nvim_ai#errlog_file()")
        traceback.print_exc(file=open(errfile,'a'))
        with open(errfile, 'a') as f:
            output_str = "出错的 res: \n\n" + json.dumps(res) + '\n\n'
            f.write(output_str)
        return {}

def get_valid_json(string):
    res = False
    try:
        res = json.loads(string)
        return res
    except json.JSONDecodeError as e:
        return False

def fetch_async(prompts, callback):
    fetch_thread = threading.Thread(target=fetch, args=(prompts, callback))
    fetch_thread.start()

def response_handler(res):
    print(res)

def do_request(prompt):
    prompts = "\n".join(prompt)
    fetch_async(prompts, callback)
    # results = result.split("\n")
    # return_str = str(results).replace("\\'", "''")
    # return return_str

def just_do_it(prompt):
    result = do_request(prompt)
    if result == "{timeout}" or result == "{error}":
        return '""'
    else:
        return result
