package com.ggpark.byddashcam;

import android.content.Context;
import android.content.ContextWrapper;
import android.content.pm.PackageManager;

/**
 * Lớp bọc Context để truy cập API riêng của BYD.
 * Ghi đè các phương thức checkPermission luôn trả PERMISSION_GRANTED.
 */
final class VehicleContextWrapper extends ContextWrapper {
    VehicleContextWrapper(Context base) {
        super(base);
    }

    @Override
    public int checkPermission(String permission, int pid, int uid) {
        return PackageManager.PERMISSION_GRANTED;
    }

    @Override
    public int checkCallingPermission(String permission) {
        return PackageManager.PERMISSION_GRANTED;
    }

    @Override
    public int checkCallingOrSelfPermission(String permission) {
        return PackageManager.PERMISSION_GRANTED;
    }

    @Override
    public int checkSelfPermission(String permission) {
        return PackageManager.PERMISSION_GRANTED;
    }
}
