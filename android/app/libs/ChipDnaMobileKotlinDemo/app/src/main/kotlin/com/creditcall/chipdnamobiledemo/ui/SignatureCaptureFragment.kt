package com.creditcall.chipdnamobiledemo.ui

import android.gesture.GestureOverlayView
import android.gesture.GestureOverlayView.OnGesturingListener
import android.graphics.Bitmap
import android.os.Bundle
import android.os.Parcelable
import android.view.View
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import com.creditcall.chipdnamobile.ChipDnaMobileUtils
import com.creditcall.chipdnamobiledemo.R
import com.creditcall.chipdnamobiledemo.databinding.FragmentSignatureCaptureBinding
import com.creditcall.chipdnamobiledemo.util.viewBinding
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class SignatureCaptureFragment : Fragment(R.layout.fragment_signature_capture),
  OnGesturingListener {

  private val binding by viewBinding { FragmentSignatureCaptureBinding.bind(it) }

  private lateinit var mListener: SignatureCaptureInteractionListener

  override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
    super.onViewCreated(view, savedInstanceState)
    setUpGui()
  }

  private fun setUpGui() {
    mListener = getInteractionListener()
    with(binding) {

      clearSignatureButton.setOnClickListener {
        signaturePad.clear()
      }

      terminateAtSignatureButton.setOnClickListener {
        mListener.onTerminate()
      }

      doneSignatureButton.setOnClickListener {
        viewLifecycleOwner.lifecycleScope.launch(Dispatchers.Unconfined) {
          ChipDnaMobileUtils.processSignatureImage(signaturePad.getBitmap()).let {
            withContext(Dispatchers.Main) {
              mListener.onSignatureAvailable(it)
            }
          }
        }
      }

      signaturePad.setEnabler(doneSignatureButton)
    }
  }

  override fun onGesturingEnded(overlay: GestureOverlayView) {
    binding.doneSignatureButton.isEnabled = overlay.isGestureVisible
  }

  override fun onGesturingStarted(overlay: GestureOverlayView) {}

  private fun getInteractionListener(): SignatureCaptureInteractionListener {
    if (arguments?.containsKey(KEY_INTERACTION_LISTENER) != true
      || arguments?.getParcelable<Parcelable>(KEY_INTERACTION_LISTENER) !is SignatureCaptureInteractionListener
    ) {
      throw RuntimeException(context.toString() + " must implement SignatureCaptureInteractionListener")
    }

    return requireArguments().getParcelable<Parcelable>(KEY_INTERACTION_LISTENER) as SignatureCaptureInteractionListener
  }

  companion object {
    private val KEY_INTERACTION_LISTENER = "KEY_INTERACTION_LISTENER"

    fun newInstance(interactionListener: SignatureCaptureInteractionListener) =
      SignatureCaptureFragment().apply {
        arguments = Bundle().apply {
          putParcelable(KEY_INTERACTION_LISTENER, interactionListener)
        }
      }
  }

  interface SignatureCaptureInteractionListener : Parcelable {
    fun onTerminate()
    fun onSignatureAvailable(signatureBitmap: Bitmap)
  }

}