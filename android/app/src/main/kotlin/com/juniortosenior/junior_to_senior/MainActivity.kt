package com.juniortosenior.junior_to_senior

import com.ryanheise.audioservice.AudioServiceActivity

// audio_service shares one FlutterEngine between the UI and the background
// playback service; its activity base class is what wires that up.
class MainActivity : AudioServiceActivity()
