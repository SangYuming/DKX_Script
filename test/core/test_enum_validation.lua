--[[
测试脚本：枚举验证功能测试
@desc：测试常量模块和API客户端的枚举验证功能
@author：SangYuming
@version：1.0.0
]]

-- 加载必要的模块
local Config = require("core.utils.config")

-- 初始化配置
Config:init()

-- 加载其他模块
local Log = require("core.utils.log")
local Constants = require("core.utils.constants")
local HttpClient = require("core.api.http_api_client")

-- 获取日志实例
local logger = Log:getLogger()

logger:info("========== 开始测试枚举验证功能 ==========")

-- 测试1：查看所有枚举定义
logger:info("\n--- 测试1：查看所有枚举定义 ---")
local enumNames = Constants:getEnumNames()
logger:info("所有枚举名称: " .. table.concat(enumNames, ", "))

for _, enumName in ipairs(enumNames) do
    local enum = Constants:getEnum(enumName)
    logger:info(string.format("枚举 '%s' (%s):", enumName, enum._desc))
    local values = Constants:getEnumValues(enumName)
    for _, value in ipairs(values) do
        local name = Constants:getEnumName(enumName, value)
        logger:info(string.format("  %d = %s", value, name))
    end
end

-- 测试2：验证有效的枚举值
logger:info("\n--- 测试2：验证有效的枚举值 ---")
local validTypesID = 1
local validCountry = 1
local valid, errMsg = Constants:validateEnum("TypesID", validTypesID)
if valid then
    logger:info(string.format("TypesID=%d 是有效的枚举值 (%s)", validTypesID, Constants:getEnumName("TypesID", validTypesID)))
else
    logger:error(errMsg)
end

valid, errMsg = Constants:validateEnum("country", validCountry)
if valid then
    logger:info(string.format("country=%d 是有效的枚举值 (%s)", validCountry, Constants:getEnumName("country", validCountry)))
else
    logger:error(errMsg)
end

-- 测试3：验证无效的枚举值
logger:info("\n--- 测试3：验证无效的枚举值 ---")
local invalidTypesID = 99
valid, errMsg = Constants:validateEnum("TypesID", invalidTypesID)
if valid then
    logger:info(string.format("TypesID=%d 是有效的枚举值", invalidTypesID))
else
    logger:info("验证成功捕获错误: " .. errMsg)
end

local invalidCountry = 99
valid, errMsg = Constants:validateEnum("country", invalidCountry)
if valid then
    logger:info(string.format("country=%d 是有效的枚举值", invalidCountry))
else
    logger:info("验证成功捕获错误: " .. errMsg)
end

-- 测试4：使用有效枚举值调用API
logger:info("\n--- 测试4：使用有效枚举值调用API ---")
local validParams = {
    names = "test_user",
    TypesID = 1,
    country = 1
}
logger:info(string.format("请求参数: names=%s, TypesID=%d (%s), country=%d (%s)", 
    validParams.names, 
    validParams.TypesID, 
    Constants:getEnumName("TypesID", validParams.TypesID),
    validParams.country,
    Constants:getEnumName("country", validParams.country)))

local response, err = HttpClient:saveAccount(validParams)
if err then
    logger:error("API调用失败: " .. err.message)
else
    logger:info("API调用成功")
end

-- 测试5：使用无效枚举值调用API
logger:info("\n--- 测试5：使用无效枚举值调用API ---")
local invalidParams = {
    names = "test_user",
    TypesID = 99,
    country = 99
}
logger:info(string.format("请求参数: names=%s, TypesID=%d (无效), country=%d (无效)", 
    invalidParams.names, invalidParams.TypesID, invalidParams.country))

local response2, err2 = HttpClient:saveAccount(invalidParams)
if err2 then
    logger:info("验证成功捕获错误: " .. err2.message)
else
    logger:error("验证未能捕获枚举值错误")
end

-- 测试6：使用类型错误的参数调用API
logger:info("\n--- 测试6：使用类型错误的参数调用API ---")
local typeErrorParams = {
    names = "test_user",
    TypesID = "1",
    country = 1
}
logger:info(string.format("请求参数: names=%s, TypesID=%s (类型错误), country=%d", 
    typeErrorParams.names, typeErrorParams.TypesID, typeErrorParams.country))

local response3, err3 = HttpClient:saveAccount(typeErrorParams)
if err3 then
    logger:info("验证成功捕获错误: " .. err3.message)
else
    logger:error("验证未能捕获类型错误")
end

logger:info("\n========== 枚举验证功能测试完成 ==========")
