package com.lyft.hammer.agent

/** Why the agent refused or failed to start. Mirrors `AgentStartError` in Hammer. */
public sealed class AgentStartError(message: String, cause: Throwable? = null) : Exception(message, cause) {

    /** The app isn't debuggable and `allowsReleaseBuild` is false. */
    public class ReleaseBuild internal constructor() : AgentStartError(
        "The Hammer agent only runs in debuggable builds by default. Pass allowsReleaseBuild to start() to run it " +
            "in this build, where adb can control the app",
    )

    /** Something else holds the agent's socket: another process of this app, or another agent in this one. */
    public class SocketUnavailable internal constructor(
        /** The abstract socket the agent tried to listen on. */
        public val socketName: String,
        cause: Throwable,
        heldByThisProcess: Boolean,
    ) : AgentStartError(
        if (heldByThisProcess) {
            "The Hammer agent can't listen on @$socketName; another agent in this process already does, such as the one " +
                "auto-start runs. To start your own, turn auto-start off with the com.lyft.hammer.agent.autostart meta-data"
        } else {
            "The Hammer agent can't listen on @$socketName; another process may already own it"
        },
        cause,
    )
}
