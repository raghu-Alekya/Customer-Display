package com.creditcall.chipdnamobiledemo.util

import android.content.Context
import android.view.View
import android.view.View.GONE
import android.view.View.VISIBLE
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import com.creditcall.chipdnamobile.ChipDnaMobile
import com.creditcall.chipdnamobile.ParameterKeys
import com.creditcall.chipdnamobile.ParameterValues
import com.creditcall.chipdnamobile.Parameters
import kotlinx.coroutines.launch

//region ChipDnaMobile
fun getInstance(): ChipDnaMobile = ChipDnaMobile.getInstance()

fun isInstanceInitialized() = ChipDnaMobile.isInitialized()

fun ChipDnaMobile.getStatus(): Parameters = getInstance().getStatus(null)
//endregion

//region Parameters
fun Parameters.isSuccess() =
  containsKey(ParameterKeys.Result) && getValue(ParameterKeys.Result).equals(
    "True",
    ignoreCase = true
  )

fun Parameters.isPasswordAttemptReached() =
  getValue(ParameterKeys.RemainingAttempts)?.equals("0") ?: true

fun Parameters.isResponseRequired() =
  getValue(ParameterKeys.ResponseRequired) == ParameterValues.TRUE

fun Parameters.isOperatorPinRequired() =
  getValue(ParameterKeys.OperatorPinRequired) == ParameterValues.TRUE
//endregion


//region Fragment
fun Fragment.launchAndRepeatOnStarted(action: suspend () -> Unit) {
  viewLifecycleOwner.lifecycleScope.launch {
    repeatOnLifecycle(Lifecycle.State.STARTED) {
      action.invoke()
    }
  }
}
//endregion

fun View.show(show: Boolean = true) {
  visibility = if (show) {
    VISIBLE
  } else {
    GONE
  }
}