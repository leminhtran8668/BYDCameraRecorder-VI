package com.ggpark.byddashcam;

/** Snapshot dữ liệu vị trí GPS. Đối tượng bất biến. */
public final class GpsFix {
    /** Giá trị sentinel khi không có tín hiệu GPS */
    public static final GpsFix UNAVAILABLE =
            new GpsFix(0.0, 0.0, 0.0, 0.0, 0L, false);

    public final double speedKmh;
    public final double latitude;
    public final double longitude;
    public final double altitude;
    /** Thời điểm fix (theo System.currentTimeMillis) */
    public final long fixTimeMs;
    /** fix 나이가 5초 이내이면 true */
    public final boolean fresh;

    public GpsFix(
            double speedKmh,
            double latitude,
            double longitude,
            double altitude,
            long fixTimeMs,
            boolean fresh) {
        this.speedKmh = speedKmh;
        this.latitude = latitude;
        this.longitude = longitude;
        this.altitude = altitude;
        this.fixTimeMs = fixTimeMs;
        this.fresh = fresh;
    }

    public boolean isAvailable() {
        return this != UNAVAILABLE && fixTimeMs > 0L;
    }
}
