package com.alekta.pinakapos

import android.app.Activity
import android.app.PendingIntent
import android.app.Presentation
import android.content.ActivityNotFoundException
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.hardware.display.DisplayManager
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.nfc.NfcAdapter
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Display
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.widget.*
import com.creditcall.chipdnamobile.*
import com.alekta.pinakapos.UsbSerialManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import java.net.URL
import java.text.NumberFormat
import java.util.Locale

class MainActivity : FlutterActivity() {

    // ===== Weighing scale =====
    private var usbSerialManager: UsbSerialManager? = null

    // ===== VP3350 / ChipDnaMobile =====
    private val VP3350_CHANNEL = "vp3350_channel"
    private val SUNMI_PAYMENT_PACKAGE = "com.sunmi.payment.demo"
    private var chipDna: ChipDnaMobile? = null
    private var pendingResult: MethodChannel.Result? = null

    // ===== Customer display =====
    private val CHANNEL = "com.alekta.pinakapos/sunmi_display"
    private var customerDisplayPresentation: CustomerDisplayPresentation? = null
    private var currentStoreId: String = ""
    private var currentStoreName: String = ""
    private var currentStoreLogoUrl: String? = null
    private var currentStoreBaseUrl: String = ""
    private val PAYMENT_CHANNEL = "sunmi_payment_channel"
    private var saleResultCallback: MethodChannel.Result? = null
    private var isOrderActive = false
    private var authToken: String = ""
    private var isShowingThankYou = false

    // ===== USB Printer Permission =====
    private val PRINTER_CHANNEL = "com.alekta.pinakapos/printer_permission"
    private var usbPermissionReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ===== USB Printer Permission Channel =====
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PRINTER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasUSBPermission" -> {
                        val vendorId = call.argument<Int>("vendorId")
                        val productId = call.argument<Int>("productId")
                        if (vendorId != null && productId != null) {
                            result.success(checkUSBPermission(vendorId, productId))
                        } else {
                            result.success(false)
                        }
                    }
                    "requestUSBPermission" -> {
                        val vendorId = call.argument<Int>("vendorId")
                        val productId = call.argument<Int>("productId")
                        if (vendorId != null && productId != null) {
                            requestUSBPermission(vendorId, productId, result)
                        } else {
                            result.error("INVALID_ARGS", "Vendor ID and Product ID required", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // ===== Weighing scale setup =====
        usbSerialManager = UsbSerialManager(this).also { manager ->

            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                "magellan_scale"
            ).setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        manager.startListening()
                        result.success(null)
                    }
                    "stop" -> {
                        manager.stopListening()
                        result.success(null)
                    }
                    "reconnect" -> {
                        manager.restartDevice()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

            EventChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                "magellan_scale/events"
            ).setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink?) {
                    manager.setEventSink(eventSink)
                    manager.startListening()
                }

                override fun onCancel(arguments: Any?) {
                    manager.setEventSink(null)
                }
            })
        }

        handleUsbDeviceIntent(intent)

        // ===== VP3350 / ChipDnaMobile channel =====
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VP3350_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initialize" -> initializeSoftPos(result)
                    "startTransaction" -> {
                        val amount = call.argument<String>("amount")
                        if (!amount.isNullOrEmpty()) {
                            pendingResult = result
                            startSale(amount)
                        } else {
                            result.error("INVALID_AMOUNT", "Amount missing", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // ===== Customer display channel =====
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            Log.d(
                "CustomerDisplay",
                "📢 MethodChannel callllll → method=${call.method}, args=${call.arguments}"
            )

            when (call.method) {

                "showWelcome" -> {
                    Log.d("CustomerDisplay", "➡ showWelcome invoked")
                    if (showWelcomeOnCustomerDisplay()) {
                        Log.d("CustomerDisplay", "✔ Welcome displayed")
                        result.success("Welcome shown")
                    } else {
                        Log.e("CustomerDisplay", "❌ No secondary display found for Welcome")
                        result.error("NO_DISPLAY", "No secondary display found", null)
                    }
                }

                "showWelcomeWithStore" -> {
                    val storeId = call.argument<String>("storeId") ?: ""
                    val storeName = call.argument<String>("storeName") ?: ""
                    val storeLogoUrl = call.argument<String>("storeLogoUrl")
                    val storeBaseUrl = call.argument<String>("storeBaseUrl") ?: ""

                    Log.d(
                        "CustomerDisplay",
                        "➡ showWelcomeWithStore invoked → storeId=$storeId, storeName=$storeName, logo=$storeLogoUrl, baseUrl=$storeBaseUrl"
                    )

                    // Always update global state
                    currentStoreId = storeId
                    currentStoreName = storeName
                    currentStoreLogoUrl = storeLogoUrl
                    currentStoreBaseUrl = storeBaseUrl

                    // Ensure presentation exists
                    if (customerDisplayPresentation == null ||
                        customerDisplayPresentation?.display == null) {
                        showWelcomeOnCustomerDisplay()
                    }

                    // CRITICAL: Always update the presentation with latest store info
                    if (!isOrderActive) {
                        customerDisplayPresentation?.updateWelcomeWithStore(
                            storeId,
                            storeName,
                            storeLogoUrl,
                            storeBaseUrl
                        )
                        Log.d("CustomerDisplay", "✔ Updated welcome layout with store details")
                    } else {
                        Log.d("CustomerDisplay", " Order active → storing store info only (will apply on reset)")
                    }

                    result.success("Welcome updated with store")
                }

                "showCustomerData" -> {

                    if (isShowingThankYou) {
                        Log.d("CustomerDisplay", " Thank You active → skipping customer data update")
                        result.success("Skipped")
                        return@setMethodCallHandler
                    }

                    val orderId = call.argument<Int>("orderId") ?: 0
                    val items = call.argument<List<Map<String, Any>>>("items") ?: emptyList()
                    val grossTotal = call.argument<Double>("grossTotal") ?: 0.0
                    val discount = call.argument<Double>("discount") ?: 0.0
                    val merchantDiscount = call.argument<Double>("merchantDiscount") ?: 0.0
                    val netTotal = call.argument<Double>("netTotal") ?: 0.0
                    val tax = call.argument<Double>("tax") ?: 0.0
                    val netPayable = call.argument<Double>("netPayable") ?: 0.0
                    val orderDate = call.argument<String>("orderDate") ?: ""
                    val orderTime = call.argument<String>("orderTime") ?: ""
                    val cashbackFee = call.argument<Double>("cashbackFee") ?: 0.0
                    val loyaltyContact = call.argument<String>("loyaltyContact") ?: ""
                    val availablePoints = call.argument<Int>("availablePoints") ?: 0
                    val summaryEnabled = call.argument<Boolean>("summaryEnabled") ?: false
                    val redeemedAmount = call.argument<Double>("redeemedAmount") ?: 0.0

                    Log.d("CustomerDisplay", "☎ Loyalty Contact received: $loyaltyContact")
                    Log.d(
                        "CustomerDisplay",
                        "➡ showCustomerData invoked → orderId=$orderId, items=${items.size}, grossTotal=$grossTotal, discount=$discount, merchantDiscount=$merchantDiscount, netTotal=$netTotal, tax=$tax, netPayable=$netPayable"
                    )

                    val success = showDataOnCustomerDisplay(
                        orderId,
                        currentStoreId,
                        currentStoreName,
                        currentStoreLogoUrl,
                        items,
                        grossTotal,
                        discount,
                        merchantDiscount,
                        netTotal,
                        tax,
                        netPayable,
                        orderDate,
                        orderTime,
                        cashbackFee,
                        loyaltyContact,
                        availablePoints,
                        summaryEnabled,
                        redeemedAmount
                    )

                    if (success) {
                        Log.d("CustomerDisplay", "✔ Customer data displayed")
                        result.success("Data displayed")
                    } else {
                        Log.e("CustomerDisplay", "❌ No secondary display found for Customer data")
                        result.error("NO_DISPLAY", "No secondary display found", null)
                    }
                }

                "showThankYou" -> {
                    isShowingThankYou = true

                    Log.d("CustomerDisplay", "➡ showThankYou invoked")

                    if (showThankYouOnCustomerDisplay()) {
                        Log.d("CustomerDisplay", "✔ Thank You displayed")
                        result.success("Thank You shown")
                    } else {
                        isShowingThankYou = false
                        Log.e("CustomerDisplay", "❌ No secondary display found for Thank You")
                        result.error("NO_DISPLAY", "No secondary display found", null)
                    }
                }

                "enablePhoneInput" -> {
                    Handler(Looper.getMainLooper()).post {
                        customerDisplayPresentation?.enablePhoneInput()
                    }
                    result.success(true)
                }

                "customerDisplayResult" -> {
                    val success = call.argument<Boolean>("success") ?: false
                    val message = call.argument<String>("message") ?: ""
                    val points = call.argument<Int>("points") ?: 0
                    val redeemedAmount = call.argument<Double>("redeemedAmount") ?: 0.0

                    Log.d(
                        "CustomerDisplay",
                        "customerDisplayResult → success=$success points=$points redeemedAmount=$redeemedAmount"
                    )

                    Handler(Looper.getMainLooper()).post {
                        if (!success) {
                            Toast.makeText(
                                this@MainActivity,
                                if (message.isNotEmpty()) message else "Something went wrong",
                                Toast.LENGTH_LONG
                            ).show()
                        } else {
                            customerDisplayPresentation?.updateRedeemPopupPoints(points)
                            customerDisplayPresentation?.updateHeaderPoints(points)

                            if (redeemedAmount > 0) {
                                customerDisplayPresentation?.showRedeemSummary(redeemedAmount)
                            } else {
                                customerDisplayPresentation?.restoreSummaryAfterRedeemRemoval()
                            }
                        }
                    }
                    result.success(true)
                }

                "resetDisplay" -> {
                    Log.d("CustomerDisplay", "🔥 resetDisplay called")
                    isOrderActive = false
                    customerDisplayPresentation?.resetCustomerLayoutState()

                    val displayManager =
                        getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
                    val displays = displayManager.displays

                    if (displays.size > 1) {
                        val secondaryDisplay = displays[1]
                        customerDisplayPresentation?.dismiss()
                        customerDisplayPresentation = CustomerDisplayPresentation(
                            this@MainActivity,
                            this@MainActivity,
                            secondaryDisplay
                        )
                        customerDisplayPresentation?.show()
                        customerDisplayPresentation?.showWelcomeLayout(
                            currentStoreId,
                            currentStoreName,
                            currentStoreLogoUrl,
                            currentStoreBaseUrl
                        )
                    }
                    result.success("Display reset to welcome")
                }

                "setDisplayOrderId" -> {
                    val orderId = call.argument<Int>("orderId") ?: 0
                    Handler(Looper.getMainLooper()).post {
                        customerDisplayPresentation?.setOrderId(orderId)
                    }
                    result.success(null)
                }

                else -> {
                    Log.w("CustomerDisplay", "⚠ Method not implemented: ${call.method}")
                    result.notImplemented()
                }
            }
        }

        // ===== Payment channel =====
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PAYMENT_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {

                "startSale" -> {
                    val amount = call.argument<String>("amount")
                    val orderId = call.argument<String>("orderId")
                    val intent = buildSunmiSaleIntent()
                    if (intent == null) {
                        result.error("APP_NOT_INSTALLED", "Sunmi SaleActivity not found", null)
                        return@setMethodCallHandler
                    }
                    intent.putExtra("amount", amount)
                    intent.putExtra("orderId", orderId)
                    saleResultCallback = result
                    try {
                        @Suppress("DEPRECATION")
                        startActivityForResult(intent, 9090)
                    } catch (e: ActivityNotFoundException) {
                        result.error(
                            "APP_NOT_INSTALLED",
                            "Sunmi payment activity not available: ${e.message}",
                            null
                        )
                    }
                }

                "startVoid" -> {
                    val amount = call.argument<String>("amount")
                    val originOrderId = call.argument<String>("originOrderId")
                    val originTransactionId = call.argument<String>("originTransactionId")

                    Log.d(
                        "SunmiVoid",
                        "➡ startVoid → amount=$amount, originOrderId=$originOrderId, originTxn=$originTransactionId"
                    )

                    if (originOrderId.isNullOrEmpty() || originTransactionId.isNullOrEmpty()) {
                        result.error("INVALID_ARGS", "Missing origin order or transaction ID", null)
                        return@setMethodCallHandler
                    }

                    val intent = buildSunmiVoidIntent()
                    if (intent == null) {
                        result.error("APP_NOT_INSTALLED", "Sunmi VoidActivity not found", null)
                        return@setMethodCallHandler
                    }

                    intent.putExtra("amount", amount)
                    intent.putExtra("originOrderId", originOrderId)
                    intent.putExtra("originTransactionId", originTransactionId)
                    saleResultCallback = result
                    try {
                        @Suppress("DEPRECATION")
                        startActivityForResult(intent, 9091)
                    } catch (e: ActivityNotFoundException) {
                        result.error(
                            "APP_NOT_INSTALLED",
                            "Sunmi void activity not available: ${e.message}",
                            null
                        )
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    // ===== Sunmi intent builders =====

    private fun buildSunmiSaleIntent(): Intent? {
        val actionIntent = Intent("com.example.PAY_SALE").apply {
            setPackage(SUNMI_PAYMENT_PACKAGE)
            addCategory(Intent.CATEGORY_DEFAULT)
        }
        if (actionIntent.resolveActivity(packageManager) != null) {
            Log.d("SunmiPay", "Resolved SaleActivity via action com.example.PAY_SALE")
            return actionIntent
        }
        val explicitIntent = Intent().apply {
            setClassName(
                SUNMI_PAYMENT_PACKAGE,
                "$SUNMI_PAYMENT_PACKAGE.page.trans.SaleActivity"
            )
        }
        if (explicitIntent.resolveActivity(packageManager) != null) {
            Log.d("SunmiPay", "Resolved SaleActivity via explicit class")
            return explicitIntent
        }
        Log.e("SunmiPay", "Unable to resolve SaleActivity in $SUNMI_PAYMENT_PACKAGE")
        return null
    }

    private fun buildSunmiVoidIntent(): Intent? {
        val explicitIntent = Intent().apply {
            setClassName(
                SUNMI_PAYMENT_PACKAGE,
                "$SUNMI_PAYMENT_PACKAGE.page.trans.VoidActivity"
            )
        }
        if (explicitIntent.resolveActivity(packageManager) != null) {
            Log.d("SunmiPay", "Resolved VoidActivity via explicit class")
            return explicitIntent
        }
        Log.e("SunmiPay", "Unable to resolve VoidActivity in $SUNMI_PAYMENT_PACKAGE")
        return null
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleUsbDeviceIntent(intent)
    }

    private fun handleUsbDeviceIntent(intent: Intent?) {
        if (intent?.action == UsbManager.ACTION_USB_DEVICE_ATTACHED) {
            @Suppress("DEPRECATION")
            val device = intent.getParcelableExtra<android.hardware.usb.UsbDevice>(UsbManager.EXTRA_DEVICE)
            if (device != null && usbSerialManager != null) {
                usbSerialManager!!.connectToDevice(device)
            }
        }
    }

    // ===== USB Printer Permission Methods =====

    private fun checkUSBPermission(vendorId: Int, productId: Int): Boolean {
        val usbManager = getSystemService(Context.USB_SERVICE) as UsbManager
        val device = usbManager.deviceList.values.find {
            it.vendorId == vendorId && it.productId == productId
        }
        return device?.let { usbManager.hasPermission(it) } ?: false
    }

    private fun requestUSBPermission(vendorId: Int, productId: Int, result: MethodChannel.Result) {
        val usbManager = getSystemService(Context.USB_SERVICE) as UsbManager

        val device = usbManager.deviceList.values.find {
            it.vendorId == vendorId && it.productId == productId
        }

        if (device == null) {
            result.error("DEVICE_NOT_FOUND", "USB device not found", null)
            return
        }

        if (usbManager.hasPermission(device)) {
            result.success(true)
            return
        }

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val permissionIntent = PendingIntent.getBroadcast(
            this,
            device.deviceId,
            Intent("com.alekta.pinakapos.USB_PERMISSION"),
            flags
        )

        usbPermissionReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if ("com.alekta.pinakapos.USB_PERMISSION" == intent.action) {
                    synchronized(this) {
                        val grantedDevice = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
                        } else {
                            @Suppress("DEPRECATION")
                            intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                        }

                        if (intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
                            && grantedDevice != null
                            && grantedDevice.vendorId == vendorId
                            && grantedDevice.productId == productId) {
                            result.success(true)
                        } else {
                            result.error("PERMISSION_DENIED", "USB permission denied", null)
                        }

                        try {
                            unregisterReceiver(this)
                        } catch (e: Exception) {
                            // Receiver already unregistered
                        }
                    }
                }
            }
        }

        val filter = IntentFilter("com.alekta.pinakapos.USB_PERMISSION")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(usbPermissionReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(usbPermissionReceiver, filter)
        }

        usbManager.requestPermission(device, permissionIntent)
    }

    // ===== ChipDnaMobile (VP3350) =====

    private fun initializeSoftPos(result: MethodChannel.Result) {
        val nfcAdapter = try {
            NfcAdapter.getDefaultAdapter(this)
        } catch (e: Exception) {
            Log.e("CHIPDNA", "NFC ADAPTER ERROR -> ${e.message}", e)
            result.error("NFC_ERROR", "Unable to access NFC adapter: ${e.message}", null)
            return
        }

        if (nfcAdapter == null) {
            result.error("NFC_NOT_SUPPORTED", "NFC not available", null)
            return
        }

        if (!nfcAdapter.isEnabled) {
            result.error("NFC_DISABLED", "Enable NFC", null)
            return
        }

        val mainHandler = Handler(Looper.getMainLooper())
        Thread {
            try {
                Log.d("CHIPDNA", "STEP 1 -> INITIALIZE SDK")

                if (!ChipDnaMobile.isInitialized()) {
                    val initParams = Parameters().apply {
                        add(ParameterKeys.Password, "12345678")
                    }
                    val initResult = ChipDnaMobile.initialize(applicationContext, initParams)
                    Log.d("CHIPDNA", "INIT RESULT -> ${initResult.getValue("RESULT")}")
                    if (initResult.getValue("RESULT") != "True") {
                        mainHandler.post {
                            result.error(
                                "INIT_FAILED",
                                initResult.getValue("ERRORS") ?: "Initialization failed",
                                null
                            )
                        }
                        return@Thread
                    }
                }

                chipDna = ChipDnaMobile.getInstance()
                val properties = Parameters()
                properties.add(ParameterKeys.ApiKey, "hu55nue338WqPa7zR4PQA76Nar4yRmcu")
                properties.add(ParameterKeys.Environment, "STAGING")
                properties.add(ParameterKeys.ApplicationIdentifier, "PINAKAPOS")
                properties.add(
                    ParameterKeys.CertificateFingerprint,
                    "AB:BE:6D:A9:1D:2E:DF:CA:DF:93:36:32:D3:19:5E:02:F9:75:5B:4B:E4:82:E2:98:7B:81:1B:51:CD:FB:66:4E"
                )
                val propResult = chipDna?.setProperties(properties)
                if (propResult?.getValue("RESULT") != "True") {
                    mainHandler.post {
                        result.error(
                            "PROPERTY_FAILED",
                            propResult?.getValue("ERRORS") ?: "SetProperties failed",
                            null
                        )
                    }
                    return@Thread
                }

                val connectParams = Parameters()
                connectParams.add(ParameterKeys.TapToMobilePOI, "TRUE")
                connectParams.add(ParameterKeys.PaymentDevicePOI, "FALSE")
                val connectResult = chipDna?.connectAndConfigure(connectParams)
                if (connectResult?.getValue("RESULT") != "True") {
                    mainHandler.post {
                        result.error(
                            "CONNECT_FAILED",
                            connectResult?.getValue("ERRORS") ?: "Connect failed",
                            null
                        )
                    }
                    return@Thread
                }

                registerListeners()
                mainHandler.post { result.success("SOFTPOS_READY") }
            } catch (e: Exception) {
                Log.e("CHIPDNA", "INIT EXCEPTION -> ${e.message}")
                mainHandler.post { result.error("INIT_EXCEPTION", e.message, null) }
            }
        }.start()
    }

    private fun startSale(amount: String) {
        if (chipDna == null) {
            pendingResult?.error("NOT_INITIALIZED", "Initialize first", null)
            return
        }
        try {
            Log.d("CHIPDNA", "Starting transaction -> $amount")
            val request = Parameters()
            request.add(ParameterKeys.TransactionType, "SALE")
            request.add(ParameterKeys.Amount, amount)
            request.add(ParameterKeys.Currency, "840")
            request.add(ParameterKeys.TransactionPOI, "TAP_TO_MOBILE")
            request.add(ParameterKeys.TransactionId, System.currentTimeMillis().toString())

            Thread {
                try {
                    chipDna?.startTransaction(request)
                } catch (e: Exception) {
                    Log.e("CHIPDNA", "START SALE ERROR -> ${e.message}", e)
                    pendingResult?.error("SALE_ERROR", e.message, null)
                }
            }.start()
        } catch (e: Exception) {
            Log.e("CHIPDNA", "START SALE ERROR -> ${e.message}")
            pendingResult?.error("SALE_ERROR", e.message, null)
        }
    }

    private fun registerListeners() {
        chipDna?.addTransactionUpdateListener { parameters ->
            try {
                Log.d("CHIPDNA", "UPDATE -> $parameters")
            } catch (e: Exception) {
                Log.e("CHIPDNA", "UPDATE LISTENER ERROR -> ${e.message}", e)
            }
        }
        chipDna?.addUserNotificationListener { parameters ->
            try {
                Log.d("CHIPDNA", "USER_NOTIFICATION -> $parameters")
            } catch (e: Exception) {
                Log.e("CHIPDNA", "USER_NOTIFICATION LISTENER ERROR -> ${e.message}", e)
            }
        }
        chipDna?.addTransactionFinishedListener { parameters ->
            try {
                Log.d("CHIPDNA", "FINISHED -> $parameters")
                val resultValue = parameters.getValue("RESULT")
                val errors = parameters.getValue("ERRORS")
                if (resultValue == "True") {
                    pendingResult?.success("APPROVED")
                } else {
                    pendingResult?.error("DECLINED", errors ?: "Transaction Failed", null)
                }
            } catch (e: Exception) {
                Log.e("CHIPDNA", "TRANSACTION_FINISHED LISTENER ERROR -> ${e.message}", e)
                pendingResult?.error("TRANSACTION_FINISHED_EXCEPTION", e.message, null)
            } finally {
                pendingResult = null
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == 9090 || requestCode == 9091) {
            if (resultCode == Activity.RESULT_OK) {
                val paymentResult = data?.getStringExtra("paymentResult")
                if (paymentResult != null) {
                    saleResultCallback?.success(paymentResult)
                } else {
                    saleResultCallback?.error("NO_RESULT", "No payment result", null)
                }
            } else {
                saleResultCallback?.error("CANCELLED", "Operation cancelled", null)
            }
            saleResultCallback = null
        }
    }

    override fun onResume() {
        super.onResume()
        Log.d("CustomerDisplay", "➡ onResume called")
    }

    override fun onDestroy() {
        usbSerialManager?.dispose()
        usbSerialManager = null

        // Clean up USB permission receiver
        try {
            usbPermissionReceiver?.let { unregisterReceiver(it) }
        } catch (e: Exception) {
            // Receiver already unregistered
        }

        Log.d("CustomerDisplay", "➡ onDestroy called, dismissing CustomerDisplayPresentation")
        customerDisplayPresentation?.dismiss()
        super.onDestroy()
    }

    // ===== Customer display helpers =====

    private fun showWelcomeOnCustomerDisplay(): Boolean {
        if (isOrderActive) {
            Log.d("CustomerDisplay", "⛔ Ignoring Welcome — Order is active")
            return true
        }

        val displayManager = getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        val displays = displayManager.displays

        return if (displays.size > 1) {
            val secondaryDisplay = displays[1]

            if (customerDisplayPresentation == null ||
                customerDisplayPresentation?.display != secondaryDisplay) {

                customerDisplayPresentation?.dismiss()
                customerDisplayPresentation = CustomerDisplayPresentation(
                    this@MainActivity,
                    this@MainActivity,
                    secondaryDisplay
                )
                customerDisplayPresentation?.show()
            }

            // Apply current store info immediately after creation
            if (currentStoreName.isNotEmpty()) {
                customerDisplayPresentation?.updateWelcomeWithStore(
                    currentStoreId,
                    currentStoreName,
                    currentStoreLogoUrl,
                    currentStoreBaseUrl
                )
            }

            true
        } else {
            Log.e("CustomerDisplay", "❌ No secondary display available")
            false
        }
    }
    private fun showDataOnCustomerDisplay(
        orderId: Int,
        storeId: String,
        storeName: String,
        storeLogoUrl: String?,
        items: List<Map<String, Any>>,
        grossTotal: Double,
        discount: Double,
        merchantDiscount: Double,
        netTotal: Double,
        tax: Double,
        netPayable: Double,
        orderDate: String,
        orderTime: String,
        cashbackFee: Double,
        loyaltyContact: String,
        availablePoints: Int,
        summaryEnabled: Boolean,
        redeemedAmount: Double
    ): Boolean {
        // 🔥 ADD THIS LINE HERE (FIRST LINE)
        isOrderActive = true


        if (customerDisplayPresentation == null) {
            Log.d("CustomerDisplay", "CustomerDisplayPresentation null, recreating display")

            val displayManager = getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
            val displays = displayManager.displays

            if (displays.size > 1) {
                val secondaryDisplay = displays[1]
                customerDisplayPresentation = CustomerDisplayPresentation(
                    this@MainActivity,
                    this@MainActivity,
                    secondaryDisplay
                )
                customerDisplayPresentation?.show()
            }
        }
        customerDisplayPresentation?.updateCustomerData(
            orderId,
            storeId,
            storeName,
            storeLogoUrl,
            items,
            grossTotal,
            discount,
            merchantDiscount,
            netTotal,
            tax,
            netPayable,
            orderDate,
            orderTime,
            cashbackFee,
            loyaltyContact,
            availablePoints,
            summaryEnabled,
            redeemedAmount
        )

        Log.d("CustomerDisplay", "✔ CustomerDisplayPresentation updated with order #$orderId")
        return customerDisplayPresentation != null
    }

    private fun showThankYouOnCustomerDisplay(): Boolean {

        val displayManager =
            getSystemService(Context.DISPLAY_SERVICE) as DisplayManager

        val displays = displayManager.displays

        Log.d(
            "CustomerDisplay",
            "Detected displays: ${displays.size} for Thank You"
        )

        return if (displays.size > 1) {

            val secondaryDisplay = displays[1]

            if (
                customerDisplayPresentation == null ||
                customerDisplayPresentation?.display != secondaryDisplay
            ) {
                customerDisplayPresentation?.dismiss()

                customerDisplayPresentation =
                    CustomerDisplayPresentation(
                        this@MainActivity,
                        this@MainActivity,
                        secondaryDisplay
                    )

                customerDisplayPresentation?.show()
            }

            isShowingThankYou = true
            customerDisplayPresentation?.showThankYouLayout()

            Handler(Looper.getMainLooper()).postDelayed({

                Log.d("CustomerDisplay", "Thank You timeout finished")

                isShowingThankYou = false
                isOrderActive = false

                customerDisplayPresentation?.resetCustomerLayoutState()

                MethodChannel(
                    flutterEngine?.dartExecutor?.binaryMessenger!!,
                    "com.alekta.pinakapos/sunmi_display"
                ).invokeMethod("showNextActiveOrder", null)

            }, 5000)

            true

        } else {
            isShowingThankYou = false
            false
        }
    }
    // =====================================================================
    // CustomerDisplayPresentation
    // =====================================================================

    class CustomerDisplayPresentation(
        private val mainActivity: MainActivity,
        context: Context,
        display: Display
    ) : Presentation(context, display) {

        private var firstOrderShown = false

        private lateinit var orderIdView: TextView
        private lateinit var pointsView: TextView
        private lateinit var itemsContainer: LinearLayout
        private lateinit var grossView: TextView
        private lateinit var discountView: TextView
        private lateinit var merchantDiscountView: TextView
        private lateinit var netTotalView: TextView
        private lateinit var taxView: TextView
        private lateinit var netPayableView: TextView
        private lateinit var welcomeText: TextView
        private lateinit var storeLogoView: ImageView
        private lateinit var storeInfoText: TextView
        private lateinit var paymentDate: TextView
        private lateinit var paymentTime: TextView
        private lateinit var totalItemsView: TextView

        private var currentStoreId: String = ""
        private var currentStoreName: String = ""
        private var currentStoreLogoUrl: String? = null
        private var currentStoreBaseUrl: String = ""
        private var cachedLogoBitmap: Bitmap? = null
        private var cachedLogoUrl: String? = null
        private val imageCache = mutableMapOf<String, Bitmap>()
        private val slideshowBitmapCache = mutableMapOf<String, Bitmap>()
        private var cachedSlideshowUrls = mutableListOf<String>()
        private var redeemedAmount = 0.0
        private var redeemPointsTextView: TextView? = null
        private var availablePoints = 0
        private var isCustomerLayoutActive = false
        private var isRedeemPopupOpen = false
        private var phoneInputUnlocked = false
        private var keepSummaryVisible = false
        private var currentDisplayedOrderId = -1

        private lateinit var slideshowContainer: LinearLayout
        private lateinit var slideshowImageView: ImageView
        private var slideshowUrls = listOf<String>()
        private var currentSlide = 0
        private var slideshowHandler: Handler? = null
        private val slideshowInterval = 3000L

        override fun onCreate(savedInstanceState: Bundle?) {
            super.onCreate(savedInstanceState)
            Log.d("CustomerDisplay", "➡ CustomerDisplayPresentation onCreate")
            setContentView(R.layout.welcome_layout)
            welcomeText = findViewById(R.id.welcome_text)
        }

        fun resetFirstOrderShown() {
            firstOrderShown = false
            Log.d("CustomerDisplay", "🔄 firstOrderShown reset")
        }

        fun updateHeaderPoints(points: Int) {
            Handler(Looper.getMainLooper()).post {

                availablePoints = points

                val headerPoints =
                    findViewById<TextView>(R.id.customer_points)

                if (headerPoints != null) {
                    headerPoints.text = points.toString()
                    headerPoints.visibility = View.VISIBLE
                    headerPoints.invalidate()
                    headerPoints.requestLayout()

                    Log.d(
                        "CustomerDisplay",
                        "HEADER POINTS UPDATED DIRECT FROM API = ${headerPoints.text}"
                    )
                } else {
                    Log.e(
                        "CustomerDisplay",
                        "customer_points header not found"
                    )
                }
            }
        }

        fun restoreSummaryAfterRedeemRemoval() {
            Handler(Looper.getMainLooper()).post {

                val summaryContainer =
                    findViewById<LinearLayout>(R.id.summary_container)

                val redeemRow =
                    findViewById<LinearLayout>(R.id.redeem_row)

                summaryContainer?.visibility = View.VISIBLE
                redeemRow?.visibility = View.GONE

                val currentNetText = netPayableView.text.toString()
                    .replace("Total :", "")
                    .replace("$", "")
                    .replace(",", "")
                    .trim()

                val currentNet = currentNetText.toDoubleOrNull() ?: 0.0

                val restoredNet = currentNet + redeemedAmount

                this.redeemedAmount = 0.0

                netPayableView.text = "Total : ${formatCurrency(restoredNet)}"

                Log.d(
                    "CustomerDisplay",
                    "Restored net payable = $restoredNet"
                )
            }
        }

        fun hideRedeemSummary() {

            Log.d("CustomerDisplay", "hideRedeemSummary called")

            this.redeemedAmount = 0.0
            val redeemRow =
                findViewById<LinearLayout>(R.id.redeem_row)

            val redeemValue =
                findViewById<TextView>(R.id.value_redeem_amount)

            redeemRow?.visibility = View.GONE
            redeemValue?.text = formatCurrency(0.0)
        }

        fun resetCustomerLayoutState() {
            isCustomerLayoutActive = false
            firstOrderShown = false
            isRedeemPopupOpen = false
            phoneInputUnlocked = false
            keepSummaryVisible = false
            this.redeemedAmount = 0.0
            currentDisplayedOrderId = -1
            Log.d("CustomerDisplay", "🔄 Customer layout state reset")
        }

        fun setOrderId(id: Int) {
            currentDisplayedOrderId = id
            if (isCustomerLayoutActive) {
                try {
                    val view = findViewById<TextView>(R.id.customer_order_id)
                    view?.text = "#$id"
                    Log.d("CustomerDisplay", "✔ Order ID updated directly → #$id")
                } catch (e: Exception) {
                    Log.e("CustomerDisplay", "❌ setOrderId failed: ${e.message}")
                }
            } else {
                Log.d("CustomerDisplay", "📝 Order ID queued for next layout → #$id")
            }
        }

        fun updateWelcomeWithStore(
            storeId: String,
            storeName: String,
            storeLogoUrl: String? = null,
            storeBaseUrl: String? = null
        ) {
            stopSlideshow()
            currentStoreId = storeId
            currentStoreName = storeName
            currentStoreLogoUrl = storeLogoUrl
            currentStoreBaseUrl = storeBaseUrl ?: ""

            // Update the welcome text with dynamic store name
            welcomeText.text = if (storeName.isNotEmpty()) {
                "Welcome to $storeName"
            } else {
                "👋 Welcome to Pinaka"
            }

            // Make sure the text is visible and properly styled
            welcomeText.visibility = View.VISIBLE
            welcomeText.invalidate()
            welcomeText.requestLayout()

            val footerText = findViewById<TextView>(R.id.footer_text)
            footerText?.visibility = if (storeName.isNotEmpty()) View.VISIBLE else View.GONE

            val logoView = findViewById<ImageView>(R.id.welcome_logo)
            if (!storeLogoUrl.isNullOrEmpty()) {
                Thread {
                    try {
                        val input = URL(storeLogoUrl).openStream()
                        val bitmap = BitmapFactory.decodeStream(input)
                        Handler(Looper.getMainLooper()).post {
                            logoView?.setImageBitmap(bitmap)
                            Log.d("CustomerDisplay", "✅ Welcome logo loaded from URL")
                        }
                    } catch (e: Exception) {
                        Handler(Looper.getMainLooper()).post {
                            logoView?.setImageResource(R.drawable.pinaka_logo)
                            Log.e("CustomerDisplay", "❌ Failed to load Welcome logo: ${e.message}")
                        }
                    }
                }.start()
            } else {
                logoView?.setImageResource(R.drawable.pinaka_logo)
                Log.d("CustomerDisplay", "✅ Using default Welcome logo")
            }

            // Also update the store info text in the customer layout if it exists
            val storeInfoText = findViewById<TextView>(R.id.store_info_text)
            if (storeInfoText != null && storeName.isNotEmpty()) {
                storeInfoText.text = storeName
            }

            if (storeName.isNotEmpty()) {
                loadSlideshowFromApi(currentStoreBaseUrl)
            }

            Log.d("CustomerDisplay", "✅ Welcome updated with store: $storeName")
        }

        private fun loadSlideshowFromApi(storeBaseUrl: String) {
            if (cachedSlideshowUrls.isNotEmpty()) {
                Log.d("CustomerDisplay", "⚡ Using cached slideshow (${cachedSlideshowUrls.size} images)")
                displaySlideshow(cachedSlideshowUrls)
                return
            }

            if (storeBaseUrl.isEmpty()) {
                Log.e("CustomerDisplay", "❌ storeBaseUrl empty")
                return
            }

            Thread {
                try {
                    val apiUrl = "$storeBaseUrl/wp-content/plugins/pinaka-pos-wp/promotion_images.php"
                    val json = URL(apiUrl).readText()
                    val jsonArray = JSONArray(json)
                    val imageUrls = mutableListOf<String>()

                    for (i in 0 until jsonArray.length()) {
                        val obj = jsonArray.getJSONObject(i)
                        val url = obj.getString("url")
                        imageUrls.add(url)
                        if (!slideshowBitmapCache.containsKey(url)) {
                            try {
                                val bitmap = BitmapFactory.decodeStream(URL(url).openStream())
                                if (bitmap != null) {
                                    slideshowBitmapCache[url] = bitmap
                                    Log.d("CustomerDisplay", "✅ Cached slide: $url")
                                }
                            } catch (e: Exception) {
                                Log.e("CustomerDisplay", "❌ Cache failed for $url")
                            }
                        }
                    }

                    cachedSlideshowUrls.clear()
                    cachedSlideshowUrls.addAll(imageUrls)

                    Handler(Looper.getMainLooper()).post {
                        displaySlideshow(cachedSlideshowUrls)
                    }
                } catch (e: Exception) {
                    Log.e("CustomerDisplay", "❌ Slideshow API failed: ${e.message}")
                    Handler(Looper.getMainLooper()).post {
                        if (cachedSlideshowUrls.isNotEmpty()) {
                            displaySlideshow(cachedSlideshowUrls)
                        }
                    }
                }
            }.start()
        }

        private fun bindSlideshowViewSafely(): Boolean {
            return try {
                slideshowImageView = findViewById(R.id.slideshow_image)
                true
            } catch (e: Exception) {
                Log.e("CustomerDisplay", "❌ slideshow_image not found")
                false
            }
        }

        private fun displaySlideshow(imageUrls: List<String>) {
            slideshowImageView = findViewById(R.id.slideshow_image)
            slideshowUrls = imageUrls
            slideshowHandler?.removeCallbacksAndMessages(null)
            slideshowHandler = Handler(Looper.getMainLooper())
            startSlideshow()
        }

        private fun startSlideshow() {
            if (slideshowHandler == null) {
                slideshowHandler = Handler(Looper.getMainLooper())
            }
            slideshowHandler?.removeCallbacksAndMessages(null)
            slideshowHandler?.post(object : Runnable {
                override fun run() {
                    if (slideshowUrls.isEmpty()) {
                        Log.d("CustomerDisplay", "⚠ No slideshow images available")
                        slideshowHandler?.postDelayed(this, 1000)
                        return
                    }
                    if (currentSlide >= slideshowUrls.size) {
                        currentSlide = 0
                    }
                    val url = slideshowUrls[currentSlide]
                    Log.d("CustomerDisplay", "🖼 Showing slide: $url")

                    try {
                        slideshowImageView = findViewById(R.id.slideshow_image)
                    } catch (e: Exception) {
                        Log.e("CustomerDisplay", "❌ slideshow_image missing")
                        slideshowHandler?.postDelayed(this, slideshowInterval)
                        return
                    }

                    val cachedBitmap = slideshowBitmapCache[url]
                    if (cachedBitmap != null) {
                        Handler(Looper.getMainLooper()).post {
                            slideshowImageView.setImageBitmap(cachedBitmap)
                            slideshowImageView.scaleType = ImageView.ScaleType.CENTER_CROP
                        }
                        Log.d("CustomerDisplay", "⚡ Loaded from cache")
                    } else {
                        Thread {
                            try {
                                val bitmap = BitmapFactory.decodeStream(URL(url).openStream())
                                if (bitmap != null) {
                                    slideshowBitmapCache[url] = bitmap
                                    Handler(Looper.getMainLooper()).post {
                                        try {
                                            slideshowImageView = findViewById(R.id.slideshow_image)
                                            slideshowImageView.setImageBitmap(bitmap)
                                            slideshowImageView.scaleType = ImageView.ScaleType.CENTER_CROP
                                            Log.d("CustomerDisplay", "✅ Downloaded & cached slide")
                                        } catch (e: Exception) {
                                            Log.e("CustomerDisplay", "❌ Failed updating ImageView")
                                        }
                                    }
                                }
                            } catch (e: Exception) {
                                Log.e("CustomerDisplay", "❌ Failed to load slide: ${e.message}")
                            }
                        }.start()
                    }

                    currentSlide = (currentSlide + 1) % slideshowUrls.size
                    slideshowHandler?.postDelayed(this, slideshowInterval)
                }
            })
        }

        fun showWelcomeLayout(
            storeId: String,
            storeName: String,
            storeLogoUrl: String?,
            storeBaseUrl: String? = null
        ) {
            Log.d("CustomerDisplay", "➡ Switching back to Welcome layout")
            Handler(Looper.getMainLooper()).post {
                isCustomerLayoutActive = false
                isRedeemPopupOpen = false
                firstOrderShown = false
                currentDisplayedOrderId = -1
                this.redeemedAmount = 0.0

                setContentView(R.layout.welcome_layout)

                currentStoreId = storeId
                currentStoreName = storeName
                currentStoreLogoUrl = storeLogoUrl
                currentStoreBaseUrl = storeBaseUrl ?: ""

                welcomeText = findViewById(R.id.welcome_text)
                val footerText = findViewById<TextView>(R.id.footer_text)
                val logoView = findViewById<ImageView>(R.id.welcome_logo)
                slideshowImageView = findViewById(R.id.slideshow_image)

                // Set the dynamic welcome text
                welcomeText.text = if (storeName.isNotEmpty()) {
                    "Welcome to $storeName"
                } else {
                    "👋 Welcome to Pinaka"
                }
                welcomeText.visibility = View.VISIBLE

                footerText.visibility = if (storeName.isNotEmpty()) View.VISIBLE else View.GONE

                // Load logo
                if (!storeLogoUrl.isNullOrEmpty()) {
                    Thread {
                        try {
                            val bitmap = BitmapFactory.decodeStream(URL(storeLogoUrl).openStream())
                            Handler(Looper.getMainLooper()).post {
                                logoView.setImageBitmap(bitmap)
                            }
                        } catch (e: Exception) {
                            Handler(Looper.getMainLooper()).post {
                                logoView.setImageResource(R.drawable.pinaka_logo)
                            }
                        }
                    }.start()
                } else {
                    logoView.setImageResource(R.drawable.pinaka_logo)
                }

                if (currentStoreBaseUrl.isNotEmpty() && storeName.isNotEmpty()) {
                    loadSlideshowFromApi(currentStoreBaseUrl)
                }

                Log.d("CustomerDisplay", "✅ Welcome layout shown with store: $storeName")
            }
        }

        fun formatCurrency(value: Double): String {
            val formatter = NumberFormat.getCurrencyInstance(Locale.US)
            return if (value < 0) {
                "-" + formatter.format(kotlin.math.abs(value))
            } else {
                formatter.format(value)
            }
        }

        private fun bindOrderViews() {
            orderIdView = findViewById(R.id.customer_order_id)
            pointsView = findViewById(R.id.customer_points)
            totalItemsView = findViewById(R.id.label_total_items)
            itemsContainer = findViewById(R.id.customer_items_container)
            grossView = findViewById(R.id.value_gross_total)
            discountView = findViewById(R.id.value_discount)
            merchantDiscountView = findViewById(R.id.value_merchant_discount)
            netTotalView = findViewById(R.id.value_net_total)
            taxView = findViewById(R.id.value_tax)
            netPayableView = findViewById(R.id.value_net_payable)
            storeLogoView = findViewById(R.id.store_logo)
            storeInfoText = findViewById(R.id.store_info_text)
            paymentDate = findViewById(R.id.payment_date)
            paymentTime = findViewById(R.id.payment_time)
            Log.d("CustomerDisplay", "✔ Customer order views bound")
        }

        private fun updateStoreInfo(
            storeId: String,
            storeName: String,
            storeLogoUrl: String?,
            orderDate: String,
            orderTime: String
        ) {
            storeInfoText.text = storeName
            paymentDate.text = orderDate
            paymentTime.text = orderTime
            storeLogoView.scaleType = ImageView.ScaleType.FIT_CENTER
            storeLogoView.adjustViewBounds = true

            if (!storeLogoUrl.isNullOrEmpty()) {
                if (storeLogoUrl == cachedLogoUrl && cachedLogoBitmap != null) {
                    storeLogoView.setImageBitmap(cachedLogoBitmap)
                    Log.d("CustomerDisplay", "⚡ Using cached logo")
                } else {
                    cachedLogoUrl = storeLogoUrl
                    Thread {
                        try {
                            val input = URL(storeLogoUrl).openStream()
                            val bitmap = BitmapFactory.decodeStream(input)
                            if (bitmap != null) {
                                cachedLogoBitmap = bitmap
                                Handler(Looper.getMainLooper()).post {
                                    storeLogoView.setImageBitmap(bitmap)
                                    storeLogoView.scaleType = ImageView.ScaleType.FIT_CENTER
                                    Log.d("CustomerDisplay", "✅ Logo loaded & cached")
                                }
                            } else {
                                Handler(Looper.getMainLooper()).post {
                                    storeLogoView.setImageResource(R.drawable.pinaka_logo)
                                    storeLogoView.scaleType = ImageView.ScaleType.FIT_CENTER
                                }
                            }
                        } catch (e: Exception) {
                            Handler(Looper.getMainLooper()).post {
                                storeLogoView.setImageResource(R.drawable.pinaka_logo)
                                storeLogoView.scaleType = ImageView.ScaleType.FIT_CENTER
                                Log.e("CustomerDisplay", "❌ Failed loading store logo")
                            }
                        }
                    }.start()
                }
            } else {
                storeLogoView.setImageResource(R.drawable.pinaka_logo)
                storeLogoView.scaleType = ImageView.ScaleType.FIT_CENTER
                Log.d("CustomerDisplay", "⚡ Showing default Pinaka logo")
            }
        }

        fun enablePhoneInput() {
            Handler(Looper.getMainLooper()).post {
                val emailInput = findViewById<EditText>(R.id.email_input)
                val customKeypad = findViewById<GridLayout>(R.id.custom_keypad)

                if (emailInput == null || customKeypad == null) {
                    Log.e("CustomerDisplay", "emailInput/customKeypad not found")
                    return@post
                }

                phoneInputUnlocked = true
                emailInput.isEnabled = true
                emailInput.isFocusable = true
                emailInput.isFocusableInTouchMode = true
                emailInput.isClickable = true
                emailInput.isCursorVisible = true
                emailInput.showSoftInputOnFocus = false

                emailInput.setOnClickListener {
                    Log.d("CustomerDisplay", "Email clicked → opening keypad")
                    customKeypad.visibility = View.VISIBLE
                }
                emailInput.setOnTouchListener { _, _ ->
                    customKeypad.visibility = View.VISIBLE
                    false
                }
                Log.d("CustomerDisplay", "Phone input enabled after checkout")
            }
        }

        // ==================== HELPER FUNCTIONS (Moved to class level) ====================
        private fun appendText(emailInput: EditText, value: String) {
            val currentText = emailInput.text.toString()
            emailInput.setText(currentText + value)
            emailInput.setSelection(emailInput.text.length)
        }

        private fun setupKey(emailInput: EditText, buttonId: Int, value: String) {
            findViewById<Button>(buttonId)?.setOnClickListener { appendText(emailInput, value) }
        }

        fun updateCustomerData(
            orderId: Int,
            storeId: String?,
            storeName: String?,
            storeLogoUrl: String?,
            items: List<Map<String, Any>>,
            grossTotal: Double,
            discount: Double,
            merchantDiscount: Double,
            netTotal: Double,
            tax: Double,
            netPayable: Double,
            orderDate: String,
            orderTime: String,
            cashbackFee: Double,
            loyaltyContact: String,
            availablePoints: Int,
            summaryEnabled: Boolean,
            redeemedAmount: Double
        ) {
            firstOrderShown = true
            this.redeemedAmount = redeemedAmount

            if (currentDisplayedOrderId != -1 && currentDisplayedOrderId != orderId) {
                Log.d("CustomerDisplay", "🆕 New order detected → clearing redeem state")
                this.redeemedAmount = 0.0
                isRedeemPopupOpen = false
                keepSummaryVisible = false
                hideRedeemSummary()
            }

            currentDisplayedOrderId = orderId
            keepSummaryVisible = summaryEnabled

            if (isRedeemPopupOpen) {
                Log.d("CustomerDisplay", "Redeem popup open for same order → skip refresh")
                if (isCustomerLayoutActive) {
//                    try {
//                        orderIdView.text = "#$orderId"
//                    } catch (_) {}
                }
                return
            }

            val defaultStoreId = "STORE001"
            val defaultStoreName = "Pinaka"
            val defaultStoreLogoUrl: String? = null

            Log.d(
                "CustomerDisplay",
                "🟢 updateCustomerData() called → orderId=$orderId, items=${items.size}, gross=$grossTotal, tax=$tax, net=$netPayable"
            )

            currentStoreId = storeId?.takeIf { it.isNotEmpty() } ?: defaultStoreId
            currentStoreName = storeName?.takeIf { it.isNotEmpty() } ?: defaultStoreName
            currentStoreLogoUrl = storeLogoUrl?.takeIf { it.isNotEmpty() } ?: defaultStoreLogoUrl

            Log.d("CustomerDisplay", "📱 Displaying Customer Contact: $loyaltyContact")
            val showDiscountDetails = summaryEnabled

            if (!isCustomerLayoutActive || findViewById<EditText>(R.id.email_input) == null) {
                Log.d("CustomerDisplay", "➡ Switching to customer display layout")
                setContentView(R.layout.customer_display_layout)
                bindOrderViews()
                isCustomerLayoutActive = true
            } else {
                Log.d("CustomerDisplay", "➡ Reusing existing customer layout")
            }

            val summaryContainer = findViewById<LinearLayout>(R.id.summary_container)
            val redeemRow = findViewById<LinearLayout>(R.id.redeem_row)
            val emailInput = findViewById<EditText>(R.id.email_input)
            val customKeypad = findViewById<GridLayout>(R.id.custom_keypad)
            val addButton = findViewById<Button>(R.id.btn_add_customer)

            // restore contact
            emailInput.setText(loyaltyContact)
            // always prevent Android keyboard
            emailInput.showSoftInputOnFocus = false

            if (!phoneInputUnlocked) {
                // BEFORE CHECKOUT → FULLY DISABLE
                customKeypad.visibility = View.GONE
                emailInput.isEnabled = false
                emailInput.isFocusable = false
                emailInput.isFocusableInTouchMode = false
                emailInput.isClickable = false
                emailInput.isCursorVisible = false
                emailInput.isLongClickable = false
                emailInput.clearFocus()
                emailInput.setOnTouchListener { _, _ -> true } // block touch completely
                addButton.isEnabled = false
                addButton.alpha = 0.5f
            } else {
                // AFTER CHECKOUT → ENABLE
                emailInput.isEnabled = true
                emailInput.isFocusable = false
                emailInput.isFocusableInTouchMode = false
                emailInput.isClickable = true
                emailInput.isCursorVisible = false
                emailInput.isLongClickable = false
                addButton.isEnabled = true
                addButton.alpha = 1f
                emailInput.setOnTouchListener { _, _ ->
                    Log.d("CustomerDisplay", "⌨ Custom keypad opened")
                    customKeypad.visibility = View.VISIBLE
                    true
                }
            }

            addButton.setOnClickListener {
                val customerValue = emailInput.text.toString().trim()
                if (customerValue.isEmpty()) {
                    Toast.makeText(context, "Enter customer number", Toast.LENGTH_SHORT).show()
                    return@setOnClickListener
                }
                Log.d("CustomerDisplay", "ADD CLICKED: $customerValue")
                showRedeemPopup(customerValue)
                MethodChannel(
                    mainActivity.flutterEngine!!.dartExecutor.binaryMessenger,
                    "com.alekta.pinakapos/sunmi_display",
                ).invokeMethod(
                    "customerDisplayRedeemClicked",
                    mapOf("contact" to customerValue)
                )
            }

            // Use class-level helper functions
            setupKey(emailInput, R.id.key_0, "0")
            setupKey(emailInput, R.id.key_1, "1")
            setupKey(emailInput, R.id.key_2, "2")
            setupKey(emailInput, R.id.key_3, "3")
            setupKey(emailInput, R.id.key_4, "4")
            setupKey(emailInput, R.id.key_5, "5")
            setupKey(emailInput, R.id.key_6, "6")
            setupKey(emailInput, R.id.key_7, "7")
            setupKey(emailInput, R.id.key_8, "8")
            setupKey(emailInput, R.id.key_9, "9")

            findViewById<Button>(R.id.key_clear)?.setOnClickListener {
                val text = emailInput.text.toString()
                if (text.isNotEmpty()) {
                    val updated = text.dropLast(1)
                    emailInput.setText(updated)
                    emailInput.setSelection(emailInput.text.length)
                }
            }

            findViewById<Button>(R.id.key_done)?.setOnClickListener {
                customKeypad.visibility = View.GONE
            }

            updateStoreInfo(currentStoreId, currentStoreName, currentStoreLogoUrl, orderDate, orderTime)

            slideshowImageView = findViewById(R.id.slideshow_image)
            if (currentStoreBaseUrl.isNotEmpty()) {
                Log.d("CustomerDisplay", "▶ Restarting slideshow")
                loadSlideshowFromApi(currentStoreBaseUrl)
            } else {
                slideshowImageView.setImageResource(R.drawable.pinaka_logo)
                slideshowImageView.scaleType = ImageView.ScaleType.FIT_CENTER
                slideshowImageView.adjustViewBounds = true
                slideshowImageView.setBackgroundColor(Color.WHITE)
            }

            itemsContainer.removeAllViews()

            // -------------------------------------------------
            // CASE A: Empty cart
            // -------------------------------------------------
            if (items.isEmpty() || grossTotal == 0.0) {
                Log.d("CustomerDisplay", "📢 Empty cart → hide summary")
                Log.d("CustomerDisplay", "🆔 EMPTY ORDER ID = $orderId")

                summaryContainer.visibility = View.GONE
                orderIdView.text = " #$orderId"

                val frameLayout = LinearLayout(context).apply {
                    orientation = LinearLayout.VERTICAL
                    gravity = Gravity.CENTER
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT,
                        LinearLayout.LayoutParams.MATCH_PARENT
                    )
                    background = GradientDrawable().apply {
                        setColor(Color.WHITE)
                        setStroke(dpToPx(2), Color.LTGRAY)
                        cornerRadius = dpToPx(0).toFloat()
                    }
                    setPadding(dpToPx(24), dpToPx(24), dpToPx(24), dpToPx(24))
                }

                val emptyImage = ImageView(context).apply {
                    setImageResource(R.drawable.empty_cart)
                    scaleType = ImageView.ScaleType.CENTER_INSIDE
                    layoutParams = LinearLayout.LayoutParams(
                        dpToPx(180),
                        dpToPx(180)
                    ).apply {
                        setMargins(0, 0, 0, dpToPx(16))
                    }
                }

                val emptyMessage = TextView(context).apply {
                    text = "No items in the Order panel"
                    textSize = 28f
                    setTextColor(Color.BLACK)
                    gravity = Gravity.CENTER
                }

                frameLayout.addView(emptyImage)
                frameLayout.addView(emptyMessage)

                val container = FrameLayout(context).apply {
                    layoutParams = FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.MATCH_PARENT,
                        FrameLayout.LayoutParams.MATCH_PARENT
                    )
                    addView(
                        frameLayout,
                        FrameLayout.LayoutParams(
                            FrameLayout.LayoutParams.MATCH_PARENT,
                            FrameLayout.LayoutParams.MATCH_PARENT,
                            Gravity.CENTER
                        )
                    )
                }

                itemsContainer.addView(container)
                return
            }

            // -------------------------------------------------
            // CASE B: Items exist → Show list
            // -------------------------------------------------
            // -----------------------------------------------------
            orderIdView.text = "#$orderId"

// Always use the latest value received
            this.availablePoints = availablePoints

// Update UI
            pointsView.text = this.availablePoints.toString()

            Log.d(
                "CustomerDisplay",
                "HEADER POINTS UPDATED = ${this.availablePoints}"
            )

            Log.d(
                "CustomerDisplay",
                "HEADER POINTS = ${this.availablePoints}"
            )

            Log.d(
                "CustomerDisplay",
                "HEADER POINTS FROM updateCustomerData = $availablePoints"
            )

            val itemsHeader = findViewById<LinearLayout>(R.id.items_header)
// ✅ Show header only when real items exist
            val hasRealItems = items.any {
                val n = it["name"] as? String ?: ""
                !n.equals("Payout", true) && !n.equals("Cashback", true)
            }
            itemsHeader.visibility = if (hasRealItems) View.VISIBLE else View.GONE

            var totalItemCount = 0

            for ((index, item) in items.withIndex()) {
                val name = (item["name"] as? String) ?: ""

                val qty: Int = when {
                    item["qty"] is Number -> (item["qty"] as Number).toInt()
                    item["quantity"] is Number -> (item["quantity"] as Number).toInt()
                    item["items_count"] is Number -> (item["items_count"] as Number).toInt()
                    item["itemCount"] is Number -> (item["itemCount"] as Number).toInt()
                    item["count"] is Number -> (item["count"] as Number).toInt()
                    item["item_count"] is Number -> (item["item_count"] as Number).toInt()
                    item["qty"] != null -> item["qty"].toString().toDoubleOrNull()?.toInt() ?: 1
                    item["quantity"] != null -> item["quantity"].toString().toDoubleOrNull()?.toInt() ?: 1
                    item["items_count"] != null -> item["items_count"].toString().toDoubleOrNull()?.toInt() ?: 1
                    item["itemCount"] != null -> item["itemCount"].toString().toDoubleOrNull()?.toInt() ?: 1
                    item["count"] != null -> item["count"].toString().toDoubleOrNull()?.toInt() ?: 1
                    item["item_count"] != null -> item["item_count"].toString().toDoubleOrNull()?.toInt() ?: 1
                    else -> 1
                }
                val price = (item["price"] as? Number)?.toDouble() ?: 0.0
                val originalPrice = (item["original_price"] as? Number)?.toDouble() ?: price
                val autoDiscount = (item["auto_discount"] as? Number)?.toDouble() ?: 0.0
                val comboDiscount = (item["combo_discount"] as? Number)?.toDouble() ?: 0.0
                val multipackDiscount = (item["multipack_discount"] as? Number)?.toDouble() ?: 0.0
                val discountType = (item["discount_type"] as? String)?.trim()?.lowercase() ?: ""

                val discountValue: Double = when {
                    discountType.contains("multipack") ->
                        if (multipackDiscount > 0) multipackDiscount else autoDiscount
                    discountType.contains("combo") || discountType.contains("mixmatch") ->
                        if (comboDiscount > 0) comboDiscount else autoDiscount
                    discountType.contains("auto") -> autoDiscount
                    else -> when {
                        multipackDiscount > 0 -> multipackDiscount
                        comboDiscount > 0 -> comboDiscount
                        else -> autoDiscount
                    }
                }

                val hasDiscount = discountValue > 0
                val originalTotal = price * qty
                val discountedTotal = originalTotal - discountValue

                Log.d("CustomerDisplay", "ITEM[$name] type=$discountType auto=$autoDiscount combo=$comboDiscount multi=$multipackDiscount → resolved=$discountValue hasDiscount=$hasDiscount")

                if (!name.equals("Payout", true) && !name.equals("Cashback", true)) {
                    totalItemCount += qty
                }

                // ===== ROW =====
                val row = LinearLayout(context).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.CENTER_VERTICAL
                    setPadding(dpToPx(12), dpToPx(8), dpToPx(12), dpToPx(8))
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT
                    )
                    setBackgroundColor(Color.WHITE)
                }

                // ===== ITEM COLUMN (1.6f) =====
                val itemColumn = LinearLayout(context).apply {
                    orientation = LinearLayout.VERTICAL
                    layoutParams = LinearLayout.LayoutParams(0, WRAP_CONTENT, 1.6f)
                }

                val nameView = TextView(context).apply {
                    text = if (name.length > 26) "${name.take(26)}…" else name
                    textSize = 20f
                    setTypeface(typeface, Typeface.BOLD)
                    setTextColor(Color.BLACK)
                }
                itemColumn.addView(nameView)

                val rawType = discountType.trim().lowercase()
                val (displayText, displayColor) = when {
                    rawType.contains("mixmatch") || rawType.contains("mix_match") ->
                        "COMBO DISCOUNT" to Color.parseColor("#FF9800")
                    rawType.contains("multipack") || rawType.contains("multi_pack") ->
                        "MULTIPACK DISCOUNT" to Color.parseColor("#2196F3")
                    rawType.contains("auto") ->
                        "AUTO DISCOUNT" to Color.RED
                    multipackDiscount > 0 ->
                        "MULTIPACK DISCOUNT" to Color.parseColor("#2196F3")
                    comboDiscount > 0 ->
                        "COMBO DISCOUNT" to Color.parseColor("#FF9800")
                    autoDiscount > 0 ->
                        "AUTO DISCOUNT" to Color.RED
                    else ->
                        "DISCOUNT" to Color.RED
                }

                if (hasDiscount && showDiscountDetails) {
                    val discountText = TextView(context).apply {
                        text = "$displayText -${formatCurrency(discountValue)}"
                        textSize = 14f
                        setTextColor(displayColor)
                    }
                    itemColumn.addView(discountText)
                }

                // ===== QTY × PRICE (1.0f) =====
                val qtyPriceView = TextView(context).apply {
                    layoutParams = LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f)
                    gravity = Gravity.START
                    textSize = 18f
                    setTextColor(Color.DKGRAY)
                    text = if (
                        name.equals("Payout", true) ||
                        name.equals("Cashback", true)
                    ) "" else "$qty × ${formatCurrency(price)}"
                }

                // ===== PRICE COLUMN =====
                val priceColumn = LinearLayout(context).apply {
                    orientation = LinearLayout.VERTICAL
                    gravity = Gravity.END
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        marginStart = dpToPx(6)
                    }
                }

                val finalPriceView = TextView(context).apply {
                    text = formatCurrency(
                        if (hasDiscount && showDiscountDetails) discountedTotal else originalTotal
                    )
                    textSize = 17f
                    setTypeface(typeface, Typeface.BOLD)
                    setTextColor(
                        if (name.equals("Payout", true)) Color.RED else Color.BLACK
                    )
                }
                priceColumn.addView(finalPriceView)

                if (hasDiscount && showDiscountDetails) {
                    val originalPriceView = TextView(context).apply {
                        text = formatCurrency(originalTotal)
                        textSize = 16f
                        setTextColor(Color.GRAY)
                        paintFlags = paintFlags or Paint.STRIKE_THRU_TEXT_FLAG
                    }
                    priceColumn.addView(originalPriceView)
                }

                row.addView(itemColumn)
                row.addView(qtyPriceView)
                row.addView(priceColumn)
                itemsContainer.addView(row)

                // ===== Divider =====
                if (index < items.size - 1) {
                    itemsContainer.addView(View(context).apply {
                        layoutParams = LinearLayout.LayoutParams(
                            LinearLayout.LayoutParams.MATCH_PARENT,
                            1
                        )
                        setBackgroundColor(Color.LTGRAY)
                    })
                }
            }

            // ===== TOTALS =====
            grossView.text = formatCurrency(grossTotal)
            val actualDiscount = kotlin.math.abs(discount)
            discountView.text = "-${formatCurrency(actualDiscount)}"

            totalItemsView.text = "Total Items : $totalItemCount"

            findViewById<TextView>(R.id.label_cashback_fee).text = "Cashback Fee"
            findViewById<TextView>(R.id.value_cashback_fee).text = formatCurrency(cashbackFee)

            merchantDiscountView.text = formatCurrency(-merchantDiscount)

            val calculatedNetTotal = grossTotal - actualDiscount
            netTotalView.text = formatCurrency(calculatedNetTotal)

            taxView.text = formatCurrency(tax)

            netPayableView.text = "Total : ${formatCurrency(netPayable)}"

            if (summaryEnabled && this.redeemedAmount > 0) {
                showRedeemSummary(redeemedAmount)
            } else {
                redeemRow.visibility = View.GONE
            }

            paymentDate.text = orderDate
            paymentTime.text = orderTime
            paymentDate.setTextColor(Color.WHITE)
            paymentTime.setTextColor(Color.WHITE)

            if (!summaryEnabled) {
                summaryContainer.visibility = View.GONE
                redeemRow.visibility = View.GONE
            } else {
                summaryContainer.visibility = View.VISIBLE
                redeemRow.visibility = if (redeemedAmount > 0) View.VISIBLE else View.GONE
            }

            Log.d(
                "CustomerDisplay",
                "✔ Order #$orderId totals updated, Total Items: $totalItemCount, Final Payable: $netPayable"
            )
        }

        private fun dpToPx(dp: Int): Int {
            return (dp * context.resources.displayMetrics.density).toInt()
        }

        fun showRedeemSummary(amount: Double) {
            Log.d("CustomerDisplay", "showRedeemSummary called amount=$amount")
            redeemedAmount = amount

            val summaryContainer = findViewById<LinearLayout>(R.id.summary_container)
            val redeemRow = findViewById<LinearLayout>(R.id.redeem_row)
            val redeemLabel = findViewById<TextView>(R.id.label_redeem_amount)
            val redeemValue = findViewById<TextView>(R.id.value_redeem_amount)

            summaryContainer?.visibility = View.VISIBLE
            redeemRow?.visibility = View.VISIBLE
            redeemLabel?.visibility = View.VISIBLE
            redeemValue?.visibility = View.VISIBLE
            redeemLabel?.text = "Redeemed Amount"
            redeemValue?.text = "-${formatCurrency(kotlin.math.abs(amount))}"

            val currentNetText = netPayableView.text.toString()
                .replace("Total :", "")
                .replace("$", "")
                .replace(",", "")
                .trim()
            val currentNet = currentNetText.toDoubleOrNull() ?: 0.0
            val updatedNet = (currentNet - amount).coerceAtLeast(0.0)
            netPayableView.text = "Total : ${formatCurrency(updatedNet)}"
        }

        fun updateRedeemPopupPoints(points: Int) {

            Handler(Looper.getMainLooper()).post {

                Log.d("CustomerDisplay", "UPDATING API POINTS = $points")

                this.availablePoints = points

                redeemPointsTextView?.let {
                    it.text = "Available Points: $points"
                    it.visibility = View.VISIBLE
                }

                pointsView.text = points.toString()
                pointsView.visibility = View.VISIBLE

                Log.d(
                    "CustomerDisplay",
                    "MAIN HEADER POINTS UPDATED = ${pointsView.text}"
                )
            }
        }

        fun showRedeemPopup(contact: String) {
            Handler(Looper.getMainLooper()).post {
                isRedeemPopupOpen = true

                val root = findViewById<FrameLayout>(android.R.id.content)

                root.findViewWithTag<View>("redeem_popup")?.let {
                    root.removeView(it)
                }

                val popupView = LayoutInflater.from(context).inflate(
                    R.layout.redeem_popup_layout,
                    root,
                    false
                )

                popupView.tag = "redeem_popup"

                redeemPointsTextView =
                    popupView.findViewById<TextView>(R.id.txt_points)

                redeemPointsTextView?.visibility = View.VISIBLE
                redeemPointsTextView?.text = "Fetching points..."
                popupView.findViewById<Button>(R.id.btn_ok)
                    .setOnClickListener {
                        isRedeemPopupOpen = false

                        root.removeView(popupView)
                        redeemPointsTextView = null

                        MethodChannel(
                            mainActivity.flutterEngine!!
                                .dartExecutor.binaryMessenger,
                            "com.alekta.pinakapos/sunmi_display"
                        ).invokeMethod(
                            "customerDisplayPopupClosed",
                            null
                        )
                    }
                root.addView(popupView)
            }
        }

        fun showThankYouLayout() {
            isCustomerLayoutActive = false
            isRedeemPopupOpen = false
            setContentView(R.layout.thank_you_layout)
            slideshowImageView = findViewById(R.id.slideshow_image)
            val thankYouText = findViewById<TextView>(R.id.thank_you_text)
            val visitAgainText = findViewById<TextView>(R.id.visit_again_text)
            thankYouText.text = "Thank You!"
            visitAgainText.text = "Please Visit Again"
            if (currentStoreBaseUrl.isNotEmpty()) {
                Log.d("CustomerDisplay", "▶ Loading Thank You slideshow")
                loadSlideshowFromApi(currentStoreBaseUrl)
            } else {
                slideshowImageView.setImageResource(R.drawable.pinaka_logo)
                slideshowImageView.scaleType = ImageView.ScaleType.FIT_CENTER
                slideshowImageView.adjustViewBounds = true
                slideshowImageView.setBackgroundColor(Color.WHITE)
            }
        }

        private fun stopSlideshow() {
            slideshowHandler?.removeCallbacksAndMessages(null)
            slideshowHandler = null
            currentSlide = 0
            Log.d("CustomerDisplay", "🛑 Slideshow stopped")
        }

        override fun onDetachedFromWindow() {
            super.onDetachedFromWindow()
            stopSlideshow()
        }
    }
}