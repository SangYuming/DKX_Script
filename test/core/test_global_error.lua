-- 测试全局异常处理模块
local Log = require("core.utils.log")
local GlobalError = require("core.utils.global_error")

-- 配置日志为DEBUG级别以便查看详细信息
Log:setLevel(Log.LEVELS.DEBUG)

print("=== 测试全局异常处理模块 ===\n")

-- 测试1: 基础异常捕获
print("1. 测试基础异常捕获")
local success, result = GlobalError.base(function()
    error("测试基础异常")
end)
print("捕获结果:", success, result)
print("")

-- 测试2: 带错误类型的异常捕获
print("2. 测试带错误类型的异常捕获")
success, result = GlobalError.type(function()
    error("测试业务异常")
end, GlobalError.ERROR_TYPES.BUSINESS)
print("捕获结果:", success, result)
print("")

-- 测试3: 注册自定义错误处理策略
print("3. 测试自定义错误处理策略")
GlobalError:registerHandler("custom_handler", function(errInfo)
    print("[自定义处理器] 捕获到错误:", errInfo.message)
    print("[自定义处理器] 错误类型:", errInfo.type)
    print("[自定义处理器] 错误代码:", errInfo.code)
    return "自定义处理结果"
end)

-- 使用自定义处理器
success, result = GlobalError.base(function()
    error("测试自定义处理器")
end, "custom_handler")
print("捕获结果:", success, result)
print("")

-- 测试4: 业务错误包装
print("4. 测试业务错误包装")
local businessError = GlobalError.wrapBusinessError("业务逻辑错误", {param = "value"})
print("包装的业务错误:")
for k, v in pairs(businessError) do
    print("  ", k, v)
end
print("")

-- 测试5: 正常执行的函数
print("5. 测试正常执行的函数")
success, result = GlobalError.base(function(a, b)
    return a + b
end, 10, 20)
print("执行结果:", success, result)
print("")

-- 测试6: 全局异常捕获
print("6. 测试全局异常捕获 (触发__G__TRACKBACK__)")
print("下面的错误将被全局异常处理器捕获")
print("----------------------------------------")

-- 触发全局异常
local function triggerGlobalError()
    error("全局异常测试")
end

local function callWithDelay()
    triggerGlobalError()
end

-- 使用pcall包装以防止脚本终止
local success, result = pcall(callWithDelay)
if not success then
    print("----------------------------------------")
    print("脚本继续执行...")
end

print("\n=== 测试完成 ===")
