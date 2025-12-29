--[[
统一异常处理模块：GlobalError
@desc：标准化捕获函数执行异常，支持错误分类、可扩展处理策略和全局异常捕获
@author：SangYuming
@version：2.0.0
]]

local GlobalError = {}

local Log = require("core.utils.log")
local logger = Log:getModule("GlobalError")

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
GlobalError.config = {
    enableGlobalHandler = true,  -- 是否启用全局异常捕获
    logLevel = Log.LEVELS.ERROR, -- 错误日志级别
    includeTraceback = true,     -- 是否包含堆栈信息
    maxStackTraceLines = 20      -- 堆栈最大行数
}

-- 错误处理策略注册中心
local errorHandlers = {
    default = nil  -- 默认处理策略
}

logger:info("GlobalError模块加载成功")

-- 格式化错误信息
local function formatError(err, errorType)
    errorType = errorType or GlobalError.ERROR_TYPES.RUNTIME
    local traceback = GlobalError.config.includeTraceback and debug.traceback() or ""
    
    -- 限制堆栈行数,避免日志过大
    if traceback and GlobalError.config.maxStackTraceLines then
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
            
            if lineCount >= GlobalError.config.maxStackTraceLines then
                table.insert(lines, "... (更多堆栈信息已截断)")
                break
            end
            
            startPos = endPos + 1
        end
        
        traceback = table.concat(lines, "\n")
    end
    
    return {
        code = GlobalError.ERROR_CODES[errorType] or -1,
        type = errorType,
        message = tostring(err),
        traceback = traceback,
        timestamp = os.time()
    }
end

-- 全局默认错误处理策略
local function defaultErrorHandler(errInfo)
    -- 根据错误类型调整日志级别
    local level = GlobalError.config.logLevel
    if errInfo.type == GlobalError.ERROR_TYPES.WARN then
        level = Log.LEVELS.WARN
    elseif errInfo.type == GlobalError.ERROR_TYPES.INFO then
        level = Log.LEVELS.INFO
    end
    
    local levelName = (function() for k, v in pairs(Log.LEVELS) do if v == level then return k:lower() end end end)() or "error"
    -- 使用冒号语法调用，确保self参数正确传递
    if logger[levelName] then
        logger[levelName](logger, 
            string.format("捕获到异常 [类型:%d][代码:%d]: %s\n堆栈:%s", 
                errInfo.type, errInfo.code, errInfo.message, errInfo.traceback)
        )
    else
        -- 降级到error方法
        logger:error(
            string.format("捕获到异常 [类型:%d][代码:%d]: %s\n堆栈:%s", 
                errInfo.type, errInfo.code, errInfo.message, errInfo.traceback)
        )
    end
    
    return errInfo
end

-- 初始化默认处理策略
errorHandlers.default = defaultErrorHandler

-- 注册错误处理策略
function GlobalError:registerHandler(name, handler)
    assert(type(name) == "string" and type(handler) == "function", 
           "参数错误:name必须是字符串,handler必须是函数")
    
    errorHandlers[name] = handler
    logger:info(string.format("注册错误处理策略: %s", name))
    return self
end

-- 设置默认错误处理策略
function GlobalError:setDefaultHandler(name)
    assert(type(name) == "string" and errorHandlers[name], 
           "参数错误:处理策略不存在")
    
    errorHandlers.default = errorHandlers[name]
    logger:info(string.format("设置默认错误处理策略: %s", name))
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
    
    local handler = errorHandlers[handlerName]
    
    local function errorHandler(err)
        local errInfo = formatError(err)
        return handler(errInfo)
    end
    
    -- 使用unpack传递参数给func
    local success, result = xpcall(function() return func(table.unpack(args)) end, errorHandler)
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
    
    local handler = errorHandlers[handlerName]
    
    local function errorHandler(err)
        local errInfo = formatError(err, errorType)
        return handler(errInfo)
    end
    
    -- 使用unpack传递参数给func
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
        GlobalError.config[key] = value
    end
    logger:info("更新GlobalError配置")
    return self
end

-- 全局异常捕获
if GlobalError.config.enableGlobalHandler then
    -- 保存原始的错误处理函数
    GlobalError.originalErrorHandler = __G__TRACKBACK__
    
    -- 设置新的全局错误处理函数
    __G__TRACKBACK__ = function(err)
        local errInfo = formatError(err, GlobalError.ERROR_TYPES.SYSTEM)
        defaultErrorHandler(errInfo)
        
        -- 调用原始错误处理函数
        if GlobalError.originalErrorHandler then
            return GlobalError.originalErrorHandler(err)
        end
    end
    
    logger:info("全局异常捕获已启用")
end

return GlobalError
