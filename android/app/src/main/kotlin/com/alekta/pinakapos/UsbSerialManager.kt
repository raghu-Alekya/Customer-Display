//package com.alekta.pinakapos
//
//
//import android.content.BroadcastReceiver
//
//import android.content.Context
//
//import android.content.Intent
//
//import android.content.IntentFilter
//
//import android.hardware.usb.UsbDevice
//
//import android.hardware.usb.UsbManager
//
//import android.os.Handler
//
//import android.os.Looper
//
//import android.util.Log
//
//import com.hoho.android.usbserial.driver.CdcAcmSerialDriver
//
//import com.hoho.android.usbserial.driver.FtdiSerialDriver
//
//import com.hoho.android.usbserial.driver.ProbeTable
//
//import com.hoho.android.usbserial.driver.UsbSerialPort
//
//import com.hoho.android.usbserial.driver.UsbSerialProber
//
//import io.flutter.plugin.common.EventChannel
//
//import org.json.JSONObject
//
//import java.util.concurrent.atomic.AtomicBoolean
//
//enum class DeviceType { SCALE, SCANNER, UNKNOWN }
//
//data class ConnectionInfo(
//
//    var connection: android.hardware.usb.UsbDeviceConnection? = null,
//
//    var port: UsbSerialPort? = null,
//
//    var readThread: Thread? = null,
//
//    var stopRead: AtomicBoolean = AtomicBoolean(false),
//
//    var weightPollRunnable: Runnable? = null,
//
//    var deviceType: DeviceType = DeviceType.UNKNOWN
//
//)
//
//class UsbSerialManager(
//
//    private val context: Context
//
//) {
//
//    companion object {
//
//        private const val TAG = "UsbSerialManager"
//
//        // Datalogic Magellan VID — used as SCANNER
//
//        private const val MAGELLAN_VID = 0x05F9
//
//        private val MAGELLAN_PIDS = intArrayOf(0x2205, 0x2601, 0x2602)
//
//        // FTDI VID 1027 (0x0403) — used as SCALE
//
//        private const val FTDI_VID = 0x0403
//
//        private const val FTDI_PID_SCALE_1 = 0xB0C2
//
//        private const val FTDI_PID_SCALE_2 = 0xB0C1
//
//        private val FTDI_SCALE_PIDS = intArrayOf(FTDI_PID_SCALE_1, FTDI_PID_SCALE_2)
//
//        private const val BAUD_RATE = 9600
//
//        private const val READ_TIMEOUT_MS = 500
//
//        private const val MAX_LOG_LINES = 200
//
//        private const val WEIGHT_POLL_INTERVAL_MS = 500L
//
//    }
//
//    @Volatile
//
//    private var eventSink: EventChannel.EventSink? = null
//
//    @Volatile
//
//    private var listening = false
//
//    private val usbManager: UsbManager = context.getSystemService(Context.USB_SERVICE) as UsbManager
//
//    private val mainHandler = Handler(Looper.getMainLooper())
//
//    private val deviceConnections = mutableMapOf<String, ConnectionInfo>()
//
//    private val pendingPermissions = mutableSetOf<Int>()
//
//    private val rawLog = mutableListOf<String>()
//
//    private var permissionReceiver: PermissionBroadcastReceiver? = null
//
//    private var lastLoggedDevices = setOf<String>()
//
//    private val usbReceiver = object : BroadcastReceiver() {
//
//        override fun onReceive(context: Context?, intent: Intent?) {
//
//            when (intent?.action) {
//
//                UsbManager.ACTION_USB_DEVICE_ATTACHED -> {
//
//                    @Suppress("DEPRECATION")
//
//                    val device = intent?.getParcelableExtra<UsbDevice>(UsbManager.EXTRA_DEVICE)
//
//                    if (device != null && listening) {
//
//                        Log.i(TAG, "DEVICE ATTACHED: ${device.deviceName} VID=0x${device.vendorId.toString(16)} PID=0x${device.productId.toString(16)}")
//
//                        mainHandler.post { tryConnect(device) }
//
//                    }
//
//                }
//
//                UsbManager.ACTION_USB_DEVICE_DETACHED -> {
//
//                    @Suppress("DEPRECATION")
//
//                    val device = intent?.getParcelableExtra<UsbDevice>(UsbManager.EXTRA_DEVICE)
//
//                    if (device != null) {
//
//                        Log.i(TAG, "DEVICE DETACHED: ${device.deviceName}")
//
//                        mainHandler.post { handleDetach(device) }
//
//                    }
//
//                }
//
//            }
//
//        }
//
//    }
//
//    init {
//
//        Log.i(TAG, "UsbSerialManager initialized")
//
//        val filter = IntentFilter().apply {
//
//            addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
//
//            addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
//
//        }
//
//        if (android.os.Build.VERSION.SDK_INT >= 33) {
//
//            context.registerReceiver(usbReceiver, filter, Context.RECEIVER_EXPORTED)
//
//        } else {
//
//            context.registerReceiver(usbReceiver, filter)
//
//        }
//
//        permissionReceiver = PermissionBroadcastReceiver(this).also { receiver ->
//
//            val permFilter = IntentFilter().apply { addAction(ACTION_USB_PERMISSION) }
//
//            if (android.os.Build.VERSION.SDK_INT >= 33) {
//
//                context.registerReceiver(receiver, permFilter, Context.RECEIVER_EXPORTED)
//
//            } else {
//
//                context.registerReceiver(receiver, permFilter)
//
//            }
//
//        }
//
//    }
//
//    fun setEventSink(sink: EventChannel.EventSink?) {
//
//        eventSink = sink
//
//        if (sink != null) {
//
//            Log.i(TAG, "EventSink connected")
//
//        }
//
//    }
//
//    fun startListening() {
//
//        Log.i(TAG, "Start listening for devices")
//
//        listening = true
//
//        emitStatus("connecting", "Scanning for devices...")
//
//        findAndConnect()
//
//        // Flutter treats every "connecting" as disconnected until "connected".
//
//        // If USB was already open, findAndConnect() does nothing — re-emit connected.
//
//        emitConnectedIfAlreadyOpen()
//
//    }
//
//    /** When [deviceConnections] already has an open port, sync Flutter UI (EventChannel re-subscribe, etc.). */
//
//    private fun emitConnectedIfAlreadyOpen() {
//
//        if (!listening || deviceConnections.isEmpty()) return
//
//        val info = deviceConnections.values.firstOrNull { it.port != null } ?: return
//
//        val typeLabel = if (info.deviceType == DeviceType.SCALE) "Scale" else "Scanner"
//
//        emitStatus("connected", "$typeLabel connected")
//
//    }
//
//    fun connectToDevice(device: UsbDevice) {
//
//        Log.i(TAG, "Manual device connection: ${device.deviceName}")
//
//        listening = true
//
//        emitStatus("connecting", "Connecting...")
//
//        tryConnect(device)
//
//    }
//
//    fun stopListening() {
//
//        Log.i(TAG, "Stop listening")
//
//        listening = false
//
//        for ((key, info) in deviceConnections.toMap()) {
//
//            closePort(info, key)
//
//            deviceConnections.remove(key)
//
//        }
//
//        emitStatus("stopped", "Stopped")
//
//    }
//
//    /** Drop active USB connections and scan again (MethodChannel "reconnect"). */
//
//    fun restartDevice() {
//
//        Log.i(TAG, "Restart USB serial (reconnect)")
//
//        if (!listening) {
//
//            startListening()
//
//            return
//
//        }
//
//        for ((key, info) in deviceConnections.toMap()) {
//
//            closePort(info, key)
//
//            deviceConnections.remove(key)
//
//        }
//
//        emitStatus("connecting", "Reconnecting...")
//
//        mainHandler.postDelayed({ findAndConnect() }, 300)
//
//    }
//
//    fun dispose() {
//
//        Log.i(TAG, "Dispose")
//
//        permissionReceiver?.let { context.unregisterReceiver(it) }
//
//        permissionReceiver = null
//
//        try {
//
//            context.unregisterReceiver(usbReceiver)
//
//        } catch (_: Exception) {}
//
//        stopListening()
//
//        eventSink = null
//
//    }
//
//    private fun findAndConnect() {
//
//        val deviceList = usbManager.deviceList ?: return
//
//        val currentDevices = deviceList.values
//
//            .filter { isTargetDevice(it) }
//
//            .map { it.deviceName }
//
//            .toSet()
//
//        if (currentDevices != lastLoggedDevices) {
//
//            Log.i(TAG, "Found ${currentDevices.size} target devices")
//
//            lastLoggedDevices = currentDevices
//
//        }
//
//        for (device in deviceList.values) {
//
//            if (isTargetDevice(device) && deviceConnections[device.deviceName] == null) {
//
//                Log.i(TAG, "Connecting: ${device.deviceName}")
//
//                tryConnect(device)
//
//            }
//
//        }
//
//        if (deviceConnections.isEmpty() && listening) {
//
//            emitStatus("disconnected", "No device found")
//
//        }
//
//    }
//
//    private fun isTargetDevice(device: UsbDevice): Boolean {
//
//        val vid = device.vendorId
//
//        return (vid == FTDI_VID) || (vid == MAGELLAN_VID)
//
//    }
//
//    private fun getDeviceType(device: UsbDevice): DeviceType {
//
//        val vid = device.vendorId
//
//        val pid = device.productId
//
//        return when {
//
//            vid == FTDI_VID && FTDI_SCALE_PIDS.contains(pid) -> DeviceType.SCALE
//
//            vid == FTDI_VID -> DeviceType.SCALE
//
//            vid == MAGELLAN_VID -> DeviceType.SCANNER
//
//            else -> DeviceType.UNKNOWN
//
//        }
//
//    }
//
//    private fun getCustomProber(): UsbSerialProber {
//
//        val table = UsbSerialProber.getDefaultProbeTable()
//
//        for (pid in MAGELLAN_PIDS) {
//
//            table.addProduct(MAGELLAN_VID, pid, CdcAcmSerialDriver::class.java)
//
//        }
//
//        table.addProduct(FTDI_VID, FTDI_PID_SCALE_1, FtdiSerialDriver::class.java)
//
//        table.addProduct(FTDI_VID, FTDI_PID_SCALE_2, FtdiSerialDriver::class.java)
//
//        return UsbSerialProber(table)
//
//    }
//
//    private fun tryConnect(device: UsbDevice) {
//
//        if (!listening) return
//
//        val key = device.deviceName
//
//        if (deviceConnections[key] != null) return
//
//        if (pendingPermissions.contains(device.deviceId)) return
//
//        if (!usbManager.hasPermission(device)) {
//
//            Log.i(TAG, "Requesting permission: ${device.deviceId}")
//
//            pendingPermissions.add(device.deviceId)
//
//            emitStatus("connecting", "Requesting permission...")
//
//            usbManager.requestPermission(device, createPermissionIntent())
//
//            return
//
//        }
//
//        openDevice(device)
//
//    }
//
//    private fun createPermissionIntent(): android.app.PendingIntent {
//
//        val flags = android.app.PendingIntent.FLAG_MUTABLE or android.app.PendingIntent.FLAG_UPDATE_CURRENT
//
//        return android.app.PendingIntent.getBroadcast(context, 0, Intent(ACTION_USB_PERMISSION), flags)
//
//    }
//
//    fun onPermissionResult(granted: Boolean, device: UsbDevice?) {
//
//        if (device != null) {
//
//            pendingPermissions.remove(device.deviceId)
//
//        }
//
//        if (!granted || device == null) {
//
//            Log.w(TAG, "Permission denied")
//
//            emitStatus("error", "Permission denied")
//
//            return
//
//        }
//
//        if (listening) {
//
//            openDevice(device)
//
//        }
//
//    }
//
//    private fun openDevice(device: UsbDevice) {
//
//        val key = device.deviceName
//
//        val deviceType = getDeviceType(device)
//
//        Log.i(TAG, "Opening ${deviceType.name}: $key")
//
//        val conn = usbManager.openDevice(device) ?: run {
//
//            Log.e(TAG, "Failed to open device")
//
//            emitStatus("error", "Failed to open device")
//
//            return
//
//        }
//
//        val prober = getCustomProber()
//
//        val driver = prober.probeDevice(device) ?: run {
//
//            Log.e(TAG, "No driver found")
//
//            conn.close()
//
//            emitStatus("error", "No compatible driver")
//
//            return
//
//        }
//
//        val ports = driver.ports
//
//        if (ports.isEmpty()) {
//
//            Log.e(TAG, "No ports available")
//
//            conn.close()
//
//            emitStatus("error", "No ports available")
//
//            return
//
//        }
//
//        val port = ports[0]
//
//        try {
//
//            port.open(conn)
//
//            if (deviceType == DeviceType.SCALE) {
//
//                port.setParameters(BAUD_RATE, 7, UsbSerialPort.STOPBITS_1, UsbSerialPort.PARITY_EVEN)
//
//                port.setDTR(true)
//
//                port.setRTS(true)
//
//            } else {
//
//                port.setParameters(BAUD_RATE, 8, UsbSerialPort.STOPBITS_1, UsbSerialPort.PARITY_NONE)
//
//            }
//
//            Log.i(TAG, "Port configured: ${deviceType.name}")
//
//        } catch (e: Exception) {
//
//            Log.e(TAG, "Port configuration failed", e)
//
//            try { port.close() } catch (_: Exception) {}
//
//            conn.close()
//
//            emitStatus("error", "Port config failed")
//
//            return
//
//        }
//
//        val info = ConnectionInfo(
//
//            connection = conn,
//
//            port = port,
//
//            stopRead = AtomicBoolean(false),
//
//            deviceType = deviceType
//
//        )
//
//        deviceConnections[key] = info
//
//        val typeLabel = if (deviceType == DeviceType.SCALE) "Scale" else "Scanner"
//
//        emitStatus("connected", "$typeLabel connected")
//
//        Log.i(TAG, "$typeLabel connected: $key")
//
//        if (deviceType == DeviceType.SCALE) {
//
//            try {
//
//                port.write("W\r".toByteArray(), 500)
//
//            } catch (e: Exception) {
//
//                Log.w(TAG, "Initial command failed", e)
//
//            }
//
//            Handler(Looper.getMainLooper()).postDelayed({
//
//                try {
//
//                    val readBuffer = ByteArray(256)
//
//                    val bytesRead = port.read(readBuffer, READ_TIMEOUT_MS)
//
//                    if (bytesRead > 0) {
//
//                        val rawData = String(readBuffer.take(bytesRead).toByteArray())
//
//                        Log.d("SCALE_RAW", rawData)
//
//                        addRawLog("Scale: $rawData")
//
//                        processLine(rawData, key, deviceType)
//
//                    }
//
//                } catch (e: Exception) {
//
//                    Log.w(TAG, "Delayed read error", e)
//
//                }
//
//            }, 500)
//
//            startWeightPolling(info, key)
//
//        }
//
//        startReadThread(info, key)
//
//    }
//
//    private fun startWeightPolling(info: ConnectionInfo, key: String) {
//
//        info.weightPollRunnable?.let { mainHandler.removeCallbacks(it) }
//
//        info.weightPollRunnable = object : Runnable {
//
//            override fun run() {
//
//                if (info.stopRead.get() || info.port == null) return
//
//                try {
//
//                    val commands = listOf(
//
//                        byteArrayOf('W'.code.toByte(), '\r'.code.toByte()),
//
//                        byteArrayOf('S'.code.toByte(), '\r'.code.toByte()),
//
//                        byteArrayOf(0x1B, 'W'.code.toByte(), '\r'.code.toByte()),
//
//                        byteArrayOf(0x1B, 'S'.code.toByte(), '\r'.code.toByte()),
//
//                        byteArrayOf('W'.code.toByte(), '\r'.code.toByte(), '\n'.code.toByte()),
//
//                        byteArrayOf('S'.code.toByte(), '\r'.code.toByte(), '\n'.code.toByte()),
//
//                        byteArrayOf(0x02, 'W'.code.toByte(), 0x03),
//
//                        byteArrayOf(0x02, 0x57, 0x03),
//
//                        )
//
//                    for (cmd in commands) {
//
//                        try {
//
//                            info.port?.write(cmd, 500)
//
//                            Thread.sleep(50)
//
//                        } catch (e: Exception) {
//
//                            Log.w(TAG, "Poll command failed", e)
//
//                        }
//
//                    }
//
//                } catch (e: Exception) {
//
//                    Log.w(TAG, "Weight poll error", e)
//
//                }
//
//                if (!info.stopRead.get() && info.port != null) {
//
//                    mainHandler.postDelayed(this, WEIGHT_POLL_INTERVAL_MS)
//
//                }
//
//            }
//
//        }
//
//        mainHandler.postDelayed(info.weightPollRunnable!!, WEIGHT_POLL_INTERVAL_MS)
//
//    }
//
//    private fun stopWeightPolling(info: ConnectionInfo) {
//
//        info.weightPollRunnable?.let { mainHandler.removeCallbacks(it) }
//
//        info.weightPollRunnable = null
//
//    }
//
//    private fun startReadThread(info: ConnectionInfo, key: String) {
//
//        info.readThread = Thread {
//
//            val buffer = ByteArray(256)
//
//            val lineBuffer = StringBuilder()
//
//            val maxLineLength = 128
//
//            val port = info.port ?: return@Thread
//
//            while (!info.stopRead.get()) {
//
//                try {
//
//                    val n = port.read(buffer, READ_TIMEOUT_MS)
//
//                    if (n <= 0) continue
//
//                    for (i in 0 until n) {
//
//                        val b = buffer[i].toInt().and(0x7F)
//
//                        when {
//
//                            b == 0x0A || b == 0x0D || b == 0x03 -> {
//
//                                if (lineBuffer.isNotEmpty()) {
//
//                                    val line = lineBuffer.toString().trim()
//
//                                    lineBuffer.setLength(0)
//
//                                    if (line.isNotEmpty()) {
//
//                                        processLine(line, key, info.deviceType)
//
//                                    }
//
//                                }
//
//                            }
//
//                            b == 0x02 -> lineBuffer.setLength(0)
//
//                            b in 32..126 -> {
//
//                                lineBuffer.append(b.toChar())
//
//                                if (lineBuffer.length >= maxLineLength) {
//
//                                    val line = lineBuffer.toString().trim()
//
//                                    lineBuffer.setLength(0)
//
//                                    if (line.isNotEmpty()) {
//
//                                        processLine(line, key, info.deviceType)
//
//                                    }
//
//                                }
//
//                            }
//
//                        }
//
//                    }
//
//                } catch (e: Exception) {
//
//                    if (!info.stopRead.get()) {
//
//                        Log.e(TAG, "Read error", e)
//
//                        mainHandler.post { handleDetach(port.driver.device) }
//
//                    }
//
//                    break
//
//                }
//
//            }
//
//        }.apply { start() }
//
//    }
//
//    private fun processLine(line: String, source: String, deviceType: DeviceType) {
//
//        if (line.isEmpty()) return
//
//        mainHandler.post {
//
//            addRawLog("$source: $line")
//
//            when (deviceType) {
//
//                DeviceType.SCALE -> {
//
//                    val parsed = parseWeight(line)
//
//                    if (parsed != null) {
//
//                        emitWeight(parsed, "$source: $line")
//
//                    } else if (line.all { it.isDigit() } && line.length in 6..13) {
//
//                        emitScan("$source: $line")
//
//                    }
//
//                }
//
//                DeviceType.SCANNER -> {
//
//                    if (looksLikeBarcode(line)) {
//
//                        emitScan("$source: $line")
//
//                    } else {
//
//                        val parsed = parseWeight(line)
//
//                        if (parsed != null) {
//
//                            emitWeight(parsed, "$source: $line")
//
//                        }
//
//                    }
//
//                }
//
//                DeviceType.UNKNOWN -> {
//
//                    val parsed = parseWeight(line)
//
//                    if (parsed != null) {
//
//                        emitWeight(parsed, "$source: $line")
//
//                    } else if (looksLikeBarcode(line)) {
//
//                        emitScan("$source: $line")
//
//                    }
//
//                }
//
//            }
//
//        }
//
//    }
//
//    private fun looksLikeBarcode(line: String): Boolean {
//
//        if (line.length !in 4..64) return false
//
//        val alphaNum = line.count { it.isLetterOrDigit() }
//
//        if (alphaNum < line.length * 3 / 4) return false
//
//        return !line.contains(Regex("""\d+[.,]\d+"""))
//
//    }
//
//    private fun addRawLog(line: String) {
//
//        rawLog.add(line)
//
//        if (rawLog.size > MAX_LOG_LINES) rawLog.removeAt(0)
//
//        emitRaw(line)
//
//    }
//
//    private fun parseWeight(line: String): JSONObject? {
//
//        val trimmed = line.trim()
//
//        if (trimmed.isEmpty()) return null
//
//        val upper = trimmed.uppercase()
//
//        val magellanMatch = Regex("""S1(?:1(\d{4})|4[04]0(\d{4}))\s*$""", RegexOption.IGNORE_CASE).find(trimmed)
//
//        if (magellanMatch != null) {
//
//            val digits = magellanMatch.groupValues[1].ifEmpty { magellanMatch.groupValues[2] }
//
//            if (digits.length == 4) {
//
//                val weight = (digits.take(2) + "." + digits.takeLast(2)).toDoubleOrNull() ?: return null
//
//                return JSONObject().apply {
//
//                    put("weight", weight)
//
//                    put("unit", "lb")
//
//                    put("stable", true)
//
//                }
//
//            }
//
//        }
//
//        if (upper == "OL" || upper.startsWith("OL,") || upper.startsWith("OL ")) {
//
//            return JSONObject().apply {
//
//                put("weight", 0.0)
//
//                put("unit", "kg")
//
//                put("stable", false)
//
//            }
//
//        }
//
//        val prefixedRegex = Regex(
//
//            """(?:ST|US|S)[,\s]*(?:GS|NT)?,?\s*([+-]?\d+[.,]?\d*)\s*(kg|lb|g|oz)?""",
//
//            RegexOption.IGNORE_CASE
//
//        )
//
//        val prefixedMatch = prefixedRegex.find(upper)
//
//        if (prefixedMatch != null) {
//
//            val stable = upper.startsWith("ST") || (upper.startsWith("S") && !upper.startsWith("US"))
//
//            val numStr = prefixedMatch.groupValues[1].replace(',', '.')
//
//            val unit = (prefixedMatch.groupValues.getOrElse(2) { "" }).lowercase().ifEmpty { "kg" }
//
//            val weight = numStr.toDoubleOrNull() ?: return null
//
//            return JSONObject().apply {
//
//                put("weight", weight)
//
//                put("unit", unit)
//
//                put("stable", stable)
//
//            }
//
//        }
//
//        var fallbackMatch = Regex("""([+-]?\d+[.,]\d+)\s*(kg|lb|g|oz)?""", RegexOption.IGNORE_CASE).find(trimmed)
//
//        if (fallbackMatch != null) {
//
//            val numStr = fallbackMatch.groupValues[1].replace(',', '.')
//
//            val unit = (fallbackMatch.groupValues.getOrElse(2) { "" }).lowercase().ifEmpty { "kg" }
//
//            val weight = numStr.toDoubleOrNull() ?: return null
//
//            return JSONObject().apply {
//
//                put("weight", weight)
//
//                put("unit", unit)
//
//                put("stable", true)
//
//            }
//
//        }
//
//        val nciMatch = Regex("""(\d{1,3}[.,]\d{2,3})\s*(lb|kg|g|oz)?""", RegexOption.IGNORE_CASE).find(trimmed)
//
//        if (nciMatch != null) {
//
//            val numStr = nciMatch.groupValues[1].replace(',', '.')
//
//            val unit = nciMatch.groupValues.getOrElse(2) { "lb" }.lowercase()
//
//            val weight = numStr.toDoubleOrNull() ?: return null
//
//            return JSONObject().apply {
//
//                put("weight", weight)
//
//                put("unit", unit)
//
//                put("stable", true)
//
//            }
//
//        }
//
//        fallbackMatch = Regex("""([+-]?\d+)\s*(kg|lb|g|oz)\s*$""", RegexOption.IGNORE_CASE).find(trimmed)
//
//        if (fallbackMatch != null) {
//
//            val numStr = fallbackMatch.groupValues[1]
//
//            val unit = fallbackMatch.groupValues[2].lowercase()
//
//            val weight = numStr.toDoubleOrNull() ?: return null
//
//            return JSONObject().apply {
//
//                put("weight", weight)
//
//                put("unit", unit)
//
//                put("stable", true)
//
//            }
//
//        }
//
//        val lastNum = Regex("""([+-]?\d+[.,]?\d*)\s*(kg|lb|g|oz)?\s*$""", RegexOption.IGNORE_CASE).find(trimmed)
//
//        if (lastNum != null) {
//
//            val numStr = lastNum.groupValues[1].replace(',', '.')
//
//            if (numStr.replace(".", "").replace("-", "").length > 8 && !numStr.contains(".") && !numStr.contains(",")) {
//
//                return null
//
//            }
//
//            val unit = (lastNum.groupValues.getOrElse(2) { "" }).lowercase().ifEmpty { "kg" }
//
//            val weight = numStr.toDoubleOrNull() ?: return null
//
//            if (weight >= 0.001 && weight <= 99999.999) {
//
//                return JSONObject().apply {
//
//                    put("weight", weight)
//
//                    put("unit", unit)
//
//                    put("stable", true)
//
//                }
//
//            }
//
//        }
//
//        if (trimmed.all { it.isDigit() } && trimmed.length in 10..16) {
//
//            if (trimmed.length >= 4) {
//
//                val last4 = trimmed.takeLast(4)
//
//                val weight4 = (last4.take(2) + "." + last4.takeLast(2)).toDoubleOrNull()
//
//                if (weight4 != null && weight4 in 0.01..99.99) {
//
//                    return JSONObject().apply {
//
//                        put("weight", weight4)
//
//                        put("unit", "kg")
//
//                        put("stable", true)
//
//                    }
//
//                }
//
//            }
//
//            if (trimmed.length >= 5) {
//
//                val last5 = trimmed.takeLast(5)
//
//                val weight5 = (last5.take(3) + "." + last5.takeLast(2)).toDoubleOrNull()
//
//                if (weight5 != null && weight5 in 0.001..999.99) {
//
//                    return JSONObject().apply {
//
//                        put("weight", weight5)
//
//                        put("unit", "kg")
//
//                        put("stable", true)
//
//                    }
//
//                }
//
//            }
//
//        }
//
//        return null
//
//    }
//
//    private fun handleDetach(device: UsbDevice) {
//
//        val key = device.deviceName
//
//        val info = deviceConnections[key] ?: return
//
//        closePort(info, key)
//
//        deviceConnections.remove(key)
//
//        val typeLabel = if (info.deviceType == DeviceType.SCALE) "Scale" else "Scanner"
//
//        emitStatus("disconnected", "$typeLabel disconnected")
//
//        Log.i(TAG, "$typeLabel disconnected: $key")
//
//        if (listening) {
//
//            Log.i(TAG, "Reconnecting...")
//
//            emitStatus("connecting", "Reconnecting...")
//
//            mainHandler.postDelayed({ findAndConnect() }, 1000)
//
//        }
//
//    }
//
//    private fun closePort(info: ConnectionInfo, key: String) {
//
//        stopWeightPolling(info)
//
//        info.stopRead.set(true)
//
//        info.readThread?.interrupt()
//
//        info.readThread = null
//
//        try { info.port?.close() } catch (_: Exception) {}
//
//        info.port = null
//
//        try { info.connection?.close() } catch (_: Exception) {}
//
//        info.connection = null
//
//    }
//
//    private fun emitStatus(status: String, message: String) {
//
//        mainHandler.post {
//
//            try {
//
//                if (eventSink == null) return@post
//
//                val json = JSONObject().apply {
//
//                    put("type", "status")
//
//                    put("status", status)
//
//                    put("message", message)
//
//                }
//
//                eventSink?.success(json.toString())
//
//            } catch (e: Exception) {
//
//                Log.e(TAG, "Status emit failed", e)
//
//            }
//
//        }
//
//    }
//
//    private fun emitWeight(json: JSONObject, rawLine: String) {
//
//        mainHandler.post {
//
//            try {
//
//                if (eventSink == null) return@post
//
//                val w = json.getDouble("weight")
//
//                val unit = json.getString("unit")
//
//                val stable = json.getBoolean("stable")
//
//                Log.i(TAG, "Weight: $w $unit")
//
//                val wrapper = JSONObject().apply {
//
//                    put("type", "weight")
//
//                    put("weight", w)
//
//                    put("unit", unit)
//
//                    put("stable", stable)
//
//                    put("raw", rawLine)
//
//                }
//
//                eventSink?.success(wrapper.toString())
//
//            } catch (e: Exception) {
//
//                Log.e(TAG, "Weight emit failed", e)
//
//            }
//
//        }
//
//    }
//
//    private fun emitRaw(line: String) {
//
//        mainHandler.post {
//
//            try {
//
//                if (eventSink == null) return@post
//
//                val json = JSONObject().apply {
//
//                    put("type", "raw")
//
//                    put("raw", line)
//
//                }
//
//                eventSink?.success(json.toString())
//
//            } catch (e: Exception) {
//
//                Log.e(TAG, "Raw emit failed", e)
//
//            }
//
//        }
//
//    }
//
//    private fun emitScan(line: String) {
//
//        mainHandler.post {
//
//            try {
//
//                if (eventSink == null) return@post
//
//                Log.i(TAG, "Scan: $line")
//
//                val json = JSONObject().apply {
//
//                    put("type", "scan")
//
//                    put("raw", line)
//
//                }
//
//                eventSink?.success(json.toString())
//
//            } catch (e: Exception) {
//
//                Log.e(TAG, "Scan emit failed", e)
//
//            }
//
//        }
//
//    }
//
//    class PermissionBroadcastReceiver(
//
//        private val manager: UsbSerialManager
//
//    ) : BroadcastReceiver() {
//
//        override fun onReceive(context: Context?, intent: Intent?) {
//
//            if (intent?.action == ACTION_USB_PERMISSION) {
//
//                val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
//
//                @Suppress("DEPRECATION")
//
//                val device = intent?.getParcelableExtra<UsbDevice>(UsbManager.EXTRA_DEVICE)
//
//                manager.onPermissionResult(granted, device)
//
//            }
//
//        }
//
//    }
//
//}
//
//const val ACTION_USB_PERMISSION = "com.alekta.pinakapos"
//




package com.alekta.pinakapos

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.hoho.android.usbserial.driver.CdcAcmSerialDriver
import com.hoho.android.usbserial.driver.FtdiSerialDriver
import com.hoho.android.usbserial.driver.ProbeTable
import com.hoho.android.usbserial.driver.UsbSerialPort
import com.hoho.android.usbserial.driver.UsbSerialProber
import io.flutter.plugin.common.EventChannel
import org.json.JSONObject
import java.util.concurrent.atomic.AtomicBoolean

enum class DeviceType { SCALE, SCANNER, UNKNOWN }

data class ConnectionInfo(
    var connection: android.hardware.usb.UsbDeviceConnection? = null,
    var port: UsbSerialPort? = null,
    var readThread: Thread? = null,
    var stopRead: AtomicBoolean = AtomicBoolean(false),
    var weightPollRunnable: Runnable? = null,
    var deviceType: DeviceType = DeviceType.UNKNOWN
)

class UsbSerialManager(
    private val context: Context
) {
    companion object {
        private const val TAG = "UsbSerialManager"
        // Datalogic Magellan VID — used as SCANNER
        private const val MAGELLAN_VID = 0x05F9
        private val MAGELLAN_PIDS = intArrayOf(0x2205, 0x2601, 0x2602)
        // FTDI VID 1027 (0x0403) — used as SCALE
        private const val FTDI_VID = 0x0403
        private const val FTDI_PID_SCALE_1 = 0xB0C2
        private const val FTDI_PID_SCALE_2 = 0xB0C1
        private val FTDI_SCALE_PIDS = intArrayOf(FTDI_PID_SCALE_1, FTDI_PID_SCALE_2)
        private const val BAUD_RATE = 9600
        private const val READ_TIMEOUT_MS = 500
        private const val MAX_LOG_LINES = 200
        private const val WEIGHT_POLL_INTERVAL_MS = 500L
    }

    @Volatile
    private var eventSink: EventChannel.EventSink? = null
    @Volatile
    private var listening = false
    private val usbManager: UsbManager = context.getSystemService(Context.USB_SERVICE) as UsbManager
    private val mainHandler = Handler(Looper.getMainLooper())
    private val deviceConnections = mutableMapOf<String, ConnectionInfo>()
    private val pendingPermissions = mutableSetOf<Int>()
    private val rawLog = mutableListOf<String>()
    private var permissionReceiver: PermissionBroadcastReceiver? = null
    private var lastLoggedDevices = setOf<String>()

    private val usbReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                UsbManager.ACTION_USB_DEVICE_ATTACHED -> {
                    @Suppress("DEPRECATION")
                    val device = intent?.getParcelableExtra<UsbDevice>(UsbManager.EXTRA_DEVICE)
                    if (device != null && listening) {
                        Log.i(TAG, "DEVICE ATTACHED: ${device.deviceName} VID=0x${device.vendorId.toString(16)} PID=0x${device.productId.toString(16)}")
                        mainHandler.post { tryConnect(device) }
                    }
                }
                UsbManager.ACTION_USB_DEVICE_DETACHED -> {
                    @Suppress("DEPRECATION")
                    val device = intent?.getParcelableExtra<UsbDevice>(UsbManager.EXTRA_DEVICE)
                    if (device != null) {
                        Log.i(TAG, "DEVICE DETACHED: ${device.deviceName}")
                        mainHandler.post { handleDetach(device) }
                    }
                }
            }
        }
    }

    init {
        Log.i(TAG, "UsbSerialManager initialized")
        val filter = IntentFilter().apply {
            addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
            addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
        }
        if (android.os.Build.VERSION.SDK_INT >= 33) {
            context.registerReceiver(usbReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            context.registerReceiver(usbReceiver, filter)
        }

        permissionReceiver = PermissionBroadcastReceiver(this).also { receiver ->
            val permFilter = IntentFilter().apply { addAction(ACTION_USB_PERMISSION) }
            if (android.os.Build.VERSION.SDK_INT >= 33) {
                context.registerReceiver(receiver, permFilter, Context.RECEIVER_EXPORTED)
            } else {
                context.registerReceiver(receiver, permFilter)
            }
        }
    }

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
        if (sink != null) {
            Log.i(TAG, "EventSink connected")
        }
    }

    fun startListening() {
        Log.i(TAG, "Start listening for devices")
        listening = true
        emitStatus("connecting", "Scanning for devices...")
        findAndConnect()
        // Flutter treats every "connecting" as disconnected until "connected".
        // If USB was already open, findAndConnect() does nothing — re-emit connected.
        emitConnectedIfAlreadyOpen()
    }

    /** When [deviceConnections] already has an open port, sync Flutter UI (EventChannel re-subscribe, etc.). */
    private fun emitConnectedIfAlreadyOpen() {
        if (!listening || deviceConnections.isEmpty()) return
        val info = deviceConnections.values.firstOrNull { it.port != null } ?: return
        val typeLabel = if (info.deviceType == DeviceType.SCALE) "Scale" else "Scanner"
        emitStatus("connected", "$typeLabel connected")
    }

    fun connectToDevice(device: UsbDevice) {
        Log.i(TAG, "Manual device connection: ${device.deviceName}")
        listening = true
        emitStatus("connecting", "Connecting...")
        tryConnect(device)
    }

    fun stopListening() {
        Log.i(TAG, "Stop listening")
        listening = false
        for ((key, info) in deviceConnections.toMap()) {
            closePort(info, key)
            deviceConnections.remove(key)
        }
        emitStatus("stopped", "Stopped")
    }

    /** Drop active USB connections and scan again (MethodChannel "reconnect"). */
    fun restartDevice() {
        Log.i(TAG, "Restart USB serial (reconnect)")
        if (!listening) {
            startListening()
            return
        }
        for ((key, info) in deviceConnections.toMap()) {
            closePort(info, key)
            deviceConnections.remove(key)
        }
        emitStatus("connecting", "Reconnecting...")
        mainHandler.postDelayed({ findAndConnect() }, 300)
    }

    fun dispose() {
        Log.i(TAG, "Dispose")
        permissionReceiver?.let { context.unregisterReceiver(it) }
        permissionReceiver = null
        try {
            context.unregisterReceiver(usbReceiver)
        } catch (_: Exception) {}
        stopListening()
        eventSink = null
    }

    private fun findAndConnect() {
        val deviceList = usbManager.deviceList ?: return

        val currentDevices = deviceList.values
            .filter { isTargetDevice(it) }
            .map { it.deviceName }
            .toSet()

        if (currentDevices != lastLoggedDevices) {
            Log.i(TAG, "Found ${currentDevices.size} target devices")
            lastLoggedDevices = currentDevices
        }

        for (device in deviceList.values) {
            if (isTargetDevice(device) && deviceConnections[device.deviceName] == null) {
                Log.i(TAG, "Connecting: ${device.deviceName}")
                tryConnect(device)
            }
        }

        if (deviceConnections.isEmpty() && listening) {
            emitStatus("disconnected", "No device found")
        }
    }

    private fun isTargetDevice(device: UsbDevice): Boolean {
        val vid = device.vendorId
        return (vid == FTDI_VID) || (vid == MAGELLAN_VID)
    }

    private fun getDeviceType(device: UsbDevice): DeviceType {
        val vid = device.vendorId
        val pid = device.productId

        return when {
            vid == FTDI_VID && FTDI_SCALE_PIDS.contains(pid) -> DeviceType.SCALE
            vid == FTDI_VID -> DeviceType.SCALE
            vid == MAGELLAN_VID -> DeviceType.SCANNER
            else -> DeviceType.UNKNOWN
        }
    }

    private fun getCustomProber(): UsbSerialProber {
        val table = UsbSerialProber.getDefaultProbeTable()
        for (pid in MAGELLAN_PIDS) {
            table.addProduct(MAGELLAN_VID, pid, CdcAcmSerialDriver::class.java)
        }
        table.addProduct(FTDI_VID, FTDI_PID_SCALE_1, FtdiSerialDriver::class.java)
        table.addProduct(FTDI_VID, FTDI_PID_SCALE_2, FtdiSerialDriver::class.java)
        return UsbSerialProber(table)
    }

    private fun tryConnect(device: UsbDevice) {
        if (!listening) return
        val key = device.deviceName
        if (deviceConnections[key] != null) return
        if (pendingPermissions.contains(device.deviceId)) return

        if (!usbManager.hasPermission(device)) {
            Log.i(TAG, "Requesting permission: ${device.deviceId}")
            pendingPermissions.add(device.deviceId)
            emitStatus("connecting", "Requesting permission...")
            usbManager.requestPermission(device, createPermissionIntent())
            return
        }

        openDevice(device)
    }

    private fun createPermissionIntent(): android.app.PendingIntent {
        val flags = android.app.PendingIntent.FLAG_MUTABLE or android.app.PendingIntent.FLAG_UPDATE_CURRENT
        return android.app.PendingIntent.getBroadcast(context, 0, Intent(ACTION_USB_PERMISSION), flags)
    }

    fun onPermissionResult(granted: Boolean, device: UsbDevice?) {
        if (device != null) {
            pendingPermissions.remove(device.deviceId)
        }
        if (!granted || device == null) {
            Log.w(TAG, "Permission denied")
            emitStatus("error", "Permission denied")
            return
        }
        if (listening) {
            openDevice(device)
        }
    }

    private fun openDevice(device: UsbDevice) {
        val key = device.deviceName
        val deviceType = getDeviceType(device)
        Log.i(TAG, "Opening ${deviceType.name}: $key")

        val conn = usbManager.openDevice(device) ?: run {
            Log.e(TAG, "Failed to open device")
            emitStatus("error", "Failed to open device")
            return
        }

        val prober = getCustomProber()
        val driver = prober.probeDevice(device) ?: run {
            Log.e(TAG, "No driver found")
            conn.close()
            emitStatus("error", "No compatible driver")
            return
        }

        val ports = driver.ports
        if (ports.isEmpty()) {
            Log.e(TAG, "No ports available")
            conn.close()
            emitStatus("error", "No ports available")
            return
        }

        val port = ports[0]

        try {
            port.open(conn)
            if (deviceType == DeviceType.SCALE) {
                port.setParameters(BAUD_RATE, 7, UsbSerialPort.STOPBITS_1, UsbSerialPort.PARITY_EVEN)
                port.setDTR(true)
                port.setRTS(true)
            } else {
                port.setParameters(BAUD_RATE, 8, UsbSerialPort.STOPBITS_1, UsbSerialPort.PARITY_NONE)
            }
            Log.i(TAG, "Port configured: ${deviceType.name}")
        } catch (e: Exception) {
            Log.e(TAG, "Port configuration failed", e)
            try { port.close() } catch (_: Exception) {}
            conn.close()
            emitStatus("error", "Port config failed")
            return
        }

        val info = ConnectionInfo(
            connection = conn,
            port = port,
            stopRead = AtomicBoolean(false),
            deviceType = deviceType
        )
        deviceConnections[key] = info

        val typeLabel = if (deviceType == DeviceType.SCALE) "Scale" else "Scanner"
        emitStatus("connected", "$typeLabel connected")
        Log.i(TAG, "$typeLabel connected: $key")

        if (deviceType == DeviceType.SCALE) {
            try {
                port.write("W\r".toByteArray(), 500)
            } catch (e: Exception) {
                Log.w(TAG, "Initial command failed", e)
            }

            Handler(Looper.getMainLooper()).postDelayed({
                try {
                    val readBuffer = ByteArray(256)
                    val bytesRead = port.read(readBuffer, READ_TIMEOUT_MS)
                    if (bytesRead > 0) {
                        val rawData = String(readBuffer.take(bytesRead).toByteArray())
                        Log.d("SCALE_RAW", rawData)
                        addRawLog("Scale: $rawData")
                        processLine(rawData, key, deviceType)
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Delayed read error", e)
                }
            }, 500)

            startWeightPolling(info, key)
        }

        startReadThread(info, key)
    }

    private fun startWeightPolling(info: ConnectionInfo, key: String) {
        info.weightPollRunnable?.let { mainHandler.removeCallbacks(it) }
        info.weightPollRunnable = object : Runnable {
            override fun run() {
                if (info.stopRead.get() || info.port == null) return

                try {
                    val commands = listOf(
                        byteArrayOf('W'.code.toByte(), '\r'.code.toByte()),
                        byteArrayOf('S'.code.toByte(), '\r'.code.toByte()),
                        byteArrayOf(0x1B, 'W'.code.toByte(), '\r'.code.toByte()),
                        byteArrayOf(0x1B, 'S'.code.toByte(), '\r'.code.toByte()),
                        byteArrayOf('W'.code.toByte(), '\r'.code.toByte(), '\n'.code.toByte()),
                        byteArrayOf('S'.code.toByte(), '\r'.code.toByte(), '\n'.code.toByte()),
                        byteArrayOf(0x02, 'W'.code.toByte(), 0x03),
                        byteArrayOf(0x02, 0x57, 0x03),
                    )

                    for (cmd in commands) {
                        try {
                            info.port?.write(cmd, 500)
                            Thread.sleep(50)
                        } catch (e: Exception) {
                            Log.w(TAG, "Poll command failed", e)
                        }
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Weight poll error", e)
                }

                if (!info.stopRead.get() && info.port != null) {
                    mainHandler.postDelayed(this, WEIGHT_POLL_INTERVAL_MS)
                }
            }
        }
        mainHandler.postDelayed(info.weightPollRunnable!!, WEIGHT_POLL_INTERVAL_MS)
    }

    private fun stopWeightPolling(info: ConnectionInfo) {
        info.weightPollRunnable?.let { mainHandler.removeCallbacks(it) }
        info.weightPollRunnable = null
    }

    private fun startReadThread(info: ConnectionInfo, key: String) {
        info.readThread = Thread {
            val buffer = ByteArray(256)
            val lineBuffer = StringBuilder()
            val maxLineLength = 128
            val port = info.port ?: return@Thread

            while (!info.stopRead.get()) {
                try {
                    val n = port.read(buffer, READ_TIMEOUT_MS)
                    if (n <= 0) continue

                    for (i in 0 until n) {
                        val b = buffer[i].toInt().and(0x7F)
                        when {
                            b == 0x0A || b == 0x0D || b == 0x03 -> {
                                if (lineBuffer.isNotEmpty()) {
                                    val line = lineBuffer.toString().trim()
                                    lineBuffer.setLength(0)
                                    if (line.isNotEmpty()) {
                                        processLine(line, key, info.deviceType)
                                    }
                                }
                            }
                            b == 0x02 -> lineBuffer.setLength(0)
                            b in 32..126 -> {
                                lineBuffer.append(b.toChar())
                                if (lineBuffer.length >= maxLineLength) {
                                    val line = lineBuffer.toString().trim()
                                    lineBuffer.setLength(0)
                                    if (line.isNotEmpty()) {
                                        processLine(line, key, info.deviceType)
                                    }
                                }
                            }
                        }
                    }
                } catch (e: Exception) {
                    if (!info.stopRead.get()) {
                        Log.e(TAG, "Read error", e)
                        mainHandler.post { handleDetach(port.driver.device) }
                    }
                    break
                }
            }
        }.apply { start() }
    }

    private fun processLine(line: String, source: String, deviceType: DeviceType) {
        if (line.isEmpty()) return
        mainHandler.post {
            addRawLog("$source: $line")

            when (deviceType) {
                DeviceType.SCALE -> {
                    val parsed = parseWeight(line)
                    if (parsed != null) {
                        emitWeight(parsed, "$source: $line")
                    } else if (line.all { it.isDigit() } && line.length in 6..13) {
                        emitScan("$source: $line")
                    }
                }
                DeviceType.SCANNER -> {
                    if (looksLikeBarcode(line)) {
                        emitScan("$source: $line")
                    } else {
                        val parsed = parseWeight(line)
                        if (parsed != null) {
                            emitWeight(parsed, "$source: $line")
                        }
                    }
                }
                DeviceType.UNKNOWN -> {
                    val parsed = parseWeight(line)
                    if (parsed != null) {
                        emitWeight(parsed, "$source: $line")
                    } else if (looksLikeBarcode(line)) {
                        emitScan("$source: $line")
                    }
                }
            }
        }
    }

    private fun looksLikeBarcode(line: String): Boolean {
        if (line.length !in 4..64) return false
        val alphaNum = line.count { it.isLetterOrDigit() }
        if (alphaNum < line.length * 3 / 4) return false
        return !line.contains(Regex("""\d+[.,]\d+"""))
    }

    private fun addRawLog(line: String) {
        rawLog.add(line)
        if (rawLog.size > MAX_LOG_LINES) rawLog.removeAt(0)
        emitRaw(line)
    }

    private fun parseWeight(line: String): JSONObject? {
        val trimmed = line.trim()
        if (trimmed.isEmpty()) return null
        val upper = trimmed.uppercase()

        val magellanMatch = Regex("""S1(?:1(\d{4})|4[04]0(\d{4}))\s*$""", RegexOption.IGNORE_CASE).find(trimmed)
        if (magellanMatch != null) {
            val digits = magellanMatch.groupValues[1].ifEmpty { magellanMatch.groupValues[2] }
            if (digits.length == 4) {
                val weight = (digits.take(2) + "." + digits.takeLast(2)).toDoubleOrNull() ?: return null
                return JSONObject().apply {
                    put("weight", weight)
                    put("unit", "lb")
                    put("stable", true)
                }
            }
        }

        if (upper == "OL" || upper.startsWith("OL,") || upper.startsWith("OL ")) {
            return JSONObject().apply {
                put("weight", 0.0)
                put("unit", "kg")
                put("stable", false)
            }
        }

        val prefixedRegex = Regex(
            """(?:ST|US|S)[,\s]*(?:GS|NT)?,?\s*([+-]?\d+[.,]?\d*)\s*(kg|lb|g|oz)?""",
            RegexOption.IGNORE_CASE
        )
        val prefixedMatch = prefixedRegex.find(upper)
        if (prefixedMatch != null) {
            val stable = upper.startsWith("ST") || (upper.startsWith("S") && !upper.startsWith("US"))
            val numStr = prefixedMatch.groupValues[1].replace(',', '.')
            val unit = (prefixedMatch.groupValues.getOrElse(2) { "" }).lowercase().ifEmpty { "kg" }
            val weight = numStr.toDoubleOrNull() ?: return null
            return JSONObject().apply {
                put("weight", weight)
                put("unit", unit)
                put("stable", stable)
            }
        }

        var fallbackMatch = Regex("""([+-]?\d+[.,]\d+)\s*(kg|lb|g|oz)?""", RegexOption.IGNORE_CASE).find(trimmed)
        if (fallbackMatch != null) {
            val numStr = fallbackMatch.groupValues[1].replace(',', '.')
            val unit = (fallbackMatch.groupValues.getOrElse(2) { "" }).lowercase().ifEmpty { "kg" }
            val weight = numStr.toDoubleOrNull() ?: return null
            return JSONObject().apply {
                put("weight", weight)
                put("unit", unit)
                put("stable", true)
            }
        }

        val nciMatch = Regex("""(\d{1,3}[.,]\d{2,3})\s*(lb|kg|g|oz)?""", RegexOption.IGNORE_CASE).find(trimmed)
        if (nciMatch != null) {
            val numStr = nciMatch.groupValues[1].replace(',', '.')
            val unit = nciMatch.groupValues.getOrElse(2) { "lb" }.lowercase()
            val weight = numStr.toDoubleOrNull() ?: return null
            return JSONObject().apply {
                put("weight", weight)
                put("unit", unit)
                put("stable", true)
            }
        }

        fallbackMatch = Regex("""([+-]?\d+)\s*(kg|lb|g|oz)\s*$""", RegexOption.IGNORE_CASE).find(trimmed)
        if (fallbackMatch != null) {
            val numStr = fallbackMatch.groupValues[1]
            val unit = fallbackMatch.groupValues[2].lowercase()
            val weight = numStr.toDoubleOrNull() ?: return null
            return JSONObject().apply {
                put("weight", weight)
                put("unit", unit)
                put("stable", true)
            }
        }

        val lastNum = Regex("""([+-]?\d+[.,]?\d*)\s*(kg|lb|g|oz)?\s*$""", RegexOption.IGNORE_CASE).find(trimmed)
        if (lastNum != null) {
            val numStr = lastNum.groupValues[1].replace(',', '.')
            if (numStr.replace(".", "").replace("-", "").length > 8 && !numStr.contains(".") && !numStr.contains(",")) {
                return null
            }
            val unit = (lastNum.groupValues.getOrElse(2) { "" }).lowercase().ifEmpty { "kg" }
            val weight = numStr.toDoubleOrNull() ?: return null
            if (weight >= 0.001 && weight <= 99999.999) {
                return JSONObject().apply {
                    put("weight", weight)
                    put("unit", unit)
                    put("stable", true)
                }
            }
        }

        if (trimmed.all { it.isDigit() } && trimmed.length in 10..16) {
            if (trimmed.length >= 4) {
                val last4 = trimmed.takeLast(4)
                val weight4 = (last4.take(2) + "." + last4.takeLast(2)).toDoubleOrNull()
                if (weight4 != null && weight4 in 0.01..99.99) {
                    return JSONObject().apply {
                        put("weight", weight4)
                        put("unit", "kg")
                        put("stable", true)
                    }
                }
            }
            if (trimmed.length >= 5) {
                val last5 = trimmed.takeLast(5)
                val weight5 = (last5.take(3) + "." + last5.takeLast(2)).toDoubleOrNull()
                if (weight5 != null && weight5 in 0.001..999.99) {
                    return JSONObject().apply {
                        put("weight", weight5)
                        put("unit", "kg")
                        put("stable", true)
                    }
                }
            }
        }

        return null
    }

    private fun handleDetach(device: UsbDevice) {
        val key = device.deviceName
        val info = deviceConnections[key] ?: return

        closePort(info, key)
        deviceConnections.remove(key)

        val typeLabel = if (info.deviceType == DeviceType.SCALE) "Scale" else "Scanner"
        emitStatus("disconnected", "$typeLabel disconnected")
        Log.i(TAG, "$typeLabel disconnected: $key")

        if (listening) {
            Log.i(TAG, "Reconnecting...")
            emitStatus("connecting", "Reconnecting...")
            mainHandler.postDelayed({ findAndConnect() }, 1000)
        }
    }

    private fun closePort(info: ConnectionInfo, key: String) {
        stopWeightPolling(info)
        info.stopRead.set(true)
        info.readThread?.interrupt()
        info.readThread = null
        try { info.port?.close() } catch (_: Exception) {}
        info.port = null
        try { info.connection?.close() } catch (_: Exception) {}
        info.connection = null
    }

    private fun emitStatus(status: String, message: String) {
        mainHandler.post {
            try {
                if (eventSink == null) return@post
                val json = JSONObject().apply {
                    put("type", "status")
                    put("status", status)
                    put("message", message)
                }
                eventSink?.success(json.toString())
            } catch (e: Exception) {
                Log.e(TAG, "Status emit failed", e)
            }
        }
    }

    private fun emitWeight(json: JSONObject, rawLine: String) {
        mainHandler.post {
            try {
                if (eventSink == null) return@post
                val w = json.getDouble("weight")
                val unit = json.getString("unit")
                val stable = json.getBoolean("stable")
                Log.i(TAG, "Weight: $w $unit")
                val wrapper = JSONObject().apply {
                    put("type", "weight")
                    put("weight", w)
                    put("unit", unit)
                    put("stable", stable)
                    put("raw", rawLine)
                }
                eventSink?.success(wrapper.toString())
            } catch (e: Exception) {
                Log.e(TAG, "Weight emit failed", e)
            }
        }
    }

    private fun emitRaw(line: String) {
        mainHandler.post {
            try {
                if (eventSink == null) return@post
                val json = JSONObject().apply {
                    put("type", "raw")
                    put("raw", line)
                }
                eventSink?.success(json.toString())
            } catch (e: Exception) {
                Log.e(TAG, "Raw emit failed", e)
            }
        }
    }

    private fun emitScan(line: String) {
        mainHandler.post {
            try {
                if (eventSink == null) return@post
                Log.i(TAG, "Scan: $line")
                val json = JSONObject().apply {
                    put("type", "scan")
                    put("raw", line)
                }
                eventSink?.success(json.toString())
            } catch (e: Exception) {
                Log.e(TAG, "Scan emit failed", e)
            }
        }
    }

    class PermissionBroadcastReceiver(
        private val manager: UsbSerialManager
    ) : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == ACTION_USB_PERMISSION) {
                val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
                @Suppress("DEPRECATION")
                val device = intent?.getParcelableExtra<UsbDevice>(UsbManager.EXTRA_DEVICE)
                manager.onPermissionResult(granted, device)
            }
        }
    }
}

const val ACTION_USB_PERMISSION = "com.alekta.pinakapos"