package com.example.tentacle_sync_capture.ble

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.os.Build
import android.os.SystemClock
import android.util.Base64
import io.flutter.plugin.common.EventChannel
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

class GattManager(private val context: Context) : EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var bluetoothGatt: BluetoothGatt? = null
    private var connectionState = BluetoothProfile.STATE_DISCONNECTED
    private var connectedDeviceAddress: String? = null

    companion object {
        val CLIENT_CHARACTERISTIC_CONFIG: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    }

    private val gattCallback = object : BluetoothGattCallback() {
        @SuppressLint("MissingPermission")
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            connectionState = newState
            val stateString = when (newState) {
                BluetoothProfile.STATE_CONNECTED -> "connected"
                BluetoothProfile.STATE_DISCONNECTED -> "disconnected"
                BluetoothProfile.STATE_CONNECTING -> "connecting"
                BluetoothProfile.STATE_DISCONNECTING -> "disconnecting"
                else -> "unknown"
            }

            emitEvent("connectionStateChange", mapOf(
                "state" to stateString,
                "status" to status,
                "address" to (gatt.device?.address ?: connectedDeviceAddress)
            ))

            if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                bluetoothGatt?.close()
                bluetoothGatt = null
                connectedDeviceAddress = null
            }
        }

        @SuppressLint("MissingPermission")
        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            emitEvent("servicesDiscovered", mapOf(
                "status" to status,
                "services" to getServicesJson()
            ))
        }

        @Deprecated("Deprecated in Java")
        override fun onCharacteristicRead(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            status: Int
        ) {
            val value = characteristic.value
            emitGattEvent("read", characteristic, value, status)
        }

        override fun onCharacteristicRead(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray,
            status: Int
        ) {
            emitGattEvent("read", characteristic, value, status)
        }

        @Deprecated("Deprecated in Java")
        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic
        ) {
            val value = characteristic.value
            emitGattEvent("notify", characteristic, value, 0)
        }

        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray
        ) {
            emitGattEvent("notify", characteristic, value, 0)
        }

        override fun onDescriptorWrite(
            gatt: BluetoothGatt,
            descriptor: BluetoothGattDescriptor,
            status: Int
        ) {
            emitEvent("descriptorWrite", mapOf(
                "characteristicUuid" to descriptor.characteristic.uuid.toString(),
                "descriptorUuid" to descriptor.uuid.toString(),
                "status" to status
            ))
        }
    }

    private fun emitGattEvent(
        operation: String,
        characteristic: BluetoothGattCharacteristic,
        value: ByteArray?,
        status: Int
    ) {
        val serviceUuid = characteristic.service?.uuid?.toString() ?: ""
        val charUuid = characteristic.uuid.toString()

        emitEvent("characteristicEvent", mapOf(
            "operation" to operation,
            "serviceUuid" to serviceUuid,
            "characteristicUuid" to charUuid,
            "valueBase64" to (value?.let { Base64.encodeToString(it, Base64.NO_WRAP) }),
            "status" to status,
            "timestampNanos" to SystemClock.elapsedRealtimeNanos(),
            "timestampMillis" to System.currentTimeMillis()
        ))
    }

    private fun emitEvent(type: String, data: Map<String, Any?>) {
        val eventData = mutableMapOf<String, Any?>()
        eventData["type"] to type
        eventData.putAll(data)
        eventData["eventType"] = type
        eventSink?.success(eventData)
    }

    @SuppressLint("MissingPermission")
    fun connect(address: String) {
        val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothAdapter = bluetoothManager.adapter

        if (bluetoothAdapter == null) {
            emitEvent("error", mapOf("message" to "Bluetooth adapter not available"))
            return
        }

        val device: BluetoothDevice? = bluetoothAdapter?.getRemoteDevice(address)
        if (device == null) {
            emitEvent("error", mapOf("message" to "Device not found: $address"))
            return
        }

        bluetoothGatt?.close()
        connectedDeviceAddress = address
        connectionState = BluetoothProfile.STATE_CONNECTING

        bluetoothGatt = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            device.connectGatt(context, false, gattCallback, BluetoothDevice.TRANSPORT_LE)
        } else {
            device.connectGatt(context, false, gattCallback)
        }
    }

    @SuppressLint("MissingPermission")
    fun disconnect() {
        bluetoothGatt?.disconnect()
    }

    @SuppressLint("MissingPermission")
    fun discoverServices() {
        bluetoothGatt?.discoverServices()
    }

    @SuppressLint("MissingPermission")
    fun getServicesJson(): String {
        val gatt = bluetoothGatt ?: return "[]"
        val servicesArray = JSONArray()

        for (service in gatt.services) {
            val serviceObj = JSONObject()
            serviceObj.put("uuid", service.uuid.toString())
            serviceObj.put("isPrimary", service.type == 0)

            val charsArray = JSONArray()
            for (char in service.characteristics) {
                val charObj = JSONObject()
                charObj.put("uuid", char.uuid.toString())
                charObj.put("properties", char.properties)
                charObj.put("isReadable", (char.properties and BluetoothGattCharacteristic.PROPERTY_READ) != 0)
                charObj.put("isWritable", (char.properties and BluetoothGattCharacteristic.PROPERTY_WRITE) != 0)
                charObj.put("isWritableNoResponse", (char.properties and BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE) != 0)
                charObj.put("isNotifiable", (char.properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY) != 0)
                charObj.put("isIndicatable", (char.properties and BluetoothGattCharacteristic.PROPERTY_INDICATE) != 0)

                val descriptorsArray = JSONArray()
                for (desc in char.descriptors) {
                    val descObj = JSONObject()
                    descObj.put("uuid", desc.uuid.toString())
                    descriptorsArray.put(descObj)
                }
                charObj.put("descriptors", descriptorsArray)

                charsArray.put(charObj)
            }
            serviceObj.put("characteristics", charsArray)
            servicesArray.put(serviceObj)
        }

        return servicesArray.toString()
    }

    @SuppressLint("MissingPermission")
    fun subscribe(serviceUuid: String, characteristicUuid: String): Boolean {
        val gatt = bluetoothGatt ?: return false
        val service = gatt.getService(UUID.fromString(serviceUuid)) ?: return false
        val characteristic = service.getCharacteristic(UUID.fromString(characteristicUuid)) ?: return false

        if (!gatt.setCharacteristicNotification(characteristic, true)) {
            return false
        }

        val descriptor = characteristic.getDescriptor(CLIENT_CHARACTERISTIC_CONFIG)
        if (descriptor != null) {
            val value = if ((characteristic.properties and BluetoothGattCharacteristic.PROPERTY_INDICATE) != 0) {
                BluetoothGattDescriptor.ENABLE_INDICATION_VALUE
            } else {
                BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
            }

            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                gatt.writeDescriptor(descriptor, value) == BluetoothGatt.GATT_SUCCESS
            } else {
                @Suppress("DEPRECATION")
                descriptor.value = value
                @Suppress("DEPRECATION")
                gatt.writeDescriptor(descriptor)
            }
        }

        return true
    }

    @SuppressLint("MissingPermission")
    fun unsubscribe(serviceUuid: String, characteristicUuid: String): Boolean {
        val gatt = bluetoothGatt ?: return false
        val service = gatt.getService(UUID.fromString(serviceUuid)) ?: return false
        val characteristic = service.getCharacteristic(UUID.fromString(characteristicUuid)) ?: return false

        if (!gatt.setCharacteristicNotification(characteristic, false)) {
            return false
        }

        val descriptor = characteristic.getDescriptor(CLIENT_CHARACTERISTIC_CONFIG)
        if (descriptor != null) {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                gatt.writeDescriptor(descriptor, BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE) == BluetoothGatt.GATT_SUCCESS
            } else {
                @Suppress("DEPRECATION")
                descriptor.value = BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE
                @Suppress("DEPRECATION")
                gatt.writeDescriptor(descriptor)
            }
        }

        return true
    }

    @SuppressLint("MissingPermission")
    fun readCharacteristic(serviceUuid: String, characteristicUuid: String) {
        val gatt = bluetoothGatt ?: return
        val service = gatt.getService(UUID.fromString(serviceUuid)) ?: return
        val characteristic = service.getCharacteristic(UUID.fromString(characteristicUuid)) ?: return
        gatt.readCharacteristic(characteristic)
    }

    fun isConnected(): Boolean = connectionState == BluetoothProfile.STATE_CONNECTED

    fun getConnectionState(): String = when (connectionState) {
        BluetoothProfile.STATE_CONNECTED -> "connected"
        BluetoothProfile.STATE_DISCONNECTED -> "disconnected"
        BluetoothProfile.STATE_CONNECTING -> "connecting"
        BluetoothProfile.STATE_DISCONNECTING -> "disconnecting"
        else -> "unknown"
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
}
