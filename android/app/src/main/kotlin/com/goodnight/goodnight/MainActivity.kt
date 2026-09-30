package com.goodnight.goodnight

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedInputStream
import java.io.File
import java.io.FileOutputStream
import java.net.URL

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.goodnight.goodnight/app_update"
    private var updateChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        updateChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "downloadAndInstall" -> {
                    val url = call.argument<String>("url")
                    if (url.isNullOrEmpty()) {
                        result.error("NO_URL", "download url is required", null)
                        return@setMethodCallHandler
                    }
                    downloadAndInstall(url, result)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun downloadAndInstall(url: String, result: MethodChannel.Result) {
        Thread {
            try {
                val dir = File(getExternalFilesDir(null), "updates")
                if (!dir.exists()) dir.mkdirs()
                val apk = File(dir, "goodnight-update.apk")
                if (apk.exists()) apk.delete()

                val connection = URL(url).openConnection()
                connection.connect()
                val length = connection.contentLength
                val input = BufferedInputStream(connection.inputStream)
                val output = FileOutputStream(apk)
                val buffer = ByteArray(8192)
                var total: Long = 0
                var read: Int
                while (input.read(buffer).also { read = it } != -1) {
                    total += read
                    output.write(buffer, 0, read)
                    if (length > 0) {
                        val pct = (total * 100 / length).toInt()
                        runOnUiThread { updateChannel?.invokeMethod("progress", pct) }
                    }
                }
                output.flush()
                output.close()
                input.close()

                runOnUiThread { installApk(apk, result) }
            } catch (e: Exception) {
                runOnUiThread { result.error("DOWNLOAD_FAILED", e.message, null) }
            }
        }.start()
    }

    private fun installApk(apk: File, result: MethodChannel.Result) {
        try {
            // Android 8.0+ 需要先授予"安装未知应用"权限，否则安装会被系统拦截
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                if (!packageManager.canRequestPackageInstalls()) {
                    val intent = Intent(
                        Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                        Uri.parse("package:$packageName")
                    )
                    startActivity(intent)
                    result.error(
                        "NEED_PERMISSION",
                        "请先在系统设置中允许本应用安装未知应用，然后再次点击更新",
                        null
                    )
                    return
                }
            }
            val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", apk)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("INSTALL_FAILED", e.message, null)
        }
    }
}
