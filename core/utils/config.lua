--[[
配置文件读取模块：Config
@desc：读取和合并多个配置文件，支持环境变量覆盖和自定义路径
@author：SangYuming
@version：1.0.0
]]

local Config = {}

local dkjson = require("core.utils.dkjson")
local Log = require("core.utils.log")
local logger = Log:getModule("Config")

-- 存储合并后的最终配置
local configData = {}

-- 存储原始配置
local rawConfigs = {}

-- 获取环境变量，如果不存在则返回默认值
local function getEnv(envName, defaultValue)
    local value = os.getenv(envName)
    if not value then
        logger:debug("环境变量", envName, "未设置，使用默认值:", defaultValue)
        return defaultValue
    end
    return value
end

-- 配置文件路径 - 使用平台兼容的路径分隔符
local configPaths = {
    "config" .. "/" .. "default.json",
    "config" .. "/" .. string.format("%s.json", getEnv("APP_ENV", "development")),
    "config" .. "/" .. "local.json"
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
            logger:debug("在", dir, "中找到配置文件:", filename)
            return filePath
        end
    end
    
    logger:warn("在所有搜索目录中都未找到配置文件:", filename)
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
            logger:warn("配置文件不存在:", filePath)
            return nil
        end
    else
        file:close()
    end
    
    -- 转换为平台兼容的路径
    local compatiblePath = getCompatiblePath(filePath)
    
    file = io.open(compatiblePath, "r")
    if not file then
        logger:warn("无法打开配置文件:", compatiblePath)
        return nil
    end

    local content = file:read("*a")
    file:close()

    local status, result = pcall(dkjson.decode, content)
    if not status then
        logger:error("配置文件解析失败:", compatiblePath, ", 错误:", result)
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
    logger:info("开始初始化配置")
    
    -- 检查customPaths参数类型
    if customPaths and type(customPaths) ~= "table" then
        logger:error("自定义路径参数必须是表类型")
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
                logger:info("成功加载配置文件:", path)
                rawConfigs[path] = config
                configData = mergeTables(configData, config)
            end
        else
            logger:warn("配置路径必须是字符串类型，忽略第", i, "个路径")
        end
    end

    logger:info("配置初始化完成")
    return self
end

-- 获取配置项
function Config:get(key, defaultValue)
    -- 如果配置数据为空，返回默认值
    if not configData or next(configData) == nil then
        logger:warn("配置数据为空")
        return defaultValue
    end
    
    -- 如果没有提供key，返回完整配置
    if not key then return configData end
    
    -- 检查key的类型
    if type(key) ~= "string" then
        logger:error("配置键必须是字符串类型")
        return defaultValue
    end
    
    -- 使用点分隔符访问嵌套配置
    local keys = {}
    for k in key:gmatch("[^.]+" ) do
        table.insert(keys, k)
    end
    
    -- 如果key是空字符串或只有点，返回完整配置
    if #keys == 0 then
        logger:warn("无效的配置键:", key)
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
        logger:warn("配置数据未初始化，已自动创建")
    end
    
    -- 检查key参数
    if not key then 
        logger:error("配置键不能为空")
        return false 
    end
    
    -- 检查key的类型
    if type(key) ~= "string" then
        logger:error("配置键必须是字符串类型")
        return false
    end
    
    -- 支持使用点分隔符设置嵌套配置
    local keys = {}
    for k in key:gmatch("[^.]+" ) do
        table.insert(keys, k)
    end
    
    -- 验证键的有效性
    if #keys == 0 then
        logger:error("无效的配置键:", key)
        return false
    end
    
    -- 防止覆盖已有配置的非表值
    local current = configData
    for i, k in ipairs(keys) do
        if i == #keys then
            -- 如果设置的值与现有值相同，不需要更新
            if current[k] == value then
                logger:debug("配置值未变化:", key)
                return true
            end
            current[k] = value
        else
            if not current[k] then
                current[k] = {}
            elseif type(current[k]) ~= "table" then
                logger:warn("设置配置项时路径冲突:", key, "，已有值为:", current[k])
                return false
            end
            current = current[k]
        end
    end
    
    logger:debug("设置配置项:", key, "=", value)
    return true
end

-- 保存配置到文件
function Config:saveToFile(filePath)
    -- 转换为平台兼容的路径
    local compatiblePath = getCompatiblePath(filePath)
    
    local file = io.open(compatiblePath, "w")
    if not file then
        logger:error("无法保存配置到文件:", compatiblePath)
        return false
    end
    
    local content = dkjson.encode(configData, { indent = true })
    file:write(content)
    file:close()
    
    logger:info("配置已保存到文件:", compatiblePath)
    return true
end

-- 热重载配置
function Config:reload()
    logger:info("开始热重载配置")
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

-- 存储验证规则
local validationRules = {
    -- 必需的配置项列表
    required = {},
    -- 配置项类型规则
    types = {}
}

-- 设置验证规则
function Config:setValidationRules(rules)
    if type(rules) ~= "table" then
        logger:error("验证规则必须是表类型")
        return false
    end
    
    -- 更新必需配置项规则
    if rules.required and type(rules.required) == "table" then
        validationRules.required = {}
        for _, key in ipairs(rules.required) do
            if type(key) == "string" then
                validationRules.required[key] = true
            end
        end
    end
    
    -- 更新类型验证规则
    if rules.types and type(rules.types) == "table" then
        validationRules.types = rules.types
    end
    
    logger:info("配置验证规则已更新")
    return true
end

-- 验证配置
function Config:validate()
    if not configData or next(configData) == nil then
        logger:error("配置数据为空，无法验证")
        return false
    end
    
    local isValid = true
    local errors = {}
    
    -- 检查必需的配置项
    for key, _ in pairs(validationRules.required) do
        local value = self:get(key)
        if value == nil then
            local errorMsg = string.format("缺少必需的配置项: %s", key)
            table.insert(errors, errorMsg)
            logger:error(errorMsg)
            isValid = false
        end
    end
    
    -- 检查配置项类型
    for key, expectedType in pairs(validationRules.types) do
        local value = self:get(key)
        if value ~= nil and type(value) ~= expectedType then
            local errorMsg = string.format(
                "配置项 %s 类型错误，期望 %s，实际 %s", 
                key, expectedType, type(value)
            )
            table.insert(errors, errorMsg)
            logger:error(errorMsg)
            isValid = false
        end
    end
    
    -- 可以添加更多自定义验证逻辑
    
    if not isValid then
        logger:warn(string.format("配置验证失败，共 %d 个错误", #errors))
    else
        logger:info("配置验证通过")
    end
    
    return isValid, errors
end

-- 验证单个配置项
function Config:validateItem(key, expectedType)
    local value = self:get(key)
    
    if value == nil then
        logger:error("配置项不存在:", key)
        return false
    end
    
    if expectedType and type(value) ~= expectedType then
        logger:error(string.format(
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
                logger:info("检测到配置文件变更:", path)
                monitorData.fileModTimes[path] = modTime
                hasChanges = true
            end
        end
    end
    
    return hasChanges
end

-- 重新加载修改的配置
local function reloadChangedConfigs()
    logger:info("开始重新加载变更的配置")
    
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
    
    logger:info("配置重新加载完成")
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
    
    logger:info("配置监控已启动，检查间隔:", monitorData.interval, "秒")
    return true
end

-- 停止配置监控
function Config:stopMonitoring()
    monitorData.enabled = false
    logger:info("配置监控已停止")
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
        logger:error("回调必须是函数类型")
        return false
    end
    
    table.insert(monitorData.onChangeCallbacks, callback)
    logger:info("已添加配置变更回调")
    return true
end

-- 移除所有配置变更回调
function Config:clearChangeCallbacks()
    monitorData.onChangeCallbacks = {}
    logger:info("已清空所有配置变更回调")
    return true
end
return Config