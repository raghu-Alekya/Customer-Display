package com.creditcall.chipdnamobiledemo;

import android.annotation.SuppressLint;
import android.app.AlertDialog;
import android.app.ListActivity;
import android.content.Context;
import android.content.Intent;
import android.os.AsyncTask;
import android.os.Bundle;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.ListView;
import android.widget.TextView;

import com.creditcall.chipdnamobile.ChipDnaMobile;
import com.creditcall.chipdnamobile.ChipDnaMobileSerializer;
import com.creditcall.chipdnamobile.IAvailablePinPadsListener;
import com.creditcall.chipdnamobile.ParameterKeys;
import com.creditcall.chipdnamobile.ParameterValues;
import com.creditcall.chipdnamobile.Parameters;

import org.xmlpull.v1.XmlPullParserException;

import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

public class SelectPinPadActivity extends ListActivity {

    // listValues contains the list of PINpad names we're displaying
    private ArrayList<SelectablePinPad> listValues = new ArrayList<>();
    private SelectablePinPadAdapter listViewAdapter;
    private Button refreshButton;

    private AlertDialog scanningDialog;

    // Activity request code for this Activity. Used when returning the activity result.
    public static final int ACTIVITY_REQUEST_CODE = 1;
    public static final String SELECTED_PINPAD_NAME = "SELECTED_PINPAD_NAME";
    public static final String SELECTED_PINPAD_CONNECTION_TYPE = "SELECTED_PINPAD_CONNECTION_TYPE";

    // Result codes for this activity.
    public static final int RESULT_FAILED = 0;
    public static final int RESULT_OK = 1;
    public static final int UPDATE = 2;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_select_pin_pad);

        //Set up the list view to display PINpad names
        this.setUpGui();
    }

    private void setUpGui() {
        // Set up refresh button
        refreshButton = (Button) findViewById(R.id.refesh);
        refreshButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                refresh();
            }
        });

        // Set up list view
        final ListView listView = getListView();
        // Set an OnItemClickListener to receive callback about which list item has been selected.
        listView.setOnItemClickListener(new AdapterView.OnItemClickListener() {
            @SuppressLint("StaticFieldLeak")
            @Override
            // When a PINpad is selected there is no need to pass it back to the main activity. It can be saved in ChipDnaMobileProperties from here.
            public void onItemClick(AdapterView<?> parent, View view, int position, long id) {
                final SelectablePinPad selectedPinpad = (SelectablePinPad) view.getTag();
                Parameters statusParameters = ChipDnaMobile.getInstance().getStatus(null);
                final String currentPinPadName = statusParameters.getValue(ParameterKeys.PinPadName);

                new AsyncTask<String, Void, Parameters>() {

                    @Override
                    protected Parameters doInBackground(String... params) {
                        Parameters requestParameters = new Parameters();
                        requestParameters.add(ParameterKeys.PinPadName, params[0]);
                        requestParameters.add(ParameterKeys.PinPadConnectionType, params[1]);
                        return ChipDnaMobile.getInstance().setProperties(requestParameters);
                    }

                    @Override
                    protected void onPostExecute(Parameters response) {
                        Log.d(ChipDnaMobileDemoActivity.LOGGER_STR, response.toString());

                        if (response.containsKey(ParameterKeys.Result) && response.getValue(ParameterKeys.Result).equalsIgnoreCase("True")) {
                            Intent intent = new Intent();
                            intent.putExtra(SELECTED_PINPAD_NAME, selectedPinpad.getPinPadName());
                            intent.putExtra(SELECTED_PINPAD_CONNECTION_TYPE, selectedPinpad.getConnectionType());
                            if (currentPinPadName != null && currentPinPadName.length() > 0 && !currentPinPadName.equals(selectedPinpad.getPinPadName())) {
                                // User is updating there PINpad selection to a different PINpad.
                                setResult(UPDATE, intent);
                            } else {
                                setResult(RESULT_OK, intent);
                            }
                        } else {
                            setResult(RESULT_FAILED);
                        }
                        // Successfully set a PINpad and can return to the main activity with our result.
                        finish();
                    }
                }.execute(selectedPinpad.getPinPadName(), selectedPinpad.getConnectionType());

            }
        });

        // Create an ArrayAdaptor to hold our PINpad name values.
        listViewAdapter = new SelectablePinPadAdapter(this, listValues);
        // Set the list adaptor of the activity.
        setListAdapter(listViewAdapter);
        // Set the scanning dialog
        setUpScanningDialog();
        // Refresh will fill the array with values.
        refresh();
    }

    private void refresh() {
        // Clear our current PINpad names.
        listValues.clear();
        //Update our list view.
        updateListView();

        Parameters parameters = new Parameters();
        parameters.add(ParameterKeys.SearchConnectionTypeBluetooth, ParameterValues.TRUE);
        parameters.add(ParameterKeys.SearchConnectionTypeBluetoothLe, ParameterValues.TRUE);
        parameters.add(ParameterKeys.SearchConnectionTypeUsb, ParameterValues.TRUE);

        ChipDnaMobile.getInstance().clearAllAvailablePinPadsListeners();
        ChipDnaMobile.getInstance().addAvailablePinPadsListener(new AvailablePinPadsListener());
        ChipDnaMobile.getInstance().getAvailablePinPads(parameters);

        scanningDialog.show();
    }

    private class AvailablePinPadsListener implements IAvailablePinPadsListener {

        @SuppressLint("StaticFieldLeak")
        @Override
        public void onAvailablePinPads(Parameters parameters) {

            scanningDialog.dismiss();

            String availablePinPadsXml = parameters.getValue(ParameterKeys.AvailablePinPads);

            new AsyncTask<String, Void, List<SelectablePinPad>>(){
                @Override
                protected List<SelectablePinPad> doInBackground(String... params) {
                    List<SelectablePinPad> availablePinPadsList = new ArrayList<>();
                    try {
                        HashMap<String, ArrayList<String>> availablePinPadsHashMap = ChipDnaMobileSerializer.deserializeAvailablePinPads(params[0]);

                        for(String connectionType: availablePinPadsHashMap.keySet()) {
                            for (String pinpad : availablePinPadsHashMap.get(connectionType)) {
                                availablePinPadsList.add(new SelectablePinPad(pinpad, connectionType));
                            }
                        }
                    } catch (XmlPullParserException e) {
                        e.printStackTrace();
                    } catch (IOException e) {
                        e.printStackTrace();
                    }
                    return availablePinPadsList;
                }

                @Override
                protected void onPostExecute(List<SelectablePinPad> availablePinPadsList) {
                    listValues.clear();

                    if(availablePinPadsList != null) {
                        listValues.addAll(availablePinPadsList);
                    }

                    //Update our list view.
                    updateListView();
                }
            }.execute(availablePinPadsXml);
        }
    }

    private void updateListView() {
        this.runOnUiThread(new Runnable() {
            @Override
            public void run(){
                listViewAdapter.notifyDataSetChanged();
            }

        });
    }

    private void setUpScanningDialog() {
        AlertDialog.Builder scanningDialogBuilder = new AlertDialog.Builder(this);
        LayoutInflater scanningDialogInflater = this.getLayoutInflater();
        scanningDialogBuilder.setView(scanningDialogInflater.inflate(R.layout.scanning_dialog, null));
        scanningDialogBuilder.setCancelable(false);
        scanningDialog = scanningDialogBuilder.create();
    }

    class SelectablePinPad {
        private String pinPadName;
        private String connectionType;

        public SelectablePinPad(String pinPadName, String connectionType) {
            this.pinPadName = pinPadName;
            this.connectionType = connectionType;
        }

        public String getPinPadName() {
            return pinPadName;
        }

        public String getConnectionType() {
            return connectionType;
        }
    }

    class SelectablePinPadAdapter extends ArrayAdapter<SelectablePinPad> {
        //used as connection type label text in the list view
        private final String ConnectionTypeLabelBluetooth = "[BT]";
        private final String ConnectionTypeLabelUsb = "[USB]";
        private final String ConnectionTypeLabelBluetoothLe = "[BLE]";

        public SelectablePinPadAdapter(Context context, ArrayList<SelectablePinPad> pinpads) {
            super(context, 0, pinpads);
        }

        @Override
        public View getView(int position, View convertView, ViewGroup parent) {
            SelectablePinPad pinpad = getItem(position);

            if (convertView == null) {
                convertView = LayoutInflater.from(getContext()).inflate(R.layout.select_pinpad_row_layout, parent, false);
            }

            TextView pinpadNameLabel = (TextView) convertView.findViewById(R.id.pinpad_name_label);
            TextView connectionTypeLabel = (TextView) convertView.findViewById(R.id.pinpand_connection_type_label);

            pinpadNameLabel.setText(pinpad.getPinPadName());

            if (pinpad.getConnectionType().equalsIgnoreCase(ParameterValues.BluetoothConnectionType)) {
                connectionTypeLabel.setText(ConnectionTypeLabelBluetooth);
            } else if (pinpad.getConnectionType().equalsIgnoreCase(ParameterValues.UsbConnectionType)) {
                connectionTypeLabel.setText(ConnectionTypeLabelUsb);
            } else if (pinpad.getConnectionType().equalsIgnoreCase(ParameterValues.BluetoothLeConnectionType)) {
                connectionTypeLabel.setText(ConnectionTypeLabelBluetoothLe);
            } else {
                connectionTypeLabel.setText(pinpad.getConnectionType());
            }

            convertView.setTag(pinpad);

            return convertView;
        }
    }
}

