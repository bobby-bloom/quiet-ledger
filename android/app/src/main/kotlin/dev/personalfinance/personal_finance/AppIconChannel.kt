package dev.personalfinance.personal_finance

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Home-screen icon in the accent colour (`personal_finance/app_icon`).
 *
 * The manifest has one launcher activity-alias per accent preset
 * (`.LauncherSpruce`, `.LauncherBlue`, …); `setLauncherIcon` picks one and
 * the others are disabled. The switch waits until the app is in the
 * background ([applyPending] from onStop): changing launcher components
 * while the app is visible can close it on some devices.
 */
class AppIconChannel(private val context: Context, messenger: BinaryMessenger) {
    private var pending: String? = null

    init {
        MethodChannel(messenger, NAME).setMethodCallHandler { call, result ->
            when (call.method) {
                "setLauncherIcon" -> {
                    val name = call.argument<String>("name")
                    if (name == null || name !in PRESETS) {
                        result.error("args", "Unknown icon $name", null)
                    } else {
                        pending = name
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    fun applyPending() {
        val name = pending ?: return
        pending = null
        val pm = context.packageManager
        // Enable the new entry before disabling the old one, so there is
        // always a launcher icon.
        for (preset in PRESETS.sortedBy { it != name }) {
            val component = ComponentName(context, aliasClass(preset))
            val want = preset == name
            val enabled = when (pm.getComponentEnabledSetting(component)) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED -> false
                else -> preset == DEFAULT // as declared in the manifest
            }
            if (enabled == want) continue
            pm.setComponentEnabledSetting(
                component,
                if (want) {
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                } else {
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED
                },
                PackageManager.DONT_KILL_APP,
            )
        }
    }

    private fun aliasClass(preset: String): String =
        MainActivity::class.java.name.substringBeforeLast('.') +
            ".Launcher" + preset.replaceFirstChar { it.uppercase() }

    private companion object {
        const val NAME = "personal_finance/app_icon"
        const val DEFAULT = "spruce"
        val PRESETS = listOf("spruce", "blue", "violet", "amber", "rose", "slate")
    }
}
