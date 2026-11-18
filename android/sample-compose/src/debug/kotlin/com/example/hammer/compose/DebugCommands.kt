package com.example.hammer.compose

import android.content.Context
import android.widget.TextView
import com.lyft.hammer.agent.AgentCommand
import com.lyft.hammer.agent.AgentContext
import com.lyft.hammer.agent.AgentError
import com.lyft.hammer.agent.AgentErrorCode
import com.lyft.hammer.agent.CommandDescriptor
import com.lyft.hammer.agent.HammerCommandRegistrar
import com.lyft.hammer.agent.JsonValue

/** The debug build's own commands, which the debug manifest names. */
class DebugCommands : HammerCommandRegistrar {
    override fun commands(context: Context): List<AgentCommand> = listOf(ShowGreetingCommand())
}

/** Shows a greeting on the Views screen without typing, and returns the greeting's ref. */
class ShowGreetingCommand : AgentCommand {
    override val descriptor = CommandDescriptor(
        name = "show_greeting",
        summary = "Shows a greeting for a name on the Views screen, and returns the ref of the greeting.",
        parameters = listOf(
            CommandDescriptor.Parameter("name", CommandDescriptor.ParameterType.StringValue, "The name to greet.", isRequired = true),
        ),
        examples = listOf(CommandDescriptor.Example("Greet Ada", mapOf("name" to JsonValue.String("Ada")))),
    )

    override suspend fun run(arguments: JsonValue.Object, context: AgentContext): JsonValue {
        val activity = context.foregroundActivity as? MainActivity
            ?: throw AgentError("The Views screen isn't in front", AgentErrorCode.NOT_READY, "Go back to the Views screen first")
        val greeting = activity.findViewById<TextView>(R.id.greeting)
        greeting.text = activity.getString(R.string.greeting, arguments["name"]?.stringValue)
        return JsonValue.Object("ref" to JsonValue.String(context.ref(greeting)))
    }
}
