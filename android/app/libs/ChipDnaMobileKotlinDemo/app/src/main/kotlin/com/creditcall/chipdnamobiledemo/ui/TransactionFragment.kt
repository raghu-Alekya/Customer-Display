package com.creditcall.chipdnamobiledemo.ui

import android.Manifest
import android.app.AlertDialog
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.InputType
import android.text.method.ScrollingMovementMethod
import android.view.View
import android.view.View.GONE
import android.view.View.VISIBLE
import android.widget.ArrayAdapter
import android.widget.EditText
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat.checkSelfPermission
import androidx.fragment.app.Fragment
import androidx.fragment.app.viewModels
import com.creditcall.chipdnamobile.Application
import com.creditcall.chipdnamobile.ChipDnaMobile
import com.creditcall.chipdnamobile.ParameterKeys
import com.creditcall.chipdnamobiledemo.R
import com.creditcall.chipdnamobiledemo.databinding.FragmentTransactionBinding
import com.creditcall.chipdnamobiledemo.dto.Item
import com.creditcall.chipdnamobiledemo.dto.PinPad
import com.creditcall.chipdnamobiledemo.dto.SignatureCheckRequest
import com.creditcall.chipdnamobiledemo.dto.VoiceReferralRequest
import com.creditcall.chipdnamobiledemo.ui.ChipDnaDemoTapCardActivity.Companion.TRANSACTION_FINISHED_PARAMETERS_STRING
import com.creditcall.chipdnamobiledemo.ui.DigitalSignatureCaptureActivity.Companion.KEY_SIGNATURE_DATA
import com.creditcall.chipdnamobiledemo.util.*
import com.creditcall.chipdnamobiledemo.viewmodel.TransactionViewModel

class TransactionFragment : Fragment(R.layout.fragment_transaction) {

  //region UI Logic

  private val binding by viewBinding { FragmentTransactionBinding.bind(it) }

  private val viewModel by viewModels<TransactionViewModel>()

  private lateinit var availablePinPadDialogFragment: ItemListBottomSheetFragment
  private lateinit var amountDialogFragment: ItemListBottomSheetFragment
  private lateinit var transactionCommandDialogFragment: ItemListBottomSheetFragment

  private var selectedAmount: Amount? = null
  private lateinit var selectedTransactionCommand: TransactionCommand

  private lateinit var passwordAlertDialog: AlertDialog

  private val bluetoothPermissionRequestLauncher =
    registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {
      if (it.isNotEmpty()) {
        var areAllGranted = true
        for (granted in it.values) {
          if (!granted) {
            Toast.makeText(
              requireContext(),
              getString(R.string.bluetooth_permissions_not_granted),
              Toast.LENGTH_SHORT
            ).show()
            viewModel.writeToLog("All bluetooth permissions are not granted")
            areAllGranted = false
            break
          }
        }

        if (areAllGranted) {
          viewModel.onSelectPinPadButtonClicked(areBluetoothPermissionsGranted())
        }
      }
    }

  private val locationPermissionRequestLauncher =
    registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
      viewModel.onLocationPermissionResult(granted)
    }

  // Audio permission launcher - only required for Tap to Mobile transactions
  private val audioPermissionRequestLauncher =
    registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
      if (!granted) {
        Toast.makeText(
          requireContext(),
          getString(R.string.audio_permission_not_granted),
          Toast.LENGTH_SHORT
        ).show()
        viewModel.writeToLog("Audio permission not granted")
      }
      viewModel.onAudioPermissionResult(granted)
    }

  private val signatureCaptureRequestLauncher =
    registerForActivityResult(ActivityResultContracts.StartActivityForResult()) {
      val terminateTransaction =
        it.resultCode != DigitalSignatureCaptureActivity.SIGNATURE_CAPTURE_REQUEST_ACCEPTED
      viewModel.processSignatureCaptureResult(
        terminateTransaction,
        it.data?.getStringExtra(KEY_SIGNATURE_DATA)
      )
    }

  private val ttmTapCardCaptureRequestLauncher =
    registerForActivityResult(ActivityResultContracts.StartActivityForResult()) {
       val parametersString: String? = it.data?.getStringExtra(TRANSACTION_FINISHED_PARAMETERS_STRING)
      parametersString?.let { logs->
        viewModel.writeToLog(logs)
      }
    }

  override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
    super.onViewCreated(view, savedInstanceState)

    with(binding) {
      launchAndRepeatOnStarted {
        viewModel.progressLoaderState.collect {
          stateProgressLoader.visibility = if (it) VISIBLE else GONE
        }
      }

      launchAndRepeatOnStarted {
        viewModel.onTransactionReadyEvent.collect {
          with(binding) {
            userReferenceEditText.isEnabled = it
            if (it) {
              userReferenceEditText.requestFocus()
            }
            submitTransactionBtn.isEnabled = it
            autogenUserReferenceCheckBox.isEnabled = it
            amountDropDown.isEnabled = it
            transactionCmdDropDown.isEnabled = it
          }
        }
      }

      launchAndRepeatOnStarted {
        viewModel.requestPasswordEvent.collect { requestPasswordAndInitializeClient() }
      }

      launchAndRepeatOnStarted {
        viewModel.signatureCaptureEvent.collect {
          if (it) {
            val digitalSignatureCaptureIntent =
              Intent(requireContext(), DigitalSignatureCaptureActivity::class.java)
            signatureCaptureRequestLauncher.launch(digitalSignatureCaptureIntent)
          }
        }
      }

      launchAndRepeatOnStarted {
        viewModel.requestActivityEvent.collect {
          if (it) {
            val tapCardIntent =
              Intent(requireContext(), ChipDnaDemoTapCardActivity::class.java)
            ttmTapCardCaptureRequestLauncher.launch(tapCardIntent)
          }
        }
      }

      launchAndRepeatOnStarted {
        viewModel.requestBluetoothPermissionsEvent.collect { shouldRequest ->
          if (shouldRequest) {
            requestBluetoothPermissions()
          }
        }
      }

      launchAndRepeatOnStarted {
        viewModel.requestLocationPermissionsEvent.collect { shouldRequest ->
          if (shouldRequest) {
            requestLocationPermission()
          }
        }
      }

      // Audio permission event collector - only required for Tap to Mobile transactions
      launchAndRepeatOnStarted {
        viewModel.requestAudioPermissionsEvent.collect { shouldRequest ->
          if (shouldRequest) {
            requestAudioPermission()
          }
        }
      }

      launchAndRepeatOnStarted {
        viewModel.selectPinpadButtonState.collect {
          selectPinpadBtn.isEnabled = it
        }
      }

      launchAndRepeatOnStarted {
        viewModel.connectToPinpadButtonState.collect {
          connectToPinpadBtn.isEnabled = it
        }
      }

      launchAndRepeatOnStarted {
        viewModel.showAvailablePinPadEvent.collect {
          showAvailablePinPadList(it.map { item ->
            Item(
              item.name,
              "${item.connectionType}    ${item.name}",
              item
            )
          })
        }
      }

      launchAndRepeatOnStarted {
        viewModel.addLogRecordEvent.collect {
          logTextView.text = it
        }
      }

      launchAndRepeatOnStarted {
        viewModel.txnReferenceState.collect {
          it?.let { text ->
            userReferenceEditText.setText(
              text
            )
          }
        }
      }

      launchAndRepeatOnStarted {
        viewModel.onSignatureCheckRequestEvent.collect { requestSignatureCheck(it) }
      }

      launchAndRepeatOnStarted {
        viewModel.onVoiceReferralRequestEvent.collect { requestVoiceReferral(it) }
      }

      launchAndRepeatOnStarted {
        viewModel.onApplicationSelectionEvent.collect { showApplicationList(it) }
      }

      launchAndRepeatOnStarted {
        viewModel.onUserNotificationEvent.collect { showUserNotification(it) }
      }

    }

    setupGui()
  }

  override fun onResume() {
    super.onResume()
    // Initialise ChipDna Mobile before starting to interacting with the API. You can check if ChipDna Mobile has been initialised by using isInitialised()
    // It's possible that android may have cleaned up resources while the application has been in the background and needs to be re-initialised.
    if (!isInstanceInitialized()) {
      requestPasswordAndInitializeClient()
    }
  }

  private fun setupGui() {
    with(binding) {
      logTextView.movementMethod = ScrollingMovementMethod()
      selectPinpadBtn.setOnClickListener {
        viewModel.onSelectPinPadButtonClicked(
          areBluetoothPermissionsGranted()
        )
      }
      connectToPinpadBtn.setOnClickListener { viewModel.onConnectToPinpadButtonClicked(enableTtmSwitch.isChecked) }
      amountDropDown.isEnabled = false
      amountDropDown.setOnClickListener {
        showAmountItemList {
          viewModel.writeToLog("Selected: ${it.label}")
          amountValueTextView.text = it.label
          selectedAmount = it
        }
      }
      transactionCmdDropDown.isEnabled = false
      transactionCmdDropDown.setOnClickListener {
        showTransactionCommandList {
          viewModel.writeToLog("Selected: ${it.label}")
          txnCmdValueTextView.text = it.label
          selectedTransactionCommand = it
        }
      }
      submitTransactionBtn.setOnClickListener {
        if (!::selectedTransactionCommand.isInitialized) {
          viewModel.writeToLog("Select a transaction command")
        } else {
          viewModel.onSubmitTransactionButtonClicked(
            selectedTransactionCommand,
            selectedAmount,
            autogenUserReferenceCheckBox.isChecked,
            userReferenceEditText.text.toString(),
            enableTtmSwitch.isChecked
          )
        }
      }
      // TODO: Enable TTM
//      enableTtmSwitch.setEnabled(true);
//      enableTtmSwitch.setOnClickListener {
//        val statusParameters = ChipDnaMobile.getInstance().getStatus(null)
//        // Check if PINpad has already been selected. If so we can enable the connectToPinPadButton.
//        val pinpadSelected = statusParameters.containsKey(ParameterKeys.PinPadName)
//        connectToPinpadBtn.isEnabled = pinpadSelected || enableTtmSwitch.isChecked
//      }
    }
  }

  private fun requestPasswordAndInitializeClient() {

    if (!::passwordAlertDialog.isInitialized) {
      passwordAlertDialog = AlertDialog.Builder(requireContext()).apply {
        setTitle(getString(R.string.chipdna_mobile_password))

        //Use a secure text field to allow the user to enter a password.
        val passwordInputEditTextView = EditText(requireContext())
        passwordInputEditTextView.inputType =
          InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
        setView(passwordInputEditTextView)

        // Add a callback for OK button.
        setPositiveButton(getString(R.string.ok)) { dialog, _ ->
          val passwordInputString = passwordInputEditTextView.text.toString()
          if (passwordInputString.isNotBlank()) {
            dialog.dismiss()
            viewModel.initializeClient(requireContext(), passwordInputString)
          } else {
            //Prompt for password again
            requestPasswordAndInitializeClient()
          }
        }

        // Add a callback for Cancel button.
        setNegativeButton(getString(R.string.cancel)) { _, _ ->
          viewModel.writeToLog("Initialization cancelled by user")
          //Prompt for password again
          requestPasswordAndInitializeClient()
        }

        setCancelable(false)
      }.create()
    }

    if (!passwordAlertDialog.isShowing) {
      passwordAlertDialog.show()
    }

  }

  private fun showAvailablePinPadList(items: List<Item>) {
    if (!::availablePinPadDialogFragment.isInitialized) {
      availablePinPadDialogFragment = ItemListBottomSheetFragment.Builder()
        .setData(items)
        .setTitle(getString(R.string.select_pin_pad))
        .setOnRefresh { viewModel.refreshPinPad(areBluetoothPermissionsGranted()) }
        .setOnClick { viewModel.onPinPadSelected(it as PinPad) }
        .build()
    }

    if (availablePinPadDialogFragment.isVisible) {
      availablePinPadDialogFragment.updateItem(items)
    } else {
      availablePinPadDialogFragment.show(childFragmentManager, null)
    }
  }

  private fun showTransactionCommandList(onClick: (TransactionCommand) -> Unit) {
    if (!::transactionCommandDialogFragment.isInitialized) {
      transactionCommandDialogFragment = ItemListBottomSheetFragment.Builder()
        .setData(TransactionCommand.values().map { Item(it.label, it.label, it) })
        .setTitle(getString(R.string.select_transaction_command))
        .setOnClick { onClick(it as TransactionCommand) }
        .build()
    }
    transactionCommandDialogFragment.show(childFragmentManager, null)
  }

  private fun showAmountItemList(onClick: (Amount) -> Unit) {
    if (!::amountDialogFragment.isInitialized) {
      amountDialogFragment = ItemListBottomSheetFragment.Builder()
        .setData(Amount.values().map { Item(it.label, it.label, it) })
        .setTitle(getString(R.string.select_amount))
        .setOnClick { onClick(it as Amount) }
        .build()
    }
    amountDialogFragment.show(childFragmentManager, null)
  }

  private fun showApplicationList(applications: List<Application>) {
    // Create an alert dialog to display the available applications to the card holder.
    AlertDialog.Builder(requireContext()).apply {

      setTitle(getString(R.string.application_selection))

      setNegativeButton("Terminate") { dialog, _ ->
        dialog.dismiss()
        viewModel.onRequestTerminated(getString(R.string.application_selection))
      }

      // Add the selectable available applications into a select dialog list.
      val applicationsList =
        ArrayAdapter<String>(requireContext(), android.R.layout.select_dialog_singlechoice)
      for (application in applications) {
        applicationsList.add(application.name)
      }

      setAdapter(applicationsList) { dialog, appPos ->
        dialog.dismiss()
        viewModel.onApplicationSelected(applicationsList.getItem(appPos))
      }

      setCancelable(false)
    }.show()
  }

  private fun showUserNotification(message: String) {
    // Notify the card holder with the user notification using an dialog alert or other means.
    val dialog = AlertDialog.Builder(requireContext()).apply {
      setTitle("User Notification")
      setMessage(message)
      setPositiveButton("OK") { dialog, _ -> dialog.dismiss() }
    }.create()
    dialog.show()
    Handler(Looper.getMainLooper()).postDelayed({ dialog.dismiss() }, 3000L)
  }

  private fun requestSignatureCheck(request: SignatureCheckRequest) {
    AlertDialog.Builder(requireContext()).apply {
      setTitle("Please check signature.")

      val input = EditText(requireContext())

      // If operator PIN is required, Add an extra text field to allow the user to enter the operator PIN.
      if (request.isOperatorPinRequired) {
        input.inputType =
          InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
        input.hint = "Operator PIN"
        setView(input)
      }

      setPositiveButton("Accept") { dialog, _ ->
        dialog.dismiss()
        viewModel.onSignatureCheckRequestAccepted(input.text.toString(), request)
      }

      setNegativeButton("Terminate") { dialog, _ ->
        dialog.dismiss()
        viewModel.onRequestTerminated("Signature Check")
      }

      setNeutralButton("Decline") { dialog, _ ->
        // The merchant wishes to decline the transaction.
        // No operator PIN is required when declining the transaction.
        dialog.dismiss()
        viewModel.onSignatureCheckRequestDeclined(request)
      }

      setCancelable(false)
    }.show()
  }

  private fun requestVoiceReferral(request: VoiceReferralRequest) {
    viewModel.writeToLog("Requesting voice referral")
    val alertDialogContentView =
      View.inflate(requireContext(), R.layout.layout_voice_referral_request, null)

    val requestInfoTextView =
      alertDialogContentView.findViewById<TextView>(R.id.requestInfoTextView)
    val operatorPinInputEditText =
      alertDialogContentView.findViewById<EditText>(R.id.operatorPinInputEditText)
    val authCodeInputEditText =
      alertDialogContentView.findViewById<EditText>(R.id.authCodeInputEditText)

    AlertDialog.Builder(requireContext()).apply {
      setTitle("Voice Referral")

      // If returned display phone number for the merchant to call.
      if (!request.referralPhoneNumber.isNullOrBlank()) {
        requestInfoTextView.text =
          getString(R.string.please_ring_your_bank_, request.referralPhoneNumber)
      } else {
        requestInfoTextView.text = getString(R.string.please_ring_your_bank)
      }

      // If required add an extra text field to allow the user to enter their operator PIN.
      operatorPinInputEditText.show(request.isOperatorPinRequired)

      setView(alertDialogContentView)

      setPositiveButton("Accept") { dialog, _ ->
        dialog.dismiss()
        viewModel.onVoiceReferralAccepted(
          operatorPinInputEditText.text.toString(),
          authCodeInputEditText.text.toString(),
          request
        )
      }

      setNegativeButton("Terminate") { dialog, _ ->
        dialog.dismiss()
        viewModel.onRequestTerminated("Voice Referral")
      }

      setNeutralButton("Decline") { dialog, _ ->
        // The bank has instructed the merchant to decline the transaction. No authorization code or operator PIN is necessary.
        dialog.dismiss()
        viewModel.onVoiceReferralDeclined()
      }

      setCancelable(false)
    }.show()
  }

  private fun requestBluetoothPermissions() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      val bluetoothPermissionArray = arrayOf(
        Manifest.permission.BLUETOOTH_SCAN,
        Manifest.permission.BLUETOOTH_CONNECT
      )

      bluetoothPermissionRequestLauncher.launch(bluetoothPermissionArray)
    }
  }

  private fun areBluetoothPermissionsGranted(): Boolean {
    return if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
      true
    } else checkSelfPermission(
      requireContext(),
      Manifest.permission.BLUETOOTH_CONNECT
    ) == PackageManager.PERMISSION_GRANTED
            && checkSelfPermission(
      requireContext(),
      Manifest.permission.BLUETOOTH_SCAN
    ) == PackageManager.PERMISSION_GRANTED
  }

  private fun isLocationPermissionGranted(): Boolean {
    return checkSelfPermission(
      requireContext(),
      Manifest.permission.ACCESS_FINE_LOCATION
    ) == PackageManager.PERMISSION_GRANTED
  }

  private fun requestLocationPermission() {
    locationPermissionRequestLauncher.launch(Manifest.permission.ACCESS_FINE_LOCATION)
  }

  // Audio permission check method - only required for Tap to Mobile transactions
  private fun isAudioPermissionGranted(): Boolean {
    return checkSelfPermission(
      requireContext(),
      Manifest.permission.RECORD_AUDIO
    ) == PackageManager.PERMISSION_GRANTED
  }

  // Audio permission request method - only required for Tap to Mobile transactions
  private fun requestAudioPermission() {
    audioPermissionRequestLauncher.launch(Manifest.permission.RECORD_AUDIO)
  }

  // Public method to check and request audio permission if needed - only required for Tap to Mobile transactions
  fun checkAndRequestAudioPermissionIfNeeded() {
    if (!isAudioPermissionGranted()) {
      viewModel.requestAudioPermission()
    }
  }

//endregion

}