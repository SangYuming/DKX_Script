local Log = require("core.utils.log")
local GlobalError = require("core.utils.global_error")

local logger = Log:getModule("test_error_demo")

local PaymentService = {}

-- 示例1
function PaymentService:processPayment(orderId, amount)
     -- 使用GloabalError.base捕获可能发生的异常
    local success, result = GlobalError.base(
        function()
            logger:info("Start processing payment, orderId:" .. orderId, "amount:" .. amount)

            -- 
            if not orderId or orderId <= 0  then 
                error("Invalid orderId")
            end

            if not amount or amount <= 0 then
                error("The payment amount must be greater than 0")
            end

            local paymentId = "PAY" .. os.time()
            logger:info("Payment processed successfully, paymentId:" .. paymentId)

            return {
                paymentId = paymentId, status = "success"
            }
        end
    )

    if not success then
        logger:warn("支付处理失败,订单ID:", orderId)
        return { status = "FAILED", error = result.message }
    end

end


local main = function()
    local paymentService = PaymentService
    paymentService.processPayment("1001", 100)
end

main()
