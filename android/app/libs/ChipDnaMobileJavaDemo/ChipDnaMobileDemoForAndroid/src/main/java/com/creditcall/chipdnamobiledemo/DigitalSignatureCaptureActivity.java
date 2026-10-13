package com.creditcall.chipdnamobiledemo;

import android.annotation.SuppressLint;
import android.content.Intent;
import android.graphics.Bitmap;
import android.os.Bundle;
import android.os.Parcel;

import androidx.appcompat.app.AppCompatActivity;

import com.creditcall.chipdnamobile.ChipDnaMobileException;
import com.creditcall.chipdnamobile.ChipDnaMobileUtils;

@SuppressLint("ParcelCreator")
public class DigitalSignatureCaptureActivity extends AppCompatActivity implements SignatureCaptureFragment.SignatureCaptureInteractionListener {

	static final int DIGITAL_SIGNATURE_CAPTURE_ACTIVITY_CODE = 3;
	static final int SIGNATURE_CAPTURE_REQUEST_ACCEPTED = 1;
	static final int SIGNATURE_CAPTURE_REQUEST_TERMINATED = 2;

	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		setContentView(R.layout.activity_digital_signature_capture);

		getSupportFragmentManager().beginTransaction()
				.add(R.id.frameLayout, SignatureCaptureFragment.newInstance(this)).commit();
	}

	@Override
	public void onTerminate() {
		setResult(SIGNATURE_CAPTURE_REQUEST_TERMINATED);
		finish();
	}

	@Override
	public void onSignatureAvailable(Bitmap signatureBitmap) {
		Intent intent = new Intent();
		try {
			intent.putExtra(DigitalSignatureVerificationActivity.SIGNATURE_DATA, ChipDnaMobileUtils.getSignaturePngStringFromBitmap(signatureBitmap));
			setResult(SIGNATURE_CAPTURE_REQUEST_ACCEPTED, intent);
		} catch (ChipDnaMobileException e) {
			// only thrown when Bitmap is not in PNG
			// the transaction could be accepted however this implementation does not
			e.printStackTrace();
			setResult(SIGNATURE_CAPTURE_REQUEST_TERMINATED, intent);
		}
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
