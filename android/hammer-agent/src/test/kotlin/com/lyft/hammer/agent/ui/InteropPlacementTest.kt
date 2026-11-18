package com.lyft.hammer.agent.ui

import org.assertj.core.api.Assertions.assertThat
import org.junit.Test

class InteropPlacementTest {

    @Test
    fun place_mapInsideSection_goesLastInDeepestNodeBeforeLaterSiblings() {
        val mapNode = element("e4", Frame(24.0, 818.0, 400.0, 155.0), label = "Map")
        val section = element("e3", Frame(0.0, 800.0, 448.0, 173.0), children = listOf(mapNode))
        val tabBar = element("e5", Frame(0.0, 909.0, 448.0, 48.0), consumesTouches = true)
        val map = element("e9", Frame(24.0, 818.3, 400.0, 155.3), consumesTouches = true)

        val placed = InteropPlacement.place(listOf(section, tabBar), listOf(map))

        assertThat(placed.map { it.ref }).containsExactly("e3", "e5")
        assertThat(placed[0].children.single().children.single()).isSameAs(map)
        assertThat(placed[1]).isSameAs(tabBar)
    }

    @Test
    fun place_viewNoNodeContains_goesOnTop() {
        val node = element("e3", Frame(0.0, 0.0, 100.0, 100.0))
        val view = element("e9", Frame(200.0, 200.0, 10.0, 10.0))

        assertThat(InteropPlacement.place(listOf(node), listOf(view))).containsExactly(node, view)
    }

    @Test
    fun place_overlappingSiblings_picksFrontmostThatContainsIt() {
        val back = element("e3", Frame(0.0, 0.0, 100.0, 100.0))
        val front = element("e4", Frame(0.0, 0.0, 100.0, 100.0))
        val view = element("e9", Frame(10.0, 10.0, 10.0, 10.0))

        val placed = InteropPlacement.place(listOf(back, front), listOf(view))

        assertThat(placed[0]).isSameAs(back)
        assertThat(placed[1].children).containsExactly(view)
    }

    @Test
    fun place_mapUnderTabBar_leavesTabBarHittable() {
        val mapNode = element("e4", Frame(24.0, 818.0, 400.0, 155.0), label = "Map")
        val tab = element("e6", Frame(113.0, 917.0, 24.0, 32.0), consumesTouches = true)
        val tabBar = element("e5", Frame(0.0, 909.0, 448.0, 48.0), children = listOf(tab))
        val map = element("e9", Frame(24.0, 818.0, 400.0, 155.0), consumesTouches = true)

        Snapshot(listOf(window(*InteropPlacement.place(listOf(mapNode, tabBar), listOf(map)).toTypedArray())), SCREEN)

        assertThat(tab.hittable).isTrue()
    }
}
