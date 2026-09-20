package cn.campus.campus_mobile

import com.tencent.mm.opensdk.modelbiz.WXLaunchMiniProgram
import com.tencent.mm.opensdk.openapi.IWXAPI
import com.tencent.mm.opensdk.openapi.WXAPIFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * 小程序拉起的原生实现 / the native side of mini-program launching.
 *
 * 路线 A：微信 OpenSDK 的 `WXLaunchMiniProgram`。这里只做三件事，且**每一件都把结果如实返回**
 * 给 Dart 侧：
 *
 *   1. `register(appId)` —— 把 AppID 注册进 SDK。返回 false 通常意味着该 AppID 不是开放平台里
 *      的**移动应用**，或者包名/签名与开放平台上登记的不一致。
 *   2. `isInstalled()` —— 设备上有没有微信。"没装微信"和"没接入"是两种完全不同的原因，
 *      用户的下一步动作也不同，因此必须分开回答。
 *   3. `launchMiniProgram(...)` —— 真正发请求。`userName` 是小程序的**原始 ID**（gh_ 开头），
 *      **不是 AppID**；填错、或小程序未与开放平台账号关联时，微信侧不会拉起任何界面。
 *
 * Route A is the OpenSDK's `WXLaunchMiniProgram`, and every one of the three reports its result
 * honestly: `register` (false usually means the AppID is not an Open Platform *mobile app* AppID,
 * or the package/signature does not match), `isInstalled`, and `launchMiniProgram` (whose
 * `userName` is the mini program's raw id, not an AppID).
 */
class MainActivity : FlutterActivity() {
    private var api: IWXAPI? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result -> handle(call, result) }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "register" -> result.success(register(call.argument<String>("appId").orEmpty()))
            "isInstalled" -> result.success(api?.isWXAppInstalled == true)
            "launchMiniProgram" -> result.success(launch(call))
            else -> result.notImplemented()
        }
    }

    /** 注册 AppID；返回值就是"注册是否被接受"，绝不能忽略。 */
    private fun register(appId: String): Boolean {
        if (appId.isEmpty()) return false
        val wxApi = WXAPIFactory.createWXAPI(applicationContext, appId, true)
        api = wxApi
        return wxApi.registerApp(appId)
    }

    /** 发一次拉起请求 / send one launch request. */
    private fun launch(call: MethodCall): Boolean {
        val wxApi = api ?: return false
        val originalId = call.argument<String>("originalId").orEmpty()
        if (originalId.isEmpty()) return false
        val req = WXLaunchMiniProgram.Req().apply {
            userName = originalId
            path = call.argument<String>("path").orEmpty()
            // 微信文档的取值：0 正式版 / 1 开发版 / 2 体验版。这里刻意写字面量而不用 SDK 的
            // 常量名——那个常量在历史版本里拼写不一致，用错了会编不过。
            // Documented values: 0 release, 1 test, 2 preview. Literals on purpose: the SDK's
            // constant names have been inconsistent across versions.
            miniprogramType = when (call.argument<String>("type")) {
                "test" -> 1
                "preview" -> 2
                else -> 0
            }
        }
        return wxApi.sendReq(req)
    }

    private companion object {
        const val CHANNEL = "cn.campus/wechat"
    }
}
