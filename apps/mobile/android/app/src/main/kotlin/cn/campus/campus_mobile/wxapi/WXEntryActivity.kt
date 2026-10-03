package cn.campus.campus_mobile.wxapi

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.widget.Toast
import com.tencent.mm.opensdk.modelbase.BaseReq
import com.tencent.mm.opensdk.modelbase.BaseResp
import com.tencent.mm.opensdk.openapi.IWXAPIEventHandler
import com.tencent.mm.opensdk.openapi.WXAPIFactory

/** WeChat's required callback entry. AppID is public; no AppSecret is used. */
class WXEntryActivity : Activity(), IWXAPIEventHandler {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleCallback(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleCallback(intent)
    }

    private fun handleCallback(intent: Intent) {
        val appId = WeChatAppIdStore.read(this)
        if (appId.isBlank()) {
            finish()
            return
        }
        val api = WXAPIFactory.createWXAPI(this, appId, true)
        if (!api.handleIntent(intent, this)) finish()
    }

    override fun onReq(request: BaseReq) {
        finish()
    }

    override fun onResp(response: BaseResp) {
        if (response.errCode != BaseResp.ErrCode.ERR_OK) {
            val message = when (response.errCode) {
                BaseResp.ErrCode.ERR_USER_CANCEL -> "已取消微信操作"
                BaseResp.ErrCode.ERR_AUTH_DENIED -> "微信拒绝了请求，请检查应用权限与小程序关联"
                else -> "微信操作未完成（${response.errCode}），请检查小程序关联与应用签名"
            }
            Toast.makeText(this, message, Toast.LENGTH_LONG).show()
        }
        finish()
    }
}
