package com.wuninsu.scanner

import android.util.Log
import androidx.fragment.app.FragmentActivity
import com.google.mlkit.common.MlKitException
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.codescanner.GmsBarcodeScannerOptions
import com.google.mlkit.vision.codescanner.GmsBarcodeScanning
import com.nativephp.mobile.bridge.BridgeFunction
import com.nativephp.mobile.bridge.BridgeResponse
import com.nativephp.mobile.utils.NativeActionCoordinator
import org.json.JSONObject

/**
 * Scanner bridge functions.
 * Namespace: "WuninsuScanner.*"
 *
 * Uses Google's code scanner: Play services shows the camera screen itself, so the app needs no camera permission.
 */
object ScannerFunctions {

    /**
     * Parameters: id, event, formats
     * Returns: {started: true}. The outcome is dispatched later to `event` as {value, format, id, error}.
     */
    class Scan(private val activity: FragmentActivity) : BridgeFunction {
        override fun execute(parameters: Map<String, Any>): Map<String, Any> {
            val id = parameters["id"] as? String
            val event = parameters["event"] as? String
                ?: return BridgeResponse.error("INVALID_PARAMETERS", "event is required")
            val formats = (parameters["formats"] as? List<*>)
                ?.mapNotNull { FORMATS[it as? String] }
                ?.takeIf { it.isNotEmpty() }
                ?: listOf(Barcode.FORMAT_QR_CODE)

            activity.runOnUiThread {
                try {
                    val options = GmsBarcodeScannerOptions.Builder()
                        .setBarcodeFormats(formats.first(), *formats.drop(1).toIntArray())
                        .enableAutoZoom()
                        .build()

                    GmsBarcodeScanning.getClient(activity, options)
                        .startScan()
                        .addOnSuccessListener { barcode ->
                            val value = barcode.rawValue
                            if (value == null) {
                                send(event, id, null, null, "failed")
                            } else {
                                send(event, id, value, formatName(barcode.format), null)
                            }
                        }
                        .addOnCanceledListener { send(event, id, null, null, "cancelled") }
                        .addOnFailureListener { e ->
                            Log.e(TAG, "Scan failed: ${e.message}")
                            // UNAVAILABLE: the scanner module is still downloading or Play services is missing.
                            val error = if ((e as? MlKitException)?.errorCode == MlKitException.UNAVAILABLE) "unavailable" else "failed"
                            send(event, id, null, null, error)
                        }
                } catch (e: Exception) {
                    Log.e(TAG, "Could not open the scanner: ${e.message}")
                    send(event, id, null, null, "unavailable")
                }
            }

            return BridgeResponse.success(mapOf("started" to true))
        }

        private fun send(event: String, id: String?, value: String?, format: String?, error: String?) {
            val payload = JSONObject()
                .put("value", value ?: JSONObject.NULL)
                .put("format", format ?: JSONObject.NULL)
                .put("id", id ?: JSONObject.NULL)
                .put("error", error ?: JSONObject.NULL)

            NativeActionCoordinator.dispatchEvent(activity, event, payload.toString())
        }
    }

    private val FORMATS = mapOf(
        "qr" to Barcode.FORMAT_QR_CODE,
        "ean13" to Barcode.FORMAT_EAN_13,
        "ean8" to Barcode.FORMAT_EAN_8,
        "upca" to Barcode.FORMAT_UPC_A,
        "upce" to Barcode.FORMAT_UPC_E,
        "code128" to Barcode.FORMAT_CODE_128,
        "code39" to Barcode.FORMAT_CODE_39,
        "code93" to Barcode.FORMAT_CODE_93,
        "codabar" to Barcode.FORMAT_CODABAR,
        "itf" to Barcode.FORMAT_ITF,
        "pdf417" to Barcode.FORMAT_PDF417,
        "aztec" to Barcode.FORMAT_AZTEC,
        "datamatrix" to Barcode.FORMAT_DATA_MATRIX,
    )

    private fun formatName(format: Int): String =
        FORMATS.entries.firstOrNull { it.value == format }?.key ?: "unknown"

    private const val TAG = "WuninsuScanner"
}
