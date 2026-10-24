package dev.personalfinance.personal_finance

import android.content.Intent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * FlutterFragmentActivity is required by local_auth (BiometricPrompt).
 *
 * The `personal_finance/privacy` channel toggles FLAG_SECURE, which blanks
 * the app-switcher thumbnail and blocks screenshots and screen recording
 * (Settings › Privacy › Hide content in app switcher / Block screenshots).
 *
 * [BackupFolderChannel] gives scheduled backups access to a folder picked
 * through the Storage Access Framework.
 *
 * [AppIconChannel] switches the home-screen icon to the accent's preset
 * when the app goes to the background.
 */
class MainActivity : FlutterFragmentActivity() {
    private var backupFolder: BackupFolderChannel? = null
    private var appIcon: AppIconChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        backupFolder = BackupFolderChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        appIcon = AppIconChannel(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PRIVACY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecure" -> {
                        val secure = call.argument<Boolean>("secure") ?: false
                        runOnUiThread {
                            if (secure) {
                                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            } else {
                                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            }
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onStop() {
        super.onStop()
        appIcon?.applyPending()
    }

    @Deprecated("Activity result API; FlutterFragmentActivity forwards it")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (backupFolder?.onActivityResult(requestCode, resultCode, data) == true) return
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
    }

    private companion object {
        const val PRIVACY_CHANNEL = "personal_finance/privacy"
    }
}
