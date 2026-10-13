package com.creditcall.chipdnamobiledemo;

import android.content.Intent;
import android.os.Bundle;
import android.widget.TextView;

import androidx.appcompat.app.AppCompatActivity;

import com.creditcall.chipdnamobile.ChipDnaMobile;
import com.creditcall.chipdnamobile.ITransactionFinishedListener;
import com.creditcall.chipdnamobile.ITransactionUpdateListener;
import com.creditcall.chipdnamobile.IUserNotificationListener;
import com.creditcall.chipdnamobile.Parameter;
import com.creditcall.chipdnamobile.ParameterKeys;
import com.creditcall.chipdnamobile.ParameterValues;
import com.creditcall.chipdnamobile.Parameters;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

import timber.log.Timber;

public class ChipDnaDemoTapCardActivity extends AppCompatActivity implements
        ITransactionFinishedListener,
        ITransactionUpdateListener,
        IUserNotificationListener {

    public static final int TRANSACTION_FINISHED_ACTIVITY_CODE = 4;
    public static final String TRANSACTION_FINISHED_PARAMETERS_STRING = "TRANSACTION_FINISHED_PARAMETERS_STRING";

    private StringBuilder logsToPassBack = new StringBuilder(" --- ChipDnaTapCard\n");
    private final SimpleDateFormat dateFormat = new SimpleDateFormat("MM/dd/yyyy HH:mm:ss", Locale.US);
    private TextView transactionUpdateTv;
    private TextView userNotificationTv;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_chipdna_tap_card);

        transactionUpdateTv = findViewById(R.id.transaction_update);
        userNotificationTv = findViewById(R.id.user_notification);
        addListeners();
        // TODO: Enable TTM
        // After receiving the IRequestActivityListener#onRequestActivity callback, the SDK expects an Activity instance to be sent in order to proceed with the TTM transaction.
        // The activity needs to be in foreground and active until the transaction finishes. If the activity is being destroyed, the transaction will fail
        Parameters response = ChipDnaMobile.getInstance().continueRequestedActivity(this);
        if (!response.containsKey(ParameterKeys.Result) || ParameterValues.FALSE.equals(response.getValue(ParameterKeys.Result))) {
            Timber.d("Continue activity failed " + response.getValue(ParameterKeys.Errors));
            removeListeners();
            finish();
        }

        findViewById(R.id.terminate_button).setOnClickListener(v -> {
            appendToLogs("terminateTransaction (request)");
            Parameters responseParameters = ChipDnaMobile.getInstance().terminateTransaction(null);
            appendToLogs("terminateTransaction (response)");
            addParametersToLogs(responseParameters);
        });
    }

    @Override
    public void onTransactionFinishedListener(Parameters parameters) {
        Timber.d("onTransactionFinished - " + (parameters != null ? parameters.toList() : "null"));
        removeListeners();
        appendToLogs("Parameters [onTransactionFinishedListener =>]:");
        addParametersToLogs(parameters);
        Intent intent = new Intent();
        intent.putExtra(TRANSACTION_FINISHED_PARAMETERS_STRING, logsToPassBack.toString());
        setResult(RESULT_OK, intent);
        finish();
    }

    @Override
    public void onTransactionUpdateListener(Parameters parameters) {
        Timber.d("onTransactionUpdateListener - " + (parameters != null ? parameters.toList() : "null"));
        appendToLogs("Parameters [onTransactionUpdateListener =>]:");
        addParametersToLogs(parameters);
        if (parameters != null && parameters.containsKey(ParameterKeys.TransactionUpdate)) {
            runOnUiThread(() -> transactionUpdateTv.setText(parameters.getValue(ParameterKeys.TransactionUpdate)));
        }
    }

    @Override
    public void onUserNotification(Parameters parameters) {
        if (parameters != null && parameters.containsKey(ParameterKeys.UserNotification)) {
            runOnUiThread(() -> userNotificationTv.setText(parameters.getValue(ParameterKeys.UserNotification)));
        }
    }

    private void appendToLogs(String toAppend) {
        logsToPassBack.append(dateFormat.format(new Date())).append(": ").append(toAppend).append("\n");
    }

    private void addParametersToLogs(Parameters parameters) {
        if (parameters != null) {
            for (Parameter entry : parameters.toList()) {
                logsToPassBack.append("\t[").append(entry.getValue()).append("]\n");
            }
        }
    }

    private void addListeners() {
        ChipDnaMobile.getInstance().addTransactionFinishedListener(this);
        ChipDnaMobile.getInstance().addTransactionUpdateListener(this);
        ChipDnaMobile.getInstance().addUserNotificationListener(this);
    }

    private void removeListeners() {
        ChipDnaMobile.getInstance().removeTransactionFinishedListener(this);
        ChipDnaMobile.getInstance().removeTransactionUpdateListener(this);
        ChipDnaMobile.getInstance().removeUserNotificationListener(this);
    }
}