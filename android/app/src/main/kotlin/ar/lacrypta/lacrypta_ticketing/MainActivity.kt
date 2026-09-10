package ar.lacrypta.lacrypta_ticketing

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.text.Layout
import android.util.Log
import com.zcs.sdk.DriverManager
import com.zcs.sdk.Printer
import com.zcs.sdk.SdkResult
import com.zcs.sdk.Sys
import com.zcs.sdk.print.PrnStrFormat
import com.zcs.sdk.print.PrnTextFont
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Bridges the built-in ZCS SmartPos thermal printer to Flutter.
 *
 * Ported from lawalletio/flutter-pos, which is proven on this exact hardware:
 * DriverManager -> Sys.sdkInit -> Printer.setPrintAppendString/... -> setPrintStart.
 *
 * Every SDK class is referenced reflectively-ish by the vendor jar, so release
 * builds need the keep rules in proguard-rules.pro or this dies only in the field.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "ticketing/printer"
    private var printer: Printer? = null
    private var initialized = false

    // Single background thread: the printer handles one job at a time, so this
    // both serializes jobs and keeps sdkInit / bitmap work off the UI thread.
    private val printExecutor: ExecutorService = Executors.newSingleThreadExecutor()

    override fun onDestroy() {
        printExecutor.shutdown()
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAvailable" -> runAsync(result) { ensureInit() }
                    "status" -> runAsync(result) { printerStatus() }
                    "printVoucher" -> {
                        @Suppress("UNCHECKED_CAST")
                        val args = call.arguments as? Map<String, Any?> ?: emptyMap()
                        runAsync(result) { printVoucher(args) }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** Run on the print thread, reply on the UI thread as Flutter requires. */
    private fun <T> runAsync(result: MethodChannel.Result, block: () -> T) {
        printExecutor.execute {
            try {
                val value = block()
                runOnUiThread { result.success(value) }
            } catch (e: Throwable) {
                Log.e(TAG, "printer op failed", e)
                runOnUiThread { result.error("PRINT_ERROR", e.message ?: e.toString(), null) }
            }
        }
    }

    /** Init the SDK + printer once. sdkInit is best-effort: some units auto-init. */
    private fun ensureInit(): Boolean {
        if (initialized && printer != null) return true
        return try {
            val dm = DriverManager.getInstance()
            try {
                val sys: Sys = dm.getBaseSysDevice()
                val st = sys.sdkInit()
                if (st != SdkResult.SDK_OK) {
                    runCatching { sys.sysPowerOn() }
                    Thread.sleep(800)
                    sys.sdkInit()
                }
            } catch (e: Throwable) {
                Log.w(TAG, "sdkInit best-effort failed, continuing", e)
            }
            printer = dm.getPrinter()
            initialized = printer != null
            initialized
        } catch (e: Throwable) {
            // No ZCS hardware (or jars missing) — not an error, just no printer.
            Log.i(TAG, "printer unavailable: ${e.message}")
            initialized = false
            false
        }
    }

    private fun printerStatus(): Int {
        if (!ensureInit()) return STATUS_UNAVAILABLE
        return try { printer!!.getPrinterStatus() } catch (e: Throwable) { STATUS_ERROR }
    }

    private fun fmt(size: Int, ali: Layout.Alignment): PrnStrFormat {
        val f = PrnStrFormat()
        f.setTextSize(size)
        f.setAli(ali)
        f.setFont(PrnTextFont.MONOSPACE)
        return f
    }

    private fun logoBitmap(): Bitmap? =
        runCatching { BitmapFactory.decodeResource(resources, R.drawable.receipt_logo) }.getOrNull()

    private fun printVoucher(v: Map<String, Any?>): Int {
        if (!ensureInit()) throw RuntimeException("Impresora no disponible")
        val p = printer!!
        val status = p.getPrinterStatus()
        if (status == SdkResult.SDK_PRN_STATUS_PAPEROUT) return status

        val normal = fmt(22, Layout.Alignment.ALIGN_NORMAL)
        logoBitmap()?.let {
            p.setPrintAppendBitmap(it, Layout.Alignment.ALIGN_CENTER)
            p.setPrintLine(30)
        }

        str(v, "event")?.let { p.setPrintAppendString(it, fmt(26, Layout.Alignment.ALIGN_CENTER)) }
        p.setPrintAppendString("--------------------------------", normal)
        p.setPrintLine(6)

        // The voucher itself is the point of the receipt — biggest thing on it.
        p.setPrintAppendString(
            str(v, "gift") ?: "BENEFICIO",
            fmt(34, Layout.Alignment.ALIGN_CENTER),
        )
        p.setPrintLine(6)

        str(v, "attendee")?.let { p.setPrintAppendString(it, fmt(24, Layout.Alignment.ALIGN_CENTER)) }
        p.setPrintAppendString("--------------------------------", normal)
        str(v, "date")?.let { p.setPrintAppendString(it, fmt(22, Layout.Alignment.ALIGN_NORMAL)) }
        str(v, "ticket")?.let { p.setPrintAppendString(it, fmt(20, Layout.Alignment.ALIGN_NORMAL)) }

        p.setPrintLine(40)
        return p.setPrintStart()
    }

    private fun str(m: Map<String, Any?>, k: String): String? =
        m[k]?.toString()?.takeIf { it.isNotEmpty() }

    companion object {
        private const val TAG = "LcPrinter"
        private const val STATUS_UNAVAILABLE = -100
        private const val STATUS_ERROR = -101
    }
}
