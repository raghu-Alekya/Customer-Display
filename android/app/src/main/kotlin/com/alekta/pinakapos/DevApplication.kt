package com.alekta.pinakapos

import android.app.Application
import com.creditcall.chipdnamobile.ChipDnaApplication


class DevApplication : ChipDnaApplication() {

    override fun onCreate() {
        super.onCreate()
        // Any application-level initialization
    }

    override fun onSDKInitializationSuccess() {
        super.onSDKInitializationSuccess()
        println("SDK Initialization Success")
    }

    override fun onSDKInitializationFailed(errorMessage: String?) {
        super.onSDKInitializationFailed(errorMessage)
        println("SDK Initialization Failed: $errorMessage")
    }
}