package com.example.meetra_app

/**
 * VoiceMaskPreset
 *
 * Immutable data class that holds ALL DSP parameters for a single voice character.
 * Keeping parameters here (not scattered across applyPreset()) makes it trivial
 * to add new presets and keeps the DSP engine data-driven.
 *
 * pitchFactor  — linear ratio (0.5 = one octave down, 2.0 = one octave up)
 *                Derived from semitones via: factor = 2^(semitones/12)
 * lowPassHz    — IIR low-pass cutoff frequency in Hz. 0 = disabled.
 * highPassHz   — IIR high-pass cutoff frequency in Hz. 0 = disabled.
 * bandPassHz   — If both lowPassHz and highPassHz are set, acts as band-pass.
 * robotHz      — Ring modulation carrier frequency in Hz. 0 = disabled.
 * flangerRate  — Flanger LFO rate in Hz. 0 = disabled.
 * flangerDepth — Flanger depth in seconds (e.g. 0.003 = 3ms).
 * chorusDepth  — Chorus delay depth in seconds. 0 = disabled.
 * reverbMix    — Wet/dry mix for reverb tail (0.0–1.0). 0 = disabled.
 * bypass       — If true, all DSP is skipped and the buffer is passed through unchanged.
 */
data class VoiceMaskPreset(
    val id: String,
    val pitchFactor: Double = 1.0,
    val lowPassHz: Float = 0f,
    val highPassHz: Float = 0f,
    val bandLowHz: Float = 0f,
    val bandHighHz: Float = 0f,
    val robotHz: Float = 0f,
    val flangerRate: Float = 0f,
    val flangerDepth: Float = 0.003f,
    val chorusDepth: Float = 0f,
    val reverbMix: Float = 0f,
    val distortion: Float = 0f,   // 0.0 (clean) to 1.0 (crushed)
    val bassBoost: Float = 0f,    // 0.0 to 1.0
    val vibratoRate: Float = 0f,  // Hz
    val vibratoDepth: Float = 0f, // semitones factor
    val masterGain: Float = 1.0f, // Gain compensation to prevent clipping
    val bypass: Boolean = false
) {
    companion object {

        private fun semis(s: Double) = Math.pow(2.0, s / 12.0)

        val NONE = VoiceMaskPreset(id = "none", bypass = true)

        val ROBOT = VoiceMaskPreset(
            id = "robot",
            pitchFactor = semis(0.0),
            robotHz = 110f,        // More aggressive modulation
            highPassHz = 300f,     // Thin out the voice for a "radio" feel
            distortion = 0.1f,     // Metallic grit (reduced for clarity)
            masterGain = 0.9f
        )

        val ALIEN = VoiceMaskPreset(
            id = "alien",
            pitchFactor = semis(5.0),
            robotHz = 80f,
            vibratoRate = 12f,     // Rapid warble
            vibratoDepth = 0.2f,
            reverbMix = 0.15f,
            masterGain = 0.8f
        )

        val GIANT = VoiceMaskPreset(
            id = "giant",
            pitchFactor = semis(-7.0),
            bassBoost = 0.6f,      // Heavy presence
            lowPassHz = 1000f,
            masterGain = 0.8f      // Giants are loud, need more headroom
        )

        val SAGE = VoiceMaskPreset(
            id = "sage",
            pitchFactor = semis(-4.0),
            reverbMix = 0.3f,      // More ambient
            chorusDepth = 0.004f,
            masterGain = 0.9f
        )

        val VADER = VoiceMaskPreset(
            id = "vader",
            pitchFactor = semis(-12.0), // Deep bass
            bassBoost = 0.8f,          // Massive low end
            lowPassHz = 1400f,
            highPassHz = 100f,
            distortion = 0.05f,        // Menacing growl (reduced)
            reverbMix = 0.1f,
            masterGain = 0.8f          // Heavy processing needs headroom
        )

        val CHIPMUNK = VoiceMaskPreset(
            id = "chipmunk",
            pitchFactor = semis(12.0),
            highPassHz = 500f,         // Cut the bass
            masterGain = 1.0f
        )

        val GHOST = VoiceMaskPreset(
            id = "ghost",
            pitchFactor = semis(6.0),
            vibratoRate = 3f,          // Slow eerie wobble
            vibratoDepth = 0.4f,
            reverbMix = 0.4f,          // Very ambient
            chorusDepth = 0.008f,
            masterGain = 0.7f
        )

        val DEMON = VoiceMaskPreset(
            id = "demon",
            pitchFactor = semis(-9.0),
            distortion = 0.15f,        // Aggressive growl (reduced for clarity)
            flangerRate = 0.5f,
            flangerDepth = 0.008f,
            bassBoost = 0.4f,
            masterGain = 0.8f          // Distortion adds volume, compensate
        )

        val CARTOON = VoiceMaskPreset(
            id = "cartoon",
            pitchFactor = semis(8.0),
            flangerRate = 1.2f,        // "Springy" sound
            flangerDepth = 0.004f,
            masterGain = 0.9f
        )

        val RADIODJ = VoiceMaskPreset(
            id = "radiodj",
            pitchFactor = semis(-2.0),
            bandLowHz = 300f,          // Wider frequency for "presence"
            bandHighHz = 3500f,
            masterGain = 0.95f
        )

        val CUSTOM = VoiceMaskPreset(id = "custom")

        val ALL: Map<String, VoiceMaskPreset> = listOf(
            NONE, ROBOT, ALIEN, GIANT, SAGE, VADER, CHIPMUNK, GHOST, DEMON, CARTOON, RADIODJ, CUSTOM
        ).associateBy { it.id }

        fun byId(id: String) = ALL[id] ?: NONE
    }
}
