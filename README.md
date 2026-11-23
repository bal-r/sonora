# Sonora

Press **Fn** to dictate, then press it again to paste at the cursor. Sonora runs NVIDIA’s Parakeet TDT v3 on your Mac for free. Some transcription apps reserve this model for a paid tier.

<img src="docs/images/recording.png" width="198" alt="Sonora’s recording indicator with a waveform and elapsed time">

On an M3 Pro, Sonora transcribed 21.4 seconds of speech in **147 ms** (146× real time). That’s the median of seven runs with the model already loaded. [Test clip](https://github.com/FluidInference/FluidAudio/blob/e0c6103bc87a88d25276cad491c86e757f58c865/Tests/FluidAudioTests/ASR/Parakeet/SlidingWindow/Fixtures/01-validation-request-21.4s.wav)

## Build and run

Requires Apple silicon, macOS 14 or later, and Swift 6.2 or later.

```sh
make run
```

On first launch, grant Microphone and Accessibility access and download the model. Dictation then works offline. Recordings and transcripts stay on your Mac.

<details>
<summary>Settings screenshot</summary>

<img src="docs/images/settings.png" width="620" alt="Sonora settings for the shortcut, push-to-talk, cue sounds, and automatic paste">

</details>

[Apache-2.0](LICENSE) · [Third-party notices](NOTICE)
