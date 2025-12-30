--[[
基础模块类：BaseModule
@desc：提供统一的模块初始化、配置管理、日志记录和事件处理功能
@author：SangYuming
@version：1.0.0
]]

local BaseModule = {}
BaseModule.__index = BaseModule

-- 模块实例注册表
local moduleRegistry = {}

-- 创建新模块实例
function BaseModule:new(name)
    local instance = {
        name = name,
        config = {},
        logger = nil,
        eventHandlers = {}
    }
    setmetatable(instance, self)
    
    -- 注册模块实例
    moduleRegistry[name] = instance
    
    return instance
end

-- 初始化模块
function BaseModule:init()
    -- 初始化日志
    self:initLogger()
    
    -- 初始化配置
    self:initConfig()
    
    -- 注册配置变更监听
    self:registerConfigListener()
    
    self.logger:info("模块初始化完成")
    return self
end

-- 初始化日志
function BaseModule:initLogger()
    -- 避免循环依赖：Log模块继承自BaseModule，所以不能在BaseModule中直接加载Log模块
    -- 子类可以重写此方法来初始化自己的日志
    -- 例如：
    -- local Log = require("core.utils.log")
    -- self.logger = Log:getModule(self.name)
    return self
end

-- 初始化配置
function BaseModule:initConfig()
    local Config = require("core.utils.config")
    -- 子类可以重写此方法来加载特定的配置
    self.config = Config:get(self.name:lower(), {})
    return self
end

-- 注册配置变更监听
function BaseModule:registerConfigListener()
    local Config = require("core.utils.config")
    Config:onChange(function(oldConfig, newConfig)
        self:onConfigChange(oldConfig, newConfig)
    end)
    return self
end

-- 配置变更回调
function BaseModule:onConfigChange(oldConfig, newConfig)
    -- 子类可以重写此方法来处理配置变更
    self:initConfig()
    self.logger:info("配置已更新")
    return self
end

-- 注册事件处理器
function BaseModule:on(eventName, handler)
    if not self.eventHandlers[eventName] then
        self.eventHandlers[eventName] = {}
    end
    table.insert(self.eventHandlers[eventName], handler)
    return self
end

-- 触发事件
function BaseModule:emit(eventName, ...)
    if self.eventHandlers[eventName] then
        for _, handler in ipairs(self.eventHandlers[eventName]) do
            local success, err = pcall(handler, ...)
            if not success then
                self.logger:error("事件处理失败:", eventName, "错误:", err)
            end
        end
    end
    return self
end

-- 获取模块实例
function BaseModule:getInstance(name)
    return moduleRegistry[name]
end

-- 获取所有模块实例
function BaseModule:getAllInstances()
    return moduleRegistry
end

-- 初始化所有模块
function BaseModule:initAll()
    for name, instance in pairs(moduleRegistry) do
        instance:init()
    end
    return self
end

return BaseModule
