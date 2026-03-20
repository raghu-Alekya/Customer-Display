package com.creditcall.chipdnamobiledemo.ui

import android.content.Intent
import android.graphics.Bitmap
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import com.creditcall.chipdnamobile.ChipDnaMobileException
import com.creditcall.chipdnamobile.ChipDnaMobileUtils
import com.creditcall.chipdnamobiledemo.R
import kotlinx.parcelize.Parcelize

@Parcelize
class DigitalSignatureCaptureActivity : AppCompatActivity(),
  SignatureCaptureFragment.SignatureCaptureInteractionListener {

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    setContentView(R.layout.activity_digital_signature_capture)
    supportFragmentManager.beginTransaction().add(
      R.id.frameLayout,
      SignatureCaptureFragment.newInstance(this)
    ).commit()
  }

  override fun onTerminate() {
    setResult(SIGNATURE_CAPTURE_REQUEST_TERMINATED)
    finish()
  }

  override fun onSignatureAvailable(signatureBitmap: Bitmap) {
    try {
      val intent = Intent().apply {
        putExtra(
          KEY_SIGNATURE_DATA,
          ChipDnaMobileUtils.getSignaturePngStringFromBitmap(signatureBitmap)
        )
      }
      setResult(SIGNATURE_CAPTURE_REQUEST_ACCEPTED, intent)
      finish()
    } catch (e: ChipDnaMobileException) {
      e.printStackTrace()
    }
  }

  companion object {
    val SIGNATURE_CAPTURE_REQUEST_ACCEPTED = 1
    val SIGNATURE_CAPTURE_REQUEST_TERMINATED = 2
    val KEY_SIGNATURE_DATA = "KEY_SIGNATURE_DATA"
  }

}