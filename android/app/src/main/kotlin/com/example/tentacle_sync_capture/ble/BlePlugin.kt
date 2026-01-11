package com.example.tentacle_sync_capture.ble

import android.content.Context
import com.example.tentacle_sync_capture.ipc.TimecodeBroadcastService
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class BlePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var methodChannel: MethodChannel
    private lateinit var scanEventChannel: EventChannel
    private lateinit var gattEventChannel: EventChannel
    private lateinit var context: Context
    private lateinit var bleScanner: BleScanner
    private lateinit var gattManager: GattManager
    private lateinit var timecodeBroadcastService: TimecodeBroadcastService

    companion object {
        const val METHOD_CHANNEL = "com.example.tentacle_sync_capture/ble_method"
        const val SCAN_EVENT_CHANNEL = "com.example.tentacle_sync_capture/ble_scan_events"
        const val GATT_EVENT_CHANNEL = "com.example.tentacle_sync_capture/ble_gatt_events"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext

        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL)
        methodChannel.setMethodCallHandler(this)

        scanEventChannel = EventChannel(binding.binaryMessenger, SCAN_EVENT_CHANNEL)
        gattEventChannel = EventChannel(binding.binaryMessenger, GATT_EVENT_CHANNEL)

        bleScanner = BleScanner(context)
        gattManager = GattManager(context)
        timecodeBroadcastService = TimecodeBroadcastService(context)

        scanEventChannel.setStreamHandler(bleScanner)
        gattEventChannel.setStreamHandler(gattManager)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        scanEventChannel.setStreamHandler(null)
        gattEventChannel.setStreamHandler(null)
        bleScanner.stopScan()
        gattManager.disconnect()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            // Scanning methods
            "startScan" -> {
                val scanMode = call.argument<Int>("scanMode") ?: 1
                val filterByName = call.argument<String>("filterByName")
                val filterByServiceUuid = call.argument<String>("filterByServiceUuid")
                bleScanner.startScan(scanMode, filterByName, filterByServiceUuid)
                result.success(null)
            }
            "stopScan" -> {
                bleScanner.stopScan()
                result.success(null)
            }
            "isScanning" -> {
                result.success(bleScanner.isScanning())
            }

            // GATT methods
            "connect" -> {
                val address = call.argument<String>("address")
                if (address != null) {
                    gattManager.connect(address)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENT", "Address is required", null)
                }
            }
            "disconnect" -> {
                gattManager.disconnect()
                result.success(null)
            }
            "discoverServices" -> {
                gattManager.discoverServices()
                result.success(null)
            }
            "getServices" -> {
                result.success(gattManager.getServicesJson())
            }
            "subscribe" -> {
                val serviceUuid = call.argument<String>("serviceUuid")
                val charUuid = call.argument<String>("characteristicUuid")
                if (serviceUuid != null && charUuid != null) {
                    val success = gattManager.subscribe(serviceUuid, charUuid)
                    result.success(success)
                } else {
                    result.error("INVALID_ARGUMENT", "serviceUuid and characteristicUuid are required", null)
                }
            }
            "unsubscribe" -> {
                val serviceUuid = call.argument<String>("serviceUuid")
                val charUuid = call.argument<String>("characteristicUuid")
                if (serviceUuid != null && charUuid != null) {
                    val success = gattManager.unsubscribe(serviceUuid, charUuid)
                    result.success(success)
                } else {
                    result.error("INVALID_ARGUMENT", "serviceUuid and characteristicUuid are required", null)
                }
            }
            "readCharacteristic" -> {
                val serviceUuid = call.argument<String>("serviceUuid")
                val charUuid = call.argument<String>("characteristicUuid")
                if (serviceUuid != null && charUuid != null) {
                    gattManager.readCharacteristic(serviceUuid, charUuid)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENT", "serviceUuid and characteristicUuid are required", null)
                }
            }
            "isConnected" -> {
                result.success(gattManager.isConnected())
            }
            "getConnectionState" -> {
                result.success(gattManager.getConnectionState())
            }

            // IPC methods
            "setIpcEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                timecodeBroadcastService.setEnabled(enabled)
                result.success(null)
            }
            "isIpcEnabled" -> {
                result.success(timecodeBroadcastService.isEnabled())
            }
            "broadcastTimecode" -> {
                val hours = call.argument<Int>("hours") ?: 0
                val minutes = call.argument<Int>("minutes") ?: 0
                val seconds = call.argument<Int>("seconds") ?: 0
                val frames = call.argument<Int>("frames") ?: 0
                val fps = call.argument<Double>("fps") ?: 25.0
                val dropFrame = call.argument<Boolean>("dropFrame") ?: false
                val deviceAddress = call.argument<String>("deviceAddress") ?: ""
                val deviceName = call.argument<String>("deviceName")

                timecodeBroadcastService.broadcastTimecode(
                    hours, minutes, seconds, frames,
                    fps, dropFrame, deviceAddress, deviceName
                )
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }
}
