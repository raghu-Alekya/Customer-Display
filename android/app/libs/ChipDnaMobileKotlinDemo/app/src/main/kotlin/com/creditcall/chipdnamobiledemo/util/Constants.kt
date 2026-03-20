package com.creditcall.chipdnamobiledemo.util

import com.creditcall.chipdnamobile.ParameterValues

enum class TransactionCommand(val label: String) {
  Authorisation("Auth"),
  Confirm("Confirm"),
  Void("Void"),
  TransactionInfo("Transaction Info")
}

enum class Amount(val value: String, val label: String) {
  Sale("1000", "Sale - ${CURRENCY_SYM}10.00"),
  Decline("500", "Decline - ${CURRENCY_SYM}5.00"),
  Error("110000", "Error - ${CURRENCY_SYM}1100.00"),
  Voice_Ref("4723", "Voice Ref - ${CURRENCY_SYM}47.23")
}

const val APP_ID = "CEMDEMO"
const val CURRENCY_SYM = "$"
const val CURRENCY = "USD"

// Replace the APIKEY with your Gateway API KEY as found in the Gateway Control Panel's options/security keys page
const val API_KEY = "2F822Rw39fx762MaV7Yy86jXGTC7sCDy"


// Note: for the Miura 810 device, a test device will only work in testEnviornment
// and a production device will only work in LiveEnvironment
// Using the device in the wrong environment results in an  IncompatibleOSWithAppMode during
// device configuration,
const val ENVIRONMENT = ParameterValues.TestEnvironment