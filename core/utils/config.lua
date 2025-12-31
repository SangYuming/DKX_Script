--[[
配置文件读取模块：Config
@desc：读取和合并多个配置文件，支持环境变量覆盖和自定义路径
@author：SangYuming
@version：1.0.0
]]

local Config = {}

local dkjson = require("core.utils.dkjson")

-- 简单的日志输出函数，避免依赖log模块
local function log(level, ...)
    local args = { ... }
    local msg = table.concat(args, " ")
    print(string.format("[%s][Config] %s", level, msg))
end

-- 存储合并后的最终配置
local configData = {}

-- 存储原始配置
local rawConfigs = {}

-- 获取环境变量，如果不存在则返回默认值
local function getEnv(envName, defaultValue)
    local value = os.getenv(envName)
    if not value then
        log("DEBUG", "环境变量", envName, "未设置，使用默认值:", defaultValue)
        return defaultValue
    end
    return value
end

-- 配置文件路径 - 使用平台兼容的路径分隔符
local configPaths = {
    "config" .. "/" .. "default.json",
    "config" .. "/" .. "app.json",
    "config" .. "/" .. "constants.json"
}

-- 获取平台兼容的文件路径
local function getCompatiblePath(path)
    -- 规范化路径，替换多个斜杠为单个斜杠
    path = path:gsub("[\\/]+", "/")
    
    -- 在Windows上，将正斜杠替换为反斜杠
    if package.config:sub(1,1) == '\\' then
        path = path:gsub("/", "\\")
    end
    
    return path
end

-- 搜索配置文件，在多个可能的目录中查找
local function findConfigFile(filename)
    -- 默认搜索目录
    local searchDirs = {
        ".",
        "./config",
        "./script/config",
        "../config"
    }
    
    -- 尝试在各个目录中查找文件
    for _, dir in ipairs(searchDirs) do
        local filePath = getCompatiblePath(dir .. "/" .. filename)
        local file = io.open(filePath, "r")
        if file then
            file:close()
            log("DEBUG", "在", dir, "中找到配置文件:", filename)
            return filePath
        end
    end
    
    log("WARN", "在所有搜索目录中都未找到配置文件:", filename)
    return nil
end

-- 加载JSON配置文件
local function loadJsonConfig(filePath)
    -- 如果文件路径不存在，尝试搜索
    local file = io.open(filePath, "r")
    if not file then
        -- 提取文件名
        local filename = filePath:match("[^/\\]+$" or filePath)
        local foundPath = findConfigFile(filename)
        if foundPath then
            filePath = foundPath
        else
            log("WARN", "配置文件不存在:", filePath)
            return nil
        end
    else
        file:close()
    end
    
    -- 转换为平台兼容的路径
    local compatiblePath = getCompatiblePath(filePath)
    
    file = io.open(compatiblePath, "r")
    if not file then
        log("WARN", "无法打开配置文件:", compatiblePath)
        return nil
    end

    local content = file:read("*a")
    file:close()

    local status, result = pcall(dkjson.decode, content)
    if not status then
        log("ERROR", "配置文件解析失败:", compatiblePath, ", 错误:", result)
        return nil
    end

    return result
end

-- 深度合并表
local function mergeTables(dest, src)
    if not src then return dest end
    if not dest then dest = {} end
    
    for k, v in pairs(src) do
        if type(v) == "table" and type(dest[k]) == "table" then
            dest[k] = mergeTables(dest[k], v)
        else
            dest[k] = v
        end
    end
    
    return dest
end

-- 初始化配置
function Config:init(customPaths)
    log("INFO", "开始初始化配置")
    
    -- 检查customPaths参数类型
    if customPaths and type(customPaths) ~= "table" then
        log("ERROR", "自定义路径参数必须是表类型")
        return nil
    end
    
    -- 使用自定义路径或默认路径
    local paths = customPaths or configPaths
    
    -- 重置配置
    configData = {}
    rawConfigs = {}

    -- 按顺序加载并合并配置
    for i, path in ipairs(paths) do
        -- 检查路径是否为字符串
        if type(path) == "string" then
            local config = loadJsonConfig(path)
            if config then
                log("INFO", "成功加载配置文件:", path)
                rawConfigs[path] = config
                configData = mergeTables(configData, config)
            end
        else
            log("WARN", "配置路径必须是字符串类型，忽略第", i, "个路径")
        end
    end

    log("INFO", "配置初始化完成")
    return self
end

-- 获取配置项
function Config:get(key, defaultValue)
    -- 如果配置数据为空，返回默认值
    if not configData or next(configData) == nil then
        log("WARN", "配置数据为空")
        return defaultValue
    end
    
    -- 如果没有提供key，返回完整配置
    if not key then return configData end
    
    -- 检查key的类型
    if type(key) ~= "string" then
        log("ERROR", "配置键必须是字符串类型")
        return defaultValue
    end
    
    -- 使用点分隔符访问嵌套配置
    local keys = {}
    for k in key:gmatch("[^.]+" ) do
        table.insert(keys, k)
    end
    
    -- 如果key是空字符串或只有点，返回完整配置
    if #keys == 0 then
        log("WARN", "无效的配置键:", key)
        return configData
    end
    
    local value = configData
    for _, k in ipairs(keys) do
        if type(value) ~= "table" or value[k] == nil then
            return defaultValue
        end
        value = value[k]
    end
    
    return value
end

-- 动态设置配置项
function Config:set(key, value)
    -- 如果配置数据未初始化，先初始化
    if not configData then
        configData = {}
        log("WARN", "配置数据未初始化，已自动创建")
    end
    
    -- 检查key参数
    if not key then 
        log("ERROR", "配置键不能为空")
        return false 
    end
    
    -- 检查key的类型
    if type(key) ~= "string" then
        log("ERROR", "配置键必须是字符串类型")
        return false
    end
    
    -- 支持使用点分隔符设置嵌套配置
    local keys = {}
    for k in key:gmatch("[^.]+" ) do
        table.insert(keys, k)
    end
    
    -- 验证键的有效性
    if #keys == 0 then
        log("ERROR", "无效的配置键:", key)
        return false
    end
    
    -- 防止覆盖已有配置的非表值
    local current = configData
    for i, k in ipairs(keys) do
        if i == #keys then
            -- 如果设置的值与现有值相同，不需要更新
            if current[k] == value then
                log("DEBUG", "配置值未变化:", key)
                return true
            end
            current[k] = value
        else
            if not current[k] then
                current[k] = {}
            elseif type(current[k]) ~= "table" then
                log("WARN", "设置配置项时路径冲突:", key, "，已有值为:", current[k])
                return false
            end
            current = current[k]
        end
    end
    
    log("DEBUG", "设置配置项:", key, "=", value)
    return true
end

-- 保存配置到文件
function Config:saveToFile(filePath)
    -- 转换为平台兼容的路径
    local compatiblePath = getCompatiblePath(filePath)
    
    local file = io.open(compatiblePath, "w")
    if not file then
        log("ERROR", "无法保存配置到文件:", compatiblePath)
        return false
    end
    
    local content = dkjson.encode(configData, { indent = true })
    file:write(content)
    file:close()
    
    log("INFO", "配置已保存到文件:", compatiblePath)
    return true
end

-- 热重载配置
function Config:reload()
    log("INFO", "开始热重载配置")
    return self:init()
end

-- 获取原始配置
function Config:getRawConfig(filePath)
    return rawConfigs[filePath]
end

-- 导出配置为字符串
function Config:toString()
    return dkjson.encode(configData, { indent = true })
end

-- 存储验证规则，按模块分类
local validationRules = {
    global = {
        -- 全局必需的配置项列表
        required = {},
        -- 全局配置项类型规则
        types = {}
    }
}

-- 设置全局验证规则
function Config:setValidationRules(rules)
    return self:setModuleValidationRules("global", rules)
end

-- 设置模块验证规则
function Config:setModuleValidationRules(moduleName, rules)
    if type(moduleName) ~= "string" then
        log("ERROR", "模块名称必须是字符串类型")
        return false
    end
    
    if type(rules) ~= "table" then
        log("ERROR", "验证规则必须是表类型")
        return false
    end
    
    -- 初始化模块验证规则
    if not validationRules[moduleName] then
        validationRules[moduleName] = {
            required = {},
            types = {}
        }
    end
    
    -- 更新必需配置项规则
    if rules.required and type(rules.required) == "table" then
        validationRules[moduleName].required = {}
        for _, key in ipairs(rules.required) do
            if type(key) == "string" then
                validationRules[moduleName].required[key] = true
            end
        end
    end
    
    -- 更新类型验证规则
    if rules.types and type(rules.types) == "table" then
        validationRules[moduleName].types = rules.types
    end
    
    log("INFO", "模块", moduleName, "的配置验证规则已更新")
    return true
end

-- 验证配置
function Config:validate(moduleName)
    if not configData or next(configData) == nil then
        log("ERROR", "配置数据为空，无法验证")
        return false, {}
    end
    
    local isValid = true
    local errors = {}
    
    -- 获取要验证的规则集
    local rulesets = {}
    if moduleName then
        -- 只验证指定模块的规则
        if validationRules[moduleName] then
            rulesets[moduleName] = validationRules[moduleName]
        end
    else
        -- 验证所有模块的规则，包括全局规则
        rulesets = validationRules
    end
    
    -- 遍历所有规则集进行验证
    for modName, rules in pairs(rulesets) do
        log("INFO", "开始验证模块", modName, "的配置")
        
        -- 检查必需的配置项
        for key, _ in pairs(rules.required) do
            local value = self:get(key)
            if value == nil then
                local errorMsg = string.format("模块 %s: 缺少必需的配置项: %s", modName, key)
                table.insert(errors, errorMsg)
                log("ERROR", errorMsg)
                isValid = false
            end
        end
        
        -- 检查配置项类型或自定义验证规则
        for key, rule in pairs(rules.types) do
            local value = self:get(key)
            if value ~= nil then
                local isInvalid = false
                local expectedTypeStr = "unknown"
                
                if type(rule) == "string" then
                    -- 简单类型检查
                    if type(value) ~= rule then
                        isInvalid = true
                    end
                    expectedTypeStr = rule
                elseif type(rule) == "function" then
                    -- 自定义验证函数
                    local success, result = pcall(rule, value)
                    if not success or not result then
                        isInvalid = true
                    end
                    expectedTypeStr = "custom function"
                end
                
                if isInvalid then
                    local errorMsg = string.format(
                        "模块 %s: 配置项 %s 验证失败，期望 %s，实际 %s", 
                        modName, key, expectedTypeStr, type(value)
                    )
                    table.insert(errors, errorMsg)
                    log("ERROR", errorMsg)
                    isValid = false
                end
            end
        end
    end
    
    -- 可以添加更多自定义验证逻辑
    
    if not isValid then
        log("WARN", string.format("配置验证失败，共 %d 个错误", #errors))
    else
        log("INFO", "配置验证通过")
    end
    
    return isValid, errors
end

-- 验证单个配置项
function Config:validateItem(key, expectedType)
    local value = self:get(key)
    
    if value == nil then
        log("ERROR", "配置项不存在:", key)
        return false
    end
    
    if expectedType and type(value) ~= expectedType then
        log("ERROR", string.format(
            "配置项 %s 类型错误，期望 %s，实际 %s", 
            key, expectedType, type(value)
        ))
        return false
    end
    
    return true
end

-- 配置监控相关
local monitorData = {
    enabled = false,
    interval = 60, -- 默认60秒检查一次
    lastCheckTime = 0,
    fileModTimes = {}, -- 存储文件的最后修改时间
    onChangeCallbacks = {} -- 配置变更时的回调函数
}

-- 检查文件是否被修改
local function checkFileChanges()
    local hasChanges = false
    
    for path, config in pairs(rawConfigs) do
        -- 尝试获取文件信息
        local file = io.open(getCompatiblePath(path), "r")
        if file then
            file:close()
            
            -- 获取文件修改时间（这里使用简化实现，实际可能需要平台特定的方法）
            -- 注意：Lua标准库没有直接获取文件修改时间的方法，这里需要根据实际环境调整
            -- 这里我们假设有一个自定义的getFileModTime函数，或者使用其他方式实现
            local modTime = os.time() -- 临时实现，实际应该获取文件的mtime
            
            if monitorData.fileModTimes[path] ~= modTime then
                log("INFO", "检测到配置文件变更:", path)
                monitorData.fileModTimes[path] = modTime
                hasChanges = true
            end
        end
    end
    
    return hasChanges
end

-- 重新加载修改的配置
local function reloadChangedConfigs()
    log("INFO", "开始重新加载变更的配置")
    
    -- 保存当前配置的副本，用于比较
    local oldConfig = dkjson.decode(dkjson.encode(configData))
    
    -- 重新加载所有配置文件
    local newConfigData = {}
    local newRawConfigs = {}
    
    for _, path in ipairs(configPaths) do
        local config = loadJsonConfig(path)
        if config then
            newRawConfigs[path] = config
            newConfigData = mergeTables(newConfigData, config)
        end
    end
    
    -- 更新配置数据
    configData = newConfigData
    rawConfigs = newRawConfigs
    
    -- 执行变更回调
    for _, callback in ipairs(monitorData.onChangeCallbacks) do
        if type(callback) == "function" then
            pcall(callback, oldConfig, configData)
        end
    end
    
    log("INFO", "配置重新加载完成")
    return true
end

-- 启动配置监控
function Config:startMonitoring(interval)
    -- 设置检查间隔
    if interval and type(interval) == "number" and interval > 0 then
        monitorData.interval = interval
    end
    
    -- 初始化文件修改时间记录
    monitorData.fileModTimes = {}
    for path, _ in pairs(rawConfigs) do
        monitorData.fileModTimes[path] = os.time() -- 临时实现
    end
    
    monitorData.enabled = true
    monitorData.lastCheckTime = os.time()
    
    log("INFO", "配置监控已启动，检查间隔:", monitorData.interval, "秒")
    return true
end

-- 停止配置监控
function Config:stopMonitoring()
    monitorData.enabled = false
    log("INFO", "配置监控已停止")
    return true
end

-- 检查配置变更（需要在事件循环中定期调用）
function Config:checkForChanges()
    if not monitorData.enabled then
        return false
    end
    
    local currentTime = os.time()
    if currentTime - monitorData.lastCheckTime >= monitorData.interval then
        monitorData.lastCheckTime = currentTime
        
        if checkFileChanges() then
            return reloadChangedConfigs()
        end
    end
    
    return false
end

-- 添加配置变更回调
function Config:onChange(callback)
    if type(callback) ~= "function" then
        log("ERROR", "回调必须是函数类型")
        return false
    end
    
    table.insert(monitorData.onChangeCallbacks, callback)
    log("INFO", "已添加配置变更回调")
    return true
end

-- 移除所有配置变更回调
function Config:clearChangeCallbacks()
    monitorData.onChangeCallbacks = {}
    log("INFO", "已清空所有配置变更回调")
    return true
end
return Config