package com.cloudwebrtc.webrtc.record;

import android.content.Context;
import android.util.Log;

import com.cloudwebrtc.webrtc.utils.EglUtils;

import org.webrtc.VideoTrack;

import java.io.IOException;

import io.flutter.plugin.common.EventChannel;

public class AudioRecordImpl {
    private final Integer id;
    //private final VideoTrack videoTrack;
    private boolean mIsRunning;
    private AudioFileRenderer mAudioFileRenderer;
    private AudioSamplesInterceptor outputSamplesInterceptor;
    EventChannel.EventSink eventSink;

    public AudioRecordImpl(Integer id, AudioSamplesInterceptor audioDeviceModule,
                           EventChannel.EventSink eventSink
    ) {
        this.id = id;
        //this.videoTrack = videoTrack;
        outputSamplesInterceptor = audioDeviceModule;
        this.eventSink = eventSink;
    }

    public void startRecording(Context context) throws IOException {
        if (mIsRunning) return;
        mIsRunning = true;
        Log.e("///////////", "start recording called");

        mAudioFileRenderer = new AudioFileRenderer(
                EglUtils.getRootEglBaseContext(),
                eventSink,
                context
        );
        try {
            outputSamplesInterceptor.attachCallback(1, mAudioFileRenderer);
        } catch (Exception e) {
            Log.e("///////////", "Error is " + e.getMessage());
            e.printStackTrace();
        }

    }

    public void stopRecording() {
        mIsRunning = false;
    }
}
