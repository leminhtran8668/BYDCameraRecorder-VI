package com.ggpark.byddashcam;

/**
 * Hồ sơ AVMCamera dùng chung (dự phòng).
 * Dùng khi tự nhận diện thất bại hoặc người dùng chọn "Mẫu không xác định".
 * Cùng mặc định với Atto 3 nhưng ID riêng để hiện lựa chọn thủ công.
 */
public final class GenericAvmProfile implements VehicleProfile {
    public static final String MODEL_ID = "generic";

    private final int cameraId;
    private final int viewIndex;
    private final int cameraCount;
    private final int cameraWidth;
    private final int cameraHeight;

    /** 기본 생성자: Atto 3 검증값을 기본으로 사용 */
    public GenericAvmProfile() {
        this(0, 0, 4, 1280, 960);
    }

    public GenericAvmProfile(
            int cameraId,
            int viewIndex,
            int cameraCount,
            int cameraWidth,
            int cameraHeight) {
        this.cameraId = cameraId;
        this.viewIndex = viewIndex;
        this.cameraCount = cameraCount;
        this.cameraWidth = cameraWidth;
        this.cameraHeight = cameraHeight;
    }

    @Override
    public String modelId() {
        return MODEL_ID;
    }

    @Override
    public String displayName() {
        return "Mẫu không xác định (dùng chung)";
    }

    @Override
    public int avmCameraId() {
        return cameraId;
    }

    @Override
    public int avmViewIndex() {
        return viewIndex;
    }

    @Override
    public int cameraCount() {
        return cameraCount;
    }

    @Override
    public int sourceCameraWidth() {
        return cameraWidth;
    }

    @Override
    public int sourceCameraHeight() {
        return cameraHeight;
    }

    @Override
    public String[] defaultCameraNames() {
        String[] names = new String[cameraCount];
        for (int i = 0; i < cameraCount; i++) {
            names[i] = "Camera " + (i + 1);
        }
        return names;
    }
}
