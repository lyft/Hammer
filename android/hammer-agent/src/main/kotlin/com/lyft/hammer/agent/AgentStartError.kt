package com.lyft.hammer.agent

/** Why the agent refused or failed to start. Mirrors `AgentStartError` in Hammer. */
public sealed class AgentStartError(message: String, cause: Throwable? = null) : Exception(message, cause) {

    /** The app isn't debuggable and `allowsReleaseBuild` is false. */
    public class ReleaseBuild internal constructor() : AgentStartError(
        "The Hammer agent only runs in debuggable builds by default. Pass allowsReleaseBuild to start() to run it " +
            "in this build, where adb can control the app",
    )

    /** Another process holds the agent's socket, such as another process of this app. */
    public class SocketUnavailable internal constructor(
        /** The abstract socket the agent tried to listen on. */
        public val socketName: String,
        cause: Throwable,
    ) : AgentStartError("The Hammer agent can't listen on @$socketName; another process may already own it", cause)
}
