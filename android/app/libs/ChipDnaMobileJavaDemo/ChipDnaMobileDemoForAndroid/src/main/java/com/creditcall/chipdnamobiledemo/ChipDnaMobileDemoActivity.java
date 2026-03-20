package com.creditcall.chipdnamobiledemo;

import android.Manifest;

import android.annotation.SuppressLint;
import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.os.AsyncTask;
import android.os.Build;
import android.os.Handler;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.appcompat.widget.SwitchCompat;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import android.os.Bundle;
import android.os.Looper;
import android.text.InputType;
import android.text.method.ScrollingMovementMethod;
import android.util.Log;
import android.view.View;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import com.creditcall.chipdnamobile.Application;
import com.creditcall.chipdnamobile.ChipDnaMobile;
import com.creditcall.chipdnamobile.ChipDnaMobileException;
import com.creditcall.chipdnamobile.ChipDnaMobileSerializer;
import com.creditcall.chipdnamobile.ChipDnaMobileUtils;
import com.creditcall.chipdnamobile.ConfigurationErrorCode;
import com.creditcall.chipdnamobile.IApplicationSelectionListener;
import com.creditcall.chipdnamobile.ICardDetailsListener;
import com.creditcall.chipdnamobile.IConfigurationUpdateListener;
import com.creditcall.chipdnamobile.IConnectAndConfigureFinishedListener;
import com.creditcall.chipdnamobile.IDeferredAuthorizationListener;
import com.creditcall.chipdnamobile.IDeviceUpdateListener;
import com.creditcall.chipdnamobile.IForceAcceptanceListener;
import com.creditcall.chipdnamobile.IPartialApprovalListener;
import com.creditcall.chipdnamobile.IProcessReceiptFinishedListener;
import com.creditcall.chipdnamobile.IRequestActivityListener;
import com.creditcall.chipdnamobile.ISignatureCaptureListener;
import com.creditcall.chipdnamobile.ISignatureVerificationListener;
import com.creditcall.chipdnamobile.ITmsUpdateListener;
import com.creditcall.chipdnamobile.ITransactionFinishedListener;
import com.creditcall.chipdnamobile.ITransactionUpdateListener;
import com.creditcall.chipdnamobile.IUserNotificationListener;
import com.creditcall.chipdnamobile.IVerifyIdListener;
import com.creditcall.chipdnamobile.IVoiceReferralListener;
import com.creditcall.chipdnamobile.Parameter;
import com.creditcall.chipdnamobile.ParameterKeys;
import com.creditcall.chipdnamobile.ParameterValues;
import com.creditcall.chipdnamobile.Parameters;

import org.xmlpull.v1.XmlPullParserException;

import java.io.IOException;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.concurrent.Executor;
import java.util.concurrent.Executors;

public class ChipDnaMobileDemoActivity extends AppCompatActivity implements
        ActivityCompat.OnRequestPermissionsResultCallback {

    enum Command {
        SelectPinPad, ConnectPinPad, SubmitTransactionCommand
    }

    enum TransactionCommand {
        Authorisation, Confirm, Void, TransactionInfo
    }

    //Replace the APP_ID with your APPLICATION ID
    private static final String APP_ID = "CEMDEMO";

    // Replace the APIKEY with your Gateway API KEY as found in the
    // Gateway Control Panel's options/ security keys page
    private static final String APIKEY = "2F822Rw39fx762MaV7Yy86jXGTC7sCDy";


    private static final String CURRENCY = "USD";

    // Note: for the Miura 810 device, a test device will only work in testEnviornment
    // and a production device will only work in LiveEnvironment
    // Using the device in the wrong environment results in an  IncompatibleOSWithAppMode during
    // device configuration,
    private static final String ENVIRONMENT = ParameterValues.TestEnvironment;


    public static final String LOGGER_STR = "ChipDnaMobileDemo";
    private Button selectPinPadButton;
    private Button connectToPinPadButton;
    private SwitchCompat ttmSwitch;

    private final String[] AMOUNTS = {"1000", "500", "110000", "4723"};
    private DateFormat df = new SimpleDateFormat("MM/dd/yyyy HH:mm:ss");
    private String currentlySelectedAmount = AMOUNTS[0];
    private CheckBox autoGenUserRefCheckbox;
    private EditText userRefText;

    private final TransactionCommand[] TRANSACTIONCOMMANDOPTIONS = {TransactionCommand.Authorisation, TransactionCommand.Confirm, //
            TransactionCommand.Void, TransactionCommand.TransactionInfo};
    private TransactionCommand currentTransactionCommandOption = TRANSACTIONCOMMANDOPTIONS[0];
    private Button submitTransactionCommand;

    private TextView loggerTextView;

    private Context context;
    private AlertDialog passwordAlertDialog = null;
    private AlertDialog applicationSelectionAlertDialog = null;
    private AlertDialog userNotificationAlertDialog = null;

    private final Executor executor = Executors.newSingleThreadExecutor();
    private final Handler handler = new Handler(Looper.getMainLooper());

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_chipdna_mobile_demo);
        this.setupGui();
    }

    @Override
    protected void onResume() {
        super.onResume();

        context = this;

        // Initialise ChipDna Mobile before starting to interacting with the API. You can check if ChipDna Mobile has been initialised by using isInitialised()
        // It's possible that android may have cleaned up resources while the application has been in the background and needs to be re-initialised.
        if (!ChipDnaMobile.isInitialized()) {
            initChipDnaMobile();
        }

        // Location permissions are required for BLE to return scan results
        if (!isLocationPermissionGranted()) {
            requestLocationPermissions();
        }
    }

    private void setupGui() {
        // Set up the user interface and attach listeners to buttons. The buttons initial state (Enabled/Disabled) is set in the Activities layout file.
        selectPinPadButton = (Button) findViewById(R.id.select_pinpad);
        connectToPinPadButton = (Button) findViewById(R.id.connect_to_pinpad);
        ttmSwitch = (SwitchCompat) findViewById(R.id.enable_ttm);

        userRefText = (EditText) findViewById(R.id.user_reference);
        autoGenUserRefCheckbox = (CheckBox) findViewById(R.id.autogen_user_ref_checkbox);
        submitTransactionCommand = (Button) findViewById(R.id.submit_transaction_command);

        loggerTextView = (TextView) findViewById(R.id.logger_view);
        loggerTextView.setMovementMethod(new ScrollingMovementMethod());

        selectPinPadButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                selectPinPadButtonPushed();
            }
        });

        connectToPinPadButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                connectButtonPushed();
            }
        });

        submitTransactionCommand.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                submitTransactionCommandButtonPushed();
            }
        });

        // TODO: Enable TTM
//        ttmSwitch.setEnabled(true);
//        ttmSwitch.setOnClickListener(new View.OnClickListener() {
//            @Override
//            public void onClick(View v) {
//                final Parameters statusParameters = ChipDnaMobile.getInstance().getStatus(null);
//                runOnUiThread(new Runnable() {
//                    @Override
//                    public void run() {
//                        // Check if PINpad has already been selected. If so we can enable the connectToPinPadButton.
//                        boolean pinpadSelected = statusParameters.containsKey(ParameterKeys.PinPadName);
//                        connectToPinPadButton.setEnabled(pinpadSelected || ttmSwitch.isChecked());
//                    }
//                });
//            }
//        });

        // Set up the spinner view, the amounts defined in the stings.xml file.
        Spinner amountsDropdown = (Spinner) findViewById(R.id.amount_dropdown);
        ArrayAdapter<CharSequence> spinnerAdapter = ArrayAdapter.createFromResource(this, R.array.amount_values, android.R.layout.simple_spinner_item);
        spinnerAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        amountsDropdown.setAdapter(spinnerAdapter);
        amountsDropdown.setOnItemSelectedListener(amountItemSelectedListener);

        // Set up the spinner view, the buttons are defined in the stings.xml file.
        Spinner twoStageDropdown = (Spinner) findViewById(R.id.transaction_command_dropdown);
        ArrayAdapter<CharSequence> transactionCommandSpinnerAdapter = ArrayAdapter.createFromResource(this, R.array.transaction_command_values, android.R.layout.simple_spinner_item);
        transactionCommandSpinnerAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        twoStageDropdown.setAdapter(transactionCommandSpinnerAdapter);
        twoStageDropdown.setOnItemSelectedListener(transactionCommandSelectedListener);
    }

    private synchronized void initChipDnaMobile() {
        if (!ChipDnaMobile.isInitialized()) {

            if (passwordAlertDialog == null || !passwordAlertDialog.isShowing()) {
                requestPassword();
            } else {
                log("Password dialog already showing.");
            }
        }
    }

    private boolean isLocationPermissionGranted() {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED;
    }

    private void requestLocationPermissions() {
        ActivityCompat.requestPermissions(this, new String[]{Manifest.permission.ACCESS_FINE_LOCATION}, 2);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        // Check which activity is returning a result. We are only bothered about the SelectPinPadActivity.
        if (requestCode == SelectPinPadActivity.ACTIVITY_REQUEST_CODE) {
            switch (resultCode) {
                // Result ok, begin the process of connecting to the PINpad so enable the connectToPinPadButton.
                case SelectPinPadActivity.RESULT_OK:
                case SelectPinPadActivity.UPDATE: {
                    log("Selected PIN Pad: " + ChipDnaMobile.getInstance().getStatus(null).getValue(ParameterKeys.PinPadName));
                    runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            connectToPinPadButton.setEnabled(true);
                        }
                    });
                    break;
                }
                case SelectPinPadActivity.RESULT_FAILED: {
                    // Failed to select a PINpad. Exception is logged from SelectPinPadActivity.
                    log("PINpad selection failed");
                    break;
                }
            }
        } else if (requestCode == DigitalSignatureVerificationActivity.DIGITAL_SIGNATURE_VERIFICATION_ACTIVITY_CODE) {
            continueDigitalSignatureVerification(resultCode, data);
        } else if (requestCode == DigitalSignatureCaptureActivity.DIGITAL_SIGNATURE_CAPTURE_ACTIVITY_CODE) {

            final boolean terminateTransaction = resultCode != DigitalSignatureCaptureActivity.SIGNATURE_CAPTURE_REQUEST_ACCEPTED;
            String signatureData = null;
            if (data.getStringExtra(DigitalSignatureVerificationActivity.SIGNATURE_DATA) != null) {
                signatureData = data.getStringExtra(DigitalSignatureVerificationActivity.SIGNATURE_DATA);
            }
            final Parameters parameters = new Parameters();
            if (signatureData != null) {
                parameters.add(ParameterKeys.SignatureData, signatureData);
            } else {
                log("No signature data found");
            }

            if (terminateTransaction) {
                log("ChipDnaMobile.terminateTransaction (SIGNATURE_CAPTURE_REQUEST_TERMINATED)");
            } else {
                log("continueSignatureVerification =>", parameters);
            }

            executor.execute(() ->{
                Parameters paramResponse;
                if (!terminateTransaction) {
                    paramResponse = ChipDnaMobile.getInstance().continueSignatureCapture(parameters);
                } else {
                    paramResponse =  ChipDnaMobile.getInstance().terminateTransaction(null);
                }
                handler.post(() ->{
                    if (terminateTransaction) {
                        log("ChipDnaMobile.terminateTransaction (response)", paramResponse);
                    } else if ((paramResponse.getValue(ParameterKeys.Errors) != null &&
                            paramResponse.getValue(ParameterKeys.Errors).equals(ConfigurationErrorCode.PinPadNotConnected.getErrorString()))) {
                        log("ChipDnaMobile.terminateTransaction (response)", paramResponse);
                    } else {
                        log("continueSignatureCapture response=>", paramResponse);
                        if (ParameterValues.FALSE.equals(paramResponse.getValue(ParameterKeys.Result))) {
                            requestSignatureCapture();
                        }
                    }
                });
            });
        } else if (requestCode == ChipDnaDemoTapCardActivity.TRANSACTION_FINISHED_ACTIVITY_CODE && resultCode == RESULT_OK) {
            String parametersString = data.getStringExtra(ChipDnaDemoTapCardActivity.TRANSACTION_FINISHED_PARAMETERS_STRING);
            if (parametersString != null && !parametersString.isEmpty()) {
                log(parametersString);
            }
        } else {
            super.onActivityResult(requestCode, resultCode, data);
        }
    }

    private void continueDigitalSignatureVerification(int digitalSignatureActivityResultCode, Intent digitalSignatureIntent) {
        final Parameters signatureParameters = new Parameters();

        boolean paramOperatorPinRequired = true;
        String paramReceiptDataXml = null;
        boolean terminate = false;

        if (digitalSignatureIntent != null) {
            paramOperatorPinRequired = digitalSignatureIntent.getBooleanExtra(DigitalSignatureVerificationActivity.SIGNATURE_OPERATOR_PIN_REQUIRED, true);
            paramReceiptDataXml = digitalSignatureIntent.getStringExtra(DigitalSignatureVerificationActivity.SIGNATURE_RECEIPT_DATA);
        }

        switch (digitalSignatureActivityResultCode) {
            case DigitalSignatureVerificationActivity.SIGNATURE_VERIFICATION_REQUEST_APPROVED:
                final String operatorPin = digitalSignatureIntent.getStringExtra(DigitalSignatureVerificationActivity.SIGNATURE_OPERATOR_PIN);
                signatureParameters.add(ParameterKeys.Result, ParameterValues.TRUE);
                if (operatorPin != null) {
                    signatureParameters.add(ParameterKeys.OperatorPin, operatorPin);
                }
                break;
            case DigitalSignatureVerificationActivity.SIGNATURE_VERIFICATION_REQUEST_DECLINED:
                signatureParameters.add(ParameterKeys.Result, ParameterValues.FALSE);
                break;
            case DigitalSignatureVerificationActivity.SIGNATURE_VERIFICATION_REQUEST_TERMINATED:
                terminate = true;
                break;
        }

        final boolean terminateTransaction = terminate;
        final boolean operatorPinRequired = paramOperatorPinRequired;
        final String receiptDataXml = paramReceiptDataXml;
        if (terminateTransaction) {
            log("ChipDnaMobile.terminateTransaction (SIGNATURE_VERIFICATION_REQUEST_TERMINATED)");
        } else {
            log("continueSignatureVerification =>", signatureParameters);
        }
        executor.execute(() -> {
            Parameters paramResponse;
            if (terminateTransaction) {
                paramResponse = ChipDnaMobile.getInstance().terminateTransaction(null);
            } else {
                paramResponse = ChipDnaMobile.getInstance().continueSignatureVerification(signatureParameters);
            }
            handler.post(() -> {
                if (terminateTransaction) {
                    log("ChipDnaMobile.terminateTransaction (response)", paramResponse);
                } else {
                    log("continueSignatureVerification response=>", paramResponse);
                    if (!paramResponse.containsKey(ParameterKeys.Result) || paramResponse.getValue(ParameterKeys.Result).equals(ParameterValues.FALSE)) {
                        if ((paramResponse.getValue(ParameterKeys.Errors) != null &&
                                !paramResponse.getValue(ParameterKeys.Errors).equals(ConfigurationErrorCode.PinPadNotConnected.getErrorString()))) {
                            requestSignatureReview(operatorPinRequired,
                                    true,
                                    digitalSignatureIntent.getParcelableExtra(DigitalSignatureVerificationActivity.SIGNATURE_DATA),
                                    receiptDataXml);
                        }
                    }
                }
            });
        });
    }

    private void requestPassword() {
        log("Requesting password");
        runOnUiThread(new Runnable() {
            @Override
            public void run() {

                if (passwordAlertDialog == null) {
                    AlertDialog.Builder builder = new AlertDialog.Builder(ChipDnaMobileDemoActivity.this.context);
                    builder.setTitle("ChipDNA Mobile Password");

                    // User a secure text field to allow the user to enter a password.
                    final EditText input = new EditText(ChipDnaMobileDemoActivity.this.context);
                    input.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_PASSWORD);
                    builder.setView(input);

                    // Add a callback for our OK button.
                    builder.setPositiveButton("OK", new DialogInterface.OnClickListener() {
                        @Override
                        public void onClick(DialogInterface dialog, int which) {
                            String inputStr = input.getText().toString();

                            if (inputStr.length() > 0) {

                                new AsyncTask<String, Void, Parameters>() {
                                    @Override
                                    protected Parameters doInBackground(String... params) {
                                        // send a request containing the entered password so it can be handled by ChipDnaMobile.
                                        Parameters requestParameters = new Parameters();
                                        requestParameters.add(ParameterKeys.Password, params[0]);
                                        Parameters response = ChipDnaMobile.initialize(getApplicationContext(), requestParameters);
                                        return response;
                                    }

                                    @Override
                                    protected void onPostExecute(Parameters response) {
                                        if (response.containsKey(ParameterKeys.Result) && response.getValue(ParameterKeys.Result).equalsIgnoreCase("True")) {
                                            // ChipDna Mobile has been successfully initialised.
                                            log("ChipDna Mobile initialised");
                                            log("Version: "+ChipDnaMobile.getSoftwareVersion()+", Name: " +ChipDnaMobile.getSoftwareVersionName());
                                            // We can start setting our ChipDna Mobile credentials.
                                            registerListeners();
                                            setCredentials();
                                        } else {
                                            // The password is incorrect, ChipDnaMobile cannot initialise
                                            log("Failed to initialise ChipDna Mobile");
                                            if(response.getValue(ParameterKeys.RemainingAttempts).equalsIgnoreCase("0")) {
                                                // If all password attempts have been used, the database is deleted and a new password is required.
                                                log("Reached password attempt limit");
                                            } else {
                                                log("Password attempts remaining: " + response.getValue(ParameterKeys.RemainingAttempts));
                                            }
                                            requestPassword();
                                        }
                                    }
                                }.execute(input.getText().toString());

                            }
                        }
                    });

                    // Add a callback for our Cancel button.
                    builder.setNegativeButton("Cancel", new DialogInterface.OnClickListener() {
                        @Override
                        public void onClick(DialogInterface dialog, int which) {
                            log("Initialization cancelled by user");
                        }
                    });


                    builder.setCancelable(false);

                    passwordAlertDialog = builder.create();
                }
                passwordAlertDialog.show();
            }
        });
    }

    private void setCredentials() {
        // Credentials are set in ChipDnaMobile Status object. It's recommended that you fetch fresh ChipDnaMobile Status object each time you wish to make changes.
        // This ensures the set of properties used is always up to date with the version of properties in ChipDnaMobile
        final Parameters statusParameters = ChipDnaMobile.getInstance().getStatus(null);

        // Entering this method means we have successfully initialised ChipDna Mobile and start setting our ChipDna Mobile credentials.


        // Credentials are returned to ChipDnaMobile as a set of Parameters
        Parameters requestParameters = new Parameters();

        // The credentials consist of an APIKEY from your gateway account. This can be created by
        // navigating to the Gateway Options => Security Keys section.
        requestParameters.add(ParameterKeys.ApiKey,APIKEY);

        // Set ChipDna Mobile to test mode. This means ChipDna Mobile is running in it's test environment, can configure test devices and perform test transaction.
        // Use test mode while developing your application.
        requestParameters.add(ParameterKeys.Environment, ENVIRONMENT);


        // Set the Application Identifier value. This is used by the TMS platform to configure TMS properties specifically for an integrating application.
        requestParameters.add(ParameterKeys.ApplicationIdentifier, APP_ID.toUpperCase());

        // TODO: Enable TTM
        // Set the Certificate fingerprint value. This is used by the TTM to initialize TTM transactions.
        // requestParameters.add(ParameterKeys.CertificateFingerprint, "Your SHA-256 fingerprint from the keystore");

        // Once all changes have been made a call to .setProperties() is required in order for the changes to take effect.
        // Parameters are passed within this method and added to the ChipDna Mobile status object.
        ChipDnaMobile.getInstance().setProperties(requestParameters);

        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                selectPinPadButton.setEnabled(true);
                // Check if PINpad has already been selected. If so we can enable the connectToPinPadButton.
                if(statusParameters.containsKey(ParameterKeys.PinPadName)){
                    connectToPinPadButton.setEnabled(true);
                }
            }
        });
    }

    private void requestBluetoothPermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {

            final String[] android12BluetoothPermissions = new String[] {
                    Manifest.permission.BLUETOOTH_SCAN,
                    Manifest.permission.BLUETOOTH_CONNECT,
            };

            if (checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN) != PackageManager.PERMISSION_GRANTED
                    &&  checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(this, android12BluetoothPermissions, 2);
            }
        }
    }

    @SuppressLint("NewApi")
    private boolean isBluetoothPermissionGranted()  {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return true;
        }
        return checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
                && checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED;
    }

    // Audio permission check method - only required for Tap to Mobile transactions
    private boolean isAudioPermissionGranted() {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED;
    }

    // Audio permission request method - only required for Tap to Mobile transactions
    private void requestAudioPermission() {
        ActivityCompat.requestPermissions(this, new String[]{Manifest.permission.RECORD_AUDIO}, 3);
    }

    // Public method to check and request audio permission if needed - only required for Tap to Mobile transactions
    public void checkAndRequestAudioPermissionIfNeeded() {
        if (!isAudioPermissionGranted()) {
            requestAudioPermission();
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        if(requestCode == 2 && grantResults.length > 0) {
            for (int result : grantResults) {
                if (result == PackageManager.PERMISSION_DENIED) {
                    Toast.makeText(this, getString(R.string.bluetooth_permissions_not_granted), Toast.LENGTH_SHORT).show();
                    return;
                }
            }
        } else if(requestCode == 3 && grantResults.length > 0) {
            // Audio permission result handling - only required for Tap to Mobile transactions
            for (int result : grantResults) {
                if (result == PackageManager.PERMISSION_DENIED) {
                    Toast.makeText(this, getString(R.string.audio_permission_not_granted), Toast.LENGTH_SHORT).show();
                    log("Audio permission denied");
                    return;
                } else {
                    log("Audio permission granted");
                }
            }
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
    }

     /*
        Button Callbacks
     */

    private void selectPinPadButtonPushed() {
        log("Selecting PINpad");
        requestBluetoothPermissions();
        if (isBluetoothPermissionGranted()) {
            // Create a new intent to start the SelectPinPadActivity.
            Intent selectDeviceIntent = new Intent(ChipDnaMobileDemoActivity.this, SelectPinPadActivity.class);
            startActivityForResult(selectDeviceIntent, SelectPinPadActivity.ACTIVITY_REQUEST_CODE);
        }
    }

    private void connectButtonPushed(){
        log("About to connect to PINpad");
        requestBluetoothPermissions();
        if (isBluetoothPermissionGranted()) {
            // Use an instance of ChipDnaMobile to begin connectAndConfigure of the device.
            // PINpad checks are completed within connectAndConfigure, deciding whether a TMS update will need to be completed.
            Parameters connectAndConfigureParams = ChipDnaMobile.getInstance().getStatus(null);
            // TODO: Enable TTM
            // Add ParameterKeys.TapToMobilePOI and ParameterKeys.PaymentDevicePOI parameters to configure both TapToPay and PinPad
            // If no parameter passed, will default to PinPad configuration
//            boolean pinpadSelected = connectAndConfigureParams.containsKey(ParameterKeys.PinPadName);
//            if (pinpadSelected) {
//                connectAndConfigureParams.add(ParameterKeys.PaymentDevicePOI, ParameterValues.TRUE);
//            } else{
//                connectAndConfigureParams.add(ParameterKeys.PaymentDevicePOI, ParameterValues.FALSE);
//            }
//            if (ttmSwitch.isChecked()) {
//                connectAndConfigureParams.add(ParameterKeys.TapToMobilePOI, ParameterValues.TRUE);
//            }
            Parameters response = ChipDnaMobile.getInstance().connectAndConfigure(connectAndConfigureParams);
            if (response.containsKey(ParameterKeys.Result) && response.getValue(ParameterKeys.Result).equals(ParameterValues.FALSE)) {
                log("Error: " + response.getValue(ParameterKeys.Errors));
            }
        }
    }

    private void submitTransactionCommandButtonPushed() {
        log("Starting: " + currentTransactionCommandOption);

        // Request Parameters are used as to communicate - with ChipDna Mobile - the parameters needed to complete a given command.
        // They are sent with the method call to ChipDna Mobile.
        Parameters requestParameters = new Parameters();

        switch (currentTransactionCommandOption) {
            case Authorisation:
                // The following parameters are essential for the completion of a transaction.
                // In the current example the parameters are initialised as constants. They will need to be dynamically collected and initialised.
                requestParameters.add(ParameterKeys.Amount, currentlySelectedAmount);
                requestParameters.add(ParameterKeys.AmountType, ParameterValues.AmountTypeActual);
                requestParameters.add(ParameterKeys.Currency, CURRENCY);

                // The user reference is needed to be to able to access the transaction on WEBMis.
                // The reference should be unique to a transaction, so it is suggested that the reference is generated, similar to the example below.
                if(autoGenUserRefCheckbox.isChecked()) {
                    userRefText.setText(String.format("CDM-%s" ,new SimpleDateFormat("yy-MM-dd-HH.mm.ss").format(new Date())));
                }
                requestParameters.add(ParameterKeys.UserReference, userRefText.getText().toString());

                requestParameters.add(ParameterKeys.TransactionType, ParameterValues.Sale);
                requestParameters.add(ParameterKeys.PaymentMethod, ParameterValues.Card);
                // TODO: Enable TTM
                // Add ParameterKeys.TransactionPOI parameter to specify which POI to be used in case both TapToMobile and PaymentDevice are being configured
                // If just one POI is configured, this is not needed
//                if (ttmSwitch.isChecked()) {
//                    requestParameters.add(ParameterKeys.TransactionPOI, ParameterValues.TapToMobile);
//                }
                doAuthoriseTransaction(requestParameters);
                break;
            case Confirm:
                // The following parameters are used to confirm an authorised transaction.
                // The user reference is used to reference the transaction stored on WEBMis.
                requestParameters.add(ParameterKeys.UserReference, userRefText.getText().toString());
                requestParameters.add(ParameterKeys.Amount, currentlySelectedAmount);
                requestParameters.add(ParameterKeys.TipAmount, null);
                requestParameters.add(ParameterKeys.CloseTransaction,ParameterValues.TRUE);
                doConfirmTransaction(requestParameters);
                break;
            case Void:
                // The following parameters are used to void an authorised transaction.
                // The user reference is used to reference the transaction stored on WEBMis.
                requestParameters.add(ParameterKeys.UserReference, userRefText.getText().toString());
                doVoidTransaction(requestParameters);
                break;
            case TransactionInfo:
                // The following parameters are used to display information about a transaction.
                // The user reference is used to reference the transaction stored on WEBMis.
                requestParameters.add(ParameterKeys.UserReference, userRefText.getText().toString());
                doGetTransactionInformation(requestParameters);
                break;
        }
    }

    private void doAuthoriseTransaction(final Parameters authorisationParameters){
        log("Starting Transaction for amount: " + currentlySelectedAmount);

        // Use an instance of ChipDnaMobile to begin startTransaction.
        Parameters response = ChipDnaMobile.getInstance().startTransaction(authorisationParameters);

        if(response.containsKey(ParameterKeys.Result) && response.getValue(ParameterKeys.Result).equals(ParameterValues.FALSE)) {
            log("Error: " + response.getValue(ParameterKeys.Errors));
        }
    }

    private void doConfirmTransaction(final Parameters confirmParameters) {
        log("Confirm Transaction");

        new AsyncTask<String, Void, Parameters>(){
            @Override
            protected Parameters doInBackground(String... params) {
                return ChipDnaMobile.getInstance().confirmTransaction(confirmParameters);
            }

            @Override
            protected void onPostExecute(Parameters response) {
                log("Confirm Transaction Response", response);
            }
        }.execute();
    }

    private void doVoidTransaction(final Parameters voidParameters) {
        log("Void Transaction");

        new AsyncTask<String, Void, Parameters>(){
            @Override
            protected Parameters doInBackground(String... params) {
                return ChipDnaMobile.getInstance().voidTransaction(voidParameters);
            }

            @Override
            protected void onPostExecute(Parameters response) {
                log("Transaction Void Response", response);
            }
        }.execute();
    }

    private void doGetTransactionInformation(final Parameters transactionInfoParameters) {
        log("Get Transaction Info");
        new AsyncTask<String, Void, Parameters>(){
            @Override
            protected Parameters doInBackground(String... params) {
                return ChipDnaMobile.getInstance().getTransactionInformation(transactionInfoParameters);
            }

            @Override
            protected void onPostExecute(Parameters response) {
                log("Transaction Information Response", response);
            }
        }.execute();
    }

     /*
        Listener Variables
     */

    // Listener for amount dropdown menu. We simply update the current amount with that which has been selected.
    private AdapterView.OnItemSelectedListener amountItemSelectedListener = new AdapterView.OnItemSelectedListener() {
        @Override
        public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
            currentlySelectedAmount = AMOUNTS[position];
            log("Selected: " + getResources().getStringArray(R.array.amount_values)[position]);
        }

        @Override
        public void onNothingSelected(AdapterView<?> parent) {
            // Nothing to do here
        }
    };

    // Listener for two-stage option dropdown menu. We simply update the current option with that which has been selected.
    private AdapterView.OnItemSelectedListener transactionCommandSelectedListener = new AdapterView.OnItemSelectedListener() {
        @Override
        public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
            currentTransactionCommandOption = TRANSACTIONCOMMANDOPTIONS[position];
            log("Selected: " + getResources().getStringArray(R.array.transaction_command_values)[position]);
        }

        @Override
        public void onNothingSelected(AdapterView<?> parent) {
            // Nothing to do here
        }
    };

     /*
        Listeners
     */

    private void registerListeners() {
        ChipDnaMobile.getInstance().addConnectAndConfigureFinishedListener(new ConnectAndConfigureFinishedListener());
        ChipDnaMobile.getInstance().addConfigurationUpdateListener(new ConfigurationUpdateListener());
        ChipDnaMobile.getInstance().addDeviceUpdateListener(new DeviceUpdateListener());
        ChipDnaMobile.getInstance().addCardDetailsListener(new CardDetailsListener());

        TransactionListener transactionListener = new TransactionListener();
        ChipDnaMobile.getInstance().addTransactionUpdateListener(transactionListener);
        ChipDnaMobile.getInstance().addTransactionFinishedListener(transactionListener);
        ChipDnaMobile.getInstance().addDeferredAuthorizationListener(transactionListener);
        ChipDnaMobile.getInstance().addSignatureVerificationListener(transactionListener);
        ChipDnaMobile.getInstance().addVoiceReferralListener(transactionListener);
        ChipDnaMobile.getInstance().addPartialApprovalListener(transactionListener);
        ChipDnaMobile.getInstance().addForceAcceptanceListener(transactionListener);
        ChipDnaMobile.getInstance().addVerifyIdListener(transactionListener);
        ChipDnaMobile.getInstance().addApplicationSelectionListener(transactionListener);
        ChipDnaMobile.getInstance().addUserNotificationListener(transactionListener);
        ChipDnaMobile.getInstance().addTmsUpdateListener(tmsUpdateListener);
        ChipDnaMobile.getInstance().addProcessReceiptFinishedListener(new ProcessReceiptListener());
        ChipDnaMobile.getInstance().addSignatureCaptureListener(transactionListener);
        // TODO: Enable TTM
        // Add RequestActivityListener. It is needed when performing TTM transactions
        // ChipDnaMobile.getInstance().addRequestActivityListener(transactionListener);
    }

    private class ConnectAndConfigureFinishedListener implements IConnectAndConfigureFinishedListener {
        @Override
        public void onConnectAndConfigureFinished(Parameters parameters) {
            if(parameters.containsKey(ParameterKeys.Result) && parameters.getValue(ParameterKeys.Result).equalsIgnoreCase("True")){
                // Configuration has completed successfully and we are ready to perform transactions.
                log("Ready for transactions");
                runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        userRefText.setEnabled(true);
                        autoGenUserRefCheckbox.setEnabled(true);
                        submitTransactionCommand.setEnabled(true);
                    }
                });
            }else {
                // Configuration of the PINpad has failed
                //
                // d. Check error code.
                log("Failed to initialise PINpad");
                log(parameters.getValue(ParameterKeys.Errors));
            }
        }
    }

    private class ConfigurationUpdateListener implements IConfigurationUpdateListener {
        @Override
        public void onConfigurationUpdateListener(Parameters parameters) {
            log(parameters.getValue(ParameterKeys.ConfigurationUpdate));
        }
    }

    private class DeviceUpdateListener implements IDeviceUpdateListener {
        @Override
        public void onDeviceUpdate(Parameters parameters) {
            log(parameters.getValue(ParameterKeys.DeviceStatusUpdate));
        }
    }

    // This is not used in this version of the demo app.
    private class CardDetailsListener implements ICardDetailsListener {
        @Override
        public void onCardDetails(Parameters parameters) {
            log(parameters.getValue(ParameterKeys.MaskedPan));
        }
    }

    private class TransactionListener implements ITransactionUpdateListener, ITransactionFinishedListener,
            IDeferredAuthorizationListener, ISignatureVerificationListener, IVoiceReferralListener,
            IPartialApprovalListener, IForceAcceptanceListener, IVerifyIdListener, IApplicationSelectionListener, IUserNotificationListener, ISignatureCaptureListener, IRequestActivityListener {
        @Override
        public void onTransactionUpdateListener(Parameters parameters) {
            log(parameters.getValue(ParameterKeys.TransactionUpdate));
        }

        @Override
        public void onTransactionFinishedListener(Parameters parameters) {
            log("onTransactionFinishedListener =>", parameters);
        }

        @Override
        public void onSignatureVerification(Parameters parameters) {
            log("Signature Check Required");

            if (!parameters.getValue(ParameterKeys.ResponseRequired).equals(ParameterValues.TRUE)) {
                // Signature handled on PINpad. No call to ChipDna Mobile required.
                return;
            }

            final boolean operatorPinRequired = parameters.getValue(ParameterKeys.OperatorPinRequired).equals(ParameterValues.TRUE);
            final String receiptDataXml = parameters.getValue(ParameterKeys.ReceiptData);
            final boolean signatureCaptureSupported = parameters.getValue(ParameterKeys.DigitalSignatureSupported).equals(ParameterValues.TRUE);
            Bitmap signatureBitmap = null;

            if (parameters.containsKey(ParameterKeys.SignatureData)) {
                try {
                    signatureBitmap = ChipDnaMobileUtils.getBitmapFromPngString(parameters.getValue(ParameterKeys.SignatureData));
                } catch (ChipDnaMobileException e) {
                    e.printStackTrace();
                    log("Failed to generate bitmap from signature data.");
                }
            }
            final Bitmap fSignatureBitmap = signatureBitmap;

            new Thread(new Runnable() {
                @Override
                public void run() {
                    requestSignatureReview(operatorPinRequired, signatureCaptureSupported,fSignatureBitmap, receiptDataXml);
                }
            }).start();
        }

        @Override
        public void onVoiceReferral(Parameters parameters) {
            log("Voice Referral Check Required");

            if (!parameters.getValue(ParameterKeys.ResponseRequired).equals(ParameterValues.TRUE)) {
                // Voice referral handled on PINpad. No call to ChipDna Mobile required.
                return;
            }

            final String phoneNumber = parameters.getValue(ParameterKeys.ReferralNumber);
            final boolean operatorPinRequired = parameters.getValue(ParameterKeys.OperatorPinRequired).equals(ParameterValues.TRUE);

            new Thread(new Runnable() {
                @Override
                public void run() {
                    requestVoiceReferral(phoneNumber, operatorPinRequired);
                }
            }).start();
        }

          /*
            Other ChipDna Mobile Callbacks, not required in this demo.
            You may need to implement some of these depending on what your terminal supports.
          */

        @Override
        public void onVerifyId(Parameters parameters) {

        }

        @Override
        public void onDeferredAuthorizationListener(Parameters parameters) {

        }

        @Override
        public void onForceAcceptance(Parameters parameters) {

        }

        @Override
        public void onPartialApproval(Parameters parameters) {

        }

        @Override
        public void onApplicationSelection(Parameters parameters) {
            log("onApplicationSelection", parameters);
            try {
                // AvailableApplications parameter contains the applications available for selection, these will need to be deserialized.
                final ArrayList<Application> availableApplications = ChipDnaMobileSerializer.deserializeAvailableApplications(parameters.getValue(ParameterKeys.AvailableApplications));
                processApplicationSelectionRequest(availableApplications);
            } catch (XmlPullParserException | IOException e) {
                e.printStackTrace();
            }
        }

        @Override
        public void onUserNotification(Parameters parameters) {
            log("onUserNotification", parameters);
            processUserNotificationRequest(parameters);
        }

        @Override
        public void onSignatureCapture(Parameters parameters) {
            requestSignatureCapture();
        }

        @Override
        public void onRequestActivity() {
            // TODO: Enable TTM
            // When a TTM transaction is started, onRequestActivity callback will be called by the SDK.
            // In order to proceed with the transaction, an active Activity instance needs to be provided to the SDK through continueRequestedActivity
            // In this demo app we start a new ChipDnaDemoTapCardActivity and inside it we call continueRequestedActivity API
            Intent intent = new Intent(getApplicationContext(), ChipDnaDemoTapCardActivity.class);
            startActivityForResult(intent, ChipDnaDemoTapCardActivity.TRANSACTION_FINISHED_ACTIVITY_CODE);
        }
    }

    private void requestSignatureCapture(){
        Intent digitalSignatureCaptureIntent = new Intent(ChipDnaMobileDemoActivity.this, DigitalSignatureCaptureActivity.class);
        startActivityForResult(digitalSignatureCaptureIntent, DigitalSignatureCaptureActivity.DIGITAL_SIGNATURE_CAPTURE_ACTIVITY_CODE);
    }

    private ITmsUpdateListener tmsUpdateListener = new ITmsUpdateListener() {
        @Override
        public void onTmsUpdate(Parameters tmsUpdateParameters) {

        }
    };

    private class ProcessReceiptListener implements IProcessReceiptFinishedListener {
        @Override
        public void onProcessReceiptFinishedListener(Parameters parameters) {

        }
    }


     /*
        Logging
     */

    private ArrayList<String> logs = new ArrayList<String>();
    final int MAX_LOG = 100;
    private static Object LoggingLock = new Object();

    // Logging method which takes the string to be logged and display it in the logger text view.
    private void log(String toLog) {
        synchronized (LoggingLock) {
            if (logs.size() == MAX_LOG) {
                logs.remove(0);
            }

            logs.add(String.format("%s: %s\n", df.format(new Date()), toLog));
            Log.d(LOGGER_STR, toLog);
            StringBuilder sb = new StringBuilder("");
            for (String log : logs) {
                sb.append(String.format("%s", log));
            }
            final String logStr = sb.toString();
            runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    loggerTextView.setText(logStr);
                }
            });
        }
    }

    private void log(String title, Parameters parameters) {
        StringBuilder formattedLogBuilder = new StringBuilder();
        formattedLogBuilder.append(title);

        if(parameters != null) {
            for (Parameter parameter : parameters.toList()) {
                formattedLogBuilder.append(String.format("\t[%s]\n", parameter));
            }
        }

        log(formattedLogBuilder.toString());
    }


     /*
        Requests
     */

    private DialogInterface.OnClickListener getTerminateOnClickListener(final String alertDialogName){
        return new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialog, int which) {
                log("ChipDnaMobile.terminateTransaction");
                Parameters response = ChipDnaMobile.getInstance().terminateTransaction(new Parameters());

                if(response.containsKey(ParameterKeys.Result) && response.getValue(ParameterKeys.Result).equals(ParameterValues.FALSE)) {
                    log("Error: " + response.getValue(ParameterKeys.Errors));
                }
                log(alertDialogName + " Terminated");
            }
        };
    }

    private void requestSignatureReview(final boolean operatorPinRequired,
                                        final boolean signatureCaptureSupported,
                                        final Bitmap signatureData,
                                        final String receiptDataXml) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {

                if (signatureCaptureSupported && signatureData != null) {
                    Intent digitalSignatureVerificationIntent = new Intent(ChipDnaMobileDemoActivity.this, DigitalSignatureVerificationActivity.class);
                    digitalSignatureVerificationIntent.putExtra(DigitalSignatureVerificationActivity.SIGNATURE_OPERATOR_PIN_REQUIRED, operatorPinRequired);
                    digitalSignatureVerificationIntent.putExtra(DigitalSignatureVerificationActivity.SIGNATURE_RECEIPT_DATA, receiptDataXml);
                    digitalSignatureVerificationIntent.putExtra(DigitalSignatureVerificationActivity.SIGNATURE_DATA, signatureData);
                    startActivityForResult(digitalSignatureVerificationIntent, DigitalSignatureVerificationActivity.DIGITAL_SIGNATURE_VERIFICATION_ACTIVITY_CODE);
                    return;
                }
                AlertDialog.Builder builder = new AlertDialog.Builder(ChipDnaMobileDemoActivity.this.context);
                builder.setTitle("Please check signature.");
                final EditText input = new EditText(ChipDnaMobileDemoActivity.this.context);

                // If operator PIN is required, Add an extra text field to allow the user to enter the operator PIN.
                if(operatorPinRequired){
                    input.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_PASSWORD);
                    input.setHint("Operator PIN");
                    builder.setView(input);
                }

                builder.setPositiveButton("Accept", new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialog, int which) {
                        String inputStr = input.getText().toString();
                        if(operatorPinRequired){
                            // Check we have an operator PIN
                            if(inputStr.length() == 0) {
                                // No operator PIN found. Send request again.
                                log("Operator PIN required but not entered");
                                requestSignatureReview(operatorPinRequired, signatureCaptureSupported, signatureData, receiptDataXml);
                                return;
                            }
                        }

                        Parameters approveSignatureParameters = new Parameters();
                        approveSignatureParameters.add(ParameterKeys.Result, ParameterValues.TRUE);
                        approveSignatureParameters.add(ParameterKeys.OperatorPin, inputStr);

                        log("continueSignatureVerification =>", approveSignatureParameters);
                        Parameters response = ChipDnaMobile.getInstance().continueSignatureVerification(approveSignatureParameters);
                        log("continueSignatureVerification response=>", response);

                        if (!response.containsKey(ParameterKeys.Result) || response.getValue(ParameterKeys.Result).equals(ParameterValues.FALSE)) {
                            requestSignatureReview(operatorPinRequired, signatureCaptureSupported, signatureData, receiptDataXml);
                        }
                    }
                });

                builder.setNegativeButton("Terminate", getTerminateOnClickListener("Signature Check"));

                builder.setNeutralButton("Decline", new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialog, int which) {
                        // The merchant wishes to decline the transaction.
                        // No operator PIN is required when declining the transaction.
                        Parameters declineParameters = new Parameters();
                        declineParameters.add(ParameterKeys.Result, ParameterValues.FALSE);
                        log("Signature Check Declined");
                        Parameters response = ChipDnaMobile.getInstance().continueSignatureVerification(declineParameters);

                        if (!response.containsKey(ParameterKeys.Result) || response.getValue(ParameterKeys.Result).equals(ParameterValues.FALSE)) {
                            requestSignatureReview(operatorPinRequired, signatureCaptureSupported, signatureData, receiptDataXml);
                        }
                    }
                });

                builder.show();
            }
        });
    }

    private void requestVoiceReferral(final String phoneNumber, final boolean operatorPinRequired) {
        log("Requesting voice referral");
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                AlertDialog.Builder builder = new AlertDialog.Builder(ChipDnaMobileDemoActivity.this.context);
                LinearLayout contentView = new LinearLayout(ChipDnaMobileDemoActivity.this.context);
                contentView.setLayoutParams(new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT));
                contentView.setOrientation(LinearLayout.VERTICAL);

                builder.setTitle("Voice Referral");
                TextView requestText = new TextView(ChipDnaMobileDemoActivity.this.context);

                // If returned display phone number for the merchant to call.
                if(phoneNumber != null && phoneNumber.length() > 0){
                    requestText.setText("Please ring your bank: "+phoneNumber);
                }else{
                    requestText.setText("Please ring your bank.");
                }
                contentView.addView(requestText);

                final EditText operatorPinInput = new EditText(ChipDnaMobileDemoActivity.this.context);
                operatorPinInput.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_PASSWORD);
                operatorPinInput.setHint("Operator PIN");

                // If required add an extra text field to allow the user to enter their operator PIN.
                if(operatorPinRequired){
                    TextView operatorLabel = new TextView(ChipDnaMobileDemoActivity.this.context);
                    operatorLabel.setText("Operator PIN:");

                    contentView.addView(operatorLabel);
                    contentView.addView(operatorPinInput);
                }

                // Add a text field for the merchant to enter the authorization code given to them by the bank.
                final EditText authCodeInput = new EditText(ChipDnaMobileDemoActivity.this.context);
                authCodeInput.setInputType(InputType.TYPE_CLASS_TEXT);
                authCodeInput.setHint("Auth Code");
                TextView authCodeLabel = new TextView(ChipDnaMobileDemoActivity.this.context);
                authCodeLabel.setText("Authorization Code:");

                contentView.addView(authCodeLabel);
                contentView.addView(authCodeInput);

                builder.setView(contentView);

                builder.setPositiveButton("Accept", new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialog, int which) {
                        // The bank has given the authorization code and the merchant can proceed with the transaction.
                        if(operatorPinRequired){
                            // If required check we have been given an operator PIN.
                            String inputStr = operatorPinInput.getText().toString();
                            if(inputStr.length() == 0) {
                                log("Operator PIN required but not entered");
                                // If no operator PIN, try again.
                                requestVoiceReferral(phoneNumber, operatorPinRequired);
                                return;
                            }
                        }

                        String authCodeStr = authCodeInput.getText().toString();
                        String operatorPinStr = operatorPinInput.getText().toString();

                        // Check we have an authorization code.
                        if(authCodeStr == null || authCodeStr.length() < 1){
                            log("Authorization code required and not entered");
                            // If not try again.
                            requestVoiceReferral(phoneNumber, operatorPinRequired);
                            return;
                        }

                        Parameters voiceReferralParameters = new Parameters();
                        voiceReferralParameters.add(ParameterKeys.Result, ParameterValues.TRUE);
                        voiceReferralParameters.add(ParameterKeys.AuthCode, authCodeStr);
                        voiceReferralParameters.add(ParameterKeys.OperatorPin, operatorPinStr);

                        Parameters response = ChipDnaMobile.getInstance().continueVoiceReferral(voiceReferralParameters);

                        if(!response.containsKey(ParameterKeys.Result) || response.getValue(ParameterKeys.Result).equals(ParameterValues.FALSE)){
                            requestVoiceReferral(phoneNumber, operatorPinRequired);
                        }
                    }
                });


                builder.setNegativeButton("Terminate", getTerminateOnClickListener("Voice Referral"));

                // The bank has instructed the merchant to decline the transaction. No authorization code or operator PIN is necessary.
                builder.setNeutralButton("Decline", new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialog, int which) {

                        Parameters voiceReferralParameters = new Parameters();
                        voiceReferralParameters.add(ParameterKeys.Result, ParameterValues.FALSE);

                        log("Voice Referral Declined");
                        Parameters response = ChipDnaMobile.getInstance().continueVoiceReferral(voiceReferralParameters);

                        if(response.containsKey(ParameterKeys.Result) && response.getValue(ParameterKeys.Result).equals(ParameterValues.FALSE)) {
                            log("Error: " + response.getValue(ParameterKeys.Errors));
                        }

                    }
                });

                builder.show();
            }
        });
    }

    private void processApplicationSelectionRequest(final ArrayList<Application> applications){
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                // Create an alert dialog to display the available applications to the card holder.
                AlertDialog.Builder builder = new AlertDialog.Builder(ChipDnaMobileDemoActivity.this.context);
                builder.setTitle("Application Selection");
                builder.setNegativeButton("Terminate", getTerminateOnClickListener("Application Selection"));

                // Add the selectable available applications into a select dialog list.
                final ArrayAdapter<String> applicationsList = new ArrayAdapter<>(ChipDnaMobileDemoActivity.this.context, android.R.layout.select_dialog_singlechoice);
                for (Application application : applications) {
                    applicationsList.add(application.getName());
                }

                builder.setAdapter(applicationsList, new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialog, int appPos) {
                        // Initialise the application selection parameters.
                        Parameters applicationSelectionParameters = new Parameters();
                        applicationSelectionParameters.add(ParameterKeys.Result, ParameterValues.TRUE);

                        // Add the application name selected from the list by the card holder to the application selection parameters.
                        applicationSelectionParameters.add(ParameterKeys.SelectedApplication, applicationsList.getItem(appPos));
                        log("continueApplicationSelection =>", applicationSelectionParameters);

                        // Call continueApplicationSelection passing the result and application name as parameters.
                        Parameters response = ChipDnaMobile.getInstance().continueApplicationSelection(applicationSelectionParameters);
                        log("continueApplicationSelection response=>", response);
                    }
                });
                builder.setCancelable(false);
                applicationSelectionAlertDialog = builder.create();
                applicationSelectionAlertDialog.show();
            }
        });
    }

    private void processUserNotificationRequest(final Parameters parameters) {
        // Dismiss already showing dialog alerts.
        if(userNotificationAlertDialog!= null && userNotificationAlertDialog.isShowing()) {
            userNotificationAlertDialog.dismiss();
        }

        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                // Notify the card holder with the user notification using an dialog alert or other means.
                AlertDialog.Builder builder = new AlertDialog.Builder(ChipDnaMobileDemoActivity.this.context);
                builder.setTitle("User Notification");
                builder.setMessage(parameters.getValue(ParameterKeys.UserNotification));

                builder.setPositiveButton("OK", new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialog, int which) {
                        userNotificationAlertDialog.dismiss();
                    }
                });
                userNotificationAlertDialog = builder.create();
                userNotificationAlertDialog.show();
                new Handler().postDelayed(new Runnable() {
                    @Override
                    public void run() {
                        if (userNotificationAlertDialog.isShowing()) {
                            userNotificationAlertDialog.dismiss();
                        }
                    }
                }, 1000);
            }
        });
    }
}
