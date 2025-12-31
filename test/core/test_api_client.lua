--[[
测试脚本：ApiClient模块测试
@desc：测试API客户端的配置驱动调用功能
@author：SangYuming
@version：1.0.0
]]

-- 加载必要的模块
local Config = require("core.utils.config")

-- 初始化配置
Config:init()

-- 加载其他模块
local Log = require("core.utils.log")
local HttpApiClient = require("core.api.http_api_client")

-- 获取日志实例
local logger = Log:getLogger()

logger:info("========== 开始测试ApiClient模块 ==========")

-- 测试1：调用saveAccount API
logger:info("\n--- 测试1：调用saveAccount API ---")
local params = {
    names = "test_user",
    TypesID = 1,
    country = 1
}
logger:info("请求参数: names=" .. params.names .. ", TypesID=" .. params.TypesID .. ", country=" .. params.country)

local response, err = HttpApiClient:saveAccount(params)
if err then
    logger:error("saveAccount API调用失败: " .. err.message)
else
    logger:info("saveAccount API调用成功")
    logger:debug("响应: " .. (response or "nil"))
end

-- 测试2：调用getDvName API
logger:info("\n--- 测试2：调用getDvName API ---")
local response2, err2 = HttpApiClient:getDvName()
if err2 then
    logger:error("getDvName API调用失败: " .. err2.message)
else
    logger:info("getDvName API调用成功")
    logger:debug("响应: " .. (response2 or "nil"))
end

-- 测试3：调用getDvAccount API
logger:info("\n--- 测试3：调用getDvAccount API ---")
local response3, err3 = HttpApiClient:getDvAccount()
if err3 then
    logger:error("getDvAccount API调用失败: " .. err3.message)
else
    logger:info("getDvAccount API调用成功")
    logger:debug("响应: " .. (response3 or "nil"))
end

-- 测试4：调用getDvFans API
logger:info("\n--- 测试4：调用getDvFans API ---")
local response4, err4 = HttpApiClient:getDvFans()
if err4 then
    logger:error("getDvFans API调用失败: " .. err4.message)
else
    logger:info("getDvFans API调用成功")
    logger:debug("响应: " .. (response4 or "nil"))
end

-- 测试5：调用getMessageContent API
logger:info("\n--- 测试5：调用getMessageContent API ---")
local response5, err5 = HttpApiClient:getMessageContent()
if err5 then
    logger:error("getMessageContent API调用失败: " .. err5.message)
else
    logger:info("getMessageContent API调用成功")
    logger:debug("响应: " .. (response5 or "nil"))
end

-- 测试6：调用getKeyword API
logger:info("\n--- 测试6：调用getKeyword API ---")
local response6, err6 = HttpApiClient:getKeyword()
if err6 then
    logger:error("getKeyword API调用失败: " .. err6.message)
else
    logger:info("getKeyword API调用成功")
    logger:debug("响应: " .. (response6 or "nil"))
end

-- 测试7：调用saveData API
logger:info("\n--- 测试7：调用saveData API ---")
local saveDataParams = {
    data = "test_data"
}
logger:info("请求参数: data=" .. saveDataParams.data)

local response7, err7 = HttpApiClient:saveData(saveDataParams)
if err7 then
    logger:error("saveData API调用失败: " .. err7.message)
else
    logger:info("saveData API调用成功")
    logger:debug("响应: " .. (response7 or "nil"))
end

-- 测试8：使用通用call方法调用API
logger:info("\n--- 测试8：使用通用call方法调用API ---")
local response8, err8 = HttpApiClient:call("getDvName")
if err8 then
    logger:error("通用call方法调用失败: " .. err8.message)
else
    logger:info("通用call方法调用成功")
    logger:debug("响应: " .. (response8 or "nil"))
end

-- 测试9：参数验证测试
logger:info("\n--- 测试9：参数验证测试 ---")
local invalidParams = {
    names = "test_user",
    TypesID = "invalid_type", -- 应该是number，但传入了string
    country = 1
}
logger:info("请求参数（包含类型错误）: names=" .. invalidParams.names .. ", TypesID=" .. invalidParams.TypesID .. ", country=" .. invalidParams.country)

local response9, err9 = HttpApiClient:saveAccount(invalidParams)
if err9 then
    logger:info("参数验证成功捕获错误: " .. err9.message)
else
    logger:error("参数验证未能捕获类型错误")
end

logger:info("\n========== ApiClient模块测试完成 ==========")
