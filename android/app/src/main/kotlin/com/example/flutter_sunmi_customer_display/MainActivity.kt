package com.example.flutter_sunmi_customer_display

import android.app.Presentation
import android.content.Context
import android.hardware.display.DisplayManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Display
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.URL
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.View
import org.json.JSONArray
import kotlin.math.absoluteValue

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.flutter_customer_display/sunmi_display"
    private var customerDisplayPresentation: CustomerDisplayPresentation? = null
    private var currentStoreId: String = ""
    private var currentStoreName: String = ""
    private var currentStoreLogoUrl: String? = null
    private var currentStoreBaseUrl: String = ""


    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.d("CustomerDisplay", "🔧 configureFlutterEngine called")

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            Log.d("CustomerDisplay", "📢 MethodChannel call → method=${call.method}, args=${call.arguments}")

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
                        "➡ showWelcomeWithStore invoked → storeId=$storeId, storeName=$storeName, logoUrl=$storeLogoUrl, baseUrl=$storeBaseUrl"
                    )

                    currentStoreId = storeId
                    currentStoreName = storeName
                    currentStoreLogoUrl = storeLogoUrl
                    currentStoreBaseUrl = storeBaseUrl

                    // --- Call the slideshow API first to see logs ---
                    if (storeBaseUrl.isNotEmpty()) {
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

                                Log.d("CustomerDisplay", "✅ Slideshow API returned ${imageUrls.size} images for store $storeName")
                                for (url in imageUrls) {
                                    Log.d("CustomerDisplay", "Slide URL: $url")
                                }

                            } catch (e: Exception) {
                                Log.e("CustomerDisplay", "❌ Failed to load slideshow for store $storeName: ${e.message}")
                            }
                        }.start()
                    } else {
                        Log.e("CustomerDisplay", "❌ storeBaseUrl is empty → cannot load slideshow for store $storeName")
                    }

                    // --- Show Welcome layout on customer display ---
                    if (customerDisplayPresentation == null) {
                        showWelcomeOnCustomerDisplay()
                    }

                    customerDisplayPresentation?.showWelcomeLayout(storeId, storeName, storeLogoUrl, storeBaseUrl)

                    result.success("Welcome updated with store")
                }


                "showCustomerData" -> {
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

                    Log.d("CustomerDisplay", "➡ showCustomerData invoked → orderId=$orderId, items=${items.size}, grossTotal=$grossTotal, discount=$discount, merchantDiscount=$merchantDiscount, netTotal=$netTotal, tax=$tax, netPayable=$netPayable")
                    Log.d("CustomerDisplay", "➡ orderDate='$orderDate'")
                    Log.d("CustomerDisplay", "➡ orderTime='$orderTime'")

                    val success = showDataOnCustomerDisplay(
                        orderId, currentStoreId, currentStoreName, currentStoreLogoUrl, items,
                        grossTotal, discount, merchantDiscount, netTotal, tax, netPayable,orderDate, orderTime
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
                    Log.d("CustomerDisplay", "➡ showThankYou invoked")
                    if (showThankYouOnCustomerDisplay()) {
                        Log.d("CustomerDisplay", "✔ Thank You displayed")
                        result.success("Thank You shown")
                    } else {
                        Log.e("CustomerDisplay", "❌ No secondary display found for Thank You")
                        result.error("NO_DISPLAY", "No secondary display found", null)
                    }
                }

                else -> {
                    Log.w("CustomerDisplay", "⚠ Method not implemented: ${call.method}")
                    result.notImplemented()
                }
            }
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
        orderTime: String
    ): Boolean {
        if (customerDisplayPresentation == null) {
            Log.d("CustomerDisplay", "CustomerDisplayPresentation null, showing Welcome first")
            showWelcomeOnCustomerDisplay()
        }

        customerDisplayPresentation?.updateCustomerData(
            orderId, storeId, storeName, storeLogoUrl, items, grossTotal,
            discount, merchantDiscount, netTotal, tax, netPayable,orderDate, orderTime
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
    override fun onDestroy() {
        Log.d("CustomerDisplay", "➡ onDestroy called, dismissing CustomerDisplayPresentation")
        customerDisplayPresentation?.dismiss()
        super.onDestroy()
    }

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

        private fun formatCurrency(value: Double): String {
            return if (value < 0) {
                "- $${"%.2f".format(value.absoluteValue)}"
            } else {
                "$${"%.2f".format(value)}"
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
            orderTime: String
        ) {
            val defaultStoreId = "STORE001"
            val defaultStoreName = "Pinaka"
            val defaultStoreLogoUrl: String? = null

            currentStoreId = storeId?.takeIf { it.isNotEmpty() } ?: defaultStoreId
            currentStoreName = storeName?.takeIf { it.isNotEmpty() } ?: defaultStoreName
            currentStoreLogoUrl = storeLogoUrl?.takeIf { it?.isNotEmpty() == true } ?: defaultStoreLogoUrl

            Log.d("CustomerDisplay", "➡ Showing Customer Display layout")
            setContentView(R.layout.customer_display_layout)
            bindOrderViews()

            // Update store info
            updateStoreInfo(currentStoreId, currentStoreName, currentStoreLogoUrl, orderDate, orderTime)

            // --- Start slideshow ---
            slideshowImageView = findViewById(R.id.slideshow_image)
            if (currentStoreBaseUrl.isNotEmpty()) {
                loadSlideshowFromApi(currentStoreBaseUrl)
            } else {
                slideshowImageView.setImageResource(R.drawable.pinaka_logo)
                slideshowImageView.scaleType = ImageView.ScaleType.CENTER_INSIDE
                Log.d("CustomerDisplay", "✅ No storeBaseUrl → showing centered default logo")
            }

            // --- Empty cart handling ---
            itemsContainer.removeAllViews()
            if (items.isEmpty() || grossTotal == 0.0) {
                Log.d("CustomerDisplay", "📢 No order data → showing empty cart message")

                val emptyLayout = LinearLayout(context).apply {
                    orientation = LinearLayout.VERTICAL
                    gravity = Gravity.CENTER
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT,
                        LinearLayout.LayoutParams.MATCH_PARENT
                    )
                }

                val emptyImage = ImageView(context).apply {
                    setImageResource(R.drawable.empty_cart)
                    scaleType = ImageView.ScaleType.CENTER_INSIDE
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT
                    ).apply { bottomMargin = 16 }
                }

                val emptyMessage = TextView(context).apply {
                    text = "No items in the Order panel"
                    textSize = 22f
                    setTextColor(Color.BLACK)
                    gravity = Gravity.CENTER
                }

                emptyLayout.addView(emptyImage)
                emptyLayout.addView(emptyMessage)
                itemsContainer.addView(emptyLayout)
                return
            }

            // --- Populate order items ---
            orderIdView.text = "Order #$orderId"
            itemsContainer.removeAllViews()
            var totalItemCount = 0

            for ((index, item) in items.withIndex()) {
                val name = (item["name"] as? String) ?: ""
                val qty = (item["qty"] as? Number)?.toInt() ?: 0
                val price = (item["price"] as? Number)?.toDouble() ?: 0.0
                val total = price * qty

                if (!name.equals("Payout", ignoreCase = true) && !name.equals("Coupon", ignoreCase = true)) {
                    totalItemCount += qty
                }

                // --- Item layout ---
                val itemLayout = LinearLayout(context).apply {
                    orientation = LinearLayout.HORIZONTAL
                    // Remove padding for no gaps
                    setPadding(0, 0, 0, 0)
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT
                    )
                    gravity = Gravity.CENTER_VERTICAL
                    setBackgroundColor(Color.WHITE)
                }

                // --- Image ---
                val imageView = ImageView(context).apply {
                    layoutParams = LinearLayout.LayoutParams(80, 80).apply { rightMargin = 16 }
                    scaleType = ImageView.ScaleType.CENTER_CROP
                    clipToOutline = true
                    background = GradientDrawable().apply {
                        cornerRadius = 12f
                        setColor(Color.TRANSPARENT)
                    }
                }

                when {
                    name.equals("Payout", ignoreCase = true) -> imageView.setImageResource(R.drawable.ic_payout)
                    name.equals("Coupon", ignoreCase = true) -> imageView.setImageResource(R.drawable.ic_coupon)
                    else -> {
                        (item["image"] as? String)?.let { imageUrl ->
                            Thread {
                                try {
                                    val input = URL(imageUrl).openStream()
                                    val bitmap = BitmapFactory.decodeStream(input)
                                    Handler(Looper.getMainLooper()).post {
                                        imageView.setImageBitmap(bitmap)
                                    }
                                } catch (e: Exception) {
                                    Handler(Looper.getMainLooper()).post {
                                        imageView.setImageResource(android.R.drawable.ic_menu_gallery)
                                    }
                                }
                            }.start()
                        }
                    }
                }

                // --- Details layout ---
                val detailsLayout = LinearLayout(context).apply {
                    orientation = LinearLayout.VERTICAL
                    layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                }

                val displayName = if (name.length > 20) name.take(20) + "..." else name

                val nameView = TextView(context).apply {
                    textSize = 17f
                    setTypeface(typeface, Typeface.BOLD)
                    text = displayName
                    setTextColor(Color.BLACK)
                    val params = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT
                    )
                    params.bottomMargin = 4
                    layoutParams = params
                }

                val qtyPriceView = TextView(context).apply {
                    textSize = 17f
                    text = "${formatCurrency(price)} × $qty"
                    setTextColor(Color.DKGRAY)
                }

                detailsLayout.addView(nameView)
                detailsLayout.addView(qtyPriceView)
                val totalView = TextView(context).apply {
                    textSize = 18f
                    setTypeface(typeface, Typeface.BOLD)
                    text = formatCurrency(total)
                    gravity = Gravity.END
                    setTextColor(Color.BLACK)

                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        setMargins(0, 0, 10, 0)
                    }
                }

                itemLayout.addView(imageView)
                itemLayout.addView(detailsLayout)
                itemLayout.addView(totalView)

                // --- Add item layout ---
                itemsContainer.addView(itemLayout)

                // --- Add divider only between items ---
                if (index < items.size - 1) {
                    val divider = View(context).apply {
                        setBackgroundColor(Color.BLACK)
                        layoutParams = LinearLayout.LayoutParams(
                            LinearLayout.LayoutParams.MATCH_PARENT,
                            1 // divider height
                        ).apply {
                            topMargin = 1 // 1px space above
                            bottomMargin = 1 // 1px space below
                        }
                    }
                    itemsContainer.addView(divider)
                }
            }
            Log.d("CustomerDisplay", "DEBUG → Tax value: $tax")

            val summaryContainer = findViewById<LinearLayout>(R.id.summary_container)

            if (tax == 0.0) {
                Log.d("CustomerDisplay", "DEBUG → Tax is 0.0, hiding summary container")
                summaryContainer.visibility = View.GONE
                return
            } else {
                Log.d("CustomerDisplay", "DEBUG → Tax is not zero, showing summary container")
                summaryContainer.visibility = View.VISIBLE
            }

            findViewById<TextView>(R.id.label_total_items).text = "Total Items : $totalItemCount"
            grossView.text = formatCurrency(grossTotal)
            discountView.text = formatCurrency(-discount)
            merchantDiscountView.text = formatCurrency(-merchantDiscount)
            netTotalView.text = formatCurrency(netTotal)
            taxView.text = formatCurrency(tax)
            netPayableView.text = "Total : ${formatCurrency(netPayable)}"
            paymentDate.text = orderDate
            paymentTime.text = orderTime

            Log.d("CustomerDisplay", "✔ Order #$orderId totals updated, Total Items: $totalItemCount")
        }

        fun showThankYouLayout() {
            stopSlideshow()
            setContentView(R.layout.thank_you_layout)

            val storeLogoView = findViewById<ImageView>(R.id.thank_you_store_logo)
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