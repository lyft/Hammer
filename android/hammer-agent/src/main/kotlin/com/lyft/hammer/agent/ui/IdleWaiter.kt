package com.lyft.hammer.agent.ui

import android.os.Looper
import android.view.ViewTreeObserver
import com.lyft.hammer.agent.AgentError
import com.lyft.hammer.agent.AgentErrorCode
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.util.concurrent.atomic.AtomicInteger

/**
 * Waits until the app stops drawing and its main thread has nothing queued. View and Compose
 * animations both draw a frame each step, so no frames means no running animations.
 */
internal class IdleWaiter(private val reader: ScreenReader, private val main: CoroutineDispatcher) {

    suspend fun await(timeoutSeconds: Double) {
        val frames = AtomicInteger()
        val listener = ViewTreeObserver.OnDrawListener { frames.incrementAndGet() }
        val observers = withContext(main) {
            reader.windowRoots().map { root -> root.viewTreeObserver.also { it.addOnDrawListener(listener) } }
        }
        try {
            withTimeoutOrNull((timeoutSeconds * MILLIS_PER_SECOND).toLong()) { awaitQuiet(frames) } ?: throw AgentError(
                "The app was still animating after $timeoutSeconds seconds",
                AgentErrorCode.TIMED_OUT,
                "Take a screenshot to see the current state, then wait for an element instead or pass a longer timeout",
            )
        } finally {
            withContext(NonCancellable + main) {
                observers.filter { it.isAlive }.forEach { it.removeOnDrawListener(listener) }
            }
        }
    }

    /** Waits for idle, but only up to [timeoutSeconds], carrying on if the app is still animating. */
    suspend fun settle(timeoutSeconds: Double) {
        try {
            await(timeoutSeconds)
        } catch (error: AgentError) {
            if (error.code != AgentErrorCode.TIMED_OUT) throw error
        }
    }

    private suspend fun awaitQuiet(frames: AtomicInteger) {
        var quietPolls = 0
        var seen = frames.get()
        while (quietPolls < QUIET_POLLS) {
            delay(POLL_MILLIS)
            val now = frames.get()
            quietPolls = if (now == seen && Looper.getMainLooper().queue.isIdle) quietPolls + 1 else 0
            seen = now
        }
    }

    private companion object {
        const val POLL_MILLIS = 50L
        const val QUIET_POLLS = 2
        const val MILLIS_PER_SECOND = 1000
    }
}
