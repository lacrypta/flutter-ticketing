package ar.lacrypta.lacrypta_ticketing

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.text.Layout
import android.util.Log
import com.google.zxing.EncodeHintType
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel
import com.google.zxing.qrcode.encoder.Encoder
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
        val lnurl = str(v, "lnurl")
        // A treasure slip leads with the chest and the LUD-03. The venue logo
        // sits above that and eats the first thing the attendee sees.
        if (lnurl == null) {
            logoBitmap()?.let {
                p.setPrintAppendBitmap(it, Layout.Alignment.ALIGN_CENTER)
                p.setPrintLine(30)
            }
        }

        str(v, "event")?.let { p.setPrintAppendString(it, fmt(26, Layout.Alignment.ALIGN_CENTER)) }
        p.setPrintAppendString("--------------------------------", normal)
        p.setPrintLine(6)

        // Gift artwork, already reduced to 1-bit at head width by Dart.
        // When it actually printed, the image *is* the title — repeating the
        // name underneath wastes paper and looks like a caption.
        val artwork = (v["image"] as? ByteArray)?.let { bytes ->
            runCatching { BitmapFactory.decodeByteArray(bytes, 0, bytes.size) }.getOrNull()
        }
        if (artwork != null) {
            p.setPrintAppendBitmap(artwork, Layout.Alignment.ALIGN_CENTER)
            p.setPrintLine(10)
        } else {
            p.setPrintAppendString(
                str(v, "gift") ?: "BENEFICIO",
                fmt(34, Layout.Alignment.ALIGN_CENTER),
            )
            p.setPrintLine(6)
        }

        // A Sats Treasure hands the attendee a scannable LUD-03, then the amount.
        if (lnurl != null) {
            p.setPrintLine(8)
            val payload = lightningDeeplink(lnurl)
            val qr = runCatching { lud03Qr(payload) }.getOrElse { e ->
                Log.w(TAG, "LUD-03 QR encode failed, falling back", e)
                null
            }
            if (qr != null) {
                p.setPrintAppendBitmap(qr, Layout.Alignment.ALIGN_CENTER)
            } else {
                p.setPrintAppendQRCode(payload, 384, 384, Layout.Alignment.ALIGN_CENTER)
            }
            p.setPrintLine(10)
            str(v, "claimLine")?.let {
                p.setPrintAppendString(it, fmt(34, Layout.Alignment.ALIGN_CENTER))
                p.setPrintLine(8)
            }
        }

        // No attendee name, no ticket id: a voucher gets handed over, dropped
        // on a table and left in the venue. It only needs to say what it is.
        p.setPrintAppendString("--------------------------------", normal)
        str(v, "date")?.let { p.setPrintAppendString(it, fmt(22, Layout.Alignment.ALIGN_NORMAL)) }
        str(v, "giftId")?.let {
            p.setPrintLine(8)
            p.setPrintAppendString(it, fmt(18, Layout.Alignment.ALIGN_CENTER))
        }

        val block = str(v, "block")
        val btcUsd = str(v, "btcUsd")
        val satArs = str(v, "satArs")
        if (block != null || btcUsd != null || satArs != null) {
            p.setPrintLine(8)
            val market = fmt(20, Layout.Alignment.ALIGN_NORMAL)
            block?.let { p.setPrintAppendString(it, market) }
            btcUsd?.let { p.setPrintAppendString(it, market) }
            satArs?.let { p.setPrintAppendString(it, market) }
        }

        p.setPrintAppendString("\n\n", normal)
        p.setPrintLine(40)
        return p.setPrintStart()
    }

    private fun str(m: Map<String, Any?>, k: String): String? =
        m[k]?.toString()?.takeIf { it.isNotEmpty() }

    private fun lightningDeeplink(lnurl: String): String {
        val value = lnurl.trim()
        return if (value.startsWith("lightning:", ignoreCase = true)) value
        else "lightning:$value"
    }

    /**
     * LUD-03 QR sized for the 58mm head.
     *
     * [Printer.setPrintAppendQRCode] always encodes at error-correction H. A
     * withdraw LNURL is long, so H jumps several versions and the modules
     * shrink until a phone cannot read them off thermal paper. Level L is the
     * smallest symbol that still scans, and each module is a whole number of
     * printer dots so the head does not blur the edges.
     */
    private fun lud03Qr(payload: String, maxDots: Int = 384): Bitmap {
        val code = Encoder.encode(
            payload,
            ErrorCorrectionLevel.L,
            mapOf(EncodeHintType.CHARACTER_SET to "UTF-8"),
        )
        val matrix = code.matrix
        val quiet = 4
        val modules = matrix.width + quiet * 2
        val modulePx = (maxDots / modules).coerceAtLeast(1)
        val size = modules * modulePx
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(Color.WHITE)
        val paint = Paint().apply {
            color = Color.BLACK
            style = Paint.Style.FILL
            isAntiAlias = false
        }
        for (y in 0 until matrix.height) {
            for (x in 0 until matrix.width) {
                if (matrix.get(x, y).toInt() != 1) continue
                val left = (x + quiet) * modulePx
                val top = (y + quiet) * modulePx
                canvas.drawRect(
                    left.toFloat(),
                    top.toFloat(),
                    (left + modulePx).toFloat(),
                    (top + modulePx).toFloat(),
                    paint,
                )
            }
        }
        return bitmap
    }

    companion object {
        private const val TAG = "LcPrinter"
        private const val STATUS_UNAVAILABLE = -100
        private const val STATUS_ERROR = -101
    }
}
