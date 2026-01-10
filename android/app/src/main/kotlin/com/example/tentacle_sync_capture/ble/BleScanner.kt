package com.example.tentacle_sync_capture.ble

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.os.Build
import android.os.ParcelUuid
import android.os.SystemClock
import android.util.Base64
import io.flutter.plugin.common.EventChannel
import java.util.UUID

class BleScanner(private val context: Context) : EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var bluetoothLeScanner: BluetoothLeScanner? = null
    private var isCurrentlyScanning = false

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            super.onScanResult(callbackType, result)
            emitScanResult(result)
        }

        override fun onBatchScanResults(results: MutableList<ScanResult>) {
            super.onBatchScanResults(results)
            results.forEach { emitScanResult(it) }
        }

        override fun onScanFailed(errorCode: Int) {
            super.onScanFailed(errorCode)
            eventSink?.error("SCAN_FAILED", "Scan failed with error code: $errorCode", null)
            isCurrentlyScanning = false
        }
    }

    @SuppressLint("MissingPermission")
    private fun emitScanResult(result: ScanResult) {
        val device = result.device
        val scanRecord = result.scanRecord

        val timestampNanos = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            result.timestampNanos
        } else {
            SystemClock.elapsedRealtimeNanos()
        }

        val payloadBytes = scanRecord?.bytes
        val payloadBase64 = if (payloadBytes != null) {
            Base64.encodeToString(payloadBytes, Base64.NO_WRAP)
        } else {
            null
        }

        val serviceUuids = scanRecord?.serviceUuids?.map { it.uuid.toString() } ?: emptyList()
        val manufacturerData = mutableMapOf<Int, String>()
        scanRecord?.manufacturerSpecificData?.let { sparseArray ->
            for (i in 0 until sparseArray.size()) {
                val key = sparseArray.keyAt(i)
                val value = sparseArray.valueAt(i)
                manufacturerData[key] = Base64.encodeToString(value, Base64.NO_WRAP)
            }
        }

        val serviceData = mutableMapOf<String, String>()
        scanRecord?.serviceData?.forEach { (uuid, data) ->
            serviceData[uuid.uuid.toString()] = Base64.encodeToString(data, Base64.NO_WRAP)
        }

        val eventData = mapOf(
            "address" to device.address,
            "name" to (device.name ?: scanRecord?.deviceName),
            "rssi" to result.rssi,
            "timestampNanos" to timestampNanos,
            "timestampMillis" to System.currentTimeMillis(),
            "payloadBase64" to payloadBase64,
            "serviceUuids" to serviceUuids,
            "manufacturerData" to manufacturerData,
            "serviceData" to serviceData,
            "txPowerLevel" to (scanRecord?.txPowerLevel ?: Int.MIN_VALUE),
            "isConnectable" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) result.isConnectable else true
        )

        eventSink?.success(eventData)
    }

    @SuppressLint("MissingPermission")
    fun startScan(scanMode: Int, filterByName: String?, filterByServiceUuid: String?) {
        if (isCurrentlyScanning) {
            stopScan()
        }

        val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothAdapter = bluetoothManager.adapter
        bluetoothLeScanner = bluetoothAdapter?.bluetoothLeScanner

        if (bluetoothLeScanner == null) {
            eventSink?.error("BLUETOOTH_UNAVAILABLE", "Bluetooth LE scanner not available", null)
            return
        }

        val settingsBuilder = ScanSettings.Builder()
            .setScanMode(scanMode)
            .setReportDelay(0)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            settingsBuilder.setCallbackType(ScanSettings.CALLBACK_TYPE_ALL_MATCHES)
            settingsBuilder.setMatchMode(ScanSettings.MATCH_MODE_AGGRESSIVE)
            settingsBuilder.setNumOfMatches(ScanSettings.MATCH_NUM_MAX_ADVERTISEMENT)
        }

        val settings = settingsBuilder.build()

        val filters = mutableListOf<ScanFilter>()

        if (!filterByName.isNullOrEmpty()) {
            filters.add(ScanFilter.Builder().setDeviceName(filterByName).build())
        }

        if (!filterByServiceUuid.isNullOrEmpty()) {
            try {
                val uuid = UUID.fromString(filterByServiceUuid)
                filters.add(ScanFilter.Builder().setServiceUuid(ParcelUuid(uuid)).build())
            } catch (e: IllegalArgumentException) {
                eventSink?.error("INVALID_UUID", "Invalid service UUID format", null)
                return
            }
        }

        bluetoothLeScanner?.startScan(
            if (filters.isEmpty()) null else filters,
            settings,
            scanCallback
        )
        isCurrentlyScanning = true
    }

    @SuppressLint("MissingPermission")
    fun stopScan() {
        if (isCurrentlyScanning) {
            bluetoothLeScanner?.stopScan(scanCallback)
            isCurrentlyScanning = false
        }
    }

    fun isScanning(): Boolean = isCurrentlyScanning

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        stopScan()
    }
}
