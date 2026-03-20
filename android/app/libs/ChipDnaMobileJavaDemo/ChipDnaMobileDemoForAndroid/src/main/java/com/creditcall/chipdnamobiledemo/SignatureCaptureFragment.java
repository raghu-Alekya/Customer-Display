package com.creditcall.chipdnamobiledemo;

import android.gesture.GestureOverlayView;
import android.graphics.Bitmap;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.Parcelable;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;

import com.creditcall.chipdnamobile.ChipDnaMobileException;
import com.creditcall.chipdnamobile.ChipDnaMobileUtils;

import java.util.Objects;
import java.util.concurrent.Executor;
import java.util.concurrent.Executors;


public class SignatureCaptureFragment extends Fragment implements GestureOverlayView.OnGesturingListener {
    private static final String ARG_REVIEW_LISTENER = "ARG_REVIEW_LISTENER";

    private SignatureView mGestureView;
    private Button terminateButton;
    private Button clearButton;
    private Button doneButton;
    private SignatureCaptureInteractionListener mListener;
    private final Executor executor = Executors.newSingleThreadExecutor();
    private final Handler handler = new Handler(Looper.getMainLooper());

    public static SignatureCaptureFragment newInstance(SignatureCaptureFragment.SignatureCaptureInteractionListener listener) {
        SignatureCaptureFragment fragment = new SignatureCaptureFragment();
        Bundle args = new Bundle();
        args.putParcelable(ARG_REVIEW_LISTENER, listener);
        fragment.setArguments(args);
        return fragment;
    }
    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container,
                             Bundle savedInstanceState) {

        mListener = Objects.requireNonNull(getArguments()).getParcelable(ARG_REVIEW_LISTENER);

        return inflater.inflate(R.layout.fragment_signature_capture, container, false);
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);

        mGestureView = view.findViewById(R.id.signaturePad);
        terminateButton = view.findViewById(R.id.terminate_at_signature_button);
        clearButton = view.findViewById(R.id.clear_signature_button);
        doneButton = view.findViewById(R.id.done_signature_button);

        terminateButton.setOnClickListener(v -> mListener.onTerminate());

        clearButton.setOnClickListener(v -> mGestureView.clear());

        doneButton.setOnClickListener(v -> {

            Bitmap rawImage = mGestureView.getBitmap();

            executor.execute(() -> {
                Bitmap result = null;
                try {
                    result =  ChipDnaMobileUtils.processSignatureImage(rawImage);
                } catch (ChipDnaMobileException e) {
                    e.printStackTrace();
                    mListener.onTerminate();
                }
                Bitmap finalResult = result;
                handler.post(() -> mListener.onSignatureAvailable(finalResult));
            });
        });

        mGestureView.setEnabler(doneButton);
    }

    public interface SignatureCaptureInteractionListener extends Parcelable{
        void onTerminate();
        void onSignatureAvailable(Bitmap signatureBitmap);
    }

    @Override
    public void onGesturingEnded(GestureOverlayView overlay) {
        doneButton.setEnabled(overlay.isGestureVisible());
    }

    @Override
    public void onGesturingStarted(GestureOverlayView overlay) {
    }
}
