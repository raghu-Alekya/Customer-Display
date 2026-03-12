package com.example.flutter_sunmi_customer_display

import android.content.Context
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.util.Log
import io.flutter.plugin.common.EventChannel

/**
 * Lightweight USB serial bridge used by Flutter through
 * the "magellan_scale" MethodChannel / EventChannel.
 *
 * This implementation is intentionally minimal and focused on
 * compiling cleanly and avoiding crashes. You can extend it
 * later to talk to your actual scale hardware.
 */
class UsbSerialManager(private val context: Context) {

    private val usbManager: UsbManager? =
        context.getSystemService(Context.USB_SERVICE) as? UsbManager

    private var eventSink: EventChannel.EventSink? = null

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    fun startListening() {
        Log.d(TAG, "startListening() called")
        // You can enumerate devices here if needed:
        // usbManager?.deviceList?.values?.forEach { ... }
    }

    fun stopListening() {
        Log.d(TAG, "stopListening() called")
        // Stop any active read loops here if you add them later.
    }

    fun restartDevice() {
        Log.d(TAG, "restartDevice() called")
        stopListening()
        startListening()
    }

    fun connectToDevice(device: UsbDevice) {
        Log.d(TAG, "connectToDevice() → ${device.deviceName}")
        // This is a stub – if you need real serial IO,
        // open a UsbDeviceConnection and configure endpoints here.
    }

    fun dispose() {
        Log.d(TAG, "dispose() called")
        stopListening()
        eventSink = null
    }

    companion object {
        private const val TAG = "UsbSerialManager"
    }
}