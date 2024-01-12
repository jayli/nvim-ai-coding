#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from typing import Any, List, Dict, Mapping, Optional
import requests
import re
import vim
import json
import time
import threading

# 头部被截断时存储头部
half_chunk_str = ""

def safe_vim_eval(expression):
    try:
        return vim.eval(expression)
    except vim.error:
        return None

def print_log(str):
    print(str)

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

def vim_simple_callback(cmd):
    vim.command(cmd)


# 获取 chat 结果的主函数，要求流式输出
def fetch(prompts, ai_model, api_key):
    global half_chunk_str
    half_chunk_str = ""
    payload = {
        "model": ai_model,
        "messages": [
            {
                "role": "user",
                "content": prompts
            }
        ],
        "safe_mode": False
    }

    headers = {
        'Authorization': "Bearer " + api_key,
        'Content-Type': 'application/json'
    }

    payload["stream"] = "true"

    try:
        response = requests.request("POST", 
                                    "https://oa.api2d.net/v1/chat/completions",
                                    data=json.dumps(payload),
                                    headers=headers,
                                    stream=True,
                                    timeout=13)
    except requests.exceptions.Timeout as e:
        vim.async_call(vim_simple_callback, "echom 'timeout'")
        return '{timeout}'

    chunk_chars = ""

    try:
        vim.async_call(vim_simple_callback, "call nvim_ai#stream_first_rendering()")

        for chunk in response.iter_content(chunk_size=3000):
            chunk_chars = get_chars_from_chunk(chunk)

            if chunk_chars == "[DONE]":
                vim.async_call(vim_simple_callback, "call nvim_ai#teardown()")
                vim.async_call(vim_simple_callback, "echom '[DONE]'")
                return ""
            elif chunk_chars.endswith("[DONE]"):
                letters = chunk_chars.replace("[DONE]", "")
                vim.async_call(vim_command_handler, letters)
                vim.async_call(vim_command_handler, "[DONE]")
            else:
                letters = chunk_chars.replace("'", "''")
                vim.async_call(vim_command_handler, letters)

    except KeyboardInterrupt:
        vim.async_call(print_log, 'Keybord Event Interrupted')
    except Exception as e:
        vim.async_call(print_log, ">>:" + str(e))

    return ""

def parse_chunk_from_api2d(text):
    prefix = "data: "
    output = text
    if text.startswith(prefix):
        output = text[len(prefix):]
    return output.rstrip('\n')

def get_chars_from_chunk(chunk):
    global half_chunk_str
    chunk_str = parse_chunk_from_api2d(chunk.decode("utf-8"))
    if chunk_str.rstrip() == "[DONE]":
        return "[DONE]"
    try:
        # print('---------------')
        # print(chunk_str)
        result = json.loads(chunk_str)
        delta = result["choices"][0]["delta"]
        if "content" in delta:
            return result["choices"][0]["delta"]["content"]
        else:
            return ""
    except json.JSONDecodeError as e:
        # print("except: jsondecodeerror")
        tmp_data = chunk_str.split("\n")
        curr_letter = ""
        for item in tmp_data:
            if item.strip() == "":
                continue
            if item.startswith("data:"):
                line = re.sub(r"^data:", "", item).strip()
            else:
                line = item.strip()

            if line == "[DONE]":
                curr_letter = curr_letter + "[DONE]"
                break

            res = get_valid_json(line)
            if res == False:
                # print('出现了截断的情况')
                # 出现了被截断的情况
                if re.compile(r'^{.id.:').search(line) == None:
                    # 头部被截断，则补上头部
                    # print('头部被截断，补充上头部')
                    line = half_chunk_str + line
                    half_chunk_str = ""
                    # print(line)
                    res = get_valid_json(line)
                    if res == False:
                        continue

                else:
                    # print("尾部被截断，把片段保存为头部")
                    # print(line)
                    # 尾部截断，则保存为头部
                    half_chunk_str = line
                    continue

            # 正常的完整JSON
            delta = get_delta_from_res(res)
            if "content" in delta:
                curr_letter = curr_letter + delta["content"]

        return curr_letter

def get_delta_from_res(res):
    try:
        delta = res["choices"][0]["delta"]
        return delta
    except TypeError as e:
        vim.async_call(print_log, "出错的 res: " + json.dumps(res))
        return {}

def get_valid_json(string):
    res = False
    try:
        res = json.loads(string)
        return res
    except json.JSONDecodeError as e:
        return False

def fetch_async(prompts):
    ai_model = safe_vim_eval("g:nvim_ai_model")
    api_key = safe_vim_eval("g:nvim_ai_apikey")
    fetch_thread = threading.Thread(target=fetch, args=(prompts, ai_model, api_key))
    fetch_thread.start()

def noop():
    pass

def response_handler(res):
    print(res)

# prompt 是一个行组成的数组列表
def do_request(prompt_lines):
    prompts = "\n".join(prompt_lines)
    print(isinstance(prompts, str))
    fetch_async(prompts)
    # results = result.split("\n")
    # return_str = str(results).replace("\\'", "''")
    # return return_str

def just_do_it(prompt):
    result = do_request(prompt)
    if result == "{timeout}" or result == "{error}":
        return '""'
    else:
        return result
