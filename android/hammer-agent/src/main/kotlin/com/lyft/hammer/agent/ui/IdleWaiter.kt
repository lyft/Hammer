package com.lyft.hammer.agent.ui

import android.os.Looper
import android.view.View
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
 * Waits until the app stops drawing, its main thread has nothing queued, Compose has no pending work
 * and the Espresso idling resources it registers are idle. View and Compose animations both draw a
 * frame each step, so no frames means no running animations. Windows that open while it waits, such
 * as a dialog, count too.
 */
internal class IdleWaiter(private val reader: ScreenReader, private val main: CoroutineDispatcher) {

    suspend fun await(timeoutSeconds: Double) {
        val frames = AtomicInteger()
        val listener = ViewTreeObserver.OnDrawListener { frames.incrementAndGet() }
        val observers = mutableMapOf<View, ViewTreeObserver>()
        try {
            withTimeoutOrNull((timeoutSeconds * MILLIS_PER_SECOND).toLong()) { awaitQuiet(frames, listener, observers) } ?: throw AgentError(
                "The app was still busy after $timeoutSeconds seconds",
                AgentErrorCode.TIMED_OUT,
                "Take a screenshot to see the current state, then wait for an element instead or pass a longer timeout",
            )
        } finally {
            withContext(NonCancellable + main) {
                observers.values.filter { it.isAlive }.forEach { it.removeOnDrawListener(listener) }
            }
        }
    }

    /** Waits for idle, but only up to [timeoutSeconds], carrying on if the app is still busy. */
    suspend fun settle(timeoutSeconds: Double) {
        try {
            await(timeoutSeconds)
        } catch (error: AgentError) {
            if (error.code != AgentErrorCode.TIMED_OUT) throw error
        }
    }

    private suspend fun awaitQuiet(frames: AtomicInteger, listener: ViewTreeObserver.OnDrawListener, observers: MutableMap<View, ViewTreeObserver>) {
        var quietPolls = 0
        var seen = frames.get()
        while (quietPolls < QUIET_POLLS) {
            // A window that opened since the last poll hasn't been watched, so its first frames don't count
            val (watchedNew, busy) = withContext(main) {
                val roots = reader.windowRoots()
                val added = roots.filter { it !in observers }
                added.forEach { root -> observers[root] = root.viewTreeObserver.also { it.addOnDrawListener(listener) } }
                added.isNotEmpty() to isBusy(roots)
            }
            delay(POLL_MILLIS)
            val now = frames.get()
            quietPolls = if (now == seen && !watchedNew && !busy && Looper.getMainLooper().queue.isIdle) quietPolls + 1 else 0
            seen = now
        }
    }

    /** Whether Compose or an Espresso idling resource has work left. Runs on the main thread. */
    private fun isBusy(roots: List<View>): Boolean =
        (OptionalLibraries.hasCompose && roots.any(ComposeIdle::hasPendingWork)) || !EspressoIdling.isIdle()

    private companion object {
        const val POLL_MILLIS = 50L
        const val QUIET_POLLS = 2
        const val MILLIS_PER_SECOND = 1000
    }
}

/** Reads the app's Espresso idling resources, if it registers any, without depending on Espresso. */
internal object EspressoIdling {
    /** Whether every registered idling resource is idle; true without Espresso. Runs on the main thread, as Espresso asks. */
    fun isIdle(): Boolean {
        val registry = OptionalLibraries.idlingRegistry ?: return true
        return try {
            val instance = registry.getMethod("getInstance").invoke(null)
            val resources = registry.getMethod("getResources").invoke(instance) as? Collection<*> ?: return true
            // The interface's method, since an app's resource is often a class reflection can't call into
            val isIdleNow = Class.forName("androidx.test.espresso.IdlingResource", false, registry.classLoader).getMethod("isIdleNow")
            resources.all { resource -> isIdleNow.invoke(resource) as? Boolean ?: true }
        } catch (exception: ReflectiveOperationException) {
            true
        }
    }
}
