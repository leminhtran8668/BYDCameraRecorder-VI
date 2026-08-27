package com.ggpark.byddashcam;

/**
 * Hồ sơ cấu hình AVMCamera theo mẫu xe.
 * Trừu tượng hóa ID camera, view index, độ phân giải có thể khác theo mẫu.
 */
public interface VehicleProfile {
    /** Định danh duy nhất dùng lưu cài đặt (vd: "atto3") */
    String modelId();

    /** Tên mẫu hiển thị trên UI (vd: "BYD Atto 3") */
    String displayName();

    /** ID camera truyền vào AVMCamera.open() */
    int avmCameraId();

    /** enablePreviewCallback()에 전달할 뷰 인덱스 */
    int avmViewIndex();

    /** 카메라 개수 */
    int cameraCount();

    /** 단일 카메라의 소스 너비 (픽셀) */
    int sourceCameraWidth();

    /** 단일 카메라의 소스 높이 (픽셀) */
    int sourceCameraHeight();

    /** 카메라별 기본 이름 배열 (cameraCount() 길이와 일치해야 함) */
    String[] defaultCameraNames();
}
