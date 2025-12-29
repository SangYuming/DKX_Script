-- 测试日志模块
local Log = require("core.utils.log")

-- 测试链式调用
print("=== 测试链式调用 ===")
Log:setLevel(Log.LEVELS.INFO):enable(true):setConfig({ timeFormat = "%H:%M:%S" })

-- 测试全局日志实例
print("\n=== 测试全局日志实例 ===")
local globalLogger = Log:getLogger()
globalLogger:debug("这是一个调试日志")
globalLogger:info("这是一个信息日志")
globalLogger:warn("这是一个警告日志")
globalLogger:error("这是一个错误日志")
globalLogger:fatal("这是一个致命日志")

-- 测试模块日志实例
print("\n=== 测试模块日志实例 ===")
local moduleLogger1 = Log:getModule("Module1")
local moduleLogger2 = Log:getModule("Module2")

moduleLogger1:info("Module1的信息日志")
moduleLogger2:info("Module2的信息日志")

-- 测试模块级配置覆盖
print("\n=== 测试模块级配置覆盖 ===")
moduleLogger1:setConfig({ level = Log.LEVELS.ERROR, format = "[%LEVEL%] %MODULE%: %MESSAGE%" })
moduleLogger1:debug("Module1的调试日志(应该不显示)")
moduleLogger1:error("Module1的错误日志(应该以自定义格式显示)")
moduleLogger2:info("Module2的信息日志(应该以全局格式显示)")

-- 测试复杂参数和table处理
print("\n=== 测试复杂参数和table处理 ===")
globalLogger:debug("复杂参数测试", 123, true, nil, { key = "value", nested = { a = 1, b = 2 } })

-- 测试循环引用检测
print("\n=== 测试循环引用检测 ===")
local tbl = { name = "test" }
tbl.self = tbl
globalLogger:info("循环引用table:", tbl)

-- 测试深度限制
print("\n=== 测试深度限制 ===")
local deepTbl = { level1 = { level2 = { level3 = { level4 = "too deep" } } } }
globalLogger:info("深度嵌套table:", deepTbl)

-- 测试日志回调
print("\n=== 测试日志回调 ===")
Log:setConfig({ onLog = function(level, module, message, formatted) print("[回调] " .. formatted) end })
globalLogger:info("测试日志回调")

-- 测试禁用日志
print("\n=== 测试禁用日志 ===")
Log:enable(false)
globalLogger:info("这条日志应该不显示")
Log:enable(true)
globalLogger:info("日志已重新启用")

print("\n=== 所有测试完成 ===")

