-- [[Log模块与GlobalError模块的使用]]

-- 导入
local Log = require("core.utils.log")

-- 获取日志示例
local logger = Log:getModule("test_log_error")

local UserService = {}

-- 示例一：普通信息日志
function UserService:getUserInfo(userId)
    logger:info("获取用户信息userId:", userId)

    local user = { id = userId, name = "测试用户" }

    logger:debug("用户信息: %s", user)
    return user
end

-- 示例二:警告日志
function UserService:validateUserInput(input)
    if not input then
        logger:warn("用户输入为空")
        return false
    end
end

-- 示例三：错误日志
function UserService:updateUserInfo(userId, data)
    if not data then
        logger:error("更新用户失败,用户ID:", userId)
        return false
    end
end

-- 测试运行
local log_main = function()
    local userService  = UserService

    userService:getUserInfo("123");

    userService:validateUserInput()

    userService:updateUserInfo("123")

end

log_main()
