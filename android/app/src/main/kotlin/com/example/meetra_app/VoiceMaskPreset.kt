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
    val bandLowHz: Float = 0f,   // band-pass lower bound
    val bandHighHz: Float = 0f,  // band-pass upper bound
    val robotHz: Float = 0f,
    val flangerRate: Float = 0f,
    val flangerDepth: Float = 0.003f,
    val chorusDepth: Float = 0f,
    val reverbMix: Float = 0f,
    val bypass: Boolean = false
) {
    companion object {

        // ── Pitch factor helpers ─────────────────────────────────────────
        // Using precise factors derived from the pitch table rather than
        // recalculating 2^(semitones/12) every preset switch.

        private fun semis(s: Double) = Math.pow(2.0, s / 12.0)

        // ── All presets ──────────────────────────────────────────────────

        val NONE = VoiceMaskPreset(
            id = "none",
            bypass = true  // Hard bypass — zero processing overhead
        )

        val SHADOW = VoiceMaskPreset(
            id = "shadow",
            pitchFactor = semis(-5.0),   // -5 semitones (~75% speed)
            lowPassHz = 3000f             // Cuts bright highs → dark, menacing
        )

        val GIANT = VoiceMaskPreset(
            id = "titan",
            pitchFactor = semis(-7.0),   // -7 semitones (~60% speed)
            lowPassHz = 2000f             // Very warm, sub-bass presence
        )

        val OLD_MAN = VoiceMaskPreset(
            id = "oldman",
            pitchFactor = semis(-3.0),   // Slightly lower pitch
            lowPassHz = 2500f,            // Warm, slightly muffled
            chorusDepth = 0.0035f         // Slight chorus = "quivering" elder voice
        )

        val DORAEMON = VoiceMaskPreset(
            id = "doraemon",
            pitchFactor = semis(3.0),    // Slightly higher, warm robot companion
            lowPassHz = 4000f             // Still full voice but no harsh sibilance
        )

        val SHINCHAN = VoiceMaskPreset(
            id = "shinchan",
            pitchFactor = semis(7.0),    // High child voice
            bandLowHz = 1500f,
            bandHighHz = 4500f            // Band-pass: removes bass + ultra-high → nasal, squeaky
        )

        val ROBOT = VoiceMaskPreset(
            id = "robot",
            pitchFactor = 1.0,            // Pitch-neutral
            robotHz = 60f                 // Ring mod at 60Hz → classic buzzing robot carrier
        )

        val ALIEN = VoiceMaskPreset(
            id = "alien",
            pitchFactor = semis(5.0),    // +5 semitones = other-worldly pitch
            flangerRate = 0.25f,          // Slow flanger LFO
            flangerDepth = 0.003f         // 3ms depth = warbling modulation
        )

        val GHOST = VoiceMaskPreset(
            id = "ghost",
            pitchFactor = semis(3.0),
            reverbMix = 0.18f,
            chorusDepth = 0.002f
        )

        val CHIPMUNK = VoiceMaskPreset(
            id = "chipmunk",
            pitchFactor = semis(8.0)      // +8 semitones = chipmunk / speed-up
        )

        val DRUNK = VoiceMaskPreset(
            id = "drunk",
            pitchFactor = semis(-1.0),
            reverbMix = 0.15f             // Drunk reverb "cave" effect
        )

        val PRETTY_WOMAN = VoiceMaskPreset(
            id = "prettywoman",
            pitchFactor = semis(5.0),
            reverbMix = 0.12f,
            lowPassHz = 5000f             // Soft feminine voice
        )

        val CUSTOM = VoiceMaskPreset(
            id = "custom"                 // pitchFactor set externally via setCustomPitch
        )

        /** Map from string ID → Preset for O(1) lookup from MethodChannel */
        val ALL: Map<String, VoiceMaskPreset> = listOf(
            NONE, SHADOW, GIANT, OLD_MAN, DORAEMON, SHINCHAN, ROBOT,
            ALIEN, GHOST, CHIPMUNK, DRUNK, PRETTY_WOMAN, CUSTOM
        ).associateBy { it.id }

        /** Returns NONE if id is unrecognised (safe default). */
        fun byId(id: String) = ALL[id] ?: NONE
    }
}
