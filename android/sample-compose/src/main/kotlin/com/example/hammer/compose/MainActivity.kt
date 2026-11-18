package com.example.hammer.compose

import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import androidx.activity.ComponentActivity

/** A Views screen: a field, a button that greets, and a list to scroll. */
class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        val name = findViewById<EditText>(R.id.name_field)
        val greeting = findViewById<TextView>(R.id.greeting)
        findViewById<Button>(R.id.greet_button).setOnClickListener {
            greeting.text = getString(R.string.greeting, name.text)
        }
        findViewById<Button>(R.id.open_compose).setOnClickListener {
            startActivity(Intent(this, ComposeActivity::class.java))
        }
        val items = findViewById<LinearLayout>(R.id.item_list)
        for (number in 1..ITEM_COUNT) {
            items.addView(TextView(this).apply { text = getString(R.string.item, number); textSize = ITEM_TEXT_SIZE })
        }
    }

    private companion object {
        const val ITEM_COUNT = 40
        const val ITEM_TEXT_SIZE = 24f
    }
}
