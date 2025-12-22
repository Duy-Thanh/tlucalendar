#include <jni.h>
#include <string>
#include <vector>
#include <cstring>
#include "yyjson.h"

extern "C" {

    // --- Data Structures ---
    
    struct BookingStatusNative {
        int id;
        char* name;
    };

    struct ExamPeriodNative {
        int id;
        char* examPeriodCode;
        char* name;
        long long startDate;
        long long endDate;
        int numberOfExamDays;
        struct BookingStatusNative bookingStatus;
    };

    struct ExamScheduleNative {
        int id;
        char* name;
        int displayOrder;
        bool voided;
        int examPeriodsCount;
        struct ExamPeriodNative* examPeriods; // Array
    };

    // Result container to easily pass array back
    struct ExamScheduleResult {
        int count;
        struct ExamScheduleNative* schedules; // Array
        char* errorMessage; // Null if success
    };

    // --- Helper Functions ---
    
    char* safe_strdup(const char* s) {
        if (!s) return nullptr;
        return strdup(s);
    }

    // --- Exported Functions ---

    __attribute__((visibility("default"))) __attribute__((used))
    const char* get_yyjson_version() {
        return YYJSON_VERSION_STRING;
    }

    __attribute__((visibility("default"))) __attribute__((used))
    void free_exam_schedule_result(struct ExamScheduleResult* result) {
        if (!result) return;
        if (result->schedules) {
            for (int i = 0; i < result->count; ++i) {
                struct ExamScheduleNative* schedule = &result->schedules[i];
                free(schedule->name);
                if (schedule->examPeriods) {
                    for (int j = 0; j < schedule->examPeriodsCount; ++j) {
                        struct ExamPeriodNative* period = &schedule->examPeriods[j];
                        free(period->examPeriodCode);
                        free(period->name);
                        free(period->bookingStatus.name);
                    }
                    free(schedule->examPeriods);
                }
            }
            free(result->schedules);
        }
        free(result->errorMessage);
        free(result);
    }

    __attribute__((visibility("default"))) __attribute__((used))
    struct ExamScheduleResult* parse_exam_schedules(const char* json_str) {
        struct ExamScheduleResult* result = (struct ExamScheduleResult*)calloc(1, sizeof(struct ExamScheduleResult));
        if (!json_str) {
            result->errorMessage = strdup("Null JSON string");
            return result;
        }

        yyjson_doc *doc = yyjson_read(json_str, strlen(json_str), 0);
        if (!doc) {
            result->errorMessage = strdup("Failed to parse JSON");
            return result;
        }

        yyjson_val *root = yyjson_doc_get_root(doc);
        if (!yyjson_is_arr(root)) {
             result->errorMessage = strdup("Root is not an array");
             yyjson_doc_free(doc);
             return result;
        }

        result->count = (int)yyjson_arr_size(root);
        result->schedules = (struct ExamScheduleNative*)calloc(result->count, sizeof(struct ExamScheduleNative));

        size_t idx, max;
        yyjson_val *item;
        yyjson_arr_foreach(root, idx, max, item) {
            struct ExamScheduleNative* schedule = &result->schedules[idx];
            
            schedule->id = yyjson_get_int(yyjson_obj_get(item, "id"));
            schedule->name = safe_strdup(yyjson_get_str(yyjson_obj_get(item, "name")));
            schedule->displayOrder = yyjson_get_int(yyjson_obj_get(item, "displayOrder"));
            schedule->voided = yyjson_get_bool(yyjson_obj_get(item, "voided"));
            
            yyjson_val *periods = yyjson_obj_get(item, "examPeriods");
            if (yyjson_is_arr(periods)) {
                schedule->examPeriodsCount = (int)yyjson_arr_size(periods);
                schedule->examPeriods = (struct ExamPeriodNative*)calloc(schedule->examPeriodsCount, sizeof(struct ExamPeriodNative));
                
                size_t p_idx, p_max;
                yyjson_val *p_item;
                yyjson_arr_foreach(periods, p_idx, p_max, p_item) {
                     struct ExamPeriodNative* period = &schedule->examPeriods[p_idx];
                     period->id = yyjson_get_int(yyjson_obj_get(p_item, "id"));
                     period->examPeriodCode = safe_strdup(yyjson_get_str(yyjson_obj_get(p_item, "examPeriodCode")));
                     period->name = safe_strdup(yyjson_get_str(yyjson_obj_get(p_item, "name")));
                     period->startDate = yyjson_get_int(yyjson_obj_get(p_item, "startDate"));
                     period->endDate = yyjson_get_int(yyjson_obj_get(p_item, "endDate"));
                     period->numberOfExamDays = yyjson_get_int(yyjson_obj_get(p_item, "numberOfExamDays"));
                     
                     yyjson_val *status = yyjson_obj_get(p_item, "bookingStatus");
                     if (status) {
                        period->bookingStatus.id = yyjson_get_int(yyjson_obj_get(status, "id"));
                        period->bookingStatus.name = safe_strdup(yyjson_get_str(yyjson_obj_get(status, "name")));
                     }
                }
            }
        }

        yyjson_doc_free(doc);
        return result;
    }
    
    // Legacy test function
    __attribute__((visibility("default"))) __attribute__((used))
    int parse_json_test(const char* json_str) {
         // ... (keep if needed, or remove)
         return 0;
    }

}

extern "C" JNIEXPORT jstring JNICALL
Java_com_nekkochan_tlucalendar_MainActivity_stringFromJNI(
        JNIEnv* env,
        jobject /* this */) {
    std::string hello = "Hello from C++ with yyjson " YYJSON_VERSION_STRING;
    return env->NewStringUTF(hello.c_str());
}
