package com.amber.amber_md_viewer

import android.content.ContentResolver
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.amber.md/content_resolver"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "resolveContentUri" -> {
                        try {
                            val uriStr = call.argument<String>("uri")
                            if (uriStr == null) {
                                result.error("INVALID_URI", "URI is null", null)
                                return@setMethodCallHandler
                            }
                            val uri = Uri.parse(uriStr)
                            val contentResolver: ContentResolver = contentResolver

                            // Get file name
                            var fileName = "shared_file"
                            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                                if (cursor.moveToFirst()) {
                                    val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                                    if (nameIndex >= 0) {
                                        fileName = cursor.getString(nameIndex)
                                    }
                                }
                            }

                            // Copy to cache
                            val tempFile = File(cacheDir, "_amber_shared_$fileName")
                            contentResolver.openInputStream(uri)?.use { inputStream ->
                                FileOutputStream(tempFile).use { outputStream ->
                                    inputStream.copyTo(outputStream)
                                }
                            } ?: run {
                                result.error("READ_FAILED", "Cannot open input stream", null)
                                return@setMethodCallHandler
                            }

                            result.success(tempFile.absolutePath)
                        } catch (e: Exception) {
                            result.error("RESOLVE_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        flutterEngine?.activityControlSurface?.onNewIntent(intent)
    }
}
