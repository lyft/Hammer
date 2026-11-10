package com.lyft.hammer.agent

/** Responds to [request] from a client that stays connected, which always gets a response. */
internal suspend fun CommandRouter.respond(request: HttpRequest): HttpResponse = checkNotNull(respond(request) { false })
