# 实现HTTP封装类

## 1. 现有基础设施工具类分析

经过检查，现有三个基础设施工具类都已经支持动态配置：

- **Config工具类**：支持从多个JSON文件加载配置，支持环境变量覆盖，支持配置验证和热重载
- **Log工具类**：基于BaseModule构建，支持从配置中心获取配置，支持动态调整日志级别和格式
- **GlobalError工具类**：基于BaseModule构建，支持从配置中心获取配置，支持动态调整全局异常捕获开关

## 2. HTTP封装类设计

### 2.1 设计思路
- 基于BaseModule构建，遵循现有模块结构
- 提供简洁的API，隐藏底层引擎API复杂性
- 自动处理headers的json编码
- 自动处理请求参数的json编码
- 统一处理响应的json解码
- 统一的错误处理机制
- 支持配置化的超时时间和默认headers
- 支持日志记录请求和响应信息

### 2.2 配置结构
```json
"http": {
  "timeout": 10000,
  "defaultHeaders": {
    "Content-Type": "application/x-www-form-urlencoded"
  },
  "enableLog": true,
  "logLevel": "INFO"
}
```

### 2.3 实现步骤
1. 创建`http.lua`文件，继承BaseModule
2. 实现`initConfig`方法，从配置中心获取HTTP配置
3. 实现`get`方法，封装`httpget`引擎API
4. 实现`post`方法，封装`httppost`引擎API
5. 实现请求参数和headers的自动处理
6. 实现响应的自动处理和错误处理
7. 实现配置验证规则
8. 添加日志记录

## 3. API设计

```lua
-- GET请求
local response, err = http:get(url, params, options)

-- POST请求（query方式）
local response, err = http:post(url, params, options)

-- POST请求（json方式）
local response, err = http:post(url, params, { method = "json" })
```

## 4. 实现细节

- 支持配置化的默认超时时间
- 支持动态添加默认headers
- 自动根据请求方式处理参数编码
- 自动处理headers的json编码
- 统一处理响应的json解码
- 支持请求和响应的日志记录
- 集成GlobalError进行错误处理
- 支持配置验证和变更监听

现在我将开始实现HTTP封装类。