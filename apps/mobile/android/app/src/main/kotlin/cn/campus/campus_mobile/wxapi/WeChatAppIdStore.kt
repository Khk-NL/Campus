package cn.campus.campus_mobile.wxapi

import android.content.Context

/** Shares the public mobile AppID received from Dart with the WeChat callback activity. */
object WeChatAppIdStore {
    private const val PREFERENCES = "campulse.wechat"
    private const val APP_ID = "app_id"

    fun save(context: Context, appId: String): Boolean =
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .edit()
            .putString(APP_ID, appId)
            .commit()

    fun read(context: Context): String =
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .getString(APP_ID, "")
            .orEmpty()
}
