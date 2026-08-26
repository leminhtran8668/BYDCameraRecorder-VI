package com.ggpark.byddashcam;

/**
 * Hồ sơ camera BYD Atto 3.
 * Dựa trên giá trị đã kiểm chứng từ app tham chiếu (GHDanielG).
 */
public final class Atto3Profile implements VehicleProfile {
    public static final String MODEL_ID = "atto3";

    @Override
    public String modelId() {
        return MODEL_ID;
    }

    @Override
    public String displayName() {
        return "BYD Atto 3";
    }

    @Override
    public int avmCameraId() {
        return 0;
    }

    @Override
    public int avmViewIndex() {
        return 0;
    }

    @Override
    public int cameraCount() {
        return 4;
    }

    @Override
    public int sourceCameraWidth() {
        return 1280;
    }

    @Override
    public int sourceCameraHeight() {
        return 960;
    }

    @Override
    public String[] defaultCameraNames() {
        return new String[]{"Front", "Rear", "Left", "Right"};
    }
}
