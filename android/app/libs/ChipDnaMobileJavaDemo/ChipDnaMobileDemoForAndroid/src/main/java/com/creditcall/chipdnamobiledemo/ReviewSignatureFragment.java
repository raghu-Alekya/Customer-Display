package com.creditcall.chipdnamobiledemo;

import android.content.Context;
import android.graphics.Bitmap;
import android.os.Bundle;
import android.os.Parcelable;
import android.text.Editable;
import android.text.TextWatcher;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ImageView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;

public class ReviewSignatureFragment extends Fragment {
    private static final String ARG_SIGNATURE_BITMAP = "ARG_SIGNATURE_BITMAP";
    private static final String ARG_REVIEW_LISTENER = "ARG_REVIEW_LISTENER";
    private static final String ARG_OPERATOR_PIN_REQUIRED = "ARG_OPERATOR_PIN_REQUIRED";

    private Bitmap signatureBitmap;
    private boolean operatorPinRequired;

    private Button declineButton;
    private Button approveButton;
    private Button terminateButton;
    private EditText operatorPinText;
    private ImageView signatureImageView;

    private ReviewSignatureInteractionListener mListener;

    public static ReviewSignatureFragment newInstance(Bitmap signatureBitmap,
                                                      ReviewSignatureInteractionListener listener,
                                                      boolean operatorPinRequired) {
        ReviewSignatureFragment fragment = new ReviewSignatureFragment();
        Bundle args = new Bundle();
        args.putParcelable(ARG_SIGNATURE_BITMAP, signatureBitmap);
        args.putBoolean(ARG_OPERATOR_PIN_REQUIRED, operatorPinRequired);
        args.putParcelable(ARG_REVIEW_LISTENER, listener);
        fragment.setArguments(args);
        return fragment;
    }

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container,
                             Bundle savedInstanceState) {
        return inflater.inflate(R.layout.fragment_review_signature, container, false);
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);

        signatureBitmap = getArguments().getParcelable(ARG_SIGNATURE_BITMAP);
        operatorPinRequired = getArguments().getBoolean(ARG_OPERATOR_PIN_REQUIRED, true);
        mListener = getArguments().getParcelable(ARG_REVIEW_LISTENER);

        declineButton = view.findViewById(R.id.decline_signature_button);
        approveButton = view.findViewById(R.id.approve_signature_button);
        terminateButton = view.findViewById(R.id.terminate_signature_button);
        operatorPinText = view.findViewById(R.id.operator_pin_text);
        signatureImageView = view.findViewById(R.id.imageview_signature);

        declineButton.setOnClickListener(v -> mListener.onSignatureDeclined());

        approveButton.setOnClickListener(v -> mListener.onSignatureApproved(operatorPinRequired? operatorPinText.getText().toString() : null));

        operatorPinText.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence charSequence, int i, int i1, int i2) {

            }

            @Override
            public void onTextChanged(CharSequence charSequence, int i, int i1, int i2) {
                if (charSequence.toString().trim().length() == 0) {
                    approveButton.setEnabled(false);
                    declineButton.setEnabled(false);
                }else {
                    approveButton.setEnabled(true);
                    declineButton.setEnabled(true);
                }
            }

            @Override
            public void afterTextChanged(Editable editable) {

            }
        });

        terminateButton.setOnClickListener(v -> mListener.onSignatureTerminate());

        if(!operatorPinRequired) {
            operatorPinText.setVisibility(View.GONE);
        }

        if (signatureBitmap != null) {
            signatureImageView.setImageBitmap(signatureBitmap);
        }
    }

    public interface ReviewSignatureInteractionListener extends Parcelable {
        void onSignatureDeclined();
        void onSignatureApproved(String operatorPin);
        void onSignatureTerminate();
    }
}
