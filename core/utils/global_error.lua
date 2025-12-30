--[[
统一异常处理模块：GlobalError
@desc：标准化捕获函数执行异常，支持错误分类、可扩展处理策略和全局异常捕获
@author：SangYuming
@version：3.0.0
]]

local BaseModule = require("core.base.base_module")
local GlobalError = BaseModule:new("GlobalError")

-- 兼容层：获取正确的unpack函数，兼容Lua 5.1和5.3+
local unpack = table.unpack or unpack

-- 错误类型定义
GlobalError.ERROR_TYPES = {
    SYSTEM = 1,     -- 系统错误
    BUSINESS = 2,   -- 业务错误
    NETWORK = 3,    -- 网络错误
    VALIDATION = 4, -- 验证错误
    RUNTIME = 5     -- 运行时错误
}

-- 错误码映射
GlobalError.ERROR_CODES = {
    [GlobalError.ERROR_TYPES.SYSTEM] = 500,
    [GlobalError.ERROR_TYPES.BUSINESS] = 400,
    [GlobalError.ERROR_TYPES.NETWORK] = 408,
    [GlobalError.ERROR_TYPES.VALIDATION] = 422,
    [GlobalError.ERROR_TYPES.RUNTIME] = 501
}

-- 默认配置
GlobalError.defaultConfig = {
    enableGlobalHandler = true,  -- 是否启用全局异常捕获
    logLevel = 4, -- 错误日志级别，直接使用数值4表示ERROR级别
    includeTraceback = true,     -- 是否包含堆栈信息
    maxStackTraceLines = 20      -- 堆栈最大行数
}

-- 错误处理策略注册中心
GlobalError.errorHandlers = {
    default = nil  -- 默认处理策略
}

-- 重写初始化配置方法
function GlobalError:initConfig()
    local Config = require("core.utils.config")
    
    -- 定义错误处理配置验证规则
    self:registerValidationRules()
    
    -- 从配置中心获取错误处理配置，否则使用默认配置
    local errorConfig = Config:get("globalError", {})
    self.config = {}
    
    -- 合并默认配置和从配置中心获取的配置
    for k, v in pairs(self.defaultConfig) do
        self.config[k] = errorConfig[k] or v
    end
    
    -- 将字符串级别转换为数字级别
    local Log = require("core.utils.log")
    if type(self.config.logLevel) == "string" then
        self.config.logLevel = Log.LEVELS[string.upper(self.config.logLevel)] or self.defaultConfig.logLevel
    end
    
    return self
end

-- 注册验证规则
function GlobalError:registerValidationRules()
    local Config = require("core.utils.config")
    local validationRules = {
        types = {
            -- globalError.enableGlobalHandler必须是布尔值
            ["globalError.enableGlobalHandler"] = "boolean",
            -- globalError.logLevel可以是字符串或数字
            ["globalError.logLevel"] = function(value) 
                return type(value) == "string" or type(value) == "number" 
            end,
            -- globalError.includeTraceback必须是布尔值
            ["globalError.includeTraceback"] = "boolean",
            -- globalError.maxStackTraceLines必须是数字
            ["globalError.maxStackTraceLines"] = "number"
        }
    }
    
    Config:setModuleValidationRules("globalError", validationRules)
    return self
end

-- 重写配置变更处理
function GlobalError:onConfigChange(oldConfig, newConfig)
    self:initConfig()
    -- 如果全局异常处理配置变更，重新设置全局错误处理函数
    self:setupGlobalHandler()
    self.logger:info("配置已更新")
    return self
end

-- 设置全局错误处理函数
function GlobalError:setupGlobalHandler()
    local Log = require("core.utils.log")
    
    if self.config.enableGlobalHandler then
        if not __G__TRACKBACK__ or __G__TRACKBACK__ ~= function(err)
            local errInfo = self:formatError(err, self.ERROR_TYPES.SYSTEM)
            self.defaultErrorHandler(errInfo)
            
            -- 调用原始错误处理函数
            if self.originalErrorHandler then
                return self.originalErrorHandler(err)
            end
        end then
            -- 保存原始的错误处理函数
            self.originalErrorHandler = __G__TRACKBACK__
            
            -- 设置新的全局错误处理函数
            __G__TRACKBACK__ = function(err)
                local errInfo = self:formatError(err, self.ERROR_TYPES.SYSTEM)
                self.defaultErrorHandler(errInfo)
                
                -- 调用原始错误处理函数
                if self.originalErrorHandler then
                    return self.originalErrorHandler(err)
                end
            end
            
            self.logger:info("全局异常捕获已启用")
        end
    else
        -- 恢复原始的错误处理函数
        if self.originalErrorHandler then
            __G__TRACKBACK__ = self.originalErrorHandler
            self.logger:info("全局异常捕获已禁用")
        end
    end
    return self
end

-- 重写初始化日志方法
function GlobalError:initLogger()
    -- 初始化日志，使用Log模块
    local Log = require("core.utils.log")
    self.logger = Log:getModule(self.name)
    return self
end

-- 初始化模块
GlobalError:init()

-- 加载日志级别常量
local Log = require("core.utils.log")
GlobalError.LEVELS = Log.LEVELS

-- 格式化错误信息
function GlobalError:formatError(err, errorType)
    errorType = errorType or self.ERROR_TYPES.RUNTIME
    local traceback = self.config.includeTraceback and debug.traceback() or ""
    
    -- 限制堆栈行数,避免日志过大
    if traceback and self.config.maxStackTraceLines then
        local lines = {}
        local lineCount = 0
        local tempTrace = traceback
        local startPos = 1
        
        while startPos <= #tempTrace do
            local endPos = string.find(tempTrace, "\n", startPos) -- 查找下一个换行符
            
            if not endPos then -- 如果没有找到换行符，说明是最后一行
                endPos = #tempTrace + 1
            end
            
            local line = string.sub(tempTrace, startPos, endPos - 1)
            table.insert(lines, line)
            lineCount = lineCount + 1
            
            if lineCount >= self.config.maxStackTraceLines then
                table.insert(lines, "... (更多堆栈信息已截断)")
                break
            end
            
            startPos = endPos + 1
        end
        
        traceback = table.concat(lines, "\n")
    end
    
    return {
        code = self.ERROR_CODES[errorType] or -1,
        type = errorType,
        message = tostring(err),
        traceback = traceback,
        timestamp = os.time()
    }
end

-- 全局默认错误处理策略
function GlobalError:defaultErrorHandler(errInfo)
    -- 根据错误类型调整日志级别
    local level = self.config.logLevel
    if errInfo.type == self.ERROR_TYPES.WARN then
        level = self.LEVELS.WARN
    elseif errInfo.type == self.ERROR_TYPES.INFO then
        level = self.LEVELS.INFO
    end
    
    local levelName = (function() for k, v in pairs(self.LEVELS) do if v == level then return k:lower() end end end)() or "error"
    -- 使用冒号语法调用，确保self参数正确传递
    if self.logger[levelName] then
        self.logger[levelName](self.logger, 
            string.format("捕获到异常 [类型:%d][代码:%d]: %s\n堆栈:%s", 
                errInfo.type, errInfo.code, errInfo.message, errInfo.traceback)
        )
    else
        -- 降级到error方法
        self.logger:error(
            string.format("捕获到异常 [类型:%d][代码:%d]: %s\n堆栈:%s", 
                errInfo.type, errInfo.code, errInfo.message, errInfo.traceback)
        )
    end
    
    return errInfo
end

-- 初始化默认处理策略
GlobalError.errorHandlers.default = function(errInfo) return GlobalError:defaultErrorHandler(errInfo) end

-- 注册错误处理策略
function GlobalError:registerHandler(name, handler)
    assert(type(name) == "string" and type(handler) == "function", 
           "参数错误:name必须是字符串,handler必须是函数")
    
    self.errorHandlers[name] = handler
    self.logger:info(string.format("注册错误处理策略: %s", name))
    return self
end

-- 设置默认错误处理策略
function GlobalError:setDefaultHandler(name)
    assert(type(name) == "string" and self.errorHandlers[name], 
           "参数错误:处理策略不存在")
    
    self.errorHandlers.default = self.errorHandlers[name]
    self.logger:info(string.format("设置默认错误处理策略: %s", name))
    return self
end

-- 基础异常捕获
function GlobalError.base(func, ...)
    assert(type(func) == "function", "参数错误:func必须是函数类型")
    
    -- 处理参数
    local args = { ... }
    local handlerName = "default"
    
    -- 检查第二个参数是否为字符串处理器名称
    if args[1] and type(args[1]) == "string" then
        handlerName = args[1]
        table.remove(args, 1)
    end
    
    local handler = GlobalError.errorHandlers[handlerName]
    
    local function errorHandler(err)
        local errInfo = GlobalError:formatError(err)
        return handler(errInfo)
    end
    
    -- 使用兼容的unpack函数传递参数给func
    local success, result = xpcall(function() return func(unpack(args)) end, errorHandler)
    return success, result
end

-- 带错误类型的异常捕获
function GlobalError.type(func, errorType, ...)
    local isValidType = false
    for _, value in pairs(GlobalError.ERROR_TYPES) do
        if value == errorType then
            isValidType = true
            break
        end
    end
    assert(type(func) == "function" and isValidType, 
           "参数错误:func必须是函数类型，errorType必须是有效的错误类型")
    
    -- 处理参数
    local args = { ... }
    local handlerName = "default"
    
    -- 检查第三个参数是否为字符串处理器名称
    if args[1] and type(args[1]) == "string" then
        handlerName = args[1]
        table.remove(args, 1)
    end
    
    local handler = GlobalError.errorHandlers[handlerName]
    
    local function errorHandler(err)
        local errInfo = GlobalError:formatError(err, errorType)
        return handler(errInfo)
    end
    
    -- 使用兼容的unpack函数传递参数给func
    local success, result = xpcall(function() return func(unpack(args)) end, errorHandler)
    return success, result
end

-- 业务错误包装
function GlobalError.wrapBusinessError(message, data)
    return {
        code = GlobalError.ERROR_CODES[GlobalError.ERROR_TYPES.BUSINESS],
        type = GlobalError.ERROR_TYPES.BUSINESS,
        message = message,
        data = data,
        timestamp = os.time()
    }
end

-- 设置全局配置
function GlobalError:setConfig(config)
    for key, value in pairs(config or {}) do
        self.config[key] = value
    end
    self.logger:info("更新GlobalError配置")
    
    -- 更新全局错误处理
    self:setupGlobalHandler()
    
    return self
end

-- 初始化全局异常捕获
GlobalError:setupGlobalHandler()

return GlobalError
