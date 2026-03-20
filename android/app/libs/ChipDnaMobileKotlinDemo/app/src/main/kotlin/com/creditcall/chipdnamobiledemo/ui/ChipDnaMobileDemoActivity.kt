package com.creditcall.chipdnamobiledemo.ui

import androidx.appcompat.app.AppCompatActivity
import android.os.Bundle
import com.creditcall.chipdnamobiledemo.R
import timber.log.Timber
import timber.log.Timber.DebugTree

class ChipDnaMobileDemoActivity : AppCompatActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    setContentView(R.layout.activity_chipdna_mobile_demo)
    Timber.plant(DebugTree())
  }
}