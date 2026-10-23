#include "CAndroidStudio.h"
#include <stdlib.h>
#include <string.h>

#ifdef __ANDROID__
#include <CAndroid.h>
#include <android/native_activity.h>
#include <jni.h>

extern void ada_studio_receive(int64_t request, const char *payload);

JNIEXPORT void JNICALL Java_org_adaengine_studio_StudioActivity_deliver(
    JNIEnv *env, jclass type, jlong request, jstring payload
) {
    (void)type;
    if (!payload) return;
    const char *value = (*env)->GetStringUTFChars(env, payload, NULL);
    if (value) {
        ada_studio_receive(request, value);
        (*env)->ReleaseStringUTFChars(env, payload, value);
    }
}

char *ada_studio_call(const char *action, const char *payload, int64_t request) {
    if (!ada_android_is_main_thread()) return NULL;
    ANativeActivity *activity = ada_android_activity();
    if (!activity) return NULL;
    JNIEnv *env = activity->env;
    jclass type = (*env)->GetObjectClass(env, activity->clazz);
    if (!type) return NULL;
    JNINativeMethod callback = {"deliver", "(JLjava/lang/String;)V", (void *)Java_org_adaengine_studio_StudioActivity_deliver};
    if ((*env)->RegisterNatives(env, type, &callback, 1) != JNI_OK) {
        if ((*env)->ExceptionCheck(env)) (*env)->ExceptionClear(env);
        (*env)->DeleteLocalRef(env, type);
        return NULL;
    }
    jmethodID method = (*env)->GetMethodID(env, type, "call", "(Ljava/lang/String;Ljava/lang/String;J)Ljava/lang/String;");
    char *result = NULL;
    if (method) {
        jstring name = (*env)->NewStringUTF(env, action);
        jstring data = (*env)->NewStringUTF(env, payload);
        if (name && data) {
            jstring response = (*env)->CallObjectMethod(env, activity->clazz, method, name, data, (jlong)request);
            if (!(*env)->ExceptionCheck(env) && response) {
                const char *value = (*env)->GetStringUTFChars(env, response, NULL);
                if (value) { result = strdup(value); (*env)->ReleaseStringUTFChars(env, response, value); }
            }
            if (response) (*env)->DeleteLocalRef(env, response);
        }
        if (name) (*env)->DeleteLocalRef(env, name);
        if (data) (*env)->DeleteLocalRef(env, data);
    }
    if ((*env)->ExceptionCheck(env)) (*env)->ExceptionClear(env);
    (*env)->DeleteLocalRef(env, type);
    return result;
}
#else
char *ada_studio_call(const char *action, const char *payload, int64_t request) {
    (void)action; (void)payload; (void)request;
    return NULL;
}
#endif

void ada_studio_free(char *value) { free(value); }
