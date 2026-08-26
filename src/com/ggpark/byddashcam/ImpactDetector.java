package com.ggpark.byddashcam;

import android.content.Context;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.util.Log;

/**
 * Bộ phát hiện va chạm dùng gia tốc kế.
 * Lấy mẫu SENSOR_DELAY_NORMAL (~5Hz) để giảm tiêu hao pin.
 * Sau phát hiện, chặn kích hoạt lại trong MIN_RETRIGGER_NANOS (30 giây).
 */
public final class ImpactDetector implements SensorEventListener {
    public interface Listener {
        void onImpactDetected(float gForce);
    }

    private static final long MIN_RETRIGGER_NANOS = 30_000_000_000L;
    private static final String TAG = "BYDCamera";

    private SensorManager sensorManager;
    private Listener listener;
    private float thresholdG;
    private long lastTriggerNanos = 0L;

    public void start(Context context, float thresholdG, Listener listener) {
        this.thresholdG = thresholdG;
        this.listener = listener;
        sensorManager =
                (SensorManager) context.getSystemService(Context.SENSOR_SERVICE);
        if (sensorManager == null) {
            Log.w(TAG, "ImpactDetector: SensorManager unavailable");
            return;
        }
        Sensor accelerometer =
                sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER);
        if (accelerometer == null) {
            Log.w(TAG, "ImpactDetector: accelerometer not available");
            return;
        }
        sensorManager.registerListener(
                this,
                accelerometer,
                SensorManager.SENSOR_DELAY_NORMAL);
        Log.i(TAG, "ImpactDetector started, threshold=" + thresholdG + "G");
    }

    public void stop() {
        if (sensorManager != null) {
            sensorManager.unregisterListener(this);
            sensorManager = null;
        }
        listener = null;
        Log.i(TAG, "ImpactDetector stopped");
    }

    public void setThreshold(float thresholdG) {
        this.thresholdG = thresholdG;
    }

    @Override
    public void onSensorChanged(SensorEvent event) {
        float x = event.values[0];
        float y = event.values[1];
        float z = event.values[2];
        double magnitude = Math.sqrt((double) x * x + (double) y * y + (double) z * z);
        float gForce = (float) (magnitude / SensorManager.GRAVITY_EARTH);
        if (gForce < thresholdG) {
            return;
        }
        long now = System.nanoTime();
        if (now - lastTriggerNanos < MIN_RETRIGGER_NANOS) {
            return;
        }
        lastTriggerNanos = now;
        Log.i(TAG, "Impact detected: " + gForce + "G (threshold=" + thresholdG + "G)");
        Listener l = listener;
        if (l != null) {
            l.onImpactDetected(gForce);
        }
    }

    @Override
    public void onAccuracyChanged(Sensor sensor, int accuracy) {
    }
}
