--[[
HTTP API客户端模块：HttpClient
@desc：基于配置驱动的HTTP API客户端，封装Http模块，提供便捷的API调用接口
@author：SangYuming
@version：2.0.0
]]

-- 加载必要的模块
local BaseModule = require("core.base.base_module")
local Http = require("core.utils.http")
local Log = require("core.utils.log")
local Config = require("core.utils.config")
local GlobalError = require("core.utils.global_error")
local Constants = require("core.utils.constants")

local HttpClient = BaseModule:new("HttpClient")

-- 默认配置
HttpClient.defaultConfig = {
    baseUrl = "",
    enableParamValidation = true,
    enableEnumValidation = true,
    enableLog = true
}

-- 重写初始化日志方法
function HttpClient:initLogger()
    local Log = require("core.utils.log")
    self.logger = Log:getModule(self.name)
    return self
end

-- 重写初始化配置方法
function HttpClient:initConfig()
    local httpConfig = Config:get("http", {})
    
    local host = httpConfig.host or "localhost"
    local port = httpConfig.port or 80
    local protocol = port == 443 and "https" or "http"
    self.baseUrl = string.format("%s://%s:%d", protocol, host, port)
    
    self.apiConfig = Config:get("api", {})
    
    self.config = {}
    for k, v in pairs(self.defaultConfig) do
        self.config[k] = v
    end
    
    return self
end

-- 重写配置变更处理
function HttpClient:onConfigChange(oldConfig, newConfig)
    self:initConfig()
    self.logger:info("HTTP API客户端配置已更新")
    return self
end

-- 参数类型验证
local function validateParamType(value, expectedType)
    if expectedType == "string" then
        return type(value) == "string"
    elseif expectedType == "number" then
        return type(value) == "number"
    elseif expectedType == "boolean" then
        return type(value) == "boolean"
    elseif expectedType == "table" then
        return type(value) == "table"
    end
    return true
end

-- 解析参数定义
local function parseParamDef(paramDef)
    if type(paramDef) == "string" then
        -- 简单格式: "string", "number", "enum:TypesID"
        if paramDef:sub(1, 5) == "enum:" then
            return {
                type = "number",
                enum = paramDef:sub(6)
            }
        else
            return {
                type = paramDef
            }
        end
    elseif type(paramDef) == "table" then
        -- 复杂格式: { type = "string", enum = "TypesID", required = true }
        return paramDef
    end
    return {}
end

-- 验证参数
local function validateParams(apiName, params, paramDefs, enableEnumValidation)
    if not paramDefs or type(paramDefs) ~= "table" then
        return true
    end
    
    local errors = {}
    for paramName, paramDef in pairs(paramDefs) do
        local value = params[paramName]
        
        -- 解析参数定义
        local parsedDef = parseParamDef(paramDef)
        
        -- 检查必填参数
        if parsedDef.required and value == nil then
            table.insert(errors, string.format("参数'%s'是必填项", paramName))
        elseif value ~= nil then
            -- 检查参数类型
            if parsedDef.type and not validateParamType(value, parsedDef.type) then
                table.insert(errors, string.format("参数'%s'类型错误，期望'%s'，实际'%s'", 
                    paramName, parsedDef.type, type(value)))
            end
            
            -- 检查枚举值
            if enableEnumValidation and parsedDef.enum then
                local valid, errMsg = Constants:validateEnum(parsedDef.enum, value)
                if not valid then
                    table.insert(errors, string.format("参数'%s'枚举值错误: %s", paramName, errMsg))
                end
            end
        end
    end
    
    if #errors > 0 then
        return false, table.concat(errors, "; ")
    end
    
    return true
end

-- 组合完整URL
local function buildUrl(baseUrl, apiPath)
    baseUrl = baseUrl:gsub("/+$", "")
    apiPath = apiPath:gsub("^/+", "")
    return baseUrl .. "/" .. apiPath
end

-- 获取API配置
function HttpClient:getApiConfig(apiName)
    local apiInfo = self.apiConfig[apiName]
    if not apiInfo then
        return nil, GlobalError:formatError(
            string.format("API配置'%s'不存在", apiName), 
            GlobalError.ERROR_TYPES.VALIDATION
        )
    end
    return apiInfo
end

-- 调用API（通用方法）
function HttpClient:call(apiName, params, options)
    local apiInfo, err = self:getApiConfig(apiName)
    if err then
        return nil, err
    end
    
    -- 验证参数
    if self.config.enableParamValidation and apiInfo.params then
        local valid, errMsg = validateParams(apiName, params, apiInfo.params, self.config.enableEnumValidation)
        if not valid then
            self.logger:error(string.format("API参数验证失败: %s", errMsg))
            return nil, GlobalError:formatError(errMsg, GlobalError.ERROR_TYPES.VALIDATION)
        end
    end
    
    local fullUrl = buildUrl(self.baseUrl, apiInfo.url)
    
    if self.config.enableLog then
        self.logger:info(string.format("调用API: %s (%s)", apiName, apiInfo._desc or ""))
        self.logger:debug(string.format("完整URL: %s", fullUrl))
    end
    
    local method = string.upper(apiInfo.method or "GET")
    local response, httpErr
    
    if method == "GET" then
        response, httpErr = Http:get(fullUrl, params, options)
    elseif method == "POST" then
        response, httpErr = Http:post(fullUrl, params, options)
    else
        return nil, GlobalError:formatError(
            string.format("不支持的请求方法: %s", method), 
            GlobalError.ERROR_TYPES.VALIDATION
        )
    end
    
    if httpErr then
        return nil, httpErr
    end
    
    return response
end

-- 快捷方法：调用saveAccount API
function HttpClient:saveAccount(params, options)
    return self:call("saveAccount", params, options)
end

-- 快捷方法：调用getDvName API
function HttpClient:getDvName(params, options)
    return self:call("getDvName", params, options)
end

-- 快捷方法：调用getDvAccount API
function HttpClient:getDvAccount(params, options)
    return self:call("getDvAccount", params, options)
end

-- 快捷方法：调用getDvFans API
function HttpClient:getDvFans(params, options)
    return self:call("getDvFans", params, options)
end

-- 快捷方法：调用getMessageContent API
function HttpClient:getMessageContent(params, options)
    return self:call("getMessageContent", params, options)
end

-- 快捷方法：调用getKeyword API
function HttpClient:getKeyword(params, options)
    return self:call("getKeyword", params, options)
end

-- 快捷方法：调用saveData API
function HttpClient:saveData(params, options)
    return self:call("saveData", params, options)
end

-- 初始化模块
HttpClient:init()

return HttpClient
