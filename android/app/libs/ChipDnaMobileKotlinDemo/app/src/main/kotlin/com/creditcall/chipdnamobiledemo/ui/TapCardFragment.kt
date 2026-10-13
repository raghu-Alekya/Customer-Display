package com.creditcall.chipdnamobiledemo.ui

import android.os.Bundle
import android.os.Parcelable
import android.view.View
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import com.creditcall.chipdnamobile.ChipDnaMobile
import com.creditcall.chipdnamobile.ITransactionFinishedListener
import com.creditcall.chipdnamobile.ITransactionUpdateListener
import com.creditcall.chipdnamobile.IUserNotificationListener
import com.creditcall.chipdnamobile.ParameterKeys
import com.creditcall.chipdnamobile.ParameterValues
import com.creditcall.chipdnamobile.Parameters
import com.creditcall.chipdnamobiledemo.R
import com.creditcall.chipdnamobiledemo.databinding.FragmentTapCardBinding
import com.creditcall.chipdnamobiledemo.util.viewBinding
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import timber.log.Timber
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class TapCardFragment : Fragment(R.layout.fragment_tap_card), ITransactionFinishedListener, ITransactionUpdateListener,
    IUserNotificationListener {

    private val logsToPassBack = StringBuilder(" --- ChipDnaTapCard\n")
    private val dateFormat = SimpleDateFormat("MM/dd/yyyy HH:mm:ss", Locale.US)

    private val binding by viewBinding { FragmentTapCardBinding.bind(it) }

    private lateinit var mListener: TapCardInteractionListener

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        setUpGui()
        addListeners()
        // TODO: Enable TTM
        // After receiving the IRequestActivityListener#onRequestActivity callback, the SDK expects an Activity instance to be sent in order to proceed with the TTM transaction.
        // The activity needs to be in foreground and active until the transaction finishes. If the activity is being destroyed, the transaction will fail
        val response = ChipDnaMobile.getInstance().continueRequestedActivity(activity)
        if (!response.containsKey(ParameterKeys.Result) || ParameterValues.FALSE == response.getValue(ParameterKeys.Result)) {
            Timber.d("%s%s", "Continue activity failed ", response.getValue(ParameterKeys.Errors))
            removeListeners()
            appendToLogs("continueRequestedActivity failed ${response.getValue(ParameterKeys.Errors)}")
            appendToLogs("terminateTransaction (request)")
            mListener.onTransactionFinished(logsToPassBack.toString())
        }
    }

    private fun setUpGui() {
        mListener = getInteractionListener()
        with(binding) {
            terminateButton.setOnClickListener {
                appendToLogs("terminateTransaction (request)")
                val responseParameters = ChipDnaMobile.getInstance().terminateTransaction(null)
                appendToLogs("terminateTransaction (response)")
                addParametersToLogs(responseParameters)
                mListener.onTerminate(logsToPassBack.toString())
            }
        }
    }

    override fun onTransactionFinishedListener(parameters: Parameters?) {
        Timber.d("%s%s", "onTransactionFinished - ", (if (parameters != null) parameters.toList() else "null"))
        removeListeners()
        appendToLogs("Parameters [onTransactionFinishedListener =>]:")
        addParametersToLogs(parameters)
        mListener.onTransactionFinished(logsToPassBack.toString())
    }

    override fun onTransactionUpdateListener(parameters: Parameters?) {
        Timber.d("%s%s", "onTransactionUpdateListener - ", (if (parameters != null) parameters.toList() else "null"))
        appendToLogs("Parameters [onTransactionUpdateListener =>]:")
        addParametersToLogs(parameters)
        if (parameters != null && parameters.containsKey(ParameterKeys.TransactionUpdate)) {
            viewLifecycleOwner.lifecycleScope.launch(Dispatchers.Main) {
                binding.transactionUpdate.text = parameters.getValue(ParameterKeys.TransactionUpdate)
            }
        }
    }

    override fun onUserNotification(parameters: Parameters?) {
        if (parameters != null && parameters.containsKey(ParameterKeys.UserNotification)) {
            viewLifecycleOwner.lifecycleScope.launch(Dispatchers.Main) {
                binding.userNotification.text = parameters.getValue(ParameterKeys.UserNotification)
            }
        }
    }

    private fun appendToLogs(toAppend: String) {
        logsToPassBack.append(dateFormat.format(Date())).append(": ").append(toAppend).append("\n")
    }

    private fun addParametersToLogs(parameters: Parameters?) {
        if (parameters != null) {
            for (entry in parameters.toList()) {
                logsToPassBack.append("\t[").append(entry.value).append("]\n")
            }
        }
    }

    private fun addListeners() {
        ChipDnaMobile.getInstance().addTransactionFinishedListener(this)
        ChipDnaMobile.getInstance().addTransactionUpdateListener(this)
        ChipDnaMobile.getInstance().addUserNotificationListener(this)
    }

    private fun removeListeners() {
        ChipDnaMobile.getInstance().removeTransactionFinishedListener(this)
        ChipDnaMobile.getInstance().removeTransactionUpdateListener(this)
        ChipDnaMobile.getInstance().removeUserNotificationListener(this)
    }

    private fun getInteractionListener(): TapCardInteractionListener {
        if (arguments?.containsKey(KEY_INTERACTION_LISTENER) != true
            || arguments?.getParcelable<Parcelable>(KEY_INTERACTION_LISTENER) !is TapCardInteractionListener
        ) {
            throw RuntimeException(context.toString() + " must implement TapCardInteractionListener")
        }

        return requireArguments().getParcelable<Parcelable>(KEY_INTERACTION_LISTENER) as TapCardInteractionListener
    }

    companion object {
        private val KEY_INTERACTION_LISTENER = "KEY_INTERACTION_LISTENER"

        fun newInstance(interactionListener: TapCardInteractionListener) =
            TapCardFragment().apply {
                arguments = Bundle().apply {
                    putParcelable(KEY_INTERACTION_LISTENER, interactionListener)
                }
            }
    }

    interface TapCardInteractionListener : Parcelable {
        fun onTerminate(logs: String)
        fun onTransactionFinished(logs: String)
    }

}