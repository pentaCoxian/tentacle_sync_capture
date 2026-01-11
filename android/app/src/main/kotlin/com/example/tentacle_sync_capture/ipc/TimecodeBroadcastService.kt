package com.example.tentacle_sync_capture.ipc

import android.content.Context
import android.content.Intent

/**
 * Service for broadcasting timecode to other Android apps via broadcast intents.
 *
 * Other apps can receive the timecode by registering a BroadcastReceiver for the action:
 * "com.example.tentacle_sync_capture.TIMECODE_UPDATE"
 *
 * The intent extras contain:
 * - "hours" (Int): Hours component (0-23)
 * - "minutes" (Int): Minutes component (0-59)
 * - "seconds" (Int): Seconds component (0-59)
 * - "frames" (Int): Frames component (0-fps)
 * - "timecode" (String): Formatted timecode string (HH:MM:SS:FF)
 * - "fps" (Double): Frame rate
 * - "dropFrame" (Boolean): Whether drop-frame timecode is used
 * - "timestamp" (Long): System timestamp when the timecode was captured
 * - "deviceAddress" (String): BLE device address
 * - "deviceName" (String?): BLE device name (may be null)
 */
class TimecodeBroadcastService(private val context: Context) {

    companion object {
        const val ACTION_TIMECODE_UPDATE = "com.example.tentacle_sync_capture.TIMECODE_UPDATE"
        const val EXTRA_HOURS = "hours"
        const val EXTRA_MINUTES = "minutes"
        const val EXTRA_SECONDS = "seconds"
        const val EXTRA_FRAMES = "frames"
        const val EXTRA_TIMECODE = "timecode"
        const val EXTRA_FPS = "fps"
        const val EXTRA_DROP_FRAME = "dropFrame"
        const val EXTRA_TIMESTAMP = "timestamp"
        const val EXTRA_DEVICE_ADDRESS = "deviceAddress"
        const val EXTRA_DEVICE_NAME = "deviceName"
    }

    private var isEnabled = false

    /**
     * Enable or disable IPC broadcasting
     */
    fun setEnabled(enabled: Boolean) {
        isEnabled = enabled
    }

    /**
     * Check if IPC broadcasting is enabled
     */
    fun isEnabled(): Boolean = isEnabled

    /**
     * Broadcast a timecode update to other apps
     *
     * @param hours Hours component (0-23)
     * @param minutes Minutes component (0-59)
     * @param seconds Seconds component (0-59)
     * @param frames Frames component
     * @param fps Frame rate
     * @param dropFrame Whether drop-frame timecode is used
     * @param deviceAddress BLE device address
     * @param deviceName BLE device name (optional)
     */
    fun broadcastTimecode(
        hours: Int,
        minutes: Int,
        seconds: Int,
        frames: Int,
        fps: Double,
        dropFrame: Boolean,
        deviceAddress: String,
        deviceName: String?
    ) {
        if (!isEnabled) return

        val timecodeStr = String.format(
            "%02d:%02d:%02d%s%02d",
            hours, minutes, seconds,
            if (dropFrame) ";" else ":",
            frames
        )

        val intent = Intent(ACTION_TIMECODE_UPDATE).apply {
            putExtra(EXTRA_HOURS, hours)
            putExtra(EXTRA_MINUTES, minutes)
            putExtra(EXTRA_SECONDS, seconds)
            putExtra(EXTRA_FRAMES, frames)
            putExtra(EXTRA_TIMECODE, timecodeStr)
            putExtra(EXTRA_FPS, fps)
            putExtra(EXTRA_DROP_FRAME, dropFrame)
            putExtra(EXTRA_TIMESTAMP, System.currentTimeMillis())
            putExtra(EXTRA_DEVICE_ADDRESS, deviceAddress)
            deviceName?.let { putExtra(EXTRA_DEVICE_NAME, it) }

            // Make it a global broadcast that other apps can receive
            addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES)
        }

        context.sendBroadcast(intent)
    }
}
