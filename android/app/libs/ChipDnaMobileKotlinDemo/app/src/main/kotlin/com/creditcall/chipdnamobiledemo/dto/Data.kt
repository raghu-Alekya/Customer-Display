package com.creditcall.chipdnamobiledemo.dto

import android.os.Parcelable
import kotlinx.android.parcel.RawValue
import kotlinx.parcelize.Parcelize
import com.creditcall.chipdnamobile.Parameters

data class PinPad(val name: String, val connectionType: String)

@Parcelize
data class Item(val identifier: String, val description: String, val metadata: @RawValue Any) :
  Parcelable

data class SignatureCheckRequest(
  val isOperatorPinRequired: Boolean,
  val isSignatureCaptureSupported: Boolean,
  val receiptDataXmlString: String,
  val params: Parameters
)

data class VoiceReferralRequest(
  val isOperatorPinRequired: Boolean,
  val referralPhoneNumber: String?,
  val params: Parameters
)