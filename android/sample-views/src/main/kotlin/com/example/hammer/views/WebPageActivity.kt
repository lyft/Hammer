package com.example.hammer.views

import android.annotation.SuppressLint
import android.os.Bundle
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.activity.ComponentActivity

/**
 * A web page with a form, links, a section below the fold and an iframe from another origin, which the agent
 * can't read from inside the app and the hammer tool reads through its system helper.
 */
class WebPageActivity : ComponentActivity() {

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val web = WebView(this).apply {
            id = R.id.web_page
            fitsSystemWindows = true
            settings.javaScriptEnabled = true
            webViewClient = WebViewClient()
            loadUrl("file:///android_asset/page.html")
        }
        setContentView(web)
    }
}
