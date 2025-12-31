--[[
HTTP客户端模块：Http
@desc：封装引擎提供的HTTP API，提供简洁易用的HTTP请求接口
@author：SangYuming
@version：1.0.0
]]

-- 加载必要的模块
local BaseModule = require("core.base.base_module")
local dkjson = require("core.utils.dkjson")
local Log = require("core.utils.log")
local Config = require("core.utils.config")
local GlobalError = require("core.utils.global_error")

local Http = BaseModule:new("Http")

-- 默认配置
Http.defaultConfig = {
    timeout = 10000, -- 默认超时时间，单位毫秒
    defaultHeaders = {
        ["Content-Type"] = "application/x-www-form-urlencoded"
    },
    enableLog = true, -- 是否启用日志
    logLevel = "INFO", -- 日志级别
    maxLogBodyLength = 1000 -- 日志中请求和响应体的最大长度
}

-- HTTP请求方法类型
Http.METHODS = {
    GET = "GET",
    POST = "POST"
}

-- 重写初始化日志方法
function Http:initLogger()
    local Log = require("core.utils.log")
    self.logger = Log:getModule(self.name)
    return self
end

-- 重写初始化配置方法
function Http:initConfig()
    
    -- 定义HTTP配置验证规则
    self:registerValidationRules()
    
    -- 从配置中心获取HTTP配置，否则使用默认配置
    local httpConfig = Config:get("http", {})
    self.config = {}
    
    -- 合并默认配置和从配置中心获取的配置
    for k, v in pairs(self.defaultConfig) do
        self.config[k] = httpConfig[k] or v
    end
    
    -- 将字符串级别转换为数字级别
    if type(self.config.logLevel) == "string" then
        self.config.logLevel = Log.LEVELS[string.upper(self.config.logLevel)] or Log.LEVELS.INFO
    end
    
    return self
end

-- 注册验证规则
function Http:registerValidationRules()
    local validationRules = {
        types = {
            -- http.timeout必须是数字
            ["http.timeout"] = "number",
            -- http.defaultHeaders必须是表或nil
            ["http.defaultHeaders"] = function(value) 
                return value == nil or type(value) == "table" 
            end,
            -- http.enableLog必须是布尔值
            ["http.enableLog"] = "boolean",
            -- http.logLevel可以是字符串或数字
            ["http.logLevel"] = function(value) 
                return type(value) == "string" or type(value) == "number" 
            end,
            -- http.maxLogBodyLength必须是数字
            ["http.maxLogBodyLength"] = "number"
        }
    }
    
    Config:setModuleValidationRules("http", validationRules)
    return self
end

-- 重写配置变更处理
function Http:onConfigChange(oldConfig, newConfig)
    self:initConfig()
    self.logger:info("HTTP配置已更新")
    return self
end

-- 格式化请求和响应体，用于日志记录
local function formatBody(body, maxLength, depth)
    depth = depth or 1
    local maxDepth = 3 -- 最大嵌套深度
    
    if not body then
        return "(empty)"
    end
    
    if type(body) == "table" then
        if depth > maxDepth then
            return "{ ... }"
        end
        
        local parts = {}
        local isArray = true
        local maxIndex = 0
        
        -- 检查是否为数组
        for k, v in pairs(body) do
            if type(k) ~= "number" or k ~= math.floor(k) or k < 1 then
                isArray = false
            else
                maxIndex = math.max(maxIndex, k)
            end
        end
        
        if isArray then
            for i = 1, maxIndex do
                local v = body[i]
                if v ~= nil then
                    table.insert(parts, formatBody(v, maxLength, depth + 1))
                else
                    table.insert(parts, "nil")
                end
            end
            local result = "[" .. table.concat(parts, ", ") .. "]"
            if #result > maxLength then
                return string.sub(result, 1, maxLength) .. "... (truncated)"
            end
            return result
        else
            -- 收集键值对
            local kvPairs = {}
            for k, v in pairs(body) do
                local keyStr = type(k) == "string" and k or ("[" .. tostring(k) .. "]")
                table.insert(kvPairs, keyStr .. ": " .. formatBody(v, maxLength, depth + 1))
            end
            table.sort(kvPairs) -- 按键排序，确保输出一致
            local result = "{ " .. table.concat(kvPairs, ", ") .. " }"
            if #result > maxLength then
                return string.sub(result, 1, maxLength) .. "... (truncated)"
            end
            return result
        end
    end
    
    local bodyStr = tostring(body)
    if #bodyStr > maxLength then
        return string.sub(bodyStr, 1, maxLength) .. "... (truncated)"
    end
    
    return bodyStr
end

-- 记录HTTP请求日志
local function logRequest(self, method, url, params, headers, timeout)
    if not self.config.enableLog then
        return
    end
    
    self.logger:info(string.format("[%s] %s", method, url))
    self.logger:debug(string.format("Params: %s", formatBody(params, self.config.maxLogBodyLength)))
    self.logger:debug(string.format("Headers: %s", formatBody(headers, self.config.maxLogBodyLength)))
    self.logger:debug(string.format("Timeout: %d ms", timeout))
end

-- 记录HTTP响应日志
local function logResponse(self, method, url, response, duration)
    if not self.config.enableLog then
        return
    end
    
    self.logger:info(string.format("[%s] %s - Duration: %d ms", method, url, duration))
    self.logger:debug(string.format("Response: %s", formatBody(response, self.config.maxLogBodyLength)))
end

-- 将table转换为查询字符串
local function tableToQueryString(params)
    if not params or type(params) ~= "table" then
        return ""
    end
    
    local parts = {}
    for k, v in pairs(params) do
        table.insert(parts, tostring(k) .. "=" .. tostring(v))
    end
    
    return table.concat(parts, "&")
end

-- 合并headers
local function mergeHeaders(headers1, headers2)
    local result = {}
    
    -- 先合并第一个headers
    if headers1 and type(headers1) == "table" then
        for k, v in pairs(headers1) do
            result[k] = v
        end
    end
    
    -- 再合并第二个headers，覆盖第一个headers中的相同键
    if headers2 and type(headers2) == "table" then
        for k, v in pairs(headers2) do
            result[k] = v
        end
    end
    
    return result
end

-- 处理请求参数
local function processParams(params, contentType)
    if not params then
        return ""
    end
    
    -- 如果params已经是字符串，直接返回
    if type(params) == "string" then
        return params
    end
    
    -- 如果params是table，根据contentType进行处理
    if type(params) == "table" then
        -- 如果是JSON类型，返回JSON字符串
        if contentType and contentType:find("application/json") then
            local success, result = pcall(dkjson.encode, params)
            if success then
                return result
            end
        end
        
        -- 否则转换为查询字符串
        return tableToQueryString(params)
    end
    
    -- 其他类型，转换为字符串
    return tostring(params)
end

-- 处理响应
local function processResponse(response)
    if not response then
        return nil, GlobalError:formatError("Empty response", GlobalError.ERROR_TYPES.NETWORK)
    end
    
    -- 尝试解析JSON响应
    local success, result = pcall(dkjson.decode, response)
    if success then
        return result, nil
    end
    
    -- 如果解析失败，返回原始响应
    return response, nil
end

-- 处理headers，转换为JSON字符串
local function processHeaders(headers)
    local success, result = pcall(dkjson.encode, headers)
    if success then
        return result
    end
    return "{}"
end

-- 内部请求处理函数
local function request(self, method, url, params, options)
    -- 检查必要参数
    if not url then
        return nil, GlobalError:formatError("URL不能为空", GlobalError.ERROR_TYPES.VALIDATION)
    end
    
    options = options or {}
    local timeout = options.timeout or self.config.timeout
    local headers = mergeHeaders(self.config.defaultHeaders, options.headers)
    local body = ""
    
    -- 处理请求参数
    body = processParams(params, headers["Content-Type"])
    
    -- 记录请求日志
    logRequest(self, method, url, params, headers, timeout)
    
    -- 计算请求开始时间
    local startTime = os.clock() * 1000 -- 毫秒级时间
    
    local success, response
    if method == self.METHODS.GET then
        -- 检查引擎函数是否存在
        if type(httpget) ~= "function" then
            return nil, GlobalError:formatError("引擎函数httpget未找到", GlobalError.ERROR_TYPES.SYSTEM)
        end
        -- 调用引擎的httpget函数
        success, response = pcall(httpget, url, body, timeout)
    else
        -- 处理headers，转换为JSON字符串
        local headersJson = processHeaders(headers)
        
        -- 检查引擎函数是否存在
        if type(httppost) ~= "function" then
            return nil, GlobalError:formatError("引擎函数httppost未找到", GlobalError.ERROR_TYPES.SYSTEM)
        end
        -- 调用引擎的httppost函数
        success, response = pcall(httppost, url, body, headersJson, timeout)
    end
    
    -- 计算请求时长
    local duration = (os.clock() * 1000) - startTime
    
    if not success then
        -- 记录错误日志
        self.logger:error(string.format("%s请求失败: %s, 错误: %s", method, url, response))
        return nil, GlobalError:formatError(string.format("%s请求失败: %s", method, response), GlobalError.ERROR_TYPES.NETWORK)
    end
    
    -- 记录响应日志
    logResponse(self, method, url, response, duration)
    
    -- 处理响应
    return processResponse(response)
end

-- GET请求
function Http:get(url, params, options)
    return request(self, self.METHODS.GET, url, params, options)
end

-- POST请求
function Http:post(url, params, options)
    return request(self, self.METHODS.POST, url, params, options)
end

-- 初始化模块
Http:init()

return Http