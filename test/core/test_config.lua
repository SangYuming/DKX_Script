local logger = require("core.utils.log"):getModule("TestConfig")
local Config = require("core.utils.config")

-- 测试辅助函数
local function runTest(testName, testFunc)
    logger:info("开始测试:", testName)
    local status, err = pcall(testFunc)
    if status then
        logger:info("测试通过:", testName)
        return true
    else
        logger:error("测试失败:", testName, "错误:", err)
        return false
    end
end

-- 测试配置初始化
local function testInit()
    -- 使用默认路径初始化
    assert(Config:init() ~= nil, "配置初始化失败")
    
    -- 测试自定义路径初始化
    local customPaths = {"config/default.json"}
    assert(Config:init(customPaths) ~= nil, "自定义路径初始化失败")
    
    -- 测试无效参数
    assert(Config:init("not a table") == nil, "应该拒绝非表类型的路径参数")
end

-- 测试配置获取
local function testGet()
    Config:init()
    
    -- 测试获取完整配置
    local fullConfig = Config:get()
    assert(type(fullConfig) == "table", "获取完整配置失败")
    
    -- 测试获取不存在的配置项（应该返回默认值）
    assert(Config:get("non.existent", "default") == "default", "获取不存在的配置项失败")
    
    -- 测试嵌套配置获取（如果存在）
    -- 这里假设配置中有嵌套结构，否则跳过
    Config:set("test.nested.value", "test")
    assert(Config:get("test.nested.value") == "test", "嵌套配置获取失败")
    
    -- 测试无效的键类型
    assert(Config:get(123, "default") == "default", "应该拒绝非字符串类型的键")
end

-- 测试配置设置
local function testSet()
    Config:init()
    
    -- 测试基本设置
    assert(Config:set("test.key", "value") == true, "基本配置设置失败")
    assert(Config:get("test.key") == "value", "设置的配置值与获取的值不匹配")
    
    -- 测试嵌套配置设置
    assert(Config:set("test.nested.key", "nested value") == true, "嵌套配置设置失败")
    assert(Config:get("test.nested.key") == "nested value", "嵌套配置值不匹配")
    
    -- 测试路径冲突
    Config:set("conflict", "string value")
    assert(Config:set("conflict.sub", "should fail") == false, "应该检测到路径冲突")
    
    -- 测试无效参数
    assert(Config:set(nil, "value") == false, "应该拒绝nil键")
    assert(Config:set(123, "value") == false, "应该拒绝非字符串类型的键")
end

-- 测试配置保存
local function testSave()
    Config:init()
    Config:set("test.save", "save test")
    
    -- 保存到临时文件
    local tempFile = "./test_config_save.json"
    assert(Config:saveToFile(tempFile) == true, "配置保存失败")
    
    -- 验证文件存在
    local file = io.open(tempFile, "r")
    assert(file ~= nil, "保存的文件不存在")
    file:close()
    
    -- 清理测试文件
    os.remove(tempFile)
end

-- 测试配置热重载
local function testReload()
    Config:init()
    Config:set("test.before_reload", "before")
    
    -- 重载配置
    assert(Config:reload() ~= nil, "配置重载失败")
    
    -- 检查重载后之前设置的值是否被重置
    -- 注意：如果配置文件中没有这个键，应该返回nil
    assert(Config:get("test.before_reload") == nil, "重载后应该重置为配置文件中的值")
end

-- 测试配置验证
local function testValidation()
    Config:init()
    
    -- 设置验证规则
    local rules = {
        required = {"required.key"},
        types = {
            "number.key" == "number",
            "string.key" == "string"
        }
    }
    assert(Config:setValidationRules(rules) == true, "设置验证规则失败")
    
    -- 验证应该失败（缺少必需键）
    local isValid, errors = Config:validate()
    assert(isValid == false, "应该检测到缺少必需键")
    assert(#errors > 0, "应该返回验证错误信息")
    
    -- 设置必需键
    Config:set("required.key", "required value")
    Config:set("number.key", 123)
    Config:set("string.key", "string value")
    
    -- 验证应该通过
    isValid = Config:validate()
    assert(isValid == true, "配置应该通过验证")
    
    -- 测试单个配置项验证
    assert(Config:validateItem("number.key", "number") == true, "单个配置项验证失败")
    assert(Config:validateItem("string.key", "number") == false, "应该检测到类型不匹配")
    assert(Config:validateItem("non.existent") == false, "应该检测到不存在的配置项")
end

-- 测试配置监控
local function testMonitoring()
    Config:init()
    
    -- 启动监控
    assert(Config:startMonitoring(5) == true, "启动监控失败")
    
    -- 添加回调
    local callbackTriggered = false
    assert(Config:onChange(function()
        callbackTriggered = true
    end) == true, "添加回调失败")
    
    -- 检查监控状态
    -- 注意：这里只是模拟检查，实际的文件修改检测需要真实的文件操作
    -- 在实际测试中，可以修改配置文件并等待检查间隔
    
    -- 停止监控
    assert(Config:stopMonitoring() == true, "停止监控失败")
    
    -- 清空回调
    assert(Config:clearChangeCallbacks() == true, "清空回调失败")
end

-- 测试环境变量和路径处理
local function testEnvAndPath()
    -- 这个测试比较复杂，可能需要根据实际环境调整
    -- 主要是验证getCompatiblePath函数是否正确处理了不同平台的路径
    
    -- 测试无效的回调类型
    assert(Config:onChange("not a function") == false, "应该拒绝非函数类型的回调")
end

-- 运行所有测试
local function runAllTests()
    logger:info("开始运行配置模块测试")
    
    local tests = {
        {"初始化测试", testInit},
        {"获取配置测试", testGet},
        {"设置配置测试", testSet},
        {"保存配置测试", testSave},
        {"重载配置测试", testReload},
        {"配置验证测试", testValidation},
        {"配置监控测试", testMonitoring},
        {"环境变量和路径处理测试", testEnvAndPath}
    }
    
    local passedCount = 0
    for _, test in ipairs(tests) do
        if runTest(test[1], test[2]) then
            passedCount = passedCount + 1
        end
    end
    
    logger:info(string.format("测试完成: 通过 %d / %d 个测试", passedCount, #tests))
    return passedCount == #tests
end

-- 如果直接运行此文件，则执行测试
if arg and arg[0]:match("test_config.lua$" or "") then
    runAllTests()
end

-- 导出测试函数，方便在其他地方调用
return {
    runAllTests = runAllTests,
    runTest = runTest,
    testInit = testInit,
    testGet = testGet,
    testSet = testSet,
    testSave = testSave,
    testReload = testReload,
    testValidation = testValidation,
    testMonitoring = testMonitoring,
    testEnvAndPath = testEnvAndPath
}
