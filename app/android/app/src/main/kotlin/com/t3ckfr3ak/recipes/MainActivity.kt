package com.t3ckfr3ak.recipes

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pending: Map<String, String>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pending = pending ?: readShare(intent)
        if (readShare(intent) != null) {
            setIntent(Intent(this, javaClass))
        }
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        channel = MethodChannel(messenger, "recipes/share")
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialShare" -> {
                    val share = pending
                    pending = null
                    result.success(share)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val share = readShare(intent) ?: return
        setIntent(Intent(this, javaClass))
        val active = channel
        if (active == null) {
            pending = share
        } else {
            active.invokeMethod("shared", share)
        }
    }

    private fun readShare(intent: Intent?): Map<String, String>? {
        if (intent == null) return null
        val action = intent.action
        if (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE) {
            return null
        }
        val chunks = linkedSetOf<String>()
        fun add(value: String?) {
            val text = value?.trim().orEmpty()
            if (text.isNotEmpty()) chunks.add(text)
        }
        add(intent.getStringExtra(Intent.EXTRA_TEXT))
        intent.getStringArrayListExtra(Intent.EXTRA_TEXT)?.forEach { add(it) }
        val clip = intent.clipData
        if (clip != null) {
            for (index in 0 until clip.itemCount) {
                val item = clip.getItemAt(index)
                add(item.text?.toString())
                val uri = item.uri
                if (uri != null && (uri.scheme == "http" || uri.scheme == "https")) {
                    add(uri.toString())
                }
            }
        }
        val html = intent.getStringExtra(Intent.EXTRA_HTML_TEXT)
            ?: clip?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.htmlText
            ?: ""
        val text = chunks.joinToString("\n\n")
        val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT)?.trim().orEmpty()
        if (text.isBlank() && html.isBlank() && subject.isBlank()) return null
        return mapOf("text" to text, "html" to html, "subject" to subject)
    }
}
