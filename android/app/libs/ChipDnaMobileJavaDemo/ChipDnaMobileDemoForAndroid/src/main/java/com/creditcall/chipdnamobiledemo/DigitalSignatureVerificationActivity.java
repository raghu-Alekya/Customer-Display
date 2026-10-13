package com.creditcall.chipdnamobiledemo;

import android.annotation.SuppressLint;
import android.content.Intent;
import android.graphics.Bitmap;
import android.os.Bundle;
import android.os.Parcel;

import androidx.appcompat.app.AppCompatActivity;

@SuppressLint("ParcelCreator")
public class DigitalSignatureVerificationActivity extends AppCompatActivity
        implements ReviewSignatureFragment.ReviewSignatureInteractionListener {

    static final int DIGITAL_SIGNATURE_VERIFICATION_ACTIVITY_CODE = 2;
    static final int SIGNATURE_VERIFICATION_REQUEST_APPROVED = 1;
    static final int SIGNATURE_VERIFICATION_REQUEST_DECLINED = 2;
    static final int SIGNATURE_VERIFICATION_REQUEST_TERMINATED = 3;
    static final String SIGNATURE_DATA = "SIGNATURE_DATA";
    static final String SIGNATURE_OPERATOR_PIN = "SIGNATURE_OPERATOR_PIN";
    static final String SIGNATURE_OPERATOR_PIN_REQUIRED = "SIGNATURE_OPERATOR_PIN_REQUIRED";
    static final String SIGNATURE_RECEIPT_DATA = "SIGNATURE_RECEIPT_DATA";

    private boolean operatorPinRequired;
    private String receiptDataXml;
    public static Bitmap signatureData;
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        setContentView(R.layout.activity_digital_signature);
        // However, if we're being restored from a previous state,
        // then we don't need to do anything and should return or else
        // we could end up with overlapping fragments.
        if (savedInstanceState != null) {
            return;
        }

        // Add the fragment to the 'fragment_container' FrameLayout
        getSupportFragmentManager().beginTransaction()
                .replace(R.id.frameLayout, ReviewSignatureFragment.newInstance(getIntent().getParcelableExtra(SIGNATURE_DATA),
                        this,
                        getIntent().getBooleanExtra(SIGNATURE_OPERATOR_PIN_REQUIRED, true)
                )).commit();
    }

    @Override
    protected void onResume() {
        super.onResume();

        Intent intent = getIntent();
        if (intent == null) {
            finish();
        }

        operatorPinRequired = intent.getBooleanExtra(DigitalSignatureVerificationActivity.SIGNATURE_OPERATOR_PIN_REQUIRED, true);
        receiptDataXml = intent.getStringExtra(DigitalSignatureVerificationActivity.SIGNATURE_RECEIPT_DATA);
        signatureData = intent.getParcelableExtra(SIGNATURE_DATA);
    }

    @Override
    public void onSignatureTerminate() {
        setResult(SIGNATURE_VERIFICATION_REQUEST_TERMINATED);
        finish();
    }


    @Override
    public void onSignatureDeclined() {
        setResult(SIGNATURE_VERIFICATION_REQUEST_DECLINED);
        finish();
    }

    @Override
    public void onSignatureApproved(String operatorPin) {
        Intent intent = new Intent();
        intent.putExtra(SIGNATURE_OPERATOR_PIN, operatorPin);
        intent.putExtra(SIGNATURE_OPERATOR_PIN_REQUIRED, operatorPinRequired);
        intent.putExtra(SIGNATURE_RECEIPT_DATA, receiptDataXml);
        intent.putExtra(SIGNATURE_DATA, signatureData);
        setResult(SIGNATURE_VERIFICATION_REQUEST_APPROVED, intent);
        finish();
    }

    @Override
    public int describeContents() {
        return 0;
    }

    @Override
    public void writeToParcel(Parcel parcel, int i) {

    }
}
