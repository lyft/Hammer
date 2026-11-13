package com.example.hammer.views

import android.os.Bundle
import android.widget.Button
import android.widget.EditText
import android.widget.TextView
import androidx.activity.ComponentActivity

/** A Views screen with a field and a button that greets. */
class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        val name = findViewById<EditText>(R.id.name_field)
        val greeting = findViewById<TextView>(R.id.greeting)
        // Text with an empty content description, as text with optional accessibility text has
        findViewById<TextView>(R.id.note).contentDescription = ""
        findViewById<Button>(R.id.greet_button).setOnClickListener {
            greeting.text = getString(R.string.greeting, name.text)
        }
    }
}
