package com.lyft.hammer.agent

import android.app.Application
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.lyft.hammer.agent.core.WireCommand
import com.lyft.hammer.agent.core.toGson
import com.lyft.hammer.agent.core.toJsonValue
import com.lyft.hammer.agent.ui.AgentScreen
import com.lyft.hammer.agent.ui.BuiltinAgentCommands
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** The agent's [AgentEnvironment] in a running app. */
internal class AndroidEnvironment(private val application: Application) : AgentEnvironment {

    private val screen = AgentScreen(application)

    override val socketName: String
        get() = SocketListener.socketName(application.packageName)

    override val isDebuggable: Boolean
        get() = application.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0

    override val manifestEntries: Map<String, String> by lazy {
        val metaData = application.packageManager.getApplicationInfo(application.packageName, PackageManager.GET_META_DATA).metaData
        metaData?.keySet()?.associateWith { metaData.get(it).toString() }.orEmpty()
    }

    override val otherProcessName: String?
        get() = Application.getProcessName().takeIf { it != application.packageName }

    override fun builtinCommands(): List<WireCommand> = BuiltinAgentCommands(screen).all

    override fun wire(command: AgentCommand): WireCommand = object : WireCommand {
        override val descriptor = command.descriptor

        override suspend fun run(arguments: JsonObject): JsonElement = withContext(Dispatchers.Main) {
            command.run(arguments.toJsonValue(), AgentContext(screen)).toGson()
        }
    }

    override fun listen(socketName: String, handler: ConnectionHandler): AgentListener =
        SocketListener(socketName, handler, AgentLog.Logcat)
}
