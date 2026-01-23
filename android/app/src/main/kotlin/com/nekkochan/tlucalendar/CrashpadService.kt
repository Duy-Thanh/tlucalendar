package com.nekkochan.tlucalendar

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class CrashpadService(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.nekkochan.tlucalendar/crashpad"

        // Load native library
        init {
            System.loadLibrary("nekkoFramework")
        }
    }

    private external fun initCrashpadNative(handlerPath: String, dataDir: String, url: String): Boolean

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "initialize") {
             val url = call.argument<String>("url") ?: ""
             initializeCrashpad(url, result)
        } else {
            result.notImplemented()
        }
    }

    private fun initializeCrashpad(url: String, result: MethodChannel.Result) {
        try {
            // Path where we expect the handler executable to be.
            // Since we built it as 'libcrashpad_handler.so', it should be in the nativeLibraryDir.
            val nativeLibDir = context.applicationInfo.nativeLibraryDir
            val handlerPath = File(nativeLibDir, "libcrashpad_handler.so").absolutePath
            
            // Database path
            val dataDir = File(context.cacheDir, "crashpad_db")
            if (!dataDir.exists()) dataDir.mkdirs()

            Log.d("CrashpadService", "Initializing with handler: $handlerPath")
            
            val success = initCrashpadNative(handlerPath, dataDir.absolutePath, url)
            result.success(success)
        } catch (e: Exception) {
            Log.e("CrashpadService", "Failed to init", e)
            result.error("INIT_FAILED", e.message, null)
        }
    }
}
