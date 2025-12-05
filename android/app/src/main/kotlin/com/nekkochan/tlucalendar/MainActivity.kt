package com.nekkochan.tlucalendar

import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.nekkochan.tlucalendar/navigation"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Make navigation bar transparent on all Android versions
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 10+ (API 29+): Full edge-to-edge with transparent navigation
            window.isNavigationBarContrastEnforced = false
        }
        
        // Enable edge-to-edge layout
        WindowCompat.setDecorFitsSystemWindows(window, false)
        
        // Set navigation bar color to transparent
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            window.navigationBarColor = android.graphics.Color.TRANSPARENT
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openLicenseActivity" -> {
                    try {
                        val intent = Intent(this, LicenseActivity::class.java)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ACTIVITY_ERROR", "Failed to open LicenseActivity", e.message)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
