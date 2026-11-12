# The agent creates registrars that only the manifest names
-keep class * implements com.lyft.hammer.agent.HammerCommandRegistrar {
    <init>();
}
