package mw.escom.escom_loadshedding

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import org.json.JSONArray

/**
 * Swaps the launcher icon between a lit and an unlit bulb, following the
 * primary saved location's power status.
 *
 * Android has no API for changing an app's icon at runtime, so the manifest
 * declares two launcher aliases of MainActivity (one per icon) and exactly
 * one is enabled at a time. The Dart side hands over the current status plus
 * the schedule's upcoming on/off transitions; an alarm then flips the icon at
 * each transition, so it stays right while the app is closed.
 */
object AppIcon {
    private const val PREFS = "app_icon"
    private const val KEY_LIT = "lit"
    private const val KEY_TRANSITIONS = "transitions"
    private const val ALIAS_ON = "mw.escom.escom_loadshedding.LauncherOn"
    private const val ALIAS_OFF = "mw.escom.escom_loadshedding.LauncherOff"

    /** Set while MainActivity is on screen - see [sync]. */
    @Volatile
    var appInForeground = false

    /** Stores the status as of now and the transitions that follow it. */
    fun update(context: Context, lit: Boolean, transitions: List<Pair<Long, Boolean>>) {
        val json = JSONArray()
        for ((at, isLit) in transitions) {
            json.put(JSONArray().put(at).put(isLit))
        }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean(KEY_LIT, lit)
            .putString(KEY_TRANSITIONS, json.toString())
            .apply()
        sync(context)
    }

    /**
     * Applies whichever icon is due right now and arms the alarm for the
     * next transition. Safe to call at any time.
     */
    fun sync(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!prefs.contains(KEY_LIT)) return
        var lit = prefs.getBoolean(KEY_LIT, true)
        val json = JSONArray(prefs.getString(KEY_TRANSITIONS, "[]"))
        val now = System.currentTimeMillis()
        var next: Long? = null
        for (i in 0 until json.length()) {
            val entry = json.getJSONArray(i)
            val at = entry.getLong(0)
            if (at <= now) {
                lit = entry.getBoolean(1)
            } else {
                next = at
                break
            }
        }

        // Switching aliases makes some launchers close the running app, so
        // while it's on screen the swap waits for MainActivity.onStop.
        if (!appInForeground) apply(context, lit)

        val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pending = PendingIntent.getBroadcast(
            context,
            0,
            Intent(context, AppIconReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        if (next != null) {
            // Exact only where exact alarms are already permitted. Otherwise
            // inexact, which needs no permission; the system may then deliver
            // it late (it allows itself up to an hour for a distant alarm).
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarms.canScheduleExactAlarms()) {
                alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, pending)
            } else {
                alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, pending)
            }
        } else {
            alarms.cancel(pending)
        }
    }

    private fun apply(context: Context, lit: Boolean) {
        val pm = context.packageManager
        val on = ComponentName(context, ALIAS_ON)
        val off = ComponentName(context, ALIAS_OFF)
        val wanted = if (lit) on else off
        if (pm.getComponentEnabledSetting(wanted) ==
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED
        ) {
            return
        }
        // Enable first, so there's never a moment with no launcher entry.
        pm.setComponentEnabledSetting(
            wanted,
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP,
        )
        pm.setComponentEnabledSetting(
            if (lit) off else on,
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP,
        )
    }
}

/** Fires at each scheduled transition, and after a reboot (which clears alarms). */
class AppIconReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        AppIcon.sync(context)
    }
}
