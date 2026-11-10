package com.lyft.hammer.agent.ui

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Rect
import android.os.Handler
import android.os.Looper
import android.view.PixelCopy
import android.view.View
import androidx.core.graphics.createBitmap
import androidx.core.graphics.scale
import com.lyft.hammer.agent.core.AgentError
import com.lyft.hammer.agent.core.AgentErrorCode
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import kotlin.coroutines.resume
import kotlin.math.roundToInt

/**
 * Captures the app's windows back to front, as PNG. Activity windows are copied from their surface
 * and other windows, such as dialogs, are drawn in software. Neither includes a SurfaceView's own
 * surface, such as a map's, which shows as blank.
 */
internal class Screenshots(
    private val reader: ScreenReader,
    private val activities: ForegroundActivities,
    private val main: CoroutineDispatcher,
    private val default: CoroutineDispatcher,
) {

    /** The area of [frame], or the whole screen, at [scale] pixels per dp. */
    suspend fun png(frame: Frame?, scale: Double, density: Double): ByteArray {
        val screen = withContext(main) { capture() }
        return withContext(default) {
            val area = frame?.let { crop(it, density, screen) } ?: Rect(0, 0, screen.width, screen.height)
            val width = (area.width() / density * scale).roundToInt().coerceAtLeast(1)
            val height = (area.height() / density * scale).roundToInt().coerceAtLeast(1)
            val cropped = Bitmap.createBitmap(screen, area.left, area.top, area.width(), area.height())
            val scaled = cropped.scale(width, height)
            ByteArrayOutputStream().also { scaled.compress(Bitmap.CompressFormat.PNG, PNG_QUALITY, it) }.toByteArray()
        }
    }

    private suspend fun capture(): Bitmap {
        val roots = reader.windowRoots()
        val bounds = roots.map(ScreenReader::screenBounds)
        val screen = createBitmap(bounds.maxOf { it.right }, bounds.maxOf { it.bottom })
        val canvas = Canvas(screen)
        roots.zip(bounds).forEach { (root, rect) ->
            canvas.drawBitmap(windowBitmap(root), rect.left.toFloat(), rect.top.toFloat(), null)
        }
        return screen
    }

    private suspend fun windowBitmap(root: View): Bitmap {
        val bitmap = createBitmap(root.width, root.height)
        val window = activities.window(root)
        val copied = window != null && suspendCancellableCoroutine { continuation ->
            PixelCopy.request(window, bitmap, { result -> continuation.resume(result == PixelCopy.SUCCESS) }, Handler(Looper.getMainLooper()))
        }
        if (!copied) root.draw(Canvas(bitmap))
        return bitmap
    }

    private fun crop(frame: Frame, density: Double, screen: Bitmap): Rect {
        val area = Rect(
            (frame.x * density).roundToInt(),
            (frame.y * density).roundToInt(),
            ((frame.x + frame.width) * density).roundToInt(),
            ((frame.y + frame.height) * density).roundToInt(),
        )
        if (frame.isEmpty || !area.intersect(0, 0, screen.width, screen.height) || area.isEmpty) {
            throw AgentError("The element's frame is empty or off screen", AgentErrorCode.INVALID_ARGUMENTS)
        }
        return area
    }

    private companion object {
        const val PNG_QUALITY = 100
    }
}
