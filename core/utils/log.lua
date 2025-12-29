--[[
日志模块：Log
@desc：基于引擎logn函数的二次封装，提供日志级别、格式化输出、模块标识等功能
@author：SangYuming
@version：1.0.0
]]

local Log = {}

-- 日志级别定义
Log.LEVELS = {
    DEBUG = 1,
    INFO  = 2,
    WARN  = 3,
    ERROR = 4,
    FATAL = 5
}

-- 默认配置
Log.config = {
    level = Log.LEVELS.INFO,  -- 默认日志级别
    format = "[%TIME%] [%LEVEL%] [%MODULE%] %MESSAGE%",  -- 默认日志格式
    enable = true,  -- 是否启用日志
    timeFormat = "%Y-%m-%d %H:%M:%S",  -- 时间格式
    maxDepth = 3,  -- table格式化的最大嵌套深度
    onLog = nil  -- 日志回调函数
}

-- 模块实例缓存
local moduleInstances = {}
-- 模块级别配置
local moduleConfigs = {}

-- 声明loggerMT
local loggerMT = {}

-- 预声明log函数，解决循环依赖
local log

-- 获取当前时间字符串
local function getTimeString()
    local time = os.time()
    return os.date(Log.config.timeFormat, time)
end

-- 获取日志级别名称
local function getLevelName(level)
    for name, value in pairs(Log.LEVELS) do
        if value == level then
            return name
        end
    end
    return "UNKNOWN"
end

-- 将值转换为字符串表示
local function valueToString(value, depth, seen)
    depth = depth or 0
    seen = seen or {}
    
    if depth > Log.config.maxDepth then
        return "<max depth>"
    end
    
    local t = type(value)
    
    -- 处理特殊类型
    if t == "nil" then
        return "nil"
    elseif t == "boolean" then
        return value and "true" or "false"
    elseif t == "number" or t == "string" then
        return tostring(value)
    elseif t == "function" then
        return "<function>"
    elseif t == "userdata" then
        return "<userdata>"
    elseif t == "thread" then
        return "<thread>"
    elseif t == "table" then
        if seen[value] then
            return "<circular>"
        end
        seen[value] = true
        
        local parts = {}
        local isArray = true
        local maxIndex = 0
        
        -- 检查是否为数组
        for k, v in pairs(value) do
            if type(k) ~= "number" or k ~= math.floor(k) or k < 1 then
                isArray = false
            else
                maxIndex = math.max(maxIndex, k)
            end
        end
        
        if isArray then
            for i = 1, maxIndex do
                local v = value[i]
                if v ~= nil then
                    table.insert(parts, valueToString(v, depth + 1, seen))
                else
                    table.insert(parts, "nil")
                end
            end
        else
            -- 收集键值对
            local kvPairs = {}
            for k, v in pairs(value) do
                local keyStr = type(k) == "string" and k or ("[" .. tostring(k) .. "]")
                table.insert(kvPairs, keyStr .. " = " .. valueToString(v, depth + 1, seen))
            end
            table.sort(kvPairs) -- 按键排序，确保输出一致
            parts = kvPairs
        end
        
        seen[value] = nil
        return "{ " .. table.concat(parts, ", ") .. " }"
    else
        return "<" .. t .. ">"
    end
end

-- 格式化多个参数为字符串
local function formatArgs(...)  
    local args = { ... }
    local parts = {}
    
    for i, arg in ipairs(args) do
        table.insert(parts, valueToString(arg))
    end
    
    return table.concat(parts, " ")
end

-- 格式化日志消息
local function formatMessage(format, time, level, module, message)
    return format:gsub("%%([A-Z]+)%%", function(key)
        if key == "TIME" then
            return time
        elseif key == "LEVEL" then
            return getLevelName(level)
        elseif key == "MODULE" then
            return module or ""
        elseif key == "MESSAGE" then
            return message
        else
            return "%" .. key .. "%"
        end
    end)
end

-- 引擎logn函数的适配层
local function engineLog(...)  
    -- 检查logn函数是否存在
    if type(logn) == "function" then
        -- 使用引擎提供的logn函数
        return logn(...)
    else
        -- 在本地开发环境中使用print作为默认实现
        local args = { ... }
        local msg = table.concat(args, " ")
        print("[LOCAL DEV] " .. msg)
        return true
    end
end

-- 获取有效配置（模块配置覆盖全局配置）
local function getEffectiveConfig(module)
    local moduleConfig = moduleConfigs[module] or {}
    local effectiveConfig = {}
    
    -- 合并配置
    for key, value in pairs(Log.config) do
        effectiveConfig[key] = moduleConfig[key] or value
    end
    
    return effectiveConfig
end

-- 核心日志输出函数
log = function(level, module, ...)
    local effectiveConfig = getEffectiveConfig(module)
    
    if not effectiveConfig.enable then
        return
    end
    
    if level < effectiveConfig.level then
        return
    end
    
    local message = formatArgs(...)
    local time = getTimeString()
    local formattedMessage = formatMessage(effectiveConfig.format, time, level, module, message)
    
    -- 使用适配后的日志输出函数
    engineLog(formattedMessage)
    
    -- 调用日志回调函数
    if effectiveConfig.onLog then
        effectiveConfig.onLog(level, module, message, formattedMessage)
    end
end

-- 定义loggerMT的__index（必须在log函数定义之后）
loggerMT.__index = {
    debug = function(self, ...)
        log(Log.LEVELS.DEBUG, self.name, ...)
    end,

    info = function(self, ...)
        log(Log.LEVELS.INFO, self.name, ...)
    end,

    warn = function(self, ...)
        log(Log.LEVELS.WARN, self.name, ...)
    end,

    error = function(self, ...)
        log(Log.LEVELS.ERROR, self.name, ...)
    end,

    fatal = function(self, ...)
        log(Log.LEVELS.FATAL, self.name, ...)
    end,

    -- 设置模块级别的日志配置
    setConfig = function(self, config)
        if not moduleConfigs[self.name] then
            moduleConfigs[self.name] = {}
        end
        for key, value in pairs(config) do
            moduleConfigs[self.name][key] = value
        end
    end
}

-- 创建模块日志实例
function Log:getModule(name)
    if not moduleInstances[name] then
        local moduleLogger = setmetatable({ name = name }, loggerMT)
        moduleInstances[name] = moduleLogger
    end
    
    return moduleInstances[name]
end

-- 配置日志模块
function Log:setConfig(config)
    for key, value in pairs(config) do
        Log.config[key] = value
    end
    return self -- 支持链式调用
end

-- 设置日志级别
function Log:setLevel(level)
    Log.config.level = level
    return self -- 支持链式调用
end

-- 启用/禁用日志
function Log:enable(enabled)
    Log.config.enable = enabled
    return self -- 支持链式调用
end

-- 获取全局日志实例
function Log:getLogger()
    return Log:getModule("GLOBAL")
end

return Log