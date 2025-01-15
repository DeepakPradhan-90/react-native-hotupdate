package com.deepak.pradhan.hotupdate;

import android.app.Application;
import android.content.Context;
import android.content.SharedPreferences;
import android.util.Log;

import androidx.annotation.NonNull;

import com.google.android.gms.tasks.OnFailureListener;
import com.google.android.gms.tasks.OnSuccessListener;
import com.google.firebase.storage.FileDownloadTask;
import com.google.firebase.storage.FirebaseStorage;
import com.google.firebase.storage.StorageReference;

import java.io.File;
import java.io.IOException;

public class HotUpdate {
    private final Application mApplication;
    private final SharedPreferences mSharedPreference;
    private static final String DEFAULT_JS_BUNDLE_NAME = "index.android.bundle";
    private static final String ASSETS_BUNDLE_PREFIX = "assets://";
    private static final String UPDATE_VERSION_KEY = "HBHotUpdateVersion";
    private static final String UPDATE_BUNDLE_HASH = "HBHotUpdateBundleHash";
    private static final String UPDATE_DIRECTORY_NAME = "HotUpdate";
    private static final String DOWNLOAD_DIRECTORY_NAME = "temp";
    private static final String DEFAULT_DOWNLOAD_FILE_NAME = "bundle.zip";

    public HotUpdate(Application application) {
        this.mApplication = application;
        this.mSharedPreference = application.getSharedPreferences(BuildConfig.APPLICATION_ID + UPDATE_DIRECTORY_NAME,
                Context.MODE_PRIVATE);
    }

    public String getJSBundleFile() {
        String updateDirPath = FileUtils.appendPathComponent(mApplication.getFilesDir().getAbsolutePath(), "HotUpdate");
        String updateVersion = mSharedPreference.getString(UPDATE_VERSION_KEY, null);
        String bundleHash = mSharedPreference.getString(UPDATE_BUNDLE_HASH, null);
        String updateBundleDirPath = FileUtils.appendPathComponent(updateDirPath, updateVersion);
        String updateBundlePath = FileUtils.appendPathComponent(updateBundleDirPath, DEFAULT_JS_BUNDLE_NAME);
        if (FileUtils.fileAtPathExists(updateBundlePath)) {
            String updateBundleHash = FileUtils.getSHA256HashFromFile(updateBundlePath);
            if (updateBundleHash.equalsIgnoreCase(bundleHash)) {
                return updateBundlePath;
            } else {
                FileUtils.deleteFileAtPathSilently(updateDirPath);
                SharedPreferences.Editor editor = mSharedPreference.edit();
                editor.remove(UPDATE_VERSION_KEY);
                editor.remove(UPDATE_BUNDLE_HASH);
                editor.apply();
            }
        }
        return ASSETS_BUNDLE_PREFIX + DEFAULT_JS_BUNDLE_NAME;
    }

    public void getUpdatedBundle(String version, String archiveHash, String bundleHash) throws IOException {
        String updateDirPath = FileUtils.appendPathComponent(mApplication.getFilesDir().getAbsolutePath(), UPDATE_DIRECTORY_NAME);
        String updateBundleDirPath = FileUtils.appendPathComponent(updateDirPath, version);
        String updateBundleFile = FileUtils.appendPathComponent(updateBundleDirPath, DEFAULT_JS_BUNDLE_NAME);
        if (FileUtils.fileAtPathExists(updateBundleFile)) {
            return;
        }
        //Remove any previous downloads
        FileUtils.deleteFileAtPathSilently(updateDirPath);
        // Get a reference to the storage service using the default Firebase App
        FirebaseStorage storage = FirebaseStorage.getInstance();
        // Create a storage reference from our app
        StorageReference storageRef = storage.getReference();
        String appVersion = BuildConfig.VERSION_NAME;
        // Create a reference with an initial file path and name
        StorageReference pathReference = storageRef.child(UPDATE_DIRECTORY_NAME+"/android/"+appVersion+"/"+version+"/"+DEFAULT_DOWNLOAD_FILE_NAME);

        String downloadTempPath = FileUtils.appendPathComponent(mApplication.getFilesDir().getAbsolutePath(), DOWNLOAD_DIRECTORY_NAME);
        File localFile = new File(downloadTempPath);

        pathReference.getFile(localFile).addOnSuccessListener(new OnSuccessListener<FileDownloadTask.TaskSnapshot>() {
            @Override
            public void onSuccess(FileDownloadTask.TaskSnapshot taskSnapshot) {
                try {
                    String hash = FileUtils.getSHA256HashFromFile(FileUtils.appendPathComponent(downloadTempPath, DEFAULT_DOWNLOAD_FILE_NAME));
                    if (hash.equalsIgnoreCase(archiveHash)) {
                        FileUtils.unzipFile(localFile, updateBundleDirPath);
                        String unzippedBundleHash = FileUtils.getSHA256HashFromFile(FileUtils.appendPathComponent(updateBundleDirPath, DEFAULT_JS_BUNDLE_NAME));
                        if (unzippedBundleHash.equalsIgnoreCase(bundleHash)) {
                            SharedPreferences.Editor editor = mSharedPreference.edit();
                            editor.putString(version, UPDATE_VERSION_KEY);
                            editor.putString(bundleHash, UPDATE_BUNDLE_HASH);
                            editor.apply();
                        } else {
                            FileUtils.deleteFileAtPathSilently(updateDirPath);
                        }
                    }
                    FileUtils.deleteFileAtPathSilently(downloadTempPath);
                } catch (IOException e) {
                    throw new RuntimeException(e);
                }
            }
        }).addOnFailureListener(new OnFailureListener() {
            @Override
            public void onFailure(@NonNull Exception exception) {
                Log.e("DOWNLOAD_ERROR", exception.getLocalizedMessage(), exception);
            }
        });
    }
}
