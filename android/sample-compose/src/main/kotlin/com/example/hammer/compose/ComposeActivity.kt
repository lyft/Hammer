package com.example.hammer.compose

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.rememberTransformableState
import androidx.compose.foundation.gestures.transformable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp

/** A Compose screen: a text field, a counter, an area to pinch and a list to scroll. */
class ComposeActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                Surface(Modifier.fillMaxSize()) {
                    ComposeScreen()
                }
            }
        }
    }
}

@Composable
private fun ComposeScreen() {
    var message by rememberSaveable { mutableStateOf("") }
    var count by rememberSaveable { mutableIntStateOf(0) }
    var zoom by rememberSaveable { mutableFloatStateOf(1f) }
    val zoomState = rememberTransformableState { change, _, _ -> zoom *= change }
    Column(Modifier.safeDrawingPadding().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("Compose", Modifier.semantics { heading() }, style = MaterialTheme.typography.headlineMedium)
        TextField(
            value = message,
            onValueChange = { message = it },
            label = { Text("Message") },
            modifier = Modifier.fillMaxWidth().testTag("message_field"),
        )
        Button(onClick = { count++ }, modifier = Modifier.testTag("count_button")) {
            Text("Count")
        }
        Text("Count: $count", Modifier.testTag("count"))
        // A row whose text sets an empty content description, as text with optional accessibility text does
        Row(Modifier.fillMaxWidth().clickable { count++ }.testTag("blank_description_row")) {
            Text("Add to count", Modifier.semantics { contentDescription = "" })
        }
        Box(
            Modifier.fillMaxWidth().height(ZOOM_AREA_HEIGHT.dp).border(1.dp, MaterialTheme.colorScheme.outline)
                .testTag("zoom_area").transformable(zoomState),
            contentAlignment = Alignment.Center,
        ) {
            Text("Zoom: ${"%.2f".format(java.util.Locale.US, zoom)}", Modifier.testTag("zoom"))
        }
        LazyColumn(Modifier.fillMaxWidth().testTag("rows")) {
            items(ROW_COUNT) { Text("Row ${it + 1}", Modifier.padding(vertical = 12.dp), style = MaterialTheme.typography.titleLarge) }
        }
    }
}

private const val ROW_COUNT = 50
private const val ZOOM_AREA_HEIGHT = 120
