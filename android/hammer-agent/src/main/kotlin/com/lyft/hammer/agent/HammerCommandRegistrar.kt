package com.lyft.hammer.agent

import android.content.Context

/**
 * Hands the agent an app's or a library's commands, so they join it however it starts. Android has no
 * counterpart in Hammer's iOS agent, where apps register commands in code.
 *
 * Name the class in a `<meta-data>` entry of the debug manifest, with the class in the key and this
 * interface's name as the value:
 *
 * ```xml
 * <meta-data
 *     android:name="com.lyft.hammer.agent.commands:com.example.app.DebugCommands"
 *     android:value="com.lyft.hammer.agent.HammerCommandRegistrar" />
 * ```
 *
 * The agent creates the registrar through its constructor without arguments and registers its commands
 * before it starts listening. It runs before `Application.onCreate`, so commands that need the app's
 * dependency injection are registered with [HammerAgent.register] instead.
 */
public interface HammerCommandRegistrar {
    /**
     * Returns the commands to register.
     *
     * @param context the application context.
     * @return the commands.
     */
    public fun commands(context: Context): List<AgentCommand>
}
