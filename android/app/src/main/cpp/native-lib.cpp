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
    
// --- ExamRoom Structs ---
    struct ExamRoomNative {
        int id;
        char* subjectName;
        char* examPeriodCode;
        char* examCode;
        char* studentCode;
        long long examDate; // Milliseconds
        char* examTime;
        char* roomName;
        char* roomBuilding;
        char* examMethod;
        char* notes;
        int numberExpectedStudent;
    };

    struct ExamRoomResult {
        int count;
        struct ExamRoomNative* rooms;
        char* errorMessage;
    };

    // --- Exported Helper for Freeing ExamRoomResult ---
    __attribute__((visibility("default"))) __attribute__((used))
    void free_exam_room_result(struct ExamRoomResult* result) {
         if (!result) return;
         if (result->rooms) {
             for (int i = 0; i < result->count; ++i) {
                 struct ExamRoomNative* room = &result->rooms[i];
                 free(room->subjectName);
                 free(room->examPeriodCode);
                 free(room->examCode);
                 free(room->studentCode);
                 free(room->examTime);
                 free(room->roomName);
                 free(room->roomBuilding);
                 free(room->examMethod);
                 free(room->notes);
             }
             free(result->rooms);
         }
         free(result->errorMessage);
         free(result);
    }
    
    // --- Helper for Time Parsing ---
    // Tries to extract "HH:mm-HH:mm" or "HH-HH" from roomCode
    // Example: "CSE406_08-11-2025_10-12_325-A2" -> "10-12"
    // Example: "SomeCode_Date_07:00-09:00_Room" -> "07:00-09:00"
    char* extract_time_from_room_code(const char* roomCode) {
        if (!roomCode) return nullptr;
        
        // We will tokenize by '_'
        char* copy = strdup(roomCode);
        char* token = strtok(copy, "_");
        while (token != nullptr) {
            // Check if token looks like time range
            // Pattern: start with digit, contains dash '-', maybe colon ':'
            // Minimal check: digit...-digit...
            
            int len = strlen(token);
            if (len >= 3) { // min "1-2"
                bool hasDash = false;
                bool firstIsDigit = (token[0] >= '0' && token[0] <= '9');
                
                if (firstIsDigit) {
                     for(int i=0; i<len; i++) {
                         if (token[i] == '-') {
                             hasDash = true;
                             break;
                         }
                     }
                }
                
                // Refined check: ensure it's not a date (Dates usually have 2 dashes like dd-mm-yyyy, or 2 slashes)
                // Time usually has 1 dash connecting two time points. 
                // But dates in this system might be "08-11-2025".
                // Let's count dashes.
                if (hasDash && firstIsDigit) {
                    int dashCount = 0;
                     for(int i=0; i<len; i++) {
                         if (token[i] == '-') dashCount++;
                     }
                     
                     // If it has 1 dash, it's likely a time range (10-12 or 07:00-09:00).
                     // If it has 2 dashes, it's likely a date (08-11-2025).
                     if (dashCount == 1) {
                         char* result = strdup(token);
                         free(copy);
                         return result;
                     }
                }
            }
            token = strtok(nullptr, "_");
        }
        
        free(copy);
        return nullptr;
    }

    // --- Helper for Robust Int parsing ---
    int64_t get_json_int64(yyjson_val* val) {
        if (!val) return 0;
        if (yyjson_is_int(val)) return yyjson_get_sint(val);
        if (yyjson_is_uint(val)) return (int64_t)yyjson_get_uint(val);
        if (yyjson_is_real(val)) return (int64_t)yyjson_get_real(val);
        if (yyjson_is_str(val)) {
            return atoll(yyjson_get_str(val));
        }
        return 0;
    }

    int get_json_int(yyjson_val* val) {
        if (!val) return 0;
        if (yyjson_is_int(val)) return yyjson_get_int(val);
        if (yyjson_is_uint(val)) return (int)yyjson_get_uint(val);
        if (yyjson_is_real(val)) return (int)yyjson_get_real(val);
        if (yyjson_is_str(val)) {
            return atoi(yyjson_get_str(val));
        }
        return 0;
    }

    // --- Parser for ExamRooms ---
    __attribute__((visibility("default"))) __attribute__((used))
    struct ExamRoomResult* parse_exam_rooms(const char* json_str) {
        struct ExamRoomResult* result = (struct ExamRoomResult*)calloc(1, sizeof(struct ExamRoomResult));
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
        result->rooms = (struct ExamRoomNative*)calloc(result->count, sizeof(struct ExamRoomNative));

        size_t idx, max;
        yyjson_val *item;
        yyjson_arr_foreach(root, idx, max, item) {
            struct ExamRoomNative* room = &result->rooms[idx];
            
            room->id = get_json_int(yyjson_obj_get(item, "id"));
            room->subjectName = safe_strdup(yyjson_get_str(yyjson_obj_get(item, "subjectName")));
            room->examPeriodCode = safe_strdup(yyjson_get_str(yyjson_obj_get(item, "examPeriodCode")));
            room->examCode = safe_strdup(yyjson_get_str(yyjson_obj_get(item, "examCode")));
            room->studentCode = safe_strdup(yyjson_get_str(yyjson_obj_get(item, "studentCode")));

            yyjson_val *examRoomObj = yyjson_obj_get(item, "examRoom");
            if (examRoomObj) {
                // Exam Date - Use 64-bit int for milliseconds
                room->examDate = get_json_int64(yyjson_obj_get(examRoomObj, "examDate"));
                
                // Exam Time logic
                yyjson_val *startHour = yyjson_obj_get(examRoomObj, "startHour");
                if (startHour) {
                     const char* startString = yyjson_get_str(yyjson_obj_get(startHour, "startString"));
                     if (startString) {
                         room->examTime = safe_strdup(startString);
                     }
                }
                
                // Fallback time from roomCode if needed
                if (!room->examTime) {
                     const char* roomCode = yyjson_get_str(yyjson_obj_get(examRoomObj, "roomCode"));
                     if (roomCode) {
                         room->examTime = extract_time_from_room_code(roomCode);
                     }
                }

                 // Room Name
                 yyjson_val *roomObj = yyjson_obj_get(examRoomObj, "room");
                 if (roomObj) {
                      room->roomName = safe_strdup(yyjson_get_str(yyjson_obj_get(roomObj, "name")));
                      
                      yyjson_val *building = yyjson_obj_get(roomObj, "building");
                      if (building) {
                          room->roomBuilding = safe_strdup(yyjson_get_str(yyjson_obj_get(building, "name")));
                      }
                 }

                 // Method
                 yyjson_val *examMethod = yyjson_obj_get(examRoomObj, "examMethod");
                 if (examMethod) {
                     room->examMethod = safe_strdup(yyjson_get_str(yyjson_obj_get(examMethod, "name")));
                 }

                 // Notes and Student count
                 room->notes = safe_strdup(yyjson_get_str(yyjson_obj_get(examRoomObj, "notes")));
                 room->numberExpectedStudent = get_json_int(yyjson_obj_get(examRoomObj, "numberExpectedStudent"));
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
