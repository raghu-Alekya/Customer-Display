package com.creditcall.chipdnamobiledemo.viewmodel

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.creditcall.chipdnamobile.*
import com.creditcall.chipdnamobiledemo.dto.PinPad
import com.creditcall.chipdnamobiledemo.dto.SignatureCheckRequest
import com.creditcall.chipdnamobiledemo.dto.VoiceReferralRequest
import com.creditcall.chipdnamobiledemo.util.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch
import org.xmlpull.v1.XmlPullParserException
import timber.log.Timber
import java.io.IOException
import java.text.DateFormat
import java.text.SimpleDateFormat
import java.util.*

class TransactionViewModel : ViewModel(), IConnectAndConfigureFinishedListener,
  IConfigurationUpdateListener, IDeviceUpdateListener, ITransactionUpdateListener,
  ITransactionFinishedListener,
  IDeferredAuthorizationListener, ISignatureVerificationListener,
  IVoiceReferralListener,
  IPartialApprovalListener, IForceAcceptanceListener,
  IVerifyIdListener, IApplicationSelectionListener,
  IUserNotificationListener, IProcessReceiptFinishedListener, ITmsUpdateListener,
  ISignatureCaptureListener, IRequestActivityListener {

  private val MAX_LOCATION_PERMISSION_REQUEST_COUNT = 3
  private var locationPermissionRetryCount = 0

  var requestBluetoothPermissionsEvent: MutableSharedFlow<Boolean> = MutableSharedFlow()
    private set

  var requestLocationPermissionsEvent: MutableSharedFlow<Boolean> = MutableSharedFlow()
    private set

  // Audio permission event - only required for Tap to Mobile transactions
  var requestAudioPermissionsEvent: MutableSharedFlow<Boolean> = MutableSharedFlow()
    private set

  var progressLoaderState: MutableStateFlow<Boolean> = MutableStateFlow(false)
    private set

  var txnReferenceState: MutableStateFlow<String?> = MutableStateFlow(null)
    private set

  var requestPasswordEvent: MutableSharedFlow<Boolean> = MutableSharedFlow()
    private set

  var signatureCaptureEvent: MutableSharedFlow<Boolean> = MutableSharedFlow()
    private set

  var requestActivityEvent: MutableSharedFlow<Boolean> = MutableSharedFlow()
    private set

  var selectPinpadButtonState: MutableStateFlow<Boolean> = MutableStateFlow(false)
    private set

  var connectToPinpadButtonState: MutableStateFlow<Boolean> = MutableStateFlow(false)
    private set

  var addLogRecordEvent: MutableSharedFlow<String> = MutableSharedFlow()
    private set

  var showAvailablePinPadEvent: MutableSharedFlow<List<PinPad>> = MutableSharedFlow()
    private set

  var onTransactionReadyEvent: MutableSharedFlow<Boolean> = MutableSharedFlow()
    private set

  var onSignatureCheckRequestEvent: MutableSharedFlow<SignatureCheckRequest> = MutableSharedFlow()
    private set

  var onVoiceReferralRequestEvent: MutableSharedFlow<VoiceReferralRequest> = MutableSharedFlow()
    private set

  var onApplicationSelectionEvent: MutableSharedFlow<List<Application>> = MutableSharedFlow()
    private set

  var onUserNotificationEvent: MutableSharedFlow<String> = MutableSharedFlow()
    private set


  //region Listeners
  override fun onConnectAndConfigureFinished(parameters: Parameters) {
    if (parameters.isSuccess()) {
      // Configuration has completed successfully and we are ready to perform transactions.
      writeToLog("Ready for transactions")
      enableTransactionFields()
    } else {
      // Configuration of the PINpad has failed. Check error code.
      writeToLog("Failed to initialise PIN pad")
      writeToLog(parameters.getValue(ParameterKeys.Errors))
      enableConnectToPinPadButton()
      disableTransactionFields()
    }
    hideProgressLoader()
  }

  override fun onConfigurationUpdateListener(parameters: Parameters) {
    writeToLog(parameters.getValue(ParameterKeys.ConfigurationUpdate))
  }

  override fun onDeviceUpdate(parameters: Parameters) {
    val deviceStatusString = parameters.getValue(ParameterKeys.DeviceStatusUpdate)
    val deviceStatus = ChipDnaMobileSerializer.deserializeDeviceStatus(deviceStatusString)
    writeToLog(deviceStatusString)
    if (deviceStatus.status == DeviceStatus.DeviceStatusEnum.DeviceStatusDisconnected) {
      //PIN pad has disconnected, enable "Connect to PIN Pad" button
      enableConnectToPinPadButton()
      disableTransactionFields()
    }
  }

  override fun onTransactionUpdateListener(params: Parameters) {
    writeToLog(params.getValue(ParameterKeys.TransactionUpdate))
  }

  override fun onTransactionFinishedListener(params: Parameters) {
    writeToLog("onTransactionFinishedListener", params)
    hideProgressLoader()
  }

  override fun onDeferredAuthorizationListener(params: Parameters) {
    writeToLog("onDeferredAuthorization", params)
  }

  override fun onSignatureVerification(params: Parameters) {
    writeToLog("Signature Check Required")
    if (params.isResponseRequired()) {
      // Signature not handled on PINpad. Call to ChipDna Mobile required.
      val receiptDataXml: String = params.getValue(ParameterKeys.ReceiptData)
      val isSignatureRequestSupported =
        params.getValue(ParameterKeys.DigitalSignatureSupported)
          .equals(ParameterValues.TRUE)
      emitSignatureCheckRequest(
        SignatureCheckRequest(
          params.isOperatorPinRequired(),
          isSignatureRequestSupported,
          receiptDataXml,
          params
        )
      )
    }
  }

  override fun onVoiceReferral(params: Parameters) {
    writeToLog("Requesting voice referral")
    if (params.isResponseRequired()) {
      // Voice referral not handled on PINpad. Call to ChipDna Mobile required.
      val phoneNumber: String = params.getValue(ParameterKeys.ReferralNumber)
      emitVoiceReferralRequest(
        VoiceReferralRequest(
          params.isOperatorPinRequired(),
          phoneNumber,
          params
        )
      )
    }
  }

  override fun onPartialApproval(params: Parameters) {
    writeToLog("onPartialApproval", params)
  }

  override fun onForceAcceptance(params: Parameters) {
    writeToLog("onForceAcceptance", params)
  }

  override fun onVerifyId(params: Parameters) {
    writeToLog("onVerifyId", params)
  }

  override fun onApplicationSelection(params: Parameters) {
    writeToLog("onApplicationSelection", params)
    showProgressLoader()
    viewModelScope.launch(Dispatchers.IO) {
      try {
        // AvailableApplications parameter contains the applications available for selection, these will need to be deserialized.
        val availableApplications =
          ChipDnaMobileSerializer.deserializeAvailableApplications(
            params.getValue(
              ParameterKeys.AvailableApplications
            )
          )
        onApplicationSelectionEvent.emit(availableApplications)
      } catch (e: XmlPullParserException) {
        e.printStackTrace()
        writeToLog("onApplicationSelection ran into issue")
      } catch (e: IOException) {
        e.printStackTrace()
      }
      hideProgressLoader()
    }
  }

  override fun onUserNotification(params: Parameters) {
    writeToLog("onUserNotification", params)
    viewModelScope.launch {
      onUserNotificationEvent.emit(params.getValue(ParameterKeys.UserNotification))
    }
  }

  override fun onProcessReceiptFinishedListener(params: Parameters) {
    writeToLog("onProcessReceiptFinishedListener", params)
  }

  override fun onTmsUpdate(params: Parameters) {
    writeToLog("TMS Update", params)
  }

  override fun onSignatureCapture(parameter: Parameters) {
    viewModelScope.launch(Dispatchers.Main) {
      signatureCaptureEvent.emit(true)
    }
  }

  override fun onRequestActivity() {
    // TODO: Enable TTM
    // When a TTM transaction is started, onRequestActivity callback will be called by the SDK.
    // In order to proceed with the transaction, an active Activity instance needs to be provided to the SDK through continueRequestedActivity
    // In this demo app we start a new ChipDnaDemoTapCardActivity and call continueRequestedActivity API
    viewModelScope.launch(Dispatchers.Main) {
      requestActivityEvent.emit(true)
    }
  }
  //endregion

  fun initializeClient(context: Context, password: String) {
    viewModelScope.launch(Dispatchers.IO) {
      showProgressLoader()

      // send a request containing the entered password so it can be handled by ChipDnaMobile.
      val responseParam = ChipDnaMobile.initialize(
        context.applicationContext,
        Parameters().apply { add(ParameterKeys.Password, password) }
      )

      if (responseParam.isSuccess()) {
        // ChipDna Mobile has been successfully initialised.
        writeToLog("ChipDna Mobile initialised")
        writeToLog("Version: " + ChipDnaMobile.getSoftwareVersion() + ", Name: " + ChipDnaMobile.getSoftwareVersionName())

        //Register for ChipDna Mobile callbacks for interactivity
        registerListeners()

        // We can start setting our ChipDna Mobile credentials.
        setCredentials()

        //Request location permission for BLE
        //Location permissions are required for BLE to return scan results
        requestLocationPermissionsEvent.emit(true)

      } else {
        // The password is incorrect, ChipDnaMobile cannot initialise
        writeToLog("Failed to initialise ChipDna Mobile")
        if (responseParam.isPasswordAttemptReached()) {
          // If all password attempts have been used, the database is deleted and a new password is required.
          writeToLog("Reached password attempt limit")
        } else {
          writeToLog(
            "Password attempts remaining: " + responseParam.getValue(
              ParameterKeys.RemainingAttempts
            )
          )
        }
        requestPasswordEvent.emit(true)
      }
      hideProgressLoader()
    }
  }

  fun onSelectPinPadButtonClicked(areBluetoothPermissionsGranted: Boolean) {
    if (!areBluetoothPermissionsGranted) {
      viewModelScope.launch(Dispatchers.Main) {
        requestBluetoothPermissionsEvent.emit(true)
      }
    } else {
      viewModelScope.launch(Dispatchers.IO) {
        showProgressLoader()
        getInstance().apply {
          clearAllAvailablePinPadsListeners()
          addAvailablePinPadsListener { params ->
            viewModelScope.launch(Dispatchers.Unconfined) {
              val availablePinPadsXml =
                params.getValue(ParameterKeys.AvailablePinPads)

              if (availablePinPadsXml.isNullOrEmpty()) {
                //Confirm that:
                // - Device bluetooth is on OR USB connection is perfect
                // - PIN pad has been paired with the device OR connected appropriate to the device
                writeToLog("Unable to load available PIN pads")
                hideProgressLoader()
                return@launch
              }

              val availablePinPadsList: MutableList<PinPad> = mutableListOf()
              var prettyConnectionType: String
              try {
                val availablePinPadsHashMap =
                  ChipDnaMobileSerializer.deserializeAvailablePinPads(
                    availablePinPadsXml
                  )
                for (connectionType in availablePinPadsHashMap.keys) {
                  availablePinPadsHashMap[connectionType]?.let { pinpads ->
                    for (pinpad in pinpads) {
                      prettyConnectionType = if (connectionType.equals(
                          ParameterValues.BluetoothConnectionType,
                          ignoreCase = true
                        )
                      ) {
                        "[BT]"
                      } else if (connectionType.equals(
                          ParameterValues.BluetoothLeConnectionType,
                          ignoreCase = true
                        )
                      ) {
                        "[BLE]"
                      } else if (connectionType.equals(
                          ParameterValues.UsbConnectionType,
                          ignoreCase = true
                        )
                      ) {
                        "[USB]"
                      } else {
                        connectionType
                      }
                      availablePinPadsList.add(
                        PinPad(
                          pinpad,
                          prettyConnectionType
                        )
                      )
                    }
                  }
                }
              } catch (e: XmlPullParserException) {
                e.printStackTrace()
                hideProgressLoader()
              } catch (e: IOException) {
                e.printStackTrace()
                hideProgressLoader()
              }
              showAvailablePinPadEvent.emit(availablePinPadsList)
              hideProgressLoader()
            }
          }
        }.getAvailablePinPads(
          Parameters().apply {
            add(ParameterKeys.SearchConnectionTypeBluetooth, ParameterValues.TRUE)
            add(ParameterKeys.SearchConnectionTypeBluetoothLe, ParameterValues.TRUE)
            add(ParameterKeys.SearchConnectionTypeUsb, ParameterValues.TRUE)
          }
        )
      }
    }
  }

  fun refreshPinPad(areBluetoothPermissionsGranted: Boolean) {
    onSelectPinPadButtonClicked(areBluetoothPermissionsGranted)
  }

  fun onSubmitTransactionButtonClicked(
    txnCmd: TransactionCommand,
    amount: Amount?,
    shouldAutogenerateRef: Boolean = false,
    reference: String? = null,
    ttmEnabled: Boolean = false,
  ) {

    writeToLog("Starting: $txnCmd")

    if (reference.isNullOrEmpty()) {
      if ((txnCmd == TransactionCommand.Authorisation && !shouldAutogenerateRef) ||
        txnCmd == TransactionCommand.Confirm || txnCmd == TransactionCommand.Void || txnCmd == TransactionCommand.TransactionInfo
      ) {
        writeToLog("Enter transaction reference")
        return
      }
    }

    if ((txnCmd == TransactionCommand.Authorisation || txnCmd == TransactionCommand.Confirm) && amount == null) {
      writeToLog("Select transaction amount")
      return
    }

    viewModelScope.launch(Dispatchers.IO) {

      showProgressLoader()

      // Request Parameters are used as to communicate - with ChipDna Mobile - the parameters needed to complete a given command.
      // They are sent with the method call to ChipDna Mobile.
      val requestParameters = Parameters()

      when (txnCmd) {

        TransactionCommand.Authorisation -> {
          // The user reference is needed to be to able to access the transaction on WEBMis.
          // The reference should be unique to a transaction, so it is suggested that the reference is generated, similar to the example below.
          var ref = reference
          if (shouldAutogenerateRef) {
            ref = "CDM-${
              SimpleDateFormat(
                "yy-MM-dd-HH.mm.ss",
                Locale.getDefault()
              ).format(Date())
            }"
            txnReferenceState.value = ref
          }

          // The following parameters are essential for the completion of a transaction.
          // In the current example the parameters are initialised as constants. They will need to be dynamically collected and initialised.
          doAuthoriseTransaction(
            requestParameters.apply {
              add(ParameterKeys.Currency, CURRENCY)
              add(ParameterKeys.AmountType, ParameterValues.AmountTypeActual)
              add(ParameterKeys.Amount, amount?.value)
              add(ParameterKeys.UserReference, ref)
              add(ParameterKeys.TransactionType, ParameterValues.Sale)
              add(ParameterKeys.PaymentMethod, ParameterValues.Card)
              // TODO: Enable TTM
              // Add ParameterKeys.TransactionPOI parameter to specify which POI to be used in case both TapToMobile and PaymentDevice are being configured
              // If just one POI is configured, this is not needed
//              if (ttmEnabled) {
//                add(ParameterKeys.TransactionPOI, ParameterValues.TapToMobile)
//              }
            }
          )
        }

        TransactionCommand.Confirm -> {
          doConfirmTransaction(
            requestParameters.apply {
              // The following parameters are used to confirm an authorised transaction.
              // The user reference is used to reference the transaction stored on WEBMis.
              add(ParameterKeys.UserReference, reference)
              add(ParameterKeys.Amount, amount?.value)
              add(ParameterKeys.TipAmount, null)
              add(ParameterKeys.CloseTransaction, ParameterValues.TRUE)
            }
          )
        }

        TransactionCommand.Void -> {
          // The following parameters are used to void an authorised transaction.
          // The user reference is used to reference the transaction stored on WEBMis.
          requestParameters.add(ParameterKeys.UserReference, reference)
          doVoidTransaction(requestParameters)
        }

        TransactionCommand.TransactionInfo -> {
          // The following parameters are used to display information about a transaction.
          // The user reference is used to reference the transaction stored on WEBMis.
          requestParameters.add(ParameterKeys.UserReference, reference)
          doGetTransactionInformation(requestParameters)
        }

      }
    }
  }

  fun onPinPadSelected(pinpad: PinPad) {
    showProgressLoader()

    //Check if it's not the currently selected PIN pad
    val currentlySelectedPinPadName =
      getInstance().getStatus().getValue(ParameterKeys.PinPadName)
    if (!currentlySelectedPinPadName.isNullOrEmpty() and pinpad.name.equals(
        currentlySelectedPinPadName,
        true
      )
    ) {
      writeToLog("PIN pad [${pinpad.name}] already selected")
      enableConnectToPinPadButton()
      hideProgressLoader()
      return
    }

    writeToLog("PIN pad selected: ${pinpad.name}")

    val connectionType = if (pinpad.connectionType.equals("[BT]", ignoreCase = true)) {
      ParameterValues.BluetoothConnectionType
    } else if (pinpad.connectionType.equals("[BLE]", ignoreCase = true)) {
      ParameterValues.BluetoothLeConnectionType
    } else if (pinpad.connectionType.equals("[USB]", ignoreCase = true)) {
      ParameterValues.UsbConnectionType
    } else {
      pinpad.connectionType
    }
    getInstance().setProperties(Parameters().apply {
      if (pinpad.name.isNotEmpty()) {
        add(ParameterKeys.PinPadName, pinpad.name)
        add(ParameterKeys.PinPadConnectionType, connectionType)
      }
    })
    connectToPinpadButtonState.value = true
    hideProgressLoader()
  }

  fun onLocationPermissionResult(granted: Boolean) {
    //This permission is essential, so it has to be granted for BLE to work.
    //Hence, we keep on requesting except the Android System stops us or max retry count reach.
    if (!granted && locationPermissionRetryCount < MAX_LOCATION_PERMISSION_REQUEST_COUNT) {
      locationPermissionRetryCount++
      viewModelScope.launch(Dispatchers.Main) {
        requestLocationPermissionsEvent.emit(true)
      }
    }
  }

  // Audio permission result handler - only required for Tap to Mobile transactions
  fun onAudioPermissionResult(granted: Boolean) {
    if (granted) {
      writeToLog("Audio permission granted")
    } else {
      writeToLog("Audio permission denied")
    }
  }

  // Audio permission request trigger - only required for Tap to Mobile transactions
  fun requestAudioPermission() {
    viewModelScope.launch(Dispatchers.Main) {
      requestAudioPermissionsEvent.emit(true)
    }
  }

  fun processSignatureCaptureResult(
    terminateTransaction: Boolean,
    signatureData: String? = null
  ) {
    val parameters = Parameters()
    if (signatureData != null) {
      parameters.add(ParameterKeys.SignatureData, signatureData)
    } else {
      writeToLog("No signature data found")
    }

    viewModelScope.launch(Dispatchers.IO) {
      val paramResponse: Parameters = if (!terminateTransaction) {
        getInstance().continueSignatureCapture(parameters)
      } else {
        getInstance().terminateTransaction(null)
      }

      if (terminateTransaction) {
        writeToLog("ChipDnaMobile.terminateTransaction (response)", paramResponse)
      } else if (paramResponse.getValue(ParameterKeys.Errors) != null &&
        paramResponse.getValue(ParameterKeys.Errors) == ConfigurationErrorCode.PinPadNotConnected.errorString
      ) {
        writeToLog("ChipDnaMobile.terminateTransaction (response) ", paramResponse)
      } else {
        writeToLog("continueSignatureCapture response=> ", paramResponse)
        if (ParameterValues.FALSE == paramResponse.getValue(ParameterKeys.Result)) {
          signatureCaptureEvent.emit(true)
        }
      }
    }
  }

  fun onConnectToPinpadButtonClicked(ttmEnabled: Boolean) {
    showProgressLoader()
    disableConnectToPinPadButton()
    writeToLog("About to connect to PIN pad")
    val params = getInstance().getStatus()
    // TODO: Enable TTM
    // Add ParameterKeys.TapToMobilePOI and ParameterKeys.PaymentDevicePOI parameters to configure both TapToPay and PinPad
    // If no parameter passed, will default to PinPad configuration
//    val pinpadSelected = params.containsKey(ParameterKeys.PinPadName)
//    if (pinpadSelected) {
//      params.add(ParameterKeys.PaymentDevicePOI, ParameterValues.TRUE)
//    } else {
//      params.add(ParameterKeys.PaymentDevicePOI, ParameterValues.FALSE)
//    }
//    if (ttmEnabled) {
//      params.add(ParameterKeys.TapToMobilePOI, ParameterValues.TRUE)
//    }

    // Use an instance of ChipDnaMobile to begin connectAndConfigure of the device.
    // PIN pad checks are completed within connectAndConfigure, deciding whether a TMS update will need to be completed.
    val response = getInstance().connectAndConfigure(params)
    if (!response.isSuccess()) {
      writeToLog("Error: " + response.getValue(ParameterKeys.Errors))
      enableConnectToPinPadButton()
      disableTransactionFields()
    }
  }

  fun onSignatureCheckRequestAccepted(operatorPin: String, request: SignatureCheckRequest) {
    //Check if operator PIN is required
    if (request.isOperatorPinRequired) {
      // Confirm that we have an operator PIN
      if (operatorPin.isBlank()) {
        // No operator PIN found. Send signature check request again.
        writeToLog("Operator PIN required but not entered")
        emitSignatureCheckRequest(request)
        return
      }
    }

    val response = getInstance().continueSignatureVerification(
      Parameters().apply {
        add(ParameterKeys.Result, ParameterValues.TRUE)
        add(ParameterKeys.OperatorPin, operatorPin)
      }
    )

    if (!response.isSuccess()) {
      emitSignatureCheckRequest(request)
    }
  }

  fun onSignatureCheckRequestDeclined(request: SignatureCheckRequest) {
    writeToLog("Signature Check Declined")
    val response = getInstance().continueSignatureVerification(Parameters().apply {
      add(ParameterKeys.Result, ParameterValues.FALSE)
    })
    if (!response.isSuccess()) {
      emitSignatureCheckRequest(request)
    }
  }

  fun onVoiceReferralAccepted(
    operatorPin: String?,
    authCode: String,
    request: VoiceReferralRequest
  ) {

    // The bank has given the authorization code and the merchant can proceed with the transaction.
    if (request.isOperatorPinRequired) {
      // If required, check if we have been given an operator PIN.
      if (operatorPin.isNullOrBlank()) {
        writeToLog("Operator PIN required but not entered")
        // No operator PIN, re-request voice referral.
        emitVoiceReferralRequest(request)
        return
      }
    }

    // Check if we have an authorization code.
    if (authCode.isBlank()) {
      writeToLog("Authorization code required and not entered")
      // No operator PIN, re-request voice referral.
      emitVoiceReferralRequest(request)
      return
    }

    showProgressLoader()

    val response = getInstance().continueVoiceReferral(Parameters().apply {
      add(ParameterKeys.Result, ParameterValues.TRUE)
      add(ParameterKeys.AuthCode, authCode)
      add(ParameterKeys.OperatorPin, operatorPin)
    })

    if (!response.isSuccess()) {
      // Unsuccessful call to ChipDNA Mobile, re-request voice referral.
      emitVoiceReferralRequest(request)
    }

    hideProgressLoader()
  }

  fun onVoiceReferralDeclined() {
    writeToLog("Voice Referral Declined")
    showProgressLoader()
    val response = getInstance().continueVoiceReferral(Parameters().apply {
      add(ParameterKeys.Result, ParameterValues.FALSE)
    })
    if (!response.isSuccess()) {
      writeToLog("Error: " + response.getValue(ParameterKeys.Errors))
    }
    hideProgressLoader()
  }

  fun onApplicationSelected(applicationName: String?) {

    showProgressLoader()

    // Initialise the application selection parameters.
    val applicationSelectionParameters = Parameters().apply {
      add(ParameterKeys.Result, ParameterValues.TRUE)

      // Add the application name selected from the list by the card holder to the application selection parameters.
      add(ParameterKeys.SelectedApplication, applicationName)
    }

    writeToLog("continueApplicationSelection =>", applicationSelectionParameters)

    // Call continueApplicationSelection passing the result and application name as parameters.
    val response = getInstance().continueApplicationSelection(applicationSelectionParameters)

    writeToLog("continueApplicationSelection response=>", response)
  }

  fun onRequestTerminated(requestTag: String) {
    writeToLog("$requestTag request terminated")
    val response = getInstance().terminateTransaction(Parameters())
    if (!response.isSuccess()) {
      writeToLog("Error: " + response.getValue(ParameterKeys.Errors))
    }
    writeToLog("$requestTag terminated")
  }

  private fun registerListeners() {
    getInstance().apply {
      addConnectAndConfigureFinishedListener(this@TransactionViewModel)
      addConfigurationUpdateListener(this@TransactionViewModel)
      addDeviceUpdateListener(this@TransactionViewModel)
      addTransactionUpdateListener(this@TransactionViewModel)
      addTransactionFinishedListener(this@TransactionViewModel)
      addDeferredAuthorizationListener(this@TransactionViewModel)
      addSignatureVerificationListener(this@TransactionViewModel)
      addVoiceReferralListener(this@TransactionViewModel)
      addPartialApprovalListener(this@TransactionViewModel)
      addForceAcceptanceListener(this@TransactionViewModel)
      addVerifyIdListener(this@TransactionViewModel)
      addApplicationSelectionListener(this@TransactionViewModel)
      addUserNotificationListener(this@TransactionViewModel)
      addTmsUpdateListener(this@TransactionViewModel)
      addProcessReceiptFinishedListener(this@TransactionViewModel)
      addSignatureCaptureListener(this@TransactionViewModel)
      // TODO: Enable TTM
      // Add RequestActivityListener. It is needed when performing TTM transactions
      // addRequestActivityListener(this@TransactionViewModel)
    }
  }

  private fun setCredentials() {
    viewModelScope.launch(Dispatchers.IO) {
      // Credentials are set in ChipDnaMobile Status object. It's recommended that you fetch fresh ChipDnaMobile Status object each time you wish to make changes.
      // This ensures the set of properties used is always up to date with the version of properties in ChipDnaMobile
      val statusParams = getInstance().getStatus()

      // Entering this method means we have successfully initialised ChipDna Mobile and start setting our ChipDna Mobile credentials.
      writeToLog("Setting credential using API Key: $API_KEY, Environment: $ENVIRONMENT")

      // Credentials are returned to ChipDnaMobile as a set of Parameters
      val requestParams = Parameters().apply {
        /// The credentials consist of an APIKEY from your gateway account. This can be created by
        // navigating to the Gateway Options => Security Keys section.
        add(ParameterKeys.ApiKey, API_KEY)
        // Set ChipDna Mobile to test mode. This means ChipDna Mobile is running in it's test environment, can configure test devices and perform test transaction.
        // Use test mode while developing your application.
        add(ParameterKeys.Environment, ENVIRONMENT)

        // Set the Application Identifier value. This is used by the TMS platform to configure TMS properties specifically for an integrating application.
        add(ParameterKeys.ApplicationIdentifier, APP_ID.uppercase(Locale.getDefault()))

        // TODO: Enable TTM
        // Set the Certificate fingerprint value. This is used by the TTM to initialize TTM transactions.
//        add(ParameterKeys.CertificateFingerprint, "Your SHA-256 fingerprint from the keystore")
      }

      // Once all changes have been made a call to .setProperties() is required in order for the changes to take effect.
      // Parameters are passed within this method and added to the ChipDna Mobile status object.
      getInstance().setProperties(requestParams)

      writeToLog("Credential set")

      selectPinpadButtonState.value = true
    }
  }

  private fun doAuthoriseTransaction(authorisationParams: Parameters) {
    writeToLog("Starting Transaction for amount: ${authorisationParams.getValue(ParameterKeys.Amount)}")

    // Use an instance of ChipDnaMobile to begin startTransaction.
    val response = getInstance().startTransaction(authorisationParams)
    if (!response.isSuccess()) {
      writeToLog("Error: " + response.getValue(ParameterKeys.Errors))
    }
  }

  private fun doConfirmTransaction(confirmParams: Parameters) {
    writeToLog("Confirm Transaction: ${confirmParams.getValue(ParameterKeys.Amount)}")
    val response = getInstance().confirmTransaction(confirmParams)
    writeToLog("Confirm Transaction Response", response)
    if (!response.isSuccess()) {
      hideProgressLoader()
    }
  }

  private fun doVoidTransaction(voidParams: Parameters) {
    writeToLog("Void Transaction: ${voidParams.getValue(ParameterKeys.UserReference)}")
    val response = getInstance().voidTransaction(voidParams)
    writeToLog("Transaction Void Response", response)
    if (!response.isSuccess()) {
      hideProgressLoader()
    }
  }

  private fun doGetTransactionInformation(transactionInfoParameters: Parameters) {
    writeToLog("Get Transaction Info: ${transactionInfoParameters.getValue(ParameterKeys.UserReference)}")
    val response = getInstance().getTransactionInformation(transactionInfoParameters)
    writeToLog("Transaction Information Response", response)
    if (!response.isSuccess()) {
      hideProgressLoader()
    }
  }

  private fun hideProgressLoader() {
    progressLoaderState.value = false
  }

  private fun showProgressLoader() {
    progressLoaderState.value = true
  }

  private fun disableConnectToPinPadButton() {
    connectToPinpadButtonState.value = false
  }

  private fun enableConnectToPinPadButton() {
    connectToPinpadButtonState.value = true
  }

  private fun disableTransactionFields() {
    viewModelScope.launch {
      onTransactionReadyEvent.emit(false)
    }
  }

  private fun enableTransactionFields() {
    viewModelScope.launch {
      onTransactionReadyEvent.emit(true)
    }
  }

  private fun emitSignatureCheckRequest(request: SignatureCheckRequest) {
    viewModelScope.launch {
      onSignatureCheckRequestEvent.emit(request)
    }
  }

  private fun emitVoiceReferralRequest(request: VoiceReferralRequest) {
    viewModelScope.launch {
      onVoiceReferralRequestEvent.emit(request)
    }
  }

  //region Log Printer
  private val logs = ArrayList<String>()
  private val MAX_LOG = 100
  private val df: DateFormat = SimpleDateFormat("MM/dd/yyyy HH:mm:ss", Locale.getDefault())

  fun writeToLog(record: String?) {
    record?.let {
      synchronized(this) {
        viewModelScope.launch(Dispatchers.Unconfined) {
          if (logs.size == MAX_LOG) {
            logs.removeAt(0)
          }
          logs.add(String.format("%s: %s\n", df.format(Date()), it))
          Timber.d(it)
          val sb = StringBuilder("")
          for (log in logs) {
            sb.append(String.format("%s", log))
          }
          addLogRecordEvent.emit(sb.toString())
        }
      }
    }
  }

  private fun writeToLog(record: String?, params: Parameters?) {
    params?.let {
      val sb = StringBuilder()
      sb.append(record)
      for (parameter in params.toList()) {
        sb.append(String.format("\t[%s]\n", parameter))
      }
      writeToLog(sb.toString())
    }
  }
//endregion

}