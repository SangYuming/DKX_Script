--[[
日志模块：Log
@desc：基于引擎logn函数的二次封装，提供日志级别、格式化输出、模块标识等功能
@author：SangYuming
@version：2.0.0
]]

local BaseModule = require("core.base.base_module")
local Log = BaseModule:new("Log")

-- 日志级别定义
Log.LEVELS = {
    DEBUG = 1,
    INFO  = 2,
    WARN  = 3,
    ERROR = 4,
    FATAL = 5
}

-- 日志级别名称映射
Log.levelNames = {
    [Log.LEVELS.DEBUG] = "DEBUG",
    [Log.LEVELS.INFO] = "INFO",
    [Log.LEVELS.WARN] = "WARN",
    [Log.LEVELS.ERROR] = "ERROR",
    [Log.LEVELS.FATAL] = "FATAL"
}

-- 默认配置
Log.defaultConfig = {
    level = Log.LEVELS.INFO,  -- 默认日志级别
    format = "[%TIME%] [%LEVEL%] [%MODULE%] %MESSAGE%",  -- 默认日志格式
    enable = true,  -- 是否启用日志
    timeFormat = "%Y-%m-%d %H:%M:%S",  -- 时间格式
    maxDepth = 3,  -- table格式化的最大嵌套深度
    onLog = nil  -- 日志回调函数
}

-- 模块实例缓存
Log.moduleInstances = {}
-- 模块级别配置
Log.moduleConfigs = {}

-- 声明loggerMT
local loggerMT = {}

-- 预声明log函数，解决循环依赖
local log

-- 重写初始化配置方法
function Log:initConfig()
    local Config = require("core.utils.config")
    
    -- 定义日志配置验证规则
    self:registerValidationRules()
    
    -- 从配置中心获取日志配置，否则使用默认配置
    local logConfig = Config:get("log", {})
    self.config = {}
    
    -- 合并默认配置和从配置中心获取的配置
    for k, v in pairs(self.defaultConfig) do
        self.config[k] = logConfig[k] or v
    end
    
    -- 将字符串级别转换为数字级别
    if type(self.config.level) == "string" then
        self.config.level = self.LEVELS[string.upper(self.config.level)] or self.defaultConfig.level
    end
    
    return self
end

-- 注册验证规则
function Log:registerValidationRules()
    local Config = require("core.utils.config")
    local validationRules = {
        types = {
            -- log.level可以是字符串或数字
            ["log.level"] = function(value) 
                return type(value) == "string" or type(value) == "number" 
            end,
            -- log.format必须是字符串
            ["log.format"] = "string",
            -- log.enable必须是布尔值
            ["log.enable"] = "boolean",
            -- log.timeFormat必须是字符串
            ["log.timeFormat"] = "string",
            -- log.maxDepth必须是数字
            ["log.maxDepth"] = "number",
            -- log.onLog必须是函数或nil
            ["log.onLog"] = function(value) 
                return value == nil or type(value) == "function" 
            end
        }
    }
    
    Config:setModuleValidationRules("log", validationRules)
    return self
end

-- 获取当前时间字符串
local function getTimeString()
    local time = os.time()
    return os.date(Log.config.timeFormat, time)
end

-- 获取日志级别名称
local function getLevelName(level)
    return Log.levelNames[level] or "UNKNOWN"
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

-- 引擎日志函数的适配层
local function engineLog(level, ...)  
    local args = { ... }
    local msg = table.concat(args, " ")
    
    -- 根据日志级别选择不同的引擎日志函数
    if type(logn) == "function" then
        if level == Log.LEVELS.DEBUG then
            -- 蓝色调试信息
            if type(logd) == "function" then
                return logd(msg)
            else
                return logn(msg)
            end
        elseif level == Log.LEVELS.ERROR or level == Log.LEVELS.FATAL then
            -- 红色错误信息
            if type(loge) == "function" then
                return loge(msg)
            else
                return logn(msg)
            end
        else
            -- 灰色普通信息（INFO, WARN）
            return logn(msg)
        end
    else
        -- 在本地开发环境中使用print作为默认实现
        -- 根据级别添加ANSI颜色代码
        local colorCode = ""
        local resetCode = "\027[0m"
        
        if level == Log.LEVELS.DEBUG then
            -- 蓝色
            colorCode = "\027[34m"
        elseif level == Log.LEVELS.ERROR or level == Log.LEVELS.FATAL then
            -- 红色
            colorCode = "\027[31m"
        elseif level == Log.LEVELS.WARN then
            -- 黄色
            colorCode = "\027[33m"
        else
            -- 默认（灰色/白色）
            colorCode = "\027[37m"
        end
        
        print("[LOCAL DEV] " .. colorCode .. msg .. resetCode)
        return true
    end
end

-- 获取有效配置（模块配置覆盖全局配置）
local function getEffectiveConfig(module)
    local moduleConfig = Log.moduleConfigs[module] or {}
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
    
    -- 使用适配后的日志输出函数，传递日志级别
    engineLog(level, formattedMessage)
    
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
        if not Log.moduleConfigs[self.name] then
            Log.moduleConfigs[self.name] = {}
        end
        for key, value in pairs(config) do
            Log.moduleConfigs[self.name][key] = value
        end
    end
}

-- 创建模块日志实例
function Log:getModule(name)
    if not self.moduleInstances[name] then
        local moduleLogger = setmetatable({ name = name }, loggerMT)
        self.moduleInstances[name] = moduleLogger
    end
    
    return self.moduleInstances[name]
end

-- 配置日志模块
function Log:setConfig(config)
    for key, value in pairs(config) do
        self.config[key] = value
    end
    return self -- 支持链式调用
end

-- 设置日志级别
function Log:setLevel(level)
    self.config.level = level
    return self -- 支持链式调用
end

-- 启用/禁用日志
function Log:enable(enabled)
    self.config.enable = enabled
    return self -- 支持链式调用
end

-- 获取全局日志实例
function Log:getLogger()
    return self:getModule("GLOBAL")
end

-- 更新配置
function Log:updateConfig()
    self:initConfig()
    -- 更新所有模块实例的配置
    for name, instance in pairs(self.moduleInstances) do
        self.moduleConfigs[name] = nil
    end
    return self
end

-- 注册验证规则
function Log:registerValidationRules()
    local Config = require("core.utils.config")
    local validationRules = {
        types = {
            -- log.level可以是字符串或数字
            ["log.level"] = function(value) 
                return type(value) == "string" or type(value) == "number" 
            end,
            -- log.format必须是字符串
            ["log.format"] = "string",
            -- log.enable必须是布尔值
            ["log.enable"] = "boolean",
            -- log.timeFormat必须是字符串
            ["log.timeFormat"] = "string",
            -- log.maxDepth必须是数字
            ["log.maxDepth"] = "number",
            -- log.onLog必须是函数或nil
            ["log.onLog"] = function(value) 
                return value == nil or type(value) == "function" 
            end
        }
    }
    
    Config:setModuleValidationRules("log", validationRules)
    return self
end

-- 重写初始化日志方法
function Log:initLogger()
    -- 直接初始化日志，不依赖BaseModule的默认实现
    -- 因为Log模块本身就是日志模块，所以不需要再加载其他日志模块
    -- 这里的logger是模块级别的日志记录器，用于记录Log模块自身的日志
    -- 注意：这里使用了一个简单的print实现，避免循环依赖
    self.logger = {
        info = function(_, ...)
            local args = { ... }
            local msg = table.concat(args, " ")
            print("[Log Module] " .. msg)
        end,
        debug = function(_, ...)
            local args = { ... }
            local msg = table.concat(args, " ")
            print("[Log Module] [DEBUG] " .. msg)
        end,
        error = function(_, ...)
            local args = { ... }
            local msg = table.concat(args, " ")
            print("[Log Module] [ERROR] " .. msg)
        end
    }
    return self
end

-- 初始化模块
Log:init()

return Log