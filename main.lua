--[[
应用主入口：main.lua
@desc：定义应用启动流程，统一初始化各个模块
@author：SangYuming
@version：1.0.0
]]

-- 应用程序对象
local App = {}

-- 初始化配置模块
local function initConfig()
    local Config = require("core.utils.config")
    -- 初始化配置，加载配置文件
    local success = Config:init()
    if not success then
        print("[ERROR] 配置初始化失败")
        return false
    end
    return true
end

-- 初始化日志模块
local function initLog()
    local Log = require("core.utils.log")
    local logger = Log:getLogger()
    logger:info("日志模块初始化成功")
    return true
end

-- 初始化错误处理模块
local function initErrorHandler()
    local GlobalError = require("core.utils.global_error")
    local Log = require("core.utils.log")
    local logger = Log:getLogger()
    logger:info("错误处理模块初始化成功")
    return true
end

-- 启动配置监控
local function startConfigMonitoring()
    local Config = require("core.utils.config")
    local Log = require("core.utils.log")
    local logger = Log:getLogger()
    
    -- 从配置中获取监控间隔，默认60秒
    local monitorInterval = Config:get("app.configMonitorInterval", 60)
    Config:startMonitoring(monitorInterval)
    logger:info("配置监控已启动，检查间隔: " .. monitorInterval .. "秒")
    return true
end

-- 初始化所有模块
function App:init()
    print("[INFO] 开始初始化应用...")
    
    -- 按照依赖顺序初始化各个模块
    if not initConfig() then
        return false
    end
    
    if not initLog() then
        return false
    end
    
    if not initErrorHandler() then
        return false
    end
    
    if not startConfigMonitoring() then
        return false
    end
    
    local Log = require("core.utils.log")
    local logger = Log:getLogger()
    logger:info("应用初始化完成")
    return true
end

-- 应用主入口函数
function App:run()
    local Log = require("core.utils.log")
    local logger = Log:getLogger()
    
    -- 初始化应用
    if not self:init() then
        logger:fatal("应用初始化失败，无法启动")
        return false
    end
    
    logger:info("应用启动成功")
    
    -- 这里可以添加应用的主循环或其他业务逻辑
    -- 例如：
    -- while true do
    --     -- 检查配置变更
    --     require("core.utils.config"):checkForChanges()
    --     -- 其他业务逻辑
    --     coroutine.yield()
    -- end
    
    return true
end

-- 应用退出函数
function App:exit(code)
    local Log = require("core.utils.log")
    local logger = Log:getLogger()
    
    logger:info("应用正在退出，退出码: " .. (code or 0))
    
    -- 清理资源
    -- 例如：关闭网络连接、保存数据等
    
    return true
end

-- 如果直接运行main.lua，则启动应用
if debug.getinfo(2) == nil then
    local success = App:run()
    if not success then
        App:exit(1)
    end
end

return App