package com.alekta.pinakapos

import com.creditcall.chipdnamobile.ChipDnaApplication

// ChipDNA Mobile (Tap to Mobile) requires the process Application to extend ChipDnaApplication
// or connectAndConfigure returns InvalidApplicationInstance.
class DevApplication : ChipDnaApplication() {

    override fun onCreate() {
        super.onCreate()
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

