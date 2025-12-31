--[[
HTTP配置测试脚本
@desc：测试Http模块能否正确获取配置数据
@author：SangYuming
@version：1.0.0
]]

-- 加载必要的模块
local Config = require("core.utils.config")

-- 初始化配置
Config:init()

-- 打印配置
local config = Config:get("http")
print("配置中心的HTTP配置:")
for k, v in pairs(config) do
    print("  " .. k .. ": " .. tostring(v))
    if type(v) == "table" then
        for subk, subv in pairs(v) do
            print("    " .. subk .. ": " .. tostring(subv))
        end
    end
end

-- 加载Http模块
local Http = require("core.utils.http")

-- 打印Http模块的配置
print("\nHttp模块的配置:")
for k, v in pairs(Http.config) do
    print("  " .. k .. ": " .. tostring(v))
    if type(v) == "table" then
        for subk, subv in pairs(v) do
            print("    " .. subk .. ": " .. tostring(subv))
        end
    end
end

print("\n测试完成")