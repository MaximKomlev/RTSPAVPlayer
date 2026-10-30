# RTSPAVPlayer

**Experimental RTSP/RTP playback using FFmpeg and Apple's native AVPlayer.**

RTSPAVPlayer explores an alternative approach to playing RTSP video streams on iOS without implementing a custom video rendering engine.

The idea is simple: use FFmpeg to receive and demultiplex an RTSP/RTP stream, continuously repackage the incoming media into small MP4 segments, and feed those segments into Apple's native `AVPlayer`.

Rather than decoding and rendering video frames through FFmpeg, the project investigates whether the incoming stream can be adapted into a format that AVPlayer can consume.

## The Idea

Apple's AVPlayer provides hardware-accelerated video decoding, playback controls, and integration with the iOS media ecosystem. However, it does not directly support RTSP streams.

A common solution is to use a third-party playback engine or convert RTSP into HLS on a streaming server.

RTSPAVPlayer experiments with a different approach: **performing the media conversion locally, on the iOS device.**

The intended processing flow is:

```text
      RTSP Video Source
              |
              v
       FFmpeg / libavformat
              |
              v
      RTSP / RTP Reception
              |
              v
       Media Demultiplexing
              |
              v
       MP4 Segment Creation
              |
              v
      Continuous Segment Feed
              |
              v
        Native AVPlayer
              |
              v
        Video Rendering
```

FFmpeg handles stream reception and media packaging, while AVPlayer remains responsible for playback and rendering.

## How It Works

### 1. Receiving the RTSP Stream

FFmpeg establishes the RTSP session and receives the underlying RTP media packets.

The incoming media is demultiplexed into audio and video packets, preserving their timing information.

### 2. Creating Small MP4 Segments

Instead of decoding video frames and rendering them manually, the experiment repackages compressed media packets into small MP4 containers.

When the source codec is compatible with AVPlayer, this can potentially be accomplished without video transcoding.

Avoiding unnecessary decoding and re-encoding is one of the primary motivations behind the approach.

### 3. Feeding AVPlayer

As new segments become available, the application supplies them to the native playback pipeline.

The goal is to allow AVPlayer to consume an ongoing RTSP stream as a sequence of locally prepared media resources.

### 4. Continuous Playback

The main challenge is maintaining uninterrupted playback across segment boundaries.

This requires careful handling of:

- Audio and video timestamps
- Segment duration and keyframe alignment
- Playback buffering
- Continuity between segments
- Network jitter and packet loss
- End-to-end latency

The project investigates these challenges rather than presenting a complete production-ready solution.

## Why This Approach?

The experiment explores whether native AVPlayer playback can be combined with FFmpeg's flexible streaming and container capabilities.

Potential advantages include:

- **Native video rendering:** Retain Apple's playback and hardware-decoding infrastructure.
- **Client-side processing:** Avoid requiring a separate RTSP-to-HLS conversion server.
- **Minimal video processing:** Repackage compatible compressed video without transcoding.
- **Separation of responsibilities:** FFmpeg handles transport and packaging; AVPlayer handles playback.
- **Architectural flexibility:** Explore additional formats and streaming protocols through media adaptation.

## Current Status

**Experimental proof of concept.**

The repository demonstrates an approach to RTSP playback using FFmpeg and AVPlayer. It is not a complete RTSP player and should not be considered production-ready.

In particular, seamless playback across consecutive MP4 segments remains an important challenge.

## Building the Project

The original project uses FFmpeg 4.1.

1. Build FFmpeg using the provided script:

   ```bash
   thirdparty/ffmpeg/general/build-ffmpeg.sh
   ```

2. Open `RTSPAVPlayer.xcodeproj` in Xcode.
3. Build and run the sample application.
4. Configure an accessible RTSP source for testing.

The project was originally tested using a Wowza RTSP sample stream. Availability of that sample endpoint is not guaranteed.

Because the project relies on an older FFmpeg version, adjustments may be necessary for modern Xcode and iOS SDKs.

## Technical Challenges and Future Improvements

Several areas would be worth investigating further:

- **Fragmented MP4 and HLS:** Generate a continuously updated HLS playlist with fragmented MP4 segments instead of relying on independent MP4 playback items.
- **Timestamp continuity:** Preserve monotonic decoding and presentation timestamps across segment boundaries.
- **Low-latency buffering:** Balance playback stability against additional segment-generation latency.
- **Audio synchronization:** Maintain consistent audio/video timing during remuxing.
- **Recovery:** Handle interrupted RTSP sessions, missing packets, and stream reconnections.
- **Codec compatibility:** Detect media formats that require transcoding rather than simple repackaging.

A fragmented-MP4-based HLS pipeline would be a natural direction for further development, allowing AVPlayer to consume a continuous live playlist rather than managing separate playback items.

## Related Project: UPlayer

The broader idea of adapting media streams for Apple's native playback engine is also explored in [UPlayer](https://github.com/MaximKomlev/UPlayer).

UPlayer uses a modular, client-side processing architecture to make MPEG-DASH streams compatible with AVPlayer through HLS generation, resource loading, caching, and optional audio transcoding.

RTSPAVPlayer represents a separate, earlier experiment focused specifically on RTSP/RTP reception and MP4 segment generation.

## License

MIT License.
