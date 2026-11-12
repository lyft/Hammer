package com.lyft.hammer.agent.ui

import com.google.gson.JsonObject
import com.google.gson.JsonParser
import com.lyft.hammer.agent.AgentError
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.catchThrowableOfType
import org.junit.Test

class TargetsTest {

    @Test
    fun parse_noTarget_isNone() {
        assertThat(Target.parse(JsonObject())).isEqualTo(Target.None)
    }

    @Test
    fun parse_query_readsEveryField() {
        assertThat(Target.parse(json("""{"identifier": "a", "label": "b", "value": "c", "traits": ["button"]}""")))
            .isEqualTo(Target.Query("a", "b", "c", listOf("button")))
    }

    @Test
    fun parse_prefixedPoint_readsIt() {
        assertThat(Target.parse(json("""{"to_x": 1.5, "to_y": 2}"""), prefix = "to_")).isEqualTo(Target.At(Point(1.5, 2.0)))
    }

    @Test
    fun parse_onlyX_isInvalid() {
        val error = parseError("""{"x": 1}""")

        assertThat(error.code).isEqualTo("invalid_arguments")
        assertThat(error.message).isEqualTo("Pass both x and y for a point")
    }

    @Test
    fun parse_refAndQuery_isInvalid() {
        assertThat(parseError("""{"ref": "e1", "label": "OK"}""").message)
            .isEqualTo("Pass only one of a ref, a query (identifier, label, value, traits) or a point")
    }

    @Test
    fun parse_unknownTrait_suggestsClosest() {
        val error = parseError("""{"traits": ["buton"]}""")

        assertThat(error.code).isEqualTo("invalid_arguments")
        assertThat(error.message).isEqualTo("Unknown trait \"buton\", did you mean button?")
    }

    @Test
    fun touchPoint_noTarget_isWindowCenter() {
        assertThat(TargetResolver.touchPoint(Target.None, Snapshot(listOf(window()), SCREEN))).isEqualTo(Point(200.0, 400.0))
    }

    @Test
    fun touchPoint_queryMatchingOne_isItsCenter() {
        val button = element("e2", Frame(0.0, 0.0, 100.0, 40.0), identifier = "sign_in", consumesTouches = true)

        val point = TargetResolver.touchPoint(Target.Query("sign_in", null, null, emptyList()), Snapshot(listOf(window(button)), SCREEN))

        assertThat(point).isEqualTo(Point(50.0, 20.0))
    }

    @Test
    fun element_noMatch_isNotFound() {
        val error = resolveError(Target.Query(null, "Continue", null, listOf("button")), Snapshot(listOf(window()), SCREEN))

        assertThat(error.code).isEqualTo("not_found")
        assertThat(error.message).isEqualTo("Unable to find element: label \"Continue\", traits button")
    }

    @Test
    fun element_buttonAndItsTitleAtSamePoint_picksButton() {
        val title = element("e3", Frame(10.0, 10.0, 80.0, 20.0), label = "OK")
        val button = element("e2", Frame(10.0, 10.0, 80.5, 20.5), label = "OK", traits = setOf("button"), children = listOf(title))

        val match = TargetResolver.element(Target.Query(null, "OK", null, emptyList()), Snapshot(listOf(window(button)), SCREEN))

        assertThat(match).isSameAs(button)
    }

    @Test
    fun element_visibleAndHiddenMatch_picksVisible() {
        val hidden = element("e2", Frame(0.0, 0.0, 10.0, 10.0), label = "OK", visible = false)
        val shown = element("e3", Frame(100.0, 100.0, 10.0, 10.0), label = "OK")

        val match = TargetResolver.element(Target.Query(null, "OK", null, emptyList()), Snapshot(listOf(window(hidden, shown)), SCREEN))

        assertThat(match).isSameAs(shown)
    }

    @Test
    fun element_twoVisibleButtons_isAmbiguous() {
        val first = element("e2", Frame(0.0, 0.0, 10.0, 10.0), label = "OK", traits = setOf("button"))
        val second = element("e3", Frame(100.0, 100.0, 10.0, 10.0), label = "OK", traits = setOf("button"))

        val error = resolveError(Target.Query(null, "OK", null, emptyList()), Snapshot(listOf(window(first, second)), SCREEN))

        assertThat(error.code).isEqualTo("ambiguous_target")
        assertThat(error.message).isEqualTo("Found 2 elements for label \"OK\"")
    }

    @Test
    fun element_unknownRef_isInvalid() {
        val error = resolveError(Target.Ref("e99"), Snapshot(listOf(window()), SCREEN))

        assertThat(error.code).isEqualTo("invalid_arguments")
        assertThat(error.message).isEqualTo("Unknown ref e99")
    }

    @Test
    fun touchPoint_invisibleElement_isNotVisible() {
        val hidden = element("e2", Frame(0.0, 0.0, 10.0, 10.0), label = "OK", visible = false)

        val error = catchThrowableOfType(
            { TargetResolver.touchPoint(Target.Ref("e2"), Snapshot(listOf(window(hidden)), SCREEN)) },
            AgentError::class.java,
        )

        assertThat(error.code).isEqualTo("not_visible")
    }

    @Test
    fun touchPoint_coveredElement_isNotHittable() {
        val button = element("e2", Frame(0.0, 0.0, 10.0, 10.0), label = "OK", consumesTouches = true)
        val overlay = element("e3", Frame(0.0, 0.0, 400.0, 400.0), consumesTouches = true)

        val error = catchThrowableOfType(
            { TargetResolver.touchPoint(Target.Ref("e2"), Snapshot(listOf(window(button, overlay)), SCREEN)) },
            AgentError::class.java,
        )

        assertThat(error.code).isEqualTo("not_hittable")
        assertThat(error.message).isEqualTo("Element e2 is not hittable, e3 (android.view.View) takes touches at its location")
    }

    private fun parseError(arguments: String): AgentError =
        catchThrowableOfType({ Target.parse(json(arguments)) }, AgentError::class.java)

    private fun resolveError(target: Target, snapshot: Snapshot): AgentError =
        catchThrowableOfType({ TargetResolver.element(target, snapshot) }, AgentError::class.java)

    private fun json(value: String): JsonObject = JsonParser.parseString(value).asJsonObject
}
