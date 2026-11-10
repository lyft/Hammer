package com.lyft.hammer.agent

/**
 * Serves Hammer's agent HTTP API on the abstract socket `hammer_<applicationId>`, which the `hammer`
 * tool reaches through `adb forward`. Mirrors `HammerAgent` in Hammer.
 *
 * A debug build that depends on the library starts an agent on its own when the app launches. Create
 * one yourself only after turning that off, such as to register commands that need the app's
 * dependency injection:
 *
 * ```kotlin
 * val agent = HammerAgent(application)
 * agent.register(SignInCommand())
 * agent.start()
 * ```
 */
public class HammerAgent internal constructor(private val core: AgentCore) {

    /**
     * Creates an agent with the built-in commands.
     *
     * @param application the app to drive.
     */
    public constructor(application: android.app.Application) :
        this(AgentCore(AndroidEnvironment(application), AgentLog.Logcat))

    /** The commands the agent runs, in the order they were registered. */
    public val commands: List<CommandDescriptor>
        get() = core.commands

    /**
     * Adds a command, or replaces the one with the same name in its position. Safe to call at any time,
     * including while the agent serves requests.
     *
     * @param command the command to add.
     * @throws IllegalArgumentException if the command uses one of
     *   [CommandDescriptor.reservedParameterNames] or the same parameter twice.
     */
    public fun register(command: AgentCommand) {
        core.register(command)
    }

    /**
     * Starts listening for commands. Does nothing if the agent is already listening, or outside the
     * app's main process, where it logs why.
     *
     * @param allowsReleaseBuild if the agent runs in an app that isn't debuggable, where adb can still
     *   connect to it.
     * @throws AgentStartError if the app isn't debuggable and [allowsReleaseBuild] is false, or another
     *   process holds the socket.
     */
    public fun start(allowsReleaseBuild: Boolean = false) {
        core.start(allowsReleaseBuild)
    }

    /** Stops listening for commands. */
    public fun stop() {
        core.stop()
    }
}
