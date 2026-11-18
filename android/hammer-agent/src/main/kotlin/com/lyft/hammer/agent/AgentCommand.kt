package com.lyft.hammer.agent

/**
 * A command the agent runs for its clients, such as an app specific action like signing in. Mirrors
 * `AgentCommand` in Hammer.
 *
 * The agent checks the arguments against [descriptor] before it calls [run]: unknown names, missing
 * required ones and wrong types fail with `invalid_arguments`, so [run] only sees arguments the
 * descriptor allows. Commands run one at a time, on the main thread.
 */
public interface AgentCommand {
    /**
     * Describes the command to clients. Its parameters can't use
     * [CommandDescriptor.reservedParameterNames].
     */
    public val descriptor: CommandDescriptor

    /**
     * Runs the command.
     *
     * @param arguments the arguments from the client.
     * @param context the state of this run, such as the refs of the views on screen.
     * @return the output for the client, such as an empty [JsonValue.Object] when there is nothing to report.
     * @throws AgentError to report a failure with a stable code and a hint. Any other exception fails
     *   with the code `failed` and its message.
     */
    public suspend fun run(arguments: JsonValue.Object, context: AgentContext): JsonValue
}
