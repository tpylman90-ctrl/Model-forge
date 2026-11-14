package org.modelforge.files;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.util.Log;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.Collections;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** SAF document bridge. No URI-to-filesystem-path conversion or broad storage permission. */
public final class ModelForgeFiles extends GodotPlugin {
    private static final String TAG = "ModelForgeFiles";
    private static final int REQUEST_OPEN_MODEL = 18450;
    private static final int REQUEST_OPEN_IMAGE = 18451;
    private static final int REQUEST_SAVE_MODEL = 18452;
    private static final long MAX_IMPORT_BYTES = 768L * 1024L * 1024L;
    private final ExecutorService io = Executors.newSingleThreadExecutor();
    private volatile String pendingExportPath = "";

    public ModelForgeFiles(Godot godot) { super(godot); }

    @Override public String getPluginName() { return "ModelForgeFiles"; }

    @Override public Set<SignalInfo> getPluginSignals() {
        return Collections.singleton(new SignalInfo("file_result", String.class, String.class, String.class));
    }

    @UsedByGodot
    public void openDocument(String kind) {
        final boolean photo = "photo".equals(kind);
        final int request = photo ? REQUEST_OPEN_IMAGE : REQUEST_OPEN_MODEL;
        runOnHostThread(() -> {
            Activity activity = getActivity();
            if (activity == null) {
                notifyResult(photo ? "photo" : "model", "", "error: Android activity unavailable");
                return;
            }
            try {
                Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
                intent.addCategory(Intent.CATEGORY_OPENABLE);
                intent.setType(photo ? "image/*" : "*/*");
                intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                activity.startActivityForResult(intent, request);
            } catch (Exception e) {
                Log.e(TAG, "Document picker could not launch", e);
                notifyResult(photo ? "photo" : "model", "", "error: " + e.getMessage());
            }
        });
    }

    @UsedByGodot
    public void saveDocument(String sourcePath, String suggestedFilename) {
        if (sourcePath == null || sourcePath.isEmpty()) {
            notifyResult("save", "", "error: No GLB data to save");
            return;
        }
        pendingExportPath = sourcePath;
        runOnHostThread(() -> {
            Activity activity = getActivity();
            if (activity == null) {
                notifyResult("save", "", "error: Android activity unavailable");
                return;
            }
            try {
                Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
                intent.addCategory(Intent.CATEGORY_OPENABLE);
                intent.setType("model/gltf-binary");
                intent.putExtra(Intent.EXTRA_TITLE,
                    suggestedFilename == null || suggestedFilename.isEmpty()
                    ? "model-forge-edited.glb" : suggestedFilename);
                intent.addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
                activity.startActivityForResult(intent, REQUEST_SAVE_MODEL);
            } catch (Exception e) {
                Log.e(TAG, "Save picker could not launch", e);
                notifyResult("save", "", "error: " + e.getMessage());
            }
        });
    }

    @Override public void onMainActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode != REQUEST_OPEN_MODEL && requestCode != REQUEST_OPEN_IMAGE
                && requestCode != REQUEST_SAVE_MODEL) {
            return;
        }
        final String kind = requestCode == REQUEST_OPEN_IMAGE ? "photo"
            : requestCode == REQUEST_SAVE_MODEL ? "save" : "model";
        if (resultCode == Activity.RESULT_CANCELED) {
            notifyResult(kind, "", "canceled");
            return;
        }
        if (resultCode != Activity.RESULT_OK || data == null || data.getData() == null) {
            notifyResult(kind, "", "error: Android picker returned no document");
            return;
        }
        final Uri uri = data.getData();
        io.execute(() -> {
            try {
                if (requestCode == REQUEST_SAVE_MODEL) {
                    exportDocument(uri);
                } else {
                    importDocument(uri, kind);
                }
            } catch (Exception e) {
                Log.e(TAG, "Document operation failed: " + kind, e);
                notifyResult(kind, "", "error: " + (e.getMessage() == null
                    ? e.getClass().getSimpleName() : e.getMessage()));
            }
        });
    }

    private void importDocument(Uri uri, String kind) throws Exception {
        final String extension = "photo".equals(kind) ? ".image" : ".glb";
        final File workDir = new File(getContext().getCacheDir(), "model_forge_imports");
        if (!workDir.isDirectory() && !workDir.mkdirs()) {
            throw new IllegalStateException("Cannot create import cache");
        }
        final File output = new File(workDir, UUID.randomUUID() + extension);
        long copied = 0;
        boolean finished = false;
        try (InputStream input = getContext().getContentResolver().openInputStream(uri);
             FileOutputStream file = new FileOutputStream(output)) {
            if (input == null) {
                throw new IllegalStateException("Document provider returned empty input stream");
            }
            byte[] buffer = new byte[64 * 1024];
            int n;
            while ((n = input.read(buffer)) != -1) {
                copied += n;
                if (copied > MAX_IMPORT_BYTES) {
                    throw new IllegalStateException("File exceeds 768 MB import limit");
                }
                file.write(buffer, 0, n);
            }
            file.flush();
            finished = true;
        } finally {
            if (!finished) {
                //noinspection ResultOfMethodCallIgnored
                output.delete();
            }
        }
        if (copied < 12) {
            //noinspection ResultOfMethodCallIgnored
            output.delete();
            throw new IllegalStateException("Selected file is empty or incomplete");
        }
        Log.i(TAG, "Import copied " + copied + " bytes to app-private cache");
        notifyResult(kind, output.getAbsolutePath(), "ok");
    }

    private void exportDocument(Uri uri) throws Exception {
        File source = new File(pendingExportPath);
        if (!source.isFile() || source.length() < 12) {
            throw new IllegalStateException("Export source unavailable");
        }
        try (FileInputStream input = new FileInputStream(source);
             OutputStream output = getContext().getContentResolver().openOutputStream(uri, "wt")) {
            if (output == null) {
                throw new IllegalStateException("Document provider refused write access");
            }
            byte[] buffer = new byte[64 * 1024];
            int n;
            while ((n = input.read(buffer)) != -1) {
                output.write(buffer, 0, n);
            }
            output.flush();
        }
        Log.i(TAG, "GLB export written via ContentResolver");
        notifyResult("save", uri.toString(), "ok");
    }

    private void notifyResult(String kind, String path, String status) {
        emitSignal("file_result", kind, path, status);
    }

    @Override public void onMainDestroy() {
        io.shutdown();
    }
}
