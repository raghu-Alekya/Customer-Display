package com.alekta.pinakapos

import android.app.Activity
import android.app.Presentation
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.hardware.display.DisplayManager
import android.hardware.usb.UsbManager
import android.nfc.NfcAdapter
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.Display
import android.view.Gravity
import android.view.View
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
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

    private var usbSerialManager: UsbSerialManager? = null
    private val VP3350_CHANNEL = "vp3350_channel"
    private var chipDna: ChipDnaMobile? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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

        // VP3350 channel (ChipDnaMobile tap-to-phone)
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

        // Customer display channel (Flutter -> Android)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "showWelcome" -> {
                        val ok = showWelcomeOnCustomerDisplay()
                        if (ok) {
                            result.success("Welcome shown")
                        } else {
                            result.error("NO_DISPLAY", "No secondary display found", null)
                        }
                    }

                    "showWelcomeWithStore" -> {
                        val storeId = call.argument<String>("storeId") ?: ""
                        val storeName = call.argument<String>("storeName") ?: ""
                        val storeLogoUrl = call.argument<String>("storeLogoUrl")
                        val storeBaseUrl = call.argument<String>("storeBaseUrl") ?: ""

                        currentStoreId = storeId
                        currentStoreName = storeName
                        currentStoreLogoUrl = storeLogoUrl
                        currentStoreBaseUrl = storeBaseUrl

                        // Ensure presentation exists before calling showWelcomeLayout()
                        if (customerDisplayPresentation == null) {
                            val ok = showWelcomeOnCustomerDisplay()
                            if (!ok) {
                                result.error("NO_DISPLAY", "No secondary display found", null)
                                return@setMethodCallHandler
                            }
                        }

                        customerDisplayPresentation?.showWelcomeLayout(
                            storeId,
                            storeName,
                            storeLogoUrl,
                            storeBaseUrl
                        )
                        result.success("Welcome updated with store")
                    }

                    "showCustomerData" -> {
                        // Extract args safely (MethodChannel types can be Map<String, Any?> at runtime)
                        val orderId = call.argument<Int>("orderId") ?: 0
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
                        val storeId = call.argument<String>("storeId") ?: ""
                        val storeName = call.argument<String>("storeName") ?: ""
                        val storeLogoUrl = call.argument<String>("storeLogoUrl")
                        val summaryEnabled = call.argument<Boolean>("summaryEnabled") ?: true

                        // Convert items payload
                        val argsMap = call.arguments as? Map<*, *>
                        val itemsAny = argsMap?.get("items")
                        val items: List<Map<String, Any>> =
                            (itemsAny as? List<*>)?.mapNotNull { entry ->
                                if (entry is Map<*, *>) {
                                    entry.entries.associate { (k, v) ->
                                        k.toString() to (v ?: "")
                                    }
                                } else null
                            } ?: emptyList()

                        // Keep current store fields in sync
                        if (storeId.isNotEmpty()) currentStoreId = storeId
                        if (storeName.isNotEmpty()) currentStoreName = storeName
                        if (!storeLogoUrl.isNullOrEmpty()) currentStoreLogoUrl = storeLogoUrl

                        // updateCustomerData() builds lots of views and logs on the UI thread.
                        // Throttle + queue to avoid "not responding"/ANR during rapid cart updates.
                        val now = SystemClock.uptimeMillis()
                        val minIntervalMs = 400L
                        if (now - lastCustomerDisplayUpdateMs < minIntervalMs) {
                            result.success("throttled")
                            return@setMethodCallHandler
                        }
                        lastCustomerDisplayUpdateMs = now

                        // Return immediately to Flutter (do not block this handler).
                        Handler(Looper.getMainLooper()).post {
                            showDataOnCustomerDisplay(
                                orderId = orderId,
                                storeId = currentStoreId,
                                storeName = currentStoreName,
                                storeLogoUrl = currentStoreLogoUrl,
                                items = items,
                                grossTotal = grossTotal,
                                discount = discount,
                                merchantDiscount = merchantDiscount,
                                netTotal = netTotal,
                                tax = tax,
                                netPayable = netPayable,
                                orderDate = orderDate,
                                orderTime = orderTime,
                                cashbackFee = cashbackFee,
                                loyaltyContact = loyaltyContact,
                                summaryEnabled = summaryEnabled
                            )
                        }

                        result.success("queued")
                    }

                    "showThankYou" -> {
                        val ok = showThankYouOnCustomerDisplay()
                        if (ok) {
                            result.success("Thank You shown")
                        } else {
                            result.error("NO_DISPLAY", "No secondary display found", null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleUsbDeviceIntent(intent)
    }

    override fun onDestroy() {
        usbSerialManager?.dispose()
        usbSerialManager = null
        super.onDestroy()
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


    //// ==== above code was for magellan scale, below is for customer display =====

    // Customer display MethodChannel (must match Flutter)
    private val CHANNEL = "com.alekta.pinakapos"
    private var customerDisplayPresentation: CustomerDisplayPresentation? = null
    private var currentStoreId: String = ""
    private var currentStoreName: String = ""
    private var currentStoreLogoUrl: String? = null
    private var currentStoreBaseUrl: String = ""
    private val PAYMENT_CHANNEL = "sunmi_payment_channel"
    private var saleResultCallback: MethodChannel.Result? = null

    // Throttle customer display updates to avoid UI thread stalls (ANR)
    private var lastCustomerDisplayUpdateMs: Long = 0L

    // ===== ChipDnaMobile (VP3350) integration =====

    private fun initializeSoftPos(result: MethodChannel.Result) {

        val nfcAdapter = try {
            NfcAdapter.getDefaultAdapter(this)
        } catch (e: Exception) {
            Log.e("CHIPDNA", "NFC ADAPTER ERROR -> ${e.message}", e)
            result.error(
                "NFC_ERROR",
                "Unable to access NFC adapter: ${e.message}",
                null
            )
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
        val thread = Thread { try {

            Log.d("CHIPDNA", "STEP 1 -> INITIALIZE SDK")

            if (!ChipDnaMobile.isInitialized()) {

                val initParams = Parameters().apply {
                    add(ParameterKeys.Password, "12345678")
                }

                val initResult = ChipDnaMobile.initialize(
                    applicationContext,
                    initParams
                )

                Log.d("CHIPDNA", "INIT RESULT -> ${initResult.getValue("RESULT")}")

                if (initResult.getValue("RESULT") != "True") {

                    val initErrors = initResult.getValue("ERRORS")
                    Log.e("CHIPDNA", "INIT FAILED -> $initErrors")

                    if (!initErrors.isNullOrBlank() && initErrors.contains("Missing", ignoreCase = true)) {
                        Log.e("CHIPDNA", "INIT FAILED - MISSING PARAMETER DETAIL -> $initErrors")
                    }

                    mainHandler.post {
                        result.error(
                            "INIT_FAILED",
                            initResult.getValue("ERRORS") ?: "Initialization failed",
                            null
                        )
                    }
                    return@Thread
                }
            } else {
                Log.d("CHIPDNA", "SDK already initialized, skipping initialize()")
            }

            chipDna = ChipDnaMobile.getInstance()

            Log.d("CHIPDNA", "STEP 2 -> SET PROPERTIES")

            val properties = Parameters()

            properties.add(ParameterKeys.ApiKey, "hu55nue338WqPa7zR4PQA76Nar4yRmcu")
            properties.add(ParameterKeys.Environment, "STAGING")

            properties.add(
                ParameterKeys.ApplicationIdentifier,
                "PINAKAPOS"
            )

            properties.add(
                ParameterKeys.CertificateFingerprint,
                "AB:BE:6D:A9:1D:2E:DF:CA:DF:93:36:32:D3:19:5E:02:F9:75:5B:4B:E4:82:E2:98:7B:81:1B:51:CD:FB:66:4E"
            )

            val propResult = chipDna?.setProperties(properties)

            Log.d("CHIPDNA", "SET PROPERTIES RESULT -> ${propResult?.getValue("RESULT")}")

            if (propResult?.getValue("RESULT") != "True") {

                val propErrors = propResult?.getValue("ERRORS")
                Log.e("CHIPDNA", "SET PROPERTIES FAILED -> $propErrors")

                if (!propErrors.isNullOrBlank() && propErrors.contains("Missing", ignoreCase = true)) {
                    Log.e("CHIPDNA", "SET PROPERTIES - MISSING PARAMETER DETAIL -> $propErrors")
                }

                    mainHandler.post {
                        result.error(
                            "PROPERTY_FAILED",
                            propResult?.getValue("ERRORS") ?: "SetProperties failed",
                            null
                        )
                    }
                    return@Thread
            }

            Log.d("CHIPDNA", "STEP 3 -> CONNECT AND CONFIGURE")

            val connectParams = Parameters()

            connectParams.add(ParameterKeys.TapToMobilePOI, "TRUE")
            connectParams.add(ParameterKeys.PaymentDevicePOI, "FALSE")

            val connectResult = chipDna?.connectAndConfigure(connectParams)

            Log.d("CHIPDNA", "CONNECT RESULT -> ${connectResult?.getValue("RESULT")}")

            if (connectResult?.getValue("RESULT") != "True") {

                val connectErrors = connectResult?.getValue("ERRORS")
                Log.e("CHIPDNA", "CONNECT FAILED -> $connectErrors")

                if (!connectErrors.isNullOrBlank() && connectErrors.contains("Missing", ignoreCase = true)) {
                    Log.e("CHIPDNA", "CONNECT - MISSING PARAMETER DETAIL -> $connectErrors")
                }

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

            mainHandler.post {
                result.error(
                    "INIT_EXCEPTION",
                    e.message,
                    null
                )
            }
        }
        }
        thread.start()
    }

    private fun startSale(amount: String) {

        if (chipDna == null) {

            pendingResult?.error(
                "NOT_INITIALIZED",
                "Initialize first",
                null
            )
            return
        }

        try {

            Log.d("CHIPDNA", "Starting transaction -> $amount")

            val request = Parameters()

            request.add(ParameterKeys.TransactionType, "SALE")
            request.add(ParameterKeys.Amount, amount)
            request.add(ParameterKeys.Currency, "840")

            request.add(
                ParameterKeys.TransactionPOI,
                "TAP_TO_MOBILE"
            )

            request.add(
                ParameterKeys.TransactionId,
                System.currentTimeMillis().toString()
            )

            Log.d("CHIPDNA", "SALE REQUEST -> $request")

            // Avoid blocking the UI thread if SDK startTransaction() is slow.
            val saleThreadChip = chipDna
            Thread {
                try {
                    saleThreadChip?.startTransaction(request)
                } catch (e: Exception) {
                    Log.e("CHIPDNA", "START SALE ERROR -> ${e.message}", e)
                    pendingResult?.error(
                        "SALE_ERROR",
                        e.message,
                        null
                    )
                }
            }.start()

        } catch (e: Exception) {

            Log.e("CHIPDNA", "START SALE ERROR -> ${e.message}")

            pendingResult?.error(
                "SALE_ERROR",
                e.message,
                null
            )
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
                    pendingResult?.error(
                        "DECLINED",
                        errors ?: "Transaction Failed",
                        null
                    )
                }
            } catch (e: Exception) {
                Log.e("CHIPDNA", "TRANSACTION_FINISHED LISTENER ERROR -> ${e.message}", e)
                pendingResult?.error(
                    "TRANSACTION_FINISHED_EXCEPTION",
                    e.message,
                    null
                )
            } finally {
                pendingResult = null
            }
        }
    }


//    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
//        super.configureFlutterEngine(flutterEngine)
//        Log.d("CustomerDisplay", "🔧 configureFlutterEngine called")
//
//
//
//        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
//            Log.d("CustomerDisplay", "📢 MethodChannel call → method=${call.method}, args=${call.arguments}")
//
//            when (call.method) {
//
//                "showWelcome" -> {
//                    Log.d("CustomerDisplay", "➡ showWelcome invoked")
//                    if (showWelcomeOnCustomerDisplay()) {
//                        Log.d("CustomerDisplay", "✔ Welcome displayed")
//                        result.success("Welcome shown")
//                    } else {
//                        Log.e("CustomerDisplay", "❌ No secondary display found for Welcome")
//                        result.error("NO_DISPLAY", "No secondary display found", null)
//                    }
//                }
//
//                "showWelcomeWithStore" -> {
//                    val storeId = call.argument<String>("storeId") ?: ""
//                    val storeName = call.argument<String>("storeName") ?: ""
//                    val storeLogoUrl = call.argument<String>("storeLogoUrl")
//                    val storeBaseUrl = call.argument<String>("storeBaseUrl") ?: ""
//
//                    Log.d(
//                        "CustomerDisplay",
//                        "➡ showWelcomeWithStore invoked → storeId=$storeId, storeName=$storeName, logoUrl=$storeLogoUrl, baseUrl=$storeBaseUrl"
//                    )
//
//                    currentStoreId = storeId
//                    currentStoreName = storeName
//                    currentStoreLogoUrl = storeLogoUrl
//                    currentStoreBaseUrl = storeBaseUrl
//
//                    // --- Call the slideshow API first to see logs ---
//                    if (storeBaseUrl.isNotEmpty()) {
//                        Thread {
//                            try {
//                                val apiUrl = "$storeBaseUrl/wp-content/plugins/pinaka-pos-wp/promotion_images.php"
//                                val json = URL(apiUrl).readText()
//                                val jsonArray = JSONArray(json)
//
//                                val imageUrls = mutableListOf<String>()
//                                for (i in 0 until jsonArray.length()) {
//                                    val obj = jsonArray.getJSONObject(i)
//                                    val url = obj.getString("url")
//                                    imageUrls.add(url)
//                                }
//
//                                Log.d("CustomerDisplay", "✅ Slideshow API returned ${imageUrls.size} images for store $storeName")
//                                for (url in imageUrls) {
//                                    Log.d("CustomerDisplay", "Slide URL: $url")
//                                }
//
//                            } catch (e: Exception) {
//                                Log.e("CustomerDisplay", "❌ Failed to load slideshow for store $storeName: ${e.message}")
//                            }
//                        }.start()
//                    } else {
//                        Log.e("CustomerDisplay", "storeBaseUrl is empty → cannot load slideshow for store $storeName")
//                    }
//
//                    // --- Show Welcome layout on customer display ---
//                    if (customerDisplayPresentation == null) {
//                        showWelcomeOnCustomerDisplay()
//                    }
//
//                    customerDisplayPresentation?.showWelcomeLayout(storeId, storeName, storeLogoUrl, storeBaseUrl)
//
//                    result.success("Welcome updated with store")
//                }
//
//
//                "showCustomerData" -> {
//                    val orderId = call.argument<Int>("orderId") ?: 0
//                    val items = call.argument<List<Map<String, Any>>>("items") ?: emptyList()
//                    val grossTotal = call.argument<Double>("grossTotal") ?: 0.0
//                    val discount = call.argument<Double>("discount") ?: 0.0
//                    val merchantDiscount = call.argument<Double>("merchantDiscount") ?: 0.0
//                    val netTotal = call.argument<Double>("netTotal") ?: 0.0
//                    val tax = call.argument<Double>("tax") ?: 0.0
//                    val netPayable = call.argument<Double>("netPayable") ?: 0.0
//                    val orderDate = call.argument<String>("orderDate") ?: ""
//                    val orderTime = call.argument<String>("orderTime") ?: ""
//                    val cashbackFee = call.argument<Double>("cashbackFee") ?: 0.0
//                    val loyaltyContact = call.argument<String>("loyaltyContact") ?: ""
//                    val summaryEnabled = call.argument<Boolean>("summaryEnabled") ?: true
//
//                    Log.d("CustomerDisplay", "☎ Loyalty Contact received: $loyaltyContact")
//
//                    Log.d("CustomerDisplay", "➡ showCustomerData invoked → orderId=$orderId, items=${items.size}, grossTotal=$grossTotal, discount=$discount, merchantDiscount=$merchantDiscount, netTotal=$netTotal, tax=$tax, netPayable=$netPayable")
//                    Log.d("CustomerDisplay", "➡ orderDate='$orderDate'")
//                    Log.d("CustomerDisplay", "➡ orderTime='$orderTime'")
//
//                    val success = showDataOnCustomerDisplay(
//                        orderId, currentStoreId, currentStoreName, currentStoreLogoUrl, items,
//                        grossTotal, discount, merchantDiscount, netTotal, tax, netPayable,orderDate, orderTime,cashbackFee,loyaltyContact,summaryEnabled
//                    )
//
//                    if (success) {
//                        Log.d("CustomerDisplay", "✔ Customer data displayed")
//                        result.success("Data displayed")
//                    } else {
//                        Log.e("CustomerDisplay", "❌ No secondary display found for Customer data")
//                        result.error("NO_DISPLAY", "No secondary display found", null)
//                    }
//                }
//
//                "showThankYou" -> {
//                    Log.d("CustomerDisplay", "➡ showThankYou invoked")
//                    if (showThankYouOnCustomerDisplay()) {
//                        Log.d("CustomerDisplay", "✔ Thank You displayed")
//                        result.success("Thank You shown")
//                    } else {
//                        Log.e("CustomerDisplay", "❌ No secondary display found for Thank You")
//                        result.error("NO_DISPLAY", "No secondary display found", null)
//                    }
//                }
//
//                else -> {
//                    Log.w("CustomerDisplay", "⚠ Method not implemented: ${call.method}")
//                    result.notImplemented()
//                }
//            }
//        }
//        // ================= PAYMENT CHANNEL =================
//        MethodChannel(
//            flutterEngine.dartExecutor.binaryMessenger,
//            PAYMENT_CHANNEL
//        ).setMethodCallHandler { call, result ->
//
//            when (call.method) {
//
//                "startSale" -> {
//                    val amount = call.argument<String>("amount")
//                    val orderId = call.argument<String>("orderId")
//
//                    val intent = Intent().apply {
//                        setClassName(
//                            "com.sunmi.payment.demo",
//                            "com.sunmi.payment.demo.page.trans.SaleActivity"
//                        )
//                        putExtra("amount", amount)
//                        putExtra("orderId", orderId)
//                    }
//
//                    saleResultCallback = result
//                    startActivityForResult(intent, 9090)
//                }
//
//                "startVoid" -> {
//                    val amount = call.argument<String>("amount")
//                    val originOrderId = call.argument<String>("originOrderId")
//                    val originTransactionId = call.argument<String>("originTransactionId")
//
//                    Log.d(
//                        "SunmiVoid",
//                        "➡ startVoid → amount=$amount, originOrderId=$originOrderId, originTxn=$originTransactionId"
//                    )
//
//                    // ✅ Basic validation only
//                    if (originOrderId.isNullOrEmpty() || originTransactionId.isNullOrEmpty()) {
//                        result.error("INVALID_ARGS", "Missing origin order or transaction ID", null)
//                        return@setMethodCallHandler
//                    }
//
//                    val intent = Intent().apply {
//                        setClassName(
//                            "com.sunmi.payment.demo",
//                            "com.sunmi.payment.demo.page.trans.VoidActivity"
//                        )
//                        putExtra("amount", amount)
//                        putExtra("originOrderId", originOrderId)
//                        putExtra("originTransactionId", originTransactionId)
//                    }
//
//                    saleResultCallback = result
//                    startActivityForResult(intent, 9091)
//                }
//
//
//                else -> result.notImplemented()
//            }
//        }
//
//    }

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
        showWelcomeOnCustomerDisplay()
    }

    private fun showWelcomeOnCustomerDisplay(): Boolean {
        val displayManager = getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        val displays = displayManager.displays
        Log.d("CustomerDisplay", "Detected displays: ${displays.size}")

        return if (displays.size > 1) {
            val secondaryDisplay = displays[1]
            Log.d("CustomerDisplay", "Secondary display found: ${secondaryDisplay.name}")

            if (customerDisplayPresentation == null || customerDisplayPresentation?.display != secondaryDisplay) {
                customerDisplayPresentation?.dismiss()
                customerDisplayPresentation = CustomerDisplayPresentation(this, secondaryDisplay)
                customerDisplayPresentation?.show()
                Log.d("CustomerDisplay", "✔ CustomerDisplayPresentation shown on secondary display")
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
        summaryEnabled: Boolean
    ): Boolean {

        if (customerDisplayPresentation == null) {
            Log.d("CustomerDisplay", "CustomerDisplayPresentation null, showing Welcome first")
            showWelcomeOnCustomerDisplay()
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
            summaryEnabled // ✅
        )

        Log.d("CustomerDisplay", "✔ CustomerDisplayPresentation updated with order #$orderId")

        return customerDisplayPresentation != null
    }


    private fun showThankYouOnCustomerDisplay(): Boolean {
        val displayManager = getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        val displays = displayManager.displays
        Log.d("CustomerDisplay", "Detected displays: ${displays.size} for Thank You")

        return if (displays.size > 1) {
            val secondaryDisplay = displays[1]
            Log.d("CustomerDisplay", "Secondary display found: ${secondaryDisplay.name} for Thank You")

            if (customerDisplayPresentation == null || customerDisplayPresentation?.display != secondaryDisplay) {
                customerDisplayPresentation?.dismiss()
                customerDisplayPresentation = CustomerDisplayPresentation(this, secondaryDisplay)
                customerDisplayPresentation?.show()
            }

            customerDisplayPresentation?.showThankYouLayout()
            Log.d("CustomerDisplay", "✔ Thank You layout displayed")

            Handler(Looper.getMainLooper()).postDelayed({
                Log.d("CustomerDisplay", "➡ Reverting back to Welcome after Thank You")
                customerDisplayPresentation?.updateWelcomeWithStore(currentStoreId, currentStoreName, currentStoreLogoUrl)
            }, 5000)

            true
        } else {
            Log.e("CustomerDisplay", "❌ No secondary display available for Thank You")
            false
        }
    }
//    override fun onDestroy() {
//        Log.d("CustomerDisplay", "➡ onDestroy called, dismissing CustomerDisplayPresentation")
//        customerDisplayPresentation?.dismiss()
//        super.onDestroy()
//    }

    // ---------------------- CustomerDisplayPresentation ----------------------
    class CustomerDisplayPresentation(
        context: Context,
        display: Display
    ) : Presentation(context, display) {

        private var firstOrderShown = false

        private lateinit var orderIdView: TextView
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

        private var currentStoreId: String = ""
        private var currentStoreName: String = ""
        private var currentStoreLogoUrl: String? = null
        private var currentStoreBaseUrl: String = ""


        private lateinit var slideshowContainer: LinearLayout

        override fun onCreate(savedInstanceState: Bundle?) {
            super.onCreate(savedInstanceState)
            Log.d("CustomerDisplay", "➡ CustomerDisplayPresentation onCreate")
            setContentView(R.layout.welcome_layout)
            welcomeText = findViewById(R.id.welcome_text)
        }

        fun updateWelcomeWithStore(
            storeId: String,
            storeName: String,
            storeLogoUrl: String? = null,
            storeBaseUrl: String? = null // new param
        ) {
            stopSlideshow()
            currentStoreId = storeId
            currentStoreName = storeName
            currentStoreLogoUrl = storeLogoUrl
            currentStoreBaseUrl = storeBaseUrl ?: ""

            welcomeText.text = if (storeName.isNotEmpty()) "Welcome to $storeName" else "👋 Welcome to Pinaka"

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

            if (storeName.isNotEmpty()) {
                loadSlideshowFromApi(currentStoreBaseUrl)
            }
        }
        private fun loadSlideshowFromApi(storeBaseUrl: String) {
            if (storeBaseUrl.isEmpty()) {
                Log.e("CustomerDisplay", "❌ storeBaseUrl is empty. Slideshow cannot be loaded.")
                displaySlideshow(emptyList())
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
                    }

                    Handler(Looper.getMainLooper()).post {
                        displaySlideshow(imageUrls)
                    }

                } catch (e: Exception) {
                    Log.e("CustomerDisplay", "❌ Failed to load slideshow: ${e.message}")
                    Handler(Looper.getMainLooper()).post {
                        displaySlideshow(emptyList())
                    }
                }
            }.start()
        }

        private lateinit var slideshowImageView: ImageView
        private var slideshowUrls = listOf<String>()
        private var currentSlide = 0
        private var slideshowHandler: Handler? = null
        private val slideshowInterval = 3000L

        private fun displaySlideshow(imageUrls: List<String>) {
            slideshowImageView = findViewById(R.id.slideshow_image)

            slideshowUrls = imageUrls
            if (slideshowHandler == null) slideshowHandler = Handler(Looper.getMainLooper())
            startSlideshow()
        }

        private fun startSlideshow() {
            stopSlideshow()
            if (slideshowHandler == null) slideshowHandler = Handler(Looper.getMainLooper())

            slideshowHandler?.post(object : Runnable {
                override fun run() {
                    if (slideshowUrls.isEmpty()) {
                        slideshowImageView.setImageResource(R.drawable.pinaka_logo)
                        slideshowImageView.scaleType = ImageView.ScaleType.CENTER_INSIDE
                    } else {
                        val url = slideshowUrls[currentSlide]
                        Thread {
                            try {
                                val input = URL(url).openStream()
                                val bitmap = BitmapFactory.decodeStream(input)
                                Handler(Looper.getMainLooper()).post {
                                    slideshowImageView.setImageBitmap(bitmap)
                                    slideshowImageView.scaleType = ImageView.ScaleType.CENTER_CROP
                                }
                            } catch (e: Exception) {
                                Log.e("CustomerDisplay", "❌ Failed to load slide image: ${e.message}")
                            }
                        }.start()
                        currentSlide = (currentSlide + 1) % slideshowUrls.size
                    }
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
            stopSlideshow()
            Log.d("CustomerDisplay", "➡ Switching back to Welcome layout")

            Handler(Looper.getMainLooper()).post {
                setContentView(R.layout.welcome_layout)

                // update current store details
                currentStoreId = storeId
                currentStoreName = storeName
                currentStoreLogoUrl = storeLogoUrl
                currentStoreBaseUrl = storeBaseUrl ?: ""

                welcomeText = findViewById(R.id.welcome_text)
                val footerText = findViewById<TextView>(R.id.footer_text)
                val logoView = findViewById<ImageView>(R.id.welcome_logo)
                slideshowImageView = findViewById(R.id.slideshow_image) // <-- important

                welcomeText.text = if (storeName.isNotEmpty()) "Welcome to $storeName" else "👋 Welcome to Pinaka"
                footerText.visibility = if (storeName.isNotEmpty()) View.VISIBLE else View.GONE

                // Load logo
                if (!storeLogoUrl.isNullOrEmpty()) {
                    Thread {
                        try {
                            val input = URL(storeLogoUrl).openStream()
                            val bitmap = BitmapFactory.decodeStream(input)
                            Handler(Looper.getMainLooper()).post {
                                logoView.setImageBitmap(bitmap)
                                Log.d("CustomerDisplay", "✅ Welcome logo loaded")
                            }
                        } catch (e: Exception) {
                            Handler(Looper.getMainLooper()).post {
                                logoView.setImageResource(R.drawable.pinaka_logo)
                                Log.e("CustomerDisplay", "❌ Failed to load Welcome logo: ${e.message}")
                            }
                        }
                    }.start()
                } else {
                    logoView.setImageResource(R.drawable.pinaka_logo)
                }

                // Stop any previous slideshow
                slideshowHandler?.removeCallbacksAndMessages(null)
                slideshowHandler = Handler(Looper.getMainLooper())

                // Load slideshow
                if (!currentStoreBaseUrl.isNullOrEmpty() && storeName.isNotEmpty()) {
                    loadSlideshowFromApi(currentStoreBaseUrl)
                }

                firstOrderShown = false
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

            if (!storeLogoUrl.isNullOrEmpty()) {
                Thread {
                    try {
                        val input = URL(storeLogoUrl).openStream()
                        val bitmap = BitmapFactory.decodeStream(input)
                        Handler(Looper.getMainLooper()).post {
                            storeLogoView.setImageBitmap(bitmap)
                            Log.d("CustomerDisplay", "✅ Loaded store logo from $storeLogoUrl")
                        }
                    } catch (e: Exception) {
                        Handler(Looper.getMainLooper()).post {
                            storeLogoView.setImageResource(R.drawable.pinaka_logo)
                            Log.e("CustomerDisplay", "❌ Failed to load store logo from $storeLogoUrl: ${e.message}")
                        }
                    }
                }.start()
            } else {
                storeLogoView.setImageResource(R.drawable.pinaka_logo)
                Log.d("CustomerDisplay", "✅ Using default store logo")
            }
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
            summaryEnabled: Boolean
        ) {
            val defaultStoreId = "STORE001"
            val defaultStoreName = "Pinaka"
            val defaultStoreLogoUrl: String? = null

            Log.d(
                "CustomerDisplay",
                "🟢 updateCustomerData() called → orderId=$orderId, items=${items.size}, gross=$grossTotal, tax=$tax, net=$netPayable"
            )


            currentStoreId = storeId?.takeIf { it.isNotEmpty() } ?: defaultStoreId
            currentStoreName = storeName?.takeIf { it.isNotEmpty() } ?: defaultStoreName
            currentStoreLogoUrl =
                storeLogoUrl?.takeIf { it?.isNotEmpty() == true } ?: defaultStoreLogoUrl

            Log.d("CustomerDisplay", "📱 Displaying Customer Contact: $loyaltyContact")
            val showDiscountDetails = summaryEnabled


            Log.d("CustomerDisplay", "➡ Showing Customer Display layout")
            setContentView(R.layout.customer_display_layout)
            bindOrderViews()

            // --- Loyalty Contact Display ---
            val emailValueView = findViewById<TextView>(R.id.email_value)

            if (loyaltyContact.isNotEmpty()) {
                emailValueView.text = loyaltyContact
            } else {
                emailValueView.text = "- Guest"
            }

            Log.d("CustomerDisplay", "📱 Loyalty Contact displayed: ${emailValueView.text}")


            // Update store info
            updateStoreInfo(
                currentStoreId,
                currentStoreName,
                currentStoreLogoUrl,
                orderDate,
                orderTime
            )

            // Slideshow
            slideshowImageView = findViewById(R.id.slideshow_image)
            if (currentStoreBaseUrl.isNotEmpty()) {
                loadSlideshowFromApi(currentStoreBaseUrl)
            } else {
                slideshowImageView.setImageResource(R.drawable.pinaka_logo)
                slideshowImageView.scaleType = ImageView.ScaleType.CENTER_INSIDE
            }

            val summaryContainer = findViewById<LinearLayout>(R.id.summary_container)

            // -----------------------------------------------------
            // CASE A: Empty cart (items empty OR grossTotal = 0.0)
            // -----------------------------------------------------
            itemsContainer.removeAllViews()

            if (items.isEmpty() || grossTotal == 0.0) {
                Log.d("CustomerDisplay", "📢 Empty cart → hide summary")

                summaryContainer.visibility = View.GONE

                // 🔲 Frame container
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

                    // ✅ SMALL, EVEN padding only
                    setPadding(
                        dpToPx(24),
                        dpToPx(24),
                        dpToPx(24),
                        dpToPx(24)
                    )
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

                // ✅ Container centers frameLayout
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

            // -----------------------------------------------------
            // CASE B: Items exist but tax = 0.0 → hide summary
            // -----------------------------------------------------
            summaryContainer.visibility =
                if (summaryEnabled) View.VISIBLE else View.GONE


            // -----------------------------------------------------
            // Items exist → Show list
            // -----------------------------------------------------
            orderIdView.text = "#$orderId"
            itemsContainer.removeAllViews()

            var totalItemCount = 0
            val itemsHeader = findViewById<LinearLayout>(R.id.items_header)

// ✅ Show header only when real items exist
            val hasRealItems = items.any {
                val n = it["name"] as? String ?: ""
                !n.equals("Payout", true) && !n.equals("Cashback", true)
            }
            itemsHeader.visibility = if (hasRealItems) View.VISIBLE else View.GONE



            for ((index, item) in items.withIndex()) {
                Log.d(
                    "CustomerDisplay",
                    "🔁 LOOP[$index] raw item = $item"
                )


                val name = (item["name"] as? String) ?: ""
                val qty = (item["qty"] as? Number)?.toInt() ?: 0
                val price = (item["price"] as? Number)?.toDouble() ?: 0.0

                val originalPrice =
                    (item["original_price"] as? Number)?.toDouble() ?: price



                val discountValue =
                    (item["auto_discount"] as? Number)?.toDouble() ?: 0.0

                val discountType =
                    (item["discount_type"] as? String)?.trim() ?: ""

                Log.d(
                    "CustomerDisplay",
                    """
    🧮 CALC[$index]
      name          = $name
      qty           = $qty
      price         = $price
      discountValue = $discountValue
      discountType  = $discountType
    """.trimIndent()
                )


                val hasDiscount = discountValue > 0
                val originalTotal = price * qty
                val discountedTotal = originalTotal - discountValue




                // ✔ SAME CALCULATION
                if (!name.equals("Payout", true) && !name.equals("Cashback", true)) {
                    totalItemCount += qty
                }

                // ================= ROW =================
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

// ================= ITEM COLUMN (1.6f) =================
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
                        "COMBO DISCOUNT" to Color.parseColor("#FF9800") // 🟠 Orange

                    rawType.contains("multipack") || rawType.contains("multi_pack") ->
                        "MULTIPACK DISCOUNT" to Color.parseColor("#2196F3") // 🔵 Blue

                    rawType.contains("auto") ->
                        "AUTO DISCOUNT" to Color.RED

                    else ->
                        rawType.uppercase() to Color.RED
                }


                if (hasDiscount && showDiscountDetails) {
                    val discountText = TextView(context).apply {
                        text = "$displayText -${formatCurrency(discountValue)}"
                        textSize = 14f
                        setTextColor(displayColor)
                    }
                    itemColumn.addView(discountText)
                }


// ================= QTY × PRICE (1.0f) =================
                val qtyPriceView = TextView(context).apply {
                    layoutParams = LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f)
                    gravity = Gravity.START   // 👈 move left
                    textSize = 18f
                    setTextColor(Color.DKGRAY)
                    text = if (
                        name.equals("Payout", true) ||
                        name.equals("Cashback", true)
                    ) "" else "$qty × ${formatCurrency(price)}"
                }

// ================= PRICE COLUMN (0.8f) =================
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

// ================= ADD TO ROW =================
                row.addView(itemColumn)
                row.addView(qtyPriceView)
                row.addView(priceColumn)

                itemsContainer.addView(row)


//                // ================= ROW =================
//                val row = LinearLayout(context).apply {
//                    orientation = LinearLayout.HORIZONTAL
//                    gravity = Gravity.CENTER_VERTICAL
//                    setPadding(dpToPx(12), dpToPx(8), dpToPx(12), dpToPx(8))
//                    layoutParams = LinearLayout.LayoutParams(
//                        LinearLayout.LayoutParams.MATCH_PARENT,
//                        LinearLayout.LayoutParams.WRAP_CONTENT
//                    )
//                    setBackgroundColor(Color.WHITE)
//                }
//
//                // ================= ITEM COLUMN (1.5f) =================
//                val itemColumn = LinearLayout(context).apply {
//                    orientation = LinearLayout.HORIZONTAL
//                    gravity = Gravity.CENTER_VERTICAL
//                    layoutParams = LinearLayout.LayoutParams(0, WRAP_CONTENT, 1.5f)
//                }
//
//// ❌ Image removed from UI — no empty gap
//// (ImageView not added to itemColumn)
//
//// ================================================
//// IMAGE LOADING LOGIC (kept for future use)
//// ================================================
//                /*
//                val imageView = ImageView(context).apply {
//                    layoutParams = LinearLayout.LayoutParams(dpToPx(40), dpToPx(40))
//                        .apply { marginEnd = dpToPx(8) }
//                    scaleType = ImageView.ScaleType.CENTER_CROP
//                }
//
//                when {
//                    name.equals("Payout", true) -> imageView.setImageResource(R.drawable.ic_payout)
//                    name.equals("Coupon", true) -> imageView.setImageResource(R.drawable.ic_coupon)
//                    else -> {
//                        (item["image"] as? String)?.let { url ->
//                            Thread {
//                                try {
//                                    val bmp = BitmapFactory.decodeStream(URL(url).openStream())
//                                    Handler(Looper.getMainLooper()).post {
//                                        imageView.setImageBitmap(bmp)
//                                    }
//                                } catch (_: Exception) {
//                                    Handler(Looper.getMainLooper()).post {
//                                        imageView.setImageResource(R.drawable.custom)
//                                    }
//                                }
//                            }.start()
//                        }
//                    }
//                }
//
//                // To re-enable images later:
//                // itemColumn.addView(imageView)
//                */
//
//                val nameView = TextView(context).apply {
//                    text = if (name.length > 26) "${name.take(26)}…" else name
//                    textSize = 20f
//                    setTypeface(typeface, Typeface.BOLD)
//                    setTextColor(Color.BLACK)
//                }
//
////                itemColumn.addView(imageView)
//                itemColumn.addView(nameView)
//
//                // ================= QTY × PRICE COLUMN (1.0f) =================
//                val qtyPriceView = TextView(context).apply {
//                    layoutParams = LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f)
//                    gravity = Gravity.CENTER
//                    textSize = 18f
//                    setTextColor(Color.DKGRAY)
//                    text = when {
//                        name.equals("Payout", true) -> ""
//                        name.equals("Cashback", true) -> ""
//                        else -> "$qty × ${formatCurrency(price)}"
//                    }
//                }
//
//                // ================= TOTAL COLUMN (0.8f) =================
//                val totalView = TextView(context).apply {
//                    layoutParams = LinearLayout.LayoutParams(0, WRAP_CONTENT, 0.8f)
//                    gravity = Gravity.END
//                    textSize = 17f
//                    setTypeface(typeface, Typeface.BOLD)
//
//                    // 🔥 Color rule for payout
//                    setTextColor(
//                        if (name.equals("Payout", true)) Color.RED
//                        else Color.BLACK
//                    )
//
//                    // ✅ THIS IS THE KEY CHANGE
//                    text = formatCurrency(
//                        if (discountValue > 0) discountedTotal else originalTotal
//                    )
//                }
//
//
//                // Add columns into row
//                row.addView(itemColumn)
//                row.addView(qtyPriceView)
//                row.addView(totalView)
//
//                itemsContainer.addView(row)

                // ================= DISCOUNT ROW =================
//                if (hasDiscount) {
//
//                    val discountLayout = LinearLayout(context).apply {
//                        orientation = LinearLayout.VERTICAL
//                        setPadding(dpToPx(12), 0, dpToPx(12), dpToPx(6))
//                    }
//
//                    // 🔸 Discount label (Combo Discount -$2.00)
//                    val discountText = TextView(context).apply {
//                        text = "$discountType -${formatCurrency(discountValue)}"
//                        textSize = 14f
//                        setTextColor(Color.parseColor("#E67E22")) // orange like screenshot
//                    }
//
//                    // 🔸 Original price (strike-through)
//                    val originalPriceText = TextView(context).apply {
//                        text = formatCurrency(originalPrice * qty)
//                        textSize = 14f
//                        setTextColor(Color.GRAY)
//                        paintFlags = paintFlags or Paint.STRIKE_THRU_TEXT_FLAG
//                    }
//
//                    discountLayout.addView(discountText)
//                    discountLayout.addView(originalPriceText)
//
//                    itemsContainer.addView(discountLayout)
//                }


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

// ================= TOTALS (UNCHANGED) =================
            findViewById<TextView>(R.id.label_total_items).text = "Total Items : $totalItemCount"
            grossView.text = formatCurrency(grossTotal)
            discountView.text = formatCurrency(-discount)
            findViewById<TextView>(R.id.label_cashback_fee).text = "Cashback Fee"
            findViewById<TextView>(R.id.value_cashback_fee).text = formatCurrency(cashbackFee)
            merchantDiscountView.text = formatCurrency(-merchantDiscount)
            netTotalView.text = formatCurrency(netTotal)
            taxView.text = formatCurrency(tax)
            netPayableView.text = "Total : ${formatCurrency(netPayable)}"
            paymentDate.text = orderDate
            paymentTime.text = orderTime
            paymentDate.setTextColor(Color.WHITE)
            paymentTime.setTextColor(Color.WHITE)


            Log.d(
                "CustomerDisplay",
                "✔ Order #$orderId totals updated, Total Items: $totalItemCount"
            )
        }
        private fun dpToPx(dp: Int): Int {
            return (dp * context.resources.displayMetrics.density).toInt()
        }


        fun showThankYouLayout() {
            stopSlideshow()
            setContentView(R.layout.thank_you_layout)

            //val storeLogoView = findViewById<ImageView>(R.id.thank_you_store_logo)
            val thankYouText = findViewById<TextView>(R.id.thank_you_text)
            val visitAgainText = findViewById<TextView>(R.id.visit_again_text)

            thankYouText.text = "Thank You!"
            visitAgainText.text = "Please Visit Again"
            if (!currentStoreLogoUrl.isNullOrEmpty()) {
                Thread {
                    try {
                        val input = URL(currentStoreLogoUrl).openStream()
                        val bitmap = BitmapFactory.decodeStream(input)
                        Handler(Looper.getMainLooper()).post {
                            storeLogoView.setImageBitmap(bitmap)
                        }
                    } catch (e: Exception) {
                        Handler(Looper.getMainLooper()).post {
                            storeLogoView.setImageResource(R.drawable.pinaka_logo)
                        }
                    }
                }.start()
            } else {
                storeLogoView.setImageResource(R.drawable.pinaka_logo)
            }
            if (!currentStoreBaseUrl.isNullOrEmpty()) {
                loadSlideshowFromApi(currentStoreBaseUrl)
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
        }
    }
}