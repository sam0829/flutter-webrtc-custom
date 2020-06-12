package com.cloudwebrtc.webrtc.record;

import android.content.Context;
import android.media.MediaCodec;
import android.media.MediaFormat;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.Looper;
import android.util.Log;
import android.view.Surface;

//import com.cloudwebrtc.webrtc.speechnew.RecognizerHelper;

import org.webrtc.EglBase;
import org.webrtc.GlRectDrawer;
import org.webrtc.VideoFrame;
import org.webrtc.VideoFrameDrawer;
import org.webrtc.VideoSink;
import org.webrtc.audio.JavaAudioDeviceModule;
import org.webrtc.audio.JavaAudioDeviceModule.SamplesReadyCallback;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.plugin.common.EventChannel;

class AudioFileRenderer implements VideoSink, SamplesReadyCallback {
    private static final String TAG = "VideoFileRenderer";
    private final HandlerThread renderThread;
    private final Handler renderThreadHandler;
    private final HandlerThread audioThread;
    private final Handler audioThreadHandler;
    private int outputFileWidth = -1;
    private int outputFileHeight = -1;
    private ByteBuffer[] encoderOutputBuffers;
    private ByteBuffer[] audioInputBuffers;
    private ByteBuffer[] audioOutputBuffers;
    private EglBase eglBase;
    private EglBase.Context sharedContext;
    private VideoFrameDrawer frameDrawer;

    // TODO: these ought to be configurable as well
    private static final String MIME_TYPE = "video/avc";    // H.264 Advanced Video Coding
    private static final int FRAME_RATE = 30;               // 30fps
    private static final int IFRAME_INTERVAL = 5;           // 5 seconds between I-frames

    private MediaCodec encoder;
    private MediaCodec.BufferInfo bufferInfo, audioBufferInfo;
    private int trackIndex = -1;
    //private int audioTrackIndex;
    private boolean isRunning = true;
    private GlRectDrawer drawer;
    private Surface surface;
    private MediaCodec audioEncoder;
    private List<Byte> bytes = new ArrayList<>();
    EventChannel.EventSink eventSink;
    Context context;

    private volatile boolean muxerStarted = false;
    //private MediaMuxer mediaMuxer;

    AudioFileRenderer(final EglBase.Context sharedContext,
                      EventChannel.EventSink eventSink,
                      Context context) throws IOException {
        renderThread = new HandlerThread(TAG + "RenderThread");
        renderThread.start();
        renderThreadHandler = new Handler(renderThread.getLooper());

        audioThread = new HandlerThread(TAG + "AudioThread");
        audioThread.start();
        audioThreadHandler = new Handler(audioThread.getLooper());

        bufferInfo = new MediaCodec.BufferInfo();
        this.sharedContext = sharedContext;

        //audioTrackIndex = -1;
        this.eventSink = eventSink;
        this.context = context;

        /*client = new MicrophoneStreamRecognizeClient(context.getResources().openRawResource(R.raw.credentials), new IResults() {
            @Override
            public void onPartial(String text) {
                Log.e("PROTO", "@@@@@@@@@@@PARTIAL" + text);
            }

            @Override
            public void onFinal(String text) {
                Log.e("PROTO", "@@@@@@@@@@@FINAL" + text);
            }
        });*/
        /*client = new RecognizerHelper(context, new IResults() {
            @Override
            public void onPartial(String text) {
                Log.e("PROTO", "@@@@@@@@@@@PARTIAL" + text);
            }

            @Override
            public void onFinal(String text) {
                Log.e("PROTO", "@@@@@@@@@@@FINAL" + text);
            }
        });*/
    }

    @Override
    public void onFrame(VideoFrame frame) {

    }

    /**
     * Release all resources. All already posted frames will be rendered first.
     */
    void release() {
        isRunning = false;
        if (audioThreadHandler != null)
            audioThreadHandler.post(() -> {
                if (audioEncoder != null) {
                    audioEncoder.stop();
                    audioEncoder.release();
                }
                audioThread.quit();
            });
    }

    private long presTime = 0L;
    private int count = 0;

    boolean isFirstByte = true;

    @Override
    public void onWebRtcAudioRecordSamplesReady(JavaAudioDeviceModule.AudioSamples audioSamples) {
        //if (true) return;
        byte[] bytes = audioSamples.getData();
        if (bytes != null) {
            Log.e("TAG", "///// Bytes received: " + bytes.length);
            Map<String, Object> audioData = new HashMap<>();
            audioData.put("bytes", bytes);
            audioData.put("sample_rate", audioSamples.getSampleRate());
            new Handler(Looper.getMainLooper())
                    .post(new Runnable() {
                        @Override
                        public void run() {
                            eventSink.success(audioData);
                        }
                    });
            /*Log.e("/////////AudioTrackTEST", "onAudioSampleReceived,"
                    + audioSamples.getData().length + " with sample rate " + audioSamples.getSampleRate());
            if (count != -1) {
                if (count < 100000) {
                    for (int i = 0; i < bytes.length; i++) {
                        this.bytes.add(bytes[i]);
                    }
                    count++;

                    if (isFirstByte) {
                        isFirstByte = false;
                        client.startRecognizing(44100);
                    }
                    try {
                        client.recognize(bytes, bytes.length, 44100);
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                } else {
                    count = -1;
                    try {
                        //client.finishRecognizing();
                        //client.destroy();
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                }
            }*/
        } else {
            Log.e("/////////AudioTrackTEST", "onAudioSampleReceived, NULL BYTESSSSSS");

        }
        /*audioThreadHandler.post(() -> {
            if (audioEncoder == null) try {
                audioEncoder = MediaCodec.createEncoderByType("audio/mp4a-latm");
                MediaFormat format = new MediaFormat();
                format.setString(MediaFormat.KEY_MIME, "audio/mp4a-latm");
                format.setInteger(MediaFormat.KEY_CHANNEL_COUNT, audioSamples.getChannelCount());
                format.setInteger(MediaFormat.KEY_SAMPLE_RATE, audioSamples.getSampleRate());
                format.setInteger(MediaFormat.KEY_BIT_RATE, 64 * 1024);
                format.setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC);
                audioEncoder.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE);
                audioEncoder.start();
                audioInputBuffers = audioEncoder.getInputBuffers();
                audioOutputBuffers = audioEncoder.getOutputBuffers();
            } catch (IOException exception) {
                Log.wtf(TAG, exception);
            }
            int bufferIndex = audioEncoder.dequeueInputBuffer(0);
            if (bufferIndex >= 0) {
                ByteBuffer buffer = audioInputBuffers[bufferIndex];
                buffer.clear();
                byte[] data = audioSamples.getData();
                buffer.put(data);
                audioEncoder.queueInputBuffer(bufferIndex, 0, data.length, presTime, 0);
                presTime += data.length * 125 / 12; // 1000000 microseconds / 48000hz / 2 bytes
            }
            drainAudio();
        });*/
    }

    private void drainAudio() {
        if (audioBufferInfo == null)
            audioBufferInfo = new MediaCodec.BufferInfo();
        while (true) {
            int encoderStatus = audioEncoder.dequeueOutputBuffer(audioBufferInfo, 10000);
            if (encoderStatus == MediaCodec.INFO_TRY_AGAIN_LATER) {
                break;
            } else if (encoderStatus == MediaCodec.INFO_OUTPUT_BUFFERS_CHANGED) {
                // not expected for an encoder
                audioOutputBuffers = audioEncoder.getOutputBuffers();
                Log.w(TAG, "encoder output buffers changed");
            } else if (encoderStatus == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                // not expected for an encoder
                MediaFormat newFormat = audioEncoder.getOutputFormat();

                Log.w(TAG, "encoder output format changed: " + newFormat);
                //audioTrackIndex = mediaMuxer.addTrack(newFormat);
                if (trackIndex != -1 && !muxerStarted) {
                    //  mediaMuxer.start();
                    muxerStarted = true;
                }
                if (!muxerStarted)
                    break;
            } else if (encoderStatus < 0) {
                Log.e(TAG, "unexpected result fr om encoder.dequeueOutputBuffer: " + encoderStatus);
            } else { // encoderStatus >= 0
                try {
                    ByteBuffer encodedData = audioOutputBuffers[encoderStatus];
                    if (encodedData == null) {
                        Log.e(TAG, "encoderOutputBuffer " + encoderStatus + " was null");
                        break;
                    }
                    // It's usually necessary to adjust the ByteBuffer values to match BufferInfo.
                    encodedData.position(audioBufferInfo.offset);
                    encodedData.limit(audioBufferInfo.offset + audioBufferInfo.size);

                    isRunning = isRunning && (audioBufferInfo.flags & MediaCodec.BUFFER_FLAG_END_OF_STREAM) == 0;
                    audioEncoder.releaseOutputBuffer(encoderStatus, false);
                    if ((audioBufferInfo.flags & MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                        break;
                    }
                } catch (Exception e) {
                    Log.wtf(TAG, e);
                    break;
                }
            }
        }
    }
}
