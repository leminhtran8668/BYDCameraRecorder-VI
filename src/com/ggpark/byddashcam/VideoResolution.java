package com.ggpark.byddashcam;

public enum VideoResolution {
    ECONOMY(
            "economy",
            "Tiết kiệm · 320×240 mỗi · 640×480 ghép",
            320,
            240,
            600_000,
            1_500_000),
    STANDARD(
            "standard",
            "Tiêu chuẩn · 640×480 mỗi · 1280×960 ghép",
            640,
            480,
            1_200_000,
            3_000_000),
    HIGH(
            "high",
            "Cao · 960×720 mỗi · 1920×1440 ghép",
            960,
            720,
            2_200_000,
            5_000_000),
    NATIVE(
            "native",
            "Gốc chất lượng cao · 1280×960 mỗi · 2560×1920 ghép",
            1280,
            960,
            8_000_000,
            24_000_000);

    public static final VideoResolution DEFAULT = STANDARD;

    public final int cameraBitrate;
    public final int cameraHeight;
    public final int cameraWidth;
    public final int combinedBitrate;
    public final String id;
    public final String label;

    VideoResolution(
            String id,
            String label,
            int cameraWidth,
            int cameraHeight,
            int cameraBitrate,
            int combinedBitrate) {
        this.id = id;
        this.label = label;
        this.cameraWidth = cameraWidth;
        this.cameraHeight = cameraHeight;
        this.cameraBitrate = cameraBitrate;
        this.combinedBitrate = combinedBitrate;
    }

    public int combinedHeight() {
        return cameraHeight * 2;
    }

    public int combinedWidth() {
        return cameraWidth * 2;
    }

    public String dimensionsLabel() {
        return cameraWidth
                + "×"
                + cameraHeight
                + " each\n"
                + combinedWidth()
                + "×"
                + combinedHeight()
                + " combined";
    }

    public static VideoResolution fromId(String id) {
        for (VideoResolution resolution : values()) {
            if (resolution.id.equals(id)) {
                return resolution;
            }
        }
        return DEFAULT;
    }
}
