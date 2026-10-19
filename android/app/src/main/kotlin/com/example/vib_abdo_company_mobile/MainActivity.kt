package com.example.vib_abdo_company_mobile

import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app/screen_security")
            .setMethodCallHandler { call, result ->
                if (call.method == "enable") {
                    window.setFlags(
                        WindowManager.LayoutParams.FLAG_SECURE,
                        WindowManager.LayoutParams.FLAG_SECURE,
                    )
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app/connectivity")
            .setMethodCallHandler { call, result ->
                if (call.method == "isOnline") {
                    val manager = getSystemService(ConnectivityManager::class.java)
                    val network = manager.activeNetwork
                    val caps = network?.let { manager.getNetworkCapabilities(it) }
                    val online = caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true
                    result.success(online)
                } else {
                    result.notImplemented()
                }
            }
    }
}
