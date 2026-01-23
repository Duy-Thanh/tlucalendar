#include <jni.h>
#include <string>
#include <vector>
#include <map>
#include <android/log.h>

#include "client/crashpad_client.h"
#include "client/crash_report_database.h"
#include "client/settings.h"

#define TAG "NekkoCrashpad"

extern "C" {

JNIEXPORT jboolean JNICALL
Java_com_nekkochan_tlucalendar_CrashpadService_initCrashpadNative(
        JNIEnv *env,
        jobject /* this */,
        jstring jHandlerPath,
        jstring jDataDir,
        jstring jUploadUrl) {

    const char *handler_path = env->GetStringUTFChars(jHandlerPath, 0);
    const char *data_dir = env->GetStringUTFChars(jDataDir, 0);
    const char *url = env->GetStringUTFChars(jUploadUrl, 0);

    base::FilePath handler(handler_path);
    base::FilePath database(data_dir);
    base::FilePath metrics(data_dir);
    std::string url_str(url);

    env->ReleaseStringUTFChars(jHandlerPath, handler_path);
    env->ReleaseStringUTFChars(jDataDir, data_dir);
    env->ReleaseStringUTFChars(jUploadUrl, url);

    crashpad::CrashpadClient client;

    // Params for the handler
    std::map<std::string, std::string> annotations;
    annotations["format"] = "minidump";
    annotations["platform"] = "android";

    std::vector<std::string> arguments;
    arguments.push_back("--no-rate-limit");

    bool success = client.StartHandlerAtCrash(
            handler,
            database,
            metrics,
            url_str,
            annotations,
            arguments
    );

    if (success) {
        __android_log_print(ANDROID_LOG_INFO, TAG, "Crashpad initialized successfully");
    } else {
        __android_log_print(ANDROID_LOG_ERROR, TAG, "Crashpad failed to initialize");
    }

    return success;
}

}
