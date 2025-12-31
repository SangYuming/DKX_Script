--[[
常量模块：Constants
@desc：管理系统中的所有常量和枚举值
@author：SangYuming
@version：1.0.0
]]

-- 加载必要的模块
local Config = require("core.utils.config")

local Constants = {}

-- 枚举值缓存
Constants.enums = {}

-- 初始化模块
function Constants:init()
    self:initConfig()
    return self
end

-- 重写初始化配置方法
function Constants:initConfig()
    -- 从配置中心加载枚举定义
    local enumsConfig = Config:get("enums", {})
    
    -- 构建枚举值映射
    for enumName, enumDef in pairs(enumsConfig) do
        if type(enumDef) == "table" and enumDef.values then
            self.enums[enumName] = {
                _desc = enumDef._desc or "",
                values = enumDef.values,
                valueSet = {},
                nameMap = {}
            }
            
            -- 构建值集合和名称映射
            for value, name in pairs(enumDef.values) do
                local numValue = tonumber(value)
                if numValue then
                    self.enums[enumName].valueSet[numValue] = true
                    self.enums[enumName].nameMap[numValue] = name
                end
            end
        end
    end
    
    return self
end

-- 获取枚举定义
function Constants:getEnum(enumName)
    return self.enums[enumName]
end

-- 检查值是否在枚举中
function Constants:isEnumValue(enumName, value)
    local enum = self.enums[enumName]
    if not enum then
        return false
    end
    return enum.valueSet[value] == true
end

-- 获取枚举值的名称
function Constants:getEnumName(enumName, value)
    local enum = self.enums[enumName]
    if not enum then
        return nil
    end
    return enum.nameMap[value]
end

-- 获取所有枚举名称
function Constants:getEnumNames()
    local names = {}
    for name, _ in pairs(self.enums) do
        table.insert(names, name)
    end
    return names
end

-- 获取枚举的所有有效值
function Constants:getEnumValues(enumName)
    local enum = self.enums[enumName]
    if not enum then
        return {}
    end
    
    local values = {}
    for value, _ in pairs(enum.valueSet) do
        table.insert(values, value)
    end
    table.sort(values)
    return values
end

-- 验证参数是否符合枚举定义
function Constants:validateEnum(enumName, value)
    if not self:isEnumValue(enumName, value) then
        local validValues = self:getEnumValues(enumName)
        local valueStr = type(value) == "string" and value or tostring(value)
        return false, string.format("值'%s'不在枚举'%s'的有效值中，有效值: %s", 
            valueStr, enumName, table.concat(validValues, ", "))
    end
    return true
end

-- 初始化模块
Constants:init()

return Constants
