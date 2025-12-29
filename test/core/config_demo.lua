-- config_demo.lua
-- 配置模块使用示例
-- 此示例展示如何使用config模块进行配置管理、环境变量设置、配置验证和监控

-- 引入配置模块和日志模块
local logger = require("core.utils.log"):getModule("ConfigDemo")
local Config = require("core.utils.config")

-- 定义示例函数
local function runDemo()
    logger:info("=== Config模块使用示例开始 ===")
    
    -- 1. 配置文件和环境变量说明
    logger:info("\n1. 配置文件和环境变量说明:")
    logger:info("   - 配置文件结构: config/default.json (默认配置)")
    logger:info("                 config/development.json 或 config/production.json (环境特定配置)")
    logger:info("                 config/local.json (本地配置，优先级最高)")
    logger:info("   - 环境变量设置: APP_ENV=development (指定当前环境)")
    logger:info("   - 在Windows命令行设置环境变量: set APP_ENV=development")
    logger:info("   - 在PowerShell设置环境变量: $env:APP_ENV = 'development'")
    logger:info("   - 在Linux/Mac设置环境变量: export APP_ENV=development")
    
    -- 2. 基本初始化和使用
    logger:info("\n2. 基本初始化和使用:")
    
    -- 2.1 使用默认配置路径初始化
    logger:info("   2.1 使用默认配置路径初始化:")
    local config = Config:init()
    if config then
        logger:info("      ✅ 配置初始化成功")
    else
        logger:error("      ❌ 配置初始化失败")
    end
    
    -- 2.2 使用自定义配置路径初始化
    logger:info("   2.2 使用自定义配置路径初始化:")
    local customPaths = {
        "./config/custom_default.json",
        "./config/custom_env.json"
    }
    local customConfig = Config:init(customPaths)
    if customConfig then
        logger:info("      ✅ 自定义配置初始化成功 (如果文件不存在会使用默认值)")
    else
        logger:error("      ❌ 自定义配置初始化失败")
    end
    
    -- 重置回默认配置
    Config:init()
    
    -- 3. 配置获取示例
    logger:info("\n3. 配置获取示例:")
    
    -- 3.1 获取完整配置
    logger:info("   3.1 获取完整配置:")
    local fullConfig = Config:get()
    logger:info("      完整配置类型:", type(fullConfig))
    
    -- 3.2 获取单个配置项
    logger:info("   3.2 获取单个配置项:")
    -- 设置一些示例配置用于演示
    Config:set("app.name", "ConfigDemo")
    Config:set("app.version", "1.0.0")
    
    local appName = Config:get("app.name")
    local appVersion = Config:get("app.version")
    local nonExistent = Config:get("non.existent", "default_value")
    
    logger:info("      app.name =", appName)
    logger:info("      app.version =", appVersion)
    logger:info("      不存在的配置项（带默认值） =", nonExistent)
    
    -- 3.3 获取嵌套配置项
    logger:info("   3.3 获取嵌套配置项:")
    Config:set("database.mysql.host", "localhost")
    Config:set("database.mysql.port", 3306)
    Config:set("database.mysql.credentials.username", "admin")
    
    local dbHost = Config:get("database.mysql.host")
    local dbPort = Config:get("database.mysql.port")
    local dbUser = Config:get("database.mysql.credentials.username")
    
    logger:info("      database.mysql.host =", dbHost)
    logger:info("      database.mysql.port =", dbPort)
    logger:info("      database.mysql.credentials.username =", dbUser)
    
    -- 4. 配置设置示例
    logger:info("\n4. 配置设置示例:")
    
    -- 4.1 设置基本配置
    logger:info("   4.1 设置基本配置:")
    local setResult = Config:set("server.port", 8081)
    logger:info("      设置server.port = 8081: ", setResult and "成功" or "失败")
    logger:info("      获取设置后的值: ", Config:get("server.port"))
    
    -- 4.2 设置嵌套配置
    logger:info("   4.2 设置嵌套配置:")
    setResult = Config:set("server.settings.debug", true)
    logger:info("      设置server.settings.debug = true: ", setResult and "成功" or "失败")
    
    -- 4.3 演示路径冲突
    logger:info("   4.3 演示路径冲突:")
    Config:set("api", "http://localhost")  -- 先设置为字符串
    setResult = Config:set("api.endpoint", "users")  -- 尝试在字符串上设置子属性
    logger:info("      尝试在字符串上设置子属性: ", setResult and "成功" or "失败")
    
    -- 5. 配置保存和重载示例
    logger:info("\n5. 配置保存和重载示例:")
    
    -- 5.1 保存配置到文件
    logger:info("   5.1 保存配置到文件:")
    local tempFile = "./config/config_demo_save.json"
    setResult = Config:saveToFile(tempFile)
    logger:info("      保存配置到" .. tempFile .. ": ", setResult and "成功" or "失败")
    
    -- 5.2 热重载配置
    logger:info("   5.2 热重载配置:")
    Config:set("demo.temp_value", "这是临时设置的值")
    logger:info("      重载前的临时值: ", Config:get("demo.temp_value"))
    
    local reloadResult = Config:reload()
    logger:info("      配置重载: ", reloadResult and "成功" or "失败")
    logger:info("      重载后的临时值: ", Config:get("demo.temp_value") or "nil (被重置)")
    
    -- 6. 配置验证示例
    logger:info("\n6. 配置验证示例:")
    
    -- 6.1 设置验证规则
    logger:info("   6.1 设置验证规则:")
    local validationRules = {
        -- 必需的配置项
        required = {
            "app.name",
            "app.version"
        },
        -- 类型验证规则
        types = {
            ["server.port"] = "number",
            ["app.version"] = "string",
            ["server.settings.debug"] = "boolean"
        }
    }
    
    setResult = Config:setValidationRules(validationRules)
    logger:info("      设置验证规则: ", setResult and "成功" or "失败")
    
    -- 6.2 执行验证
    logger:info("   6.2 执行验证:")
    local isValid, errors = Config:validate()
    logger:info("      配置验证结果: ", isValid and "通过" or "失败")
    
    if not isValid and errors then
        logger:info("      验证错误:")
        for i, err in ipairs(errors) do
            logger:info("        " .. i .. ". " .. err)
        end
    end
    
    -- 6.3 单个配置项验证
    logger:info("   6.3 单个配置项验证:")
    local isPortValid = Config:validateItem("server.port", "number")
    local isNameValid = Config:validateItem("app.name", "number")  -- 应该失败，因为是字符串
    
    logger:info("      验证server.port为数字: ", isPortValid and "通过" or "失败")
    logger:info("      验证app.name为数字: ", isNameValid and "通过" or "失败")
    
    -- 7. 配置监控示例
    logger:info("\n7. 配置监控示例:")
    
    -- 7.1 启动配置监控
    logger:info("   7.1 启动配置监控:")
    local monitorResult = Config:startMonitoring(10)  -- 每10秒检查一次
    logger:info("      启动配置监控: ", monitorResult and "成功" or "失败")
    logger:info("      监控间隔: 10秒")
    
    -- 7.2 添加配置变更回调
    logger:info("   7.2 添加配置变更回调:")
    local callbackCount = 0
    
    local onChangeCallback = function(oldConfig, newConfig)
        callbackCount = callbackCount + 1
        logger:info("      📢 检测到配置变更！回调被触发 (次数: " .. callbackCount .. ")")
        -- 这里可以添加自定义逻辑，比如根据配置变更重启服务等
    end
    
    setResult = Config:onChange(onChangeCallback)
    logger:info("      添加配置变更回调: ", setResult and "成功" or "失败")
    
    -- 7.3 模拟配置变更检测
    logger:info("   7.3 模拟配置变更检测:")
    logger:info("      注意: 在实际应用中，您需要在应用的主循环中定期调用以下方法:")
    logger:info("      local hasChanges = Config:checkForChanges()")
    logger:info("      if hasChanges then logger:info(\"配置已自动更新\") end")
    
    -- 7.4 停止监控示例
    logger:info("   7.4 停止监控示例:")
    logger:info("      停止监控代码: Config:stopMonitoring()")
    logger:info("      清空回调代码: Config:clearChangeCallbacks()")
    
    -- 8. 环境变量示例
    logger:info("\n8. 环境变量示例:")
    logger:info("   8.1 如何在代码中使用环境变量:")
    logger:info("      配置模块内部会自动使用以下逻辑获取环境变量:")
    logger:info("      local env = os.getenv('APP_ENV')")
    logger:info("      if not env then env = 'development' end  -- 默认值")
    
    logger:info("\n=== Config模块使用示例结束 ===")
    
    -- 清理临时文件
    if os.remove then
        local success, err = os.remove(tempFile)
        if success then
            logger:info("临时测试文件已清理: " .. tempFile)
        end
    end
    
    return true
end

-- 如果直接运行此文件，则执行示例
if arg and (arg[0]:match("config_demo.lua$" or "") or arg[1] == "run_config_demo") then
    runDemo()
end

-- 导出函数供其他模块调用
return {
    runDemo = runDemo
}
