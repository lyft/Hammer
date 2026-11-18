package com.lyft.hammer.system

import android.app.UiAutomation
import android.graphics.Bitmap
import com.lyft.hammer.agent.AgentError
import com.lyft.hammer.agent.AgentErrorCode
import java.io.ByteArrayOutputStream

/**
 * Captures the whole screen, with system UI and the surfaces of maps and videos, and encodes it on the device at
 * the size the tool asks for, so only a small PNG crosses adb.
 */
internal class Screenshots(private val automation: UiAutomation) {

    fun png(area: Area?, size: Pair<Int, Int>?): ByteArray {
        val captured = automation.takeScreenshot() ?: throw AgentError("Android returned no screenshot", AgentErrorCode.FAILED)
        // Newer Android versions capture into a hardware bitmap, which can't be cropped or scaled
        val screen = if (captured.config == Bitmap.Config.HARDWARE) captured.copy(Bitmap.Config.ARGB_8888, false) else captured
        val cropped = area?.let { crop(screen, it) } ?: screen
        val scaled = size?.let { (width, height) -> Bitmap.createScaledBitmap(cropped, width, height, true) } ?: cropped
        return ByteArrayOutputStream().also { scaled.compress(Bitmap.CompressFormat.PNG, PNG_QUALITY, it) }.toByteArray()
    }

    private fun crop(screen: Bitmap, area: Area): Bitmap {
        val left = area.x.coerceIn(0, screen.width)
        val top = area.y.coerceIn(0, screen.height)
        val right = (area.x + area.width).coerceIn(left, screen.width)
        val bottom = (area.y + area.height).coerceIn(top, screen.height)
        if (right - left == 0 || bottom - top == 0) {
            throw AgentError("The area is off the screen", AgentErrorCode.INVALID_ARGUMENTS)
        }
        return Bitmap.createBitmap(screen, left, top, right - left, bottom - top)
    }

    private companion object {
        // PNG ignores the quality
        const val PNG_QUALITY = 100
    }
}
