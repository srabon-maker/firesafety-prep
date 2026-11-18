package com.firesafetybd

import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.firesafetybd/app_identity"
        ).setMethodCallHandler { call, result ->
            if (call.method == "getSigningIdentity") {
                try {
                    result.success(
                        mapOf(
                            "packageName" to packageName,
                            "sha1" to installedCertificateSha1()
                        )
                    )
                } catch (error: Exception) {
                    result.error("SIGNING_INFO_UNAVAILABLE", "Could not inspect installed APK signing certificate.", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun installedCertificateSha1(): String {
        val certificates = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val info = packageManager.getPackageInfo(
                packageName, PackageManager.GET_SIGNING_CERTIFICATES
            ).signingInfo ?: error("Missing Android signing information")
            info.apkContentsSigners
        } else {
            packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES).signatures
        }
        val signer = certificates?.firstOrNull() ?: error("No APK signing certificate found")
        val digest = MessageDigest.getInstance("SHA-1").digest(signer.toByteArray())
        return digest.joinToString(":") { byte -> "%02X".format(byte.toInt() and 0xFF) }
    }
}
