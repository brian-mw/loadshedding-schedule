package mw.escom.escom_loadshedding

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mw.escom/app_icon")
            .setMethodCallHandler { call, result ->
                if (call.method == "update") {
                    val lit = call.argument<Boolean>("lit") ?: true
                    val times = call.argument<List<Number>>("times") ?: emptyList()
                    val states = call.argument<List<Boolean>>("states") ?: emptyList()
                    AppIcon.update(
                        applicationContext,
                        lit,
                        times.zip(states).map { (at, isLit) -> at.toLong() to isLit },
                    )
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun onStart() {
        super.onStart()
        AppIcon.appInForeground = true
    }

    override fun onStop() {
        super.onStop()
        AppIcon.appInForeground = false
        AppIcon.sync(applicationContext)
    }
}
