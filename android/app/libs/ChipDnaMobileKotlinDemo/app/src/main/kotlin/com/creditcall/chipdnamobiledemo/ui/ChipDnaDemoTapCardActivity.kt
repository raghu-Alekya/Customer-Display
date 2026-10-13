package com.creditcall.chipdnamobiledemo.ui

import android.content.Intent
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import com.creditcall.chipdnamobiledemo.R
import kotlinx.parcelize.Parcelize

@Parcelize
class ChipDnaDemoTapCardActivity : AppCompatActivity(), TapCardFragment.TapCardInteractionListener {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_tap_card)
        supportFragmentManager.beginTransaction().add(
            R.id.frameLayout,
            TapCardFragment.newInstance(this)
        ).commit()
    }

    override fun onTerminate(logs: String) {
        val intent = Intent()
        intent.putExtra(TRANSACTION_FINISHED_PARAMETERS_STRING, logs)
        setResult(RESULT_OK, intent)
        finish()
    }

    override fun onTransactionFinished(logs: String) {
        val intent = Intent()
        intent.putExtra(TRANSACTION_FINISHED_PARAMETERS_STRING, logs)
        setResult(RESULT_OK, intent)
        finish()
    }

    companion object {
        const val TRANSACTION_FINISHED_PARAMETERS_STRING: String = "TRANSACTION_FINISHED_PARAMETERS_STRING"
    }

}