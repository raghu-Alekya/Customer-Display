package com.alekta.pinakapos

import android.app.Application

class DevApplication : Application() {

    override fun onCreate() {
        try {
            super.onCreate()
        } catch (e: Throwable) {
            println("DevApplication onCreate init exception: ${e.message}")
        }
    }
}