-- [[
-- 个人测试文件
-- 用于验证框架有效性，不做其他用途
-- ]]
local Config = require("core.utils.config")

Config:init()

local Log = require("core.utils.log")
local Constants = require("core.utils.constants")
local HttpApiClient = require("core.utils.http")

local logger = Log:getModule("api_demo")

local enumNames = Constants:getEnumNames()
logger:info(string.format("枚举名称: %s", table.concat(enumNames, ", ")))


for _, enumName in ipairs(enumNames) do
    local validValues = Constants:getEnumValues(enumName)
    logger:info(string.format("枚举'%s'的有效值: %s", enumName, table.concat(validValues, ", ")))
end


logger:info("------test 2 ---------")
local validTypesID = 10

local valid, err = Constants:validateEnum("TypesID", validTypesID)

if valid then
    logger:info(string.format("TypesID=%d 是有效的枚举值 (%s)", validTypesID, Constants:getEnumName("TypesID", validTypesID)))
else
    logger:error(err)
end


logger:info("------test 3 ---------")

local function createEnum(tb1, start_idex)
    local enum_tb1 = {}
    local enum_idx = start_idex or 0

    for idx, val in ipairs(tb1) do
        enum_tb1[val] = idx + enum_idx
    end

    return enum_tb1
end

local TypesIDEnum = createEnum(Constants:getEnumValues("TypesID"), 100)
for key, val in pairs(TypesIDEnum) do
    logger:info(string.format("TypesIDEnum[%s] = %d", key, val))
end
