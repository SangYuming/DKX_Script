--[[
HTTP客户端测试脚本
@desc：测试Http模块的功能
@author：SangYuming
@version：1.0.0
]]

-- 加载必要的模块
local Config = require("core.utils.config")

-- 初始化配置
Config:init()

-- 加载其他模块
local Log = require("core.utils.log")
local Http = require("core.utils.http")

-- 获取日志实例
local logger = Log:getLogger()

-- 测试GET请求
logger:info("开始测试GET请求...")

local url = Config:get("database.host") .. ":" .. Config:get("database.port") .. "/DKX/collect"
local params = {
    names = "test_user",
    auth = "test_token",
    TypesID = 1,
    country = 1
}

local response, err = Http:get(url, params)
if err then
    logger:error("GET请求失败: " .. err.message)
else
    logger:info("GET请求成功")
    logger:debug("响应: " .. Log:toString(response))
end

-- 测试POST请求（query方式）
logger:info("\n开始测试POST请求（query方式）...")

local postParams = {
    names = "test_user",
    auth = "test_token",
    TypesID = 1,
    country = 1
}

local response, err = Http:post(url, postParams)
if err then
    logger:error("POST请求（query方式）失败: " .. err.message)
else
    logger:info("POST请求（query方式）成功")
    logger:debug("响应: " .. Log:toString(response))
end

-- 测试POST请求（json方式）
logger:info("\n开始测试POST请求（json方式）...")

local jsonParams = {
    names = "test_user",
    auth = "test_token",
    TypesID = 1,
    country = 1
}

local jsonHeaders = {
    ["Content-Type"] = "application/json"
}

local response, err = Http:post(url, jsonParams, { headers = jsonHeaders })
if err then
    logger:error("POST请求（json方式）失败: " .. err.message)
else
    logger:info("POST请求（json方式）成功")
    logger:debug("响应: " .. Log:toString(response))
end

logger:info("\n所有测试完成")