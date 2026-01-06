#include <jni.h>
#include <string>

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

    // --- Notification Structs ---
    struct NotificationNative {
        long long triggerTime;
        char* title;
        char* body;
        int id; // Unique ID for notification
    };

    struct NotificationResult {
        int count;
        struct NotificationNative* notifications;
        char* errorMessage;
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
    void free_notification_result(struct NotificationResult* result) {
        if (!result) return;
        if (result->notifications) {
            for(int i=0; i<result->count; i++) {
                free(result->notifications[i].title);
                free(result->notifications[i].body);
            }
            free(result->notifications);
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
    
    // --- Helper for Time Parsing (Thread-Safe Replacement for strtok) ---
    // Tries to extract "HH:mm-HH:mm" or "HH-HH" from roomCode
    // Example: "CSE406_08-11-2025_10-12_325-A2" -> "10-12"
    // Example: "SomeCode_Date_07:00-09:00_Room" -> "07:00-09:00"
    char* extract_time_from_room_code(const char* roomCode) {
        if (!roomCode) return nullptr;
        
        // Manual parsing to avoid strtok (not thread-safe)
        const char* p = roomCode;
        const char* start = p;
        
        while (*p != '\0') {
            if (*p == '_') {
                // Token found: [start, p)
                size_t len = p - start;
                if (len >= 3) { // Potential time range
                   bool hasDash = false;
                   bool firstIsDigit = (start[0] >= '0' && start[0] <= '9');
                   int dashCount = 0;
                   if (firstIsDigit) {
                       for(size_t i=0; i<len; i++) {
                           if (start[i] == '-') {
                               hasDash = true;
                               dashCount++;
                           }
                       }
                   }
                   
                   // Heuristic: 1 dash = Time (10-12), 2 dashes = Date (08-11-2025)
                   if (hasDash && firstIsDigit && dashCount == 1) {
                        char* result = (char*)malloc(len + 1);
                        if (result) {
                            memcpy(result, start, len);
                            result[len] = '\0';
                            return result;
                        }
                   }
                }
                
                start = p + 1; // Next token starts after '_'
            }
            p++;
        }
        
        // Check last token
        size_t len = p - start;
        if (len >= 3) {
            bool hasDash = false;
            bool firstIsDigit = (start[0] >= '0' && start[0] <= '9');
            int dashCount = 0;
             if (firstIsDigit) {
               for(size_t i=0; i<len; i++) {
                   if (start[i] == '-') {
                       hasDash = true;
                       dashCount++;
                   }
               }
           }
           if (hasDash && firstIsDigit && dashCount == 1) {
                char* result = (char*)malloc(len + 1);
                if (result) {
                    memcpy(result, start, len);
                    result[len] = '\0';
                    return result;
                }
           }
        }
        
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

    // --- Course Structs ---
    struct CourseNative {
        int id;
        char* courseCode;
        char* courseName;
        char* classCode;
        char* className;
        int dayOfWeek;
        int startCourseHour;
        int endCourseHour;
        char* room;
        char* building;
        char* campus;
        int credits;
        long long startDate;
        long long endDate;
        int fromWeek;
        int toWeek;
        char* lecturerName;
        char* lecturerEmail;
        char* status;
        double grade; // nullable in Dart, 0 or -1 if null? Using -1.0 as sentinel or strict?
        bool hasGrade;
    };

    struct CourseResult {
        int count;
        struct CourseNative* courses;
        char* errorMessage;
    };

    // --- Exported Helper for Freeing CourseResult ---
    __attribute__((visibility("default"))) __attribute__((used))
    void free_course_result(struct CourseResult* result) {
         if (!result) return;
         if (result->courses) {
             // Strings are borrowed from JSON buffer (Zero-Copy), so do NOT free them.
             free(result->courses);
         }
         free(result->errorMessage);
         free(result);
    }

    // --- Parser for Courses ---
    __attribute__((visibility("default"))) __attribute__((used))
    struct CourseResult* parse_courses(const char* json_str) {
        struct CourseResult* result = (struct CourseResult*)calloc(1, sizeof(struct CourseResult));
        if (!json_str) {
            result->errorMessage = strdup("Null JSON string");
            return result;
        }

        // Use INSITU flag for Zero-Copy: Modifies input string in-place.
        // We cast away const because we know Dart allocated this buffer for us to use.
        yyjson_doc *doc = yyjson_read_opts((char*)json_str, strlen(json_str), YYJSON_READ_INSITU | YYJSON_READ_STOP_WHEN_DONE, NULL, NULL);
        if (!doc) {
            result->errorMessage = strdup("Failed to parse JSON");
            return result;
        }

        yyjson_val *root = yyjson_doc_get_root(doc);
        if (!yyjson_is_arr(root)) {
             result->errorMessage = strdup("Root is not an array");
             yyjson_doc_free(doc);
             // Note: In Insitu mode, freeing doc does not touch the input buffer content (strings remain valid)
             return result;
        }
        
        // Pass 1: Count total items needed
        size_t total_count = 0;
        size_t idx, max;
        yyjson_val *item;
        
        yyjson_arr_foreach(root, idx, max, item) {
             yyjson_val *courseSubject = yyjson_obj_get(item, "courseSubject");
             if (courseSubject) {
                 yyjson_val *timetables = yyjson_obj_get(courseSubject, "timetables");
                 if (yyjson_is_arr(timetables) && yyjson_arr_size(timetables) > 0) {
                     total_count += yyjson_arr_size(timetables);
                 } else {
                     total_count++; // Fallback single item
                 }
             } else {
                 total_count++; // Fallback single item
             }
        }
        
        // Allocate exact memory
        result->count = (int)total_count;
        if (result->count > 0) {
            result->courses = (struct CourseNative*)calloc(result->count, sizeof(struct CourseNative));
        }

        // Pass 2: Fill data
        size_t current_idx = 0;
        yyjson_arr_foreach(root, idx, max, item) {
             // Extract shared data from item
             int id = get_json_int(yyjson_obj_get(item, "id"));
             
             // Prioritize subjectName, fallback to courseName
             // ZERO-COPY: Direct pointer assignment
             char* subjectName = (char*)yyjson_get_str(yyjson_obj_get(item, "subjectName"));
             if (!subjectName) subjectName = (char*)yyjson_get_str(yyjson_obj_get(item, "courseName"));
             
             char* subjectCode = (char*)yyjson_get_str(yyjson_obj_get(item, "subjectCode"));
             if (!subjectCode) subjectCode = (char*)yyjson_get_str(yyjson_obj_get(item, "courseCode"));
             
             int credits = get_json_int(yyjson_obj_get(item, "numberOfCredit"));
             if (credits == 0) credits = get_json_int(yyjson_obj_get(item, "credits"));
             
             char* status = (char*)yyjson_get_str(yyjson_obj_get(item, "status"));
             
             double grade = 0.0;
             bool hasGrade = false;
             yyjson_val* gradeVal = yyjson_obj_get(item, "grade");
             if (gradeVal && !yyjson_is_null(gradeVal)) {
                 grade = yyjson_get_num(gradeVal);
                 hasGrade = true;
             }

             yyjson_val *courseSubject = yyjson_obj_get(item, "courseSubject");
             
             if (!courseSubject) {
                 // Push 1 item with minimal info
                 if (current_idx < total_count) {
                    struct CourseNative* c = &result->courses[current_idx++];
                    c->id = id;
                    c->courseCode = subjectCode;
                    c->courseName = subjectName;
                    c->credits = credits;
                    c->status = status;
                    c->hasGrade = hasGrade;
                    c->grade = grade;
                 }
                 continue;
             }
             
             // Extract courseSubject specific data
             char* classCode = (char*)yyjson_get_str(yyjson_obj_get(courseSubject, "classCode"));
             char* className = (char*)yyjson_get_str(yyjson_obj_get(courseSubject, "className"));
             
             char* lecturerName = nullptr;
             char* lecturerEmail = nullptr;
             yyjson_val *lecturer = yyjson_obj_get(courseSubject, "lecturer");
             if (lecturer && yyjson_is_obj(lecturer)) {
                  lecturerName = (char*)yyjson_get_str(yyjson_obj_get(lecturer, "name"));
                  lecturerEmail = (char*)yyjson_get_str(yyjson_obj_get(lecturer, "email"));
             }

             yyjson_val *timetables = yyjson_obj_get(courseSubject, "timetables");
             if (yyjson_is_arr(timetables) && yyjson_arr_size(timetables) > 0) {
                  // Iterate timetables (Expansion)
                  size_t t_idx, t_max;
                  yyjson_val *timetable;
                  yyjson_arr_foreach(timetables, t_idx, t_max, timetable) {
                       if (current_idx >= total_count) break;
                       struct CourseNative* c = &result->courses[current_idx++];
                       
                       // Copy shared info
                       c->id = id;
                       c->courseCode = subjectCode;
                       c->courseName = subjectName;
                       c->credits = credits;
                       c->status = status;
                       c->hasGrade = hasGrade;
                       c->grade = grade;
                       
                       c->classCode = classCode;
                       c->className = className;
                       c->lecturerName = lecturerName;
                       c->lecturerEmail = lecturerEmail;
                       
                       // Timetable specific
                       c->dayOfWeek = get_json_int(yyjson_obj_get(timetable, "weekIndex"));
                       c->fromWeek = get_json_int(yyjson_obj_get(timetable, "fromWeek"));
                       c->toWeek = get_json_int(yyjson_obj_get(timetable, "toWeek"));
                       c->startDate = get_json_int64(yyjson_obj_get(timetable, "startDate"));
                       c->endDate = get_json_int64(yyjson_obj_get(timetable, "endDate"));
                       
                       // Start/End Hour logic
                       yyjson_val* startHour = yyjson_obj_get(timetable, "startHour");
                       if (startHour && yyjson_is_obj(startHour)) c->startCourseHour = get_json_int(yyjson_obj_get(startHour, "id"));
                       else c->startCourseHour = get_json_int(yyjson_obj_get(timetable, "startTime")); // fallback
                       
                       yyjson_val* endHour = yyjson_obj_get(timetable, "endHour");
                       if (endHour && yyjson_is_obj(endHour)) c->endCourseHour = get_json_int(yyjson_obj_get(endHour, "id"));
                       else c->endCourseHour = get_json_int(yyjson_obj_get(timetable, "endTime")); // fallback
                       
                       // Room logic
                       yyjson_val* roomVal = yyjson_obj_get(timetable, "room");
                       if (roomVal) {
                           if (yyjson_is_obj(roomVal)) {
                               c->room = (char*)yyjson_get_str(yyjson_obj_get(roomVal, "name"));
                               yyjson_val* b = yyjson_obj_get(roomVal, "building");
                               if(b && yyjson_is_obj(b)) c->building = (char*)yyjson_get_str(yyjson_obj_get(b, "name"));
                               else if (b && yyjson_is_str(b)) c->building = (char*)yyjson_get_str(b);
                           } else if (yyjson_is_str(roomVal)) {
                               c->room = (char*)yyjson_get_str(roomVal);
                           }
                       }
                       
                       if (!c->building) {
                            yyjson_val* b = yyjson_obj_get(timetable, "building");
                             if (b && yyjson_is_str(b)) c->building = (char*)yyjson_get_str(b);
                       }
                       
                       c->campus = (char*)yyjson_get_str(yyjson_obj_get(timetable, "campus"));
                  }
             } else {
                if (current_idx < total_count) {
                    struct CourseNative* c = &result->courses[current_idx++];
                    c->id = id;
                    c->courseCode = subjectCode;
                    c->courseName = subjectName;
                    c->credits = credits;
                    c->status = status;
                    c->hasGrade = hasGrade;
                    c->grade = grade;
                    c->classCode = classCode;
                    c->className = className;
                    c->lecturerName = lecturerName;
                    c->lecturerEmail = lecturerEmail;
                    
                    // Fallback simple fields if they exist at courseSubject level
                    c->dayOfWeek = get_json_int(yyjson_obj_get(courseSubject, "dayOfWeek"));
                    
                    yyjson_val* startHour = yyjson_obj_get(courseSubject, "startCourseHour");
                    if(startHour && yyjson_is_obj(startHour)) c->startCourseHour = get_json_int(yyjson_obj_get(startHour, "id"));
                    else if (startHour) c->startCourseHour = get_json_int(startHour);

                    yyjson_val* endHour = yyjson_obj_get(courseSubject, "endCourseHour");
                    if(endHour && yyjson_is_obj(endHour)) c->endCourseHour = get_json_int(yyjson_obj_get(endHour, "id"));
                    else if (endHour) c->endCourseHour = get_json_int(endHour);
                    
                    yyjson_val* roomVal = yyjson_obj_get(courseSubject, "room");
                    if(roomVal && yyjson_is_str(roomVal)) c->room = (char*)yyjson_get_str(roomVal);
                 }
             }
        }
        
        yyjson_doc_free(doc);
        return result;
    }

    // --- Native Notification Generator ---
    
    // Helper to format string safely
    char* format_string(const char* format, ...) {
        va_list args;
        va_start(args, format);
        int len = vsnprintf(nullptr, 0, format, args);
        va_end(args);
        if (len < 0) return nullptr;
        
        char* buf = (char*)malloc(len + 1);
        if (!buf) return nullptr;
        
        va_start(args, format);
        vsnprintf(buf, len + 1, format, args);
        va_end(args);
        return buf;
    }

    struct TempHour {
        int id;
        int h;
        int m;
        char* str;
    };

    __attribute__((visibility("default"))) __attribute__((used))
    struct NotificationResult* generate_notifications(
        const char* courses_json,
        const char* hours_json,
        long long semester_start_millis
    ) {
        struct NotificationResult* result = (struct NotificationResult*)calloc(1, sizeof(struct NotificationResult));
        
        if (!courses_json || !hours_json) {
             result->errorMessage = strdup("Invalid input JSONs");
             return result;
        }

        yyjson_doc *docCourses = yyjson_read_opts((char*)courses_json, strlen(courses_json), YYJSON_READ_INSITU | YYJSON_READ_STOP_WHEN_DONE, NULL, NULL);
        yyjson_doc *docHours = yyjson_read(hours_json, strlen(hours_json), 0);
        
        if (!docCourses || !docHours) {
            result->errorMessage = strdup("Failed to parse JSONs");
            if (docCourses) yyjson_doc_free(docCourses);
            if (docHours) yyjson_doc_free(docHours);
            return result;
        }
        
        yyjson_val *hRoot = yyjson_doc_get_root(docHours);
        yyjson_val *hContent = hRoot;
        if (yyjson_is_obj(hRoot)) hContent = yyjson_obj_get(hRoot, "content");
        
        size_t hCount = yyjson_arr_size(hContent);
        struct TempHour* tempHours = (struct TempHour*)calloc(hCount, sizeof(struct TempHour));
        
        size_t h_idx, h_max;
        yyjson_val *hItem;
        yyjson_arr_foreach(hContent, h_idx, h_max, hItem) {
             tempHours[h_idx].id = get_json_int(yyjson_obj_get(hItem, "id"));
             const char* s = yyjson_get_str(yyjson_obj_get(hItem, "startString"));
             if (s) {
                 tempHours[h_idx].str = (char*)s;
                 sscanf(s, "%d:%d", &tempHours[h_idx].h, &tempHours[h_idx].m);
             }
        }
        
        size_t total_notifs = 0;
        
        yyjson_val *cRoot = yyjson_doc_get_root(docCourses);
        size_t c_idx, c_max;
        yyjson_val *cItem;
        
        auto count_weeks = [](int from, int to) {
            if (to < from) return 0;
            return to - from + 1;
        };

        yyjson_arr_foreach(cRoot, c_idx, c_max, cItem) {
             yyjson_val *courseSubject = yyjson_obj_get(cItem, "courseSubject");
             if (!courseSubject) continue;
             
             yyjson_val *timetables = yyjson_obj_get(courseSubject, "timetables");
             if (yyjson_is_arr(timetables)) {
                 size_t t_idx, t_max;
                 yyjson_val *timetable;
                 yyjson_arr_foreach(timetables, t_idx, t_max, timetable) {
                      int from = get_json_int(yyjson_obj_get(timetable, "fromWeek"));
                      int to = get_json_int(yyjson_obj_get(timetable, "toWeek"));
                      total_notifs += count_weeks(from, to);
                 }
             }
        }
        
        result->count = (int)total_notifs;
        result->notifications = (struct NotificationNative*)calloc(result->count, sizeof(struct NotificationNative));
        
        size_t current_n_idx = 0;
        
        yyjson_arr_foreach(cRoot, c_idx, c_max, cItem) {
             yyjson_val *courseSubject = yyjson_obj_get(cItem, "courseSubject");
             if (!courseSubject) continue;
             
             const char* subjectName = yyjson_get_str(yyjson_obj_get(cItem, "subjectName"));
             if (!subjectName) subjectName = yyjson_get_str(yyjson_obj_get(cItem, "courseName"));
             
             yyjson_val *timetables = yyjson_obj_get(courseSubject, "timetables");
             if (yyjson_is_arr(timetables)) {
                 size_t t_idx, t_max;
                 yyjson_val *timetable;
                 yyjson_arr_foreach(timetables, t_idx, t_max, timetable) {
                      if (current_n_idx >= total_notifs) break;
                      
                      int from = get_json_int(yyjson_obj_get(timetable, "fromWeek"));
                      int to = get_json_int(yyjson_obj_get(timetable, "toWeek"));
                      int dayOfWeek = get_json_int(yyjson_obj_get(timetable, "weekIndex")); 
                      
                      yyjson_val* roomVal = yyjson_obj_get(timetable, "room");
                      const char* roomName = "Unknown";
                      if (roomVal) {
                          if (yyjson_is_obj(roomVal)) roomName = yyjson_get_str(yyjson_obj_get(roomVal, "name"));
                          else if (yyjson_is_str(roomVal)) roomName = yyjson_get_str(roomVal);
                      }
                      
                      int startHourId = 0;
                      yyjson_val* startHourObj = yyjson_obj_get(timetable, "startHour");
                      if (startHourObj && yyjson_is_obj(startHourObj)) startHourId = get_json_int(yyjson_obj_get(startHourObj, "id"));
                      else startHourId = get_json_int(yyjson_obj_get(timetable, "startTime"));

                      int hh = 0, mm = 0;
                      const char* timeStr = "00:00";
                      bool timeFound = false;
                      for(size_t i=0; i<hCount; i++) {
                          if (tempHours[i].id == startHourId) {
                              hh = tempHours[i].h;
                              mm = tempHours[i].m;
                              timeStr = tempHours[i].str;
                              timeFound = true;
                              break;
                          }
                      }
                      
                      if (!timeFound) continue;

                      for (int w = from; w <= to; w++) {
                           if (current_n_idx >= total_notifs) break;
                           
                           int days_offset = (w - 1) * 7 + (dayOfWeek - 2);
                           
                           long long target_date_millis = semester_start_millis + (long long)days_offset * 86400000LL;
                           
                           long long trigger_time = target_date_millis + (long long)hh * 3600000LL + (long long)mm * 60000LL;
                           
                           struct NotificationNative* n = &result->notifications[current_n_idx++];
                           n->triggerTime = trigger_time;
                           n->id = (int)((trigger_time / 1000) % 2147483647); 
                           
                           n->title = format_string("Lịch học: %s", subjectName);
                           n->body = format_string("Phòng: %s | Giờ: %s", roomName, timeStr);
                      }
                 }
             }
        }
        
        free(tempHours);
        yyjson_doc_free(docHours);
        yyjson_doc_free(docCourses);
        return result;
    }

    // --- CourseHour ---
    struct CourseHourNative {
        int id;
        char* name;
        char* startString;
        char* endString;
        int indexNumber;
    };
    
    struct CourseHourResult {
        int count;
        struct CourseHourNative* hours;
        char* errorMessage;
    };
    
    // --- Register Period ---
    struct SemesterRegisterPeriodNative {
        int id;
        char* name;
        long long startRegisterTime;
        long long endRegisterTime;
        long long endUnRegisterTime;
        // String fallbacks
        char* startRegisterTimeString;
        char* endRegisterTimeString;
        char* endUnRegisterTimeString;
    };

    // --- Semester ---
    struct SemesterNative {
        int id;
        char* semesterCode;
        char* semesterName;
        long long startDate;
        long long endDate;
        bool isCurrent;
        int ordinalNumbers;
        int registerPeriodsCount; // NEW
        struct SemesterRegisterPeriodNative* registerPeriods; // NEW
    };
    
    // --- SchoolYear ---
    struct SchoolYearNative {
        int id;
        char* name;
        char* code;
        int year;
        bool current;
        long long startDate;
        long long endDate;
        char* displayName;
        int semestersCount;
        struct SemesterNative* semesters;
    };
    
    struct SchoolYearResult {
        int count;
        struct SchoolYearNative* years;
        char* errorMessage;
    };

    struct SemesterResult {
        struct SemesterNative* semester; // Single object check
        char* errorMessage;
    };
    
    // --- User ---
    struct UserNative {
        char* studentId; // username
        char* fullName; // displayName
        char* email;
        int id;
    };
    
    struct UserResult {
         struct UserNative* user;
         char* errorMessage;
    };

    // --- Registration Data ---
    struct TimetableNative {
        int id;
        long long startDate;
        long long endDate;
        int fromWeek;
        int toWeek;
        int dayOfWeek;
        int startHour;
        int endHour;
        char* roomName;
        char* teacherName;
    };

    struct CourseSubjectNative {
        int id;
        char* code;
        char* name;
        char* displayCode;
        int numberStudent;
        int maxStudent;
        int numberRegisted; // numberStudent usually
        bool isSelected;
        bool isFull;
        int timetablesCount;
        struct TimetableNative* timetables;
        int credits;
        char* status; // "new", "full", etc.
    };

    struct SubjectRegistrationNative {
        char* subjectName;
        int numberOfCredit;
        int courseSubjectsCount;
        struct CourseSubjectNative* courseSubjects;
    };

    struct RegistrationPeriodNative {
        int id;
        int subjectsCount;
        struct SubjectRegistrationNative* subjects;
    };

    struct RegistrationResult {
        struct RegistrationPeriodNative* data;
        char* errorMessage;
    };

    // --- Free Functions ---
    __attribute__((visibility("default"))) __attribute__((used))
    void free_course_hour_result(struct CourseHourResult* result) {
         if (!result) return;
         if (result->hours) {
             for(int i=0; i<result->count; i++) {
                 free(result->hours[i].name);
                 free(result->hours[i].startString);
                 free(result->hours[i].endString);
             }
             free(result->hours);
         }
         free(result->errorMessage);
         free(result);
    }

    __attribute__((visibility("default"))) __attribute__((used))
    void free_school_year_result(struct SchoolYearResult* result) {
         if (!result) return;
         if (result->years) {
             for(int i=0; i<result->count; i++) {
                 free(result->years[i].name);
                 free(result->years[i].code);
                 free(result->years[i].displayName);
                 if (result->years[i].semesters) {
                     for(int j=0; j<result->years[i].semestersCount; j++) {
                         free(result->years[i].semesters[j].semesterCode);
                         free(result->years[i].semesters[j].semesterName);
                         if (result->years[i].semesters[j].registerPeriods) {
                             for(int k=0; k<result->years[i].semesters[j].registerPeriodsCount; k++) {
                                 free(result->years[i].semesters[j].registerPeriods[k].name);
                                 free(result->years[i].semesters[j].registerPeriods[k].startRegisterTimeString);
                                 free(result->years[i].semesters[j].registerPeriods[k].endRegisterTimeString);
                                 free(result->years[i].semesters[j].registerPeriods[k].endUnRegisterTimeString);
                             }
                             free(result->years[i].semesters[j].registerPeriods);
                         }
                     }
                     free(result->years[i].semesters);
                 }
             }
             free(result->years);
         }
         free(result->errorMessage);
         free(result);
    }
    
    __attribute__((visibility("default"))) __attribute__((used))
    void free_semester_result(struct SemesterResult* result) {
         if (!result) return;
         if (result->semester) {
             free(result->semester->semesterCode);
             free(result->semester->semesterName);
             if (result->semester->registerPeriods) {
                 for(int k=0; k<result->semester->registerPeriodsCount; k++) {
                     free(result->semester->registerPeriods[k].name);
                     free(result->semester->registerPeriods[k].startRegisterTimeString);
                     free(result->semester->registerPeriods[k].endRegisterTimeString);
                     free(result->semester->registerPeriods[k].endUnRegisterTimeString);
                 }
                 free(result->semester->registerPeriods);
             }
             free(result->semester);
         }
         free(result->errorMessage);
         free(result);
    }

    __attribute__((visibility("default"))) __attribute__((used))
    void free_user_result(struct UserResult* result) {
        if (!result) return;
        if (result->user) {
            free(result->user->studentId);
            free(result->user->fullName);
            free(result->user->email);
            free(result->user);
        }
        free(result->errorMessage);
        free(result);
    }

    __attribute__((visibility("default"))) __attribute__((used))
    void free_registration_result(struct RegistrationResult* result) {
        if (!result) return;
        if (result->data) {
             for(int i=0; i<result->data->subjectsCount; i++) {
                 struct SubjectRegistrationNative* s = &result->data->subjects[i];
                 free(s->subjectName);
                 if (s->courseSubjects) {
                     for(int j=0; j<s->courseSubjectsCount; j++) {
                         struct CourseSubjectNative* c = &s->courseSubjects[j];
                         free(c->code);
                         free(c->name);
                         free(c->displayCode);
                         free(c->status);
                         if (c->timetables) {
                             for(int k=0; k<c->timetablesCount; k++) {
                                 free(c->timetables[k].roomName);
                                 free(c->timetables[k].teacherName);
                             }
                             free(c->timetables);
                         }
                     }
                     free(s->courseSubjects);
                 }
             }
             free(result->data->subjects);
             free(result->data);
        }
        free(result->errorMessage);
        free(result);
    }

    // --- Parsers ---

    __attribute__((visibility("default"))) __attribute__((used))
    struct CourseHourResult* parse_course_hours(const char* json_str) {
        struct CourseHourResult* result = (struct CourseHourResult*)calloc(1, sizeof(struct CourseHourResult));
        if (!json_str) { result->errorMessage = strdup("Null JSON"); return result; }
        
        yyjson_doc *doc = yyjson_read(json_str, strlen(json_str), 0);
        if (!doc) { result->errorMessage = strdup("Parse Error"); return result; }
        
        yyjson_val *root = yyjson_doc_get_root(doc);
        // Root could be list or map {"content": []}
        yyjson_val *arr = root;
        if (yyjson_is_obj(root)) {
            arr = yyjson_obj_get(root, "content");
        }
        
        if (!yyjson_is_arr(arr)) {
           result->errorMessage = strdup("Not an array");
           yyjson_doc_free(doc);
           return result;
        }
        
        result->count = (int)yyjson_arr_size(arr);
        result->hours = (struct CourseHourNative*)calloc(result->count, sizeof(struct CourseHourNative));
        
        size_t idx, max;
        yyjson_val *item;
        yyjson_arr_foreach(arr, idx, max, item) {
            struct CourseHourNative* h = &result->hours[idx];
            h->id = get_json_int(yyjson_obj_get(item, "id"));
            h->name = safe_strdup(yyjson_get_str(yyjson_obj_get(item, "name")));
            h->startString = safe_strdup(yyjson_get_str(yyjson_obj_get(item, "startString")));
            h->endString = safe_strdup(yyjson_get_str(yyjson_obj_get(item, "endString")));
            h->indexNumber = get_json_int(yyjson_obj_get(item, "indexNumber"));
        }
        
        yyjson_doc_free(doc);
        return result;
    }
    
    __attribute__((visibility("default"))) __attribute__((used))
    struct SchoolYearResult* parse_school_years(const char* json_str) {
        struct SchoolYearResult* result = (struct SchoolYearResult*)calloc(1, sizeof(struct SchoolYearResult));
         if (!json_str) { result->errorMessage = strdup("Null JSON"); return result; }
        
        yyjson_doc *doc = yyjson_read(json_str, strlen(json_str), 0);
        if (!doc) { result->errorMessage = strdup("Parse Error"); return result; }
        
        yyjson_val *root = yyjson_doc_get_root(doc);
        yyjson_val *arr = root;
        if (yyjson_is_obj(root)) {
            arr = yyjson_obj_get(root, "content");
        }
        
        if (!yyjson_is_arr(arr)) {
           result->errorMessage = strdup("Not an array");
           yyjson_doc_free(doc);
           return result;
        }
        
        result->count = (int)yyjson_arr_size(arr);
        result->years = (struct SchoolYearNative*)calloc(result->count, sizeof(struct SchoolYearNative));
        
        size_t idx, max;
        yyjson_val *item;
        yyjson_arr_foreach(arr, idx, max, item) {
            struct SchoolYearNative* sy = &result->years[idx];
            sy->id = get_json_int(yyjson_obj_get(item, "id"));
            sy->name = safe_strdup(yyjson_get_str(yyjson_obj_get(item, "name")));
            sy->code = safe_strdup(yyjson_get_str(yyjson_obj_get(item, "code")));
            sy->displayName = safe_strdup(yyjson_get_str(yyjson_obj_get(item, "displayName")));
            sy->year = get_json_int(yyjson_obj_get(item, "year"));
            sy->current = yyjson_get_bool(yyjson_obj_get(item, "current"));
            sy->startDate = get_json_int64(yyjson_obj_get(item, "startDate"));
            sy->endDate = get_json_int64(yyjson_obj_get(item, "endDate"));
            
            yyjson_val *sems = yyjson_obj_get(item, "semesters");
            if (yyjson_is_arr(sems)) {
                sy->semestersCount = (int)yyjson_arr_size(sems);
                sy->semesters = (struct SemesterNative*)calloc(sy->semestersCount, sizeof(struct SemesterNative));
                size_t s_idx, s_max;
                yyjson_val *semItem;
                yyjson_arr_foreach(sems, s_idx, s_max, semItem) {
                     struct SemesterNative* s = &sy->semesters[s_idx];
                     s->id = get_json_int(yyjson_obj_get(semItem, "id"));
                     s->semesterCode = safe_strdup(yyjson_get_str(yyjson_obj_get(semItem, "semesterCode")));
                     s->semesterName = safe_strdup(yyjson_get_str(yyjson_obj_get(semItem, "semesterName")));
                     s->startDate = get_json_int64(yyjson_obj_get(semItem, "startDate"));
                     s->endDate = get_json_int64(yyjson_obj_get(semItem, "endDate"));
                     s->isCurrent = yyjson_get_bool(yyjson_obj_get(semItem, "isCurrent"));
                     s->ordinalNumbers = get_json_int(yyjson_obj_get(semItem, "ordinalNumbers"));
                     
                     yyjson_val *regPeriods = yyjson_obj_get(semItem, "semesterRegisterPeriods");
                     if (yyjson_is_arr(regPeriods)) {
                         s->registerPeriodsCount = (int)yyjson_arr_size(regPeriods);
                         s->registerPeriods = (struct SemesterRegisterPeriodNative*)calloc(s->registerPeriodsCount, sizeof(struct SemesterRegisterPeriodNative));
                         size_t rp_idx, rp_max;
                         yyjson_val *rpItem;
                         yyjson_arr_foreach(regPeriods, rp_idx, rp_max, rpItem) {
                             struct SemesterRegisterPeriodNative* rp = &s->registerPeriods[rp_idx];
                             rp->id = get_json_int(yyjson_obj_get(rpItem, "id"));
                             rp->name = safe_strdup(yyjson_get_str(yyjson_obj_get(rpItem, "name")));
                             rp->startRegisterTime = get_json_int64(yyjson_obj_get(rpItem, "startRegisterTime"));
                             rp->endRegisterTime = get_json_int64(yyjson_obj_get(rpItem, "endRegisterTime"));
                             rp->endUnRegisterTime = get_json_int64(yyjson_obj_get(rpItem, "endUnRegisterTime"));
                             
                             rp->startRegisterTimeString = safe_strdup(yyjson_get_str(yyjson_obj_get(rpItem, "startRegisterTimeString")));
                             rp->endRegisterTimeString = safe_strdup(yyjson_get_str(yyjson_obj_get(rpItem, "endRegisterTimeString")));
                             rp->endUnRegisterTimeString = safe_strdup(yyjson_get_str(yyjson_obj_get(rpItem, "endUnRegisterTimeString")));
                         }
                     }
                }
            }
        }
        
        yyjson_doc_free(doc);
        return result;
    }
    
    __attribute__((visibility("default"))) __attribute__((used))
    struct SemesterResult* parse_semester(const char* json_str) {
        struct SemesterResult* result = (struct SemesterResult*)calloc(1, sizeof(struct SemesterResult));
        if (!json_str) { result->errorMessage = strdup("Null JSON"); return result; }
        
        yyjson_doc *doc = yyjson_read(json_str, strlen(json_str), 0);
        if (!doc) { result->errorMessage = strdup("Parse Error"); return result; }
        
        yyjson_val *root = yyjson_doc_get_root(doc);
        if (!root || !yyjson_is_obj(root)) {
            result->errorMessage = strdup("Not an object");
            yyjson_doc_free(doc);
            return result;
        }
        
        result->semester = (struct SemesterNative*)calloc(1, sizeof(struct SemesterNative));
        struct SemesterNative* s = result->semester;
        s->id = get_json_int(yyjson_obj_get(root, "id"));
        s->semesterCode = safe_strdup(yyjson_get_str(yyjson_obj_get(root, "semesterCode")));
        s->semesterName = safe_strdup(yyjson_get_str(yyjson_obj_get(root, "semesterName")));
         s->startDate = get_json_int64(yyjson_obj_get(root, "startDate"));
         s->endDate = get_json_int64(yyjson_obj_get(root, "endDate"));
         s->isCurrent = yyjson_get_bool(yyjson_obj_get(root, "isCurrent"));
         s->ordinalNumbers = get_json_int(yyjson_obj_get(root, "ordinalNumbers"));
         
         yyjson_val *regPeriods = yyjson_obj_get(root, "semesterRegisterPeriods");
         if (yyjson_is_arr(regPeriods)) {
             s->registerPeriodsCount = (int)yyjson_arr_size(regPeriods);
             s->registerPeriods = (struct SemesterRegisterPeriodNative*)calloc(s->registerPeriodsCount, sizeof(struct SemesterRegisterPeriodNative));
             size_t rp_idx, rp_max;
             yyjson_val *rpItem;
             yyjson_arr_foreach(regPeriods, rp_idx, rp_max, rpItem) {
                 struct SemesterRegisterPeriodNative* rp = &s->registerPeriods[rp_idx];
                 rp->id = get_json_int(yyjson_obj_get(rpItem, "id"));
                 rp->name = safe_strdup(yyjson_get_str(yyjson_obj_get(rpItem, "name")));
                 rp->startRegisterTime = get_json_int64(yyjson_obj_get(rpItem, "startRegisterTime"));
                 rp->endRegisterTime = get_json_int64(yyjson_obj_get(rpItem, "endRegisterTime"));
                 rp->endUnRegisterTime = get_json_int64(yyjson_obj_get(rpItem, "endUnRegisterTime"));
                 
                 rp->startRegisterTimeString = safe_strdup(yyjson_get_str(yyjson_obj_get(rpItem, "startRegisterTimeString")));
                 rp->endRegisterTimeString = safe_strdup(yyjson_get_str(yyjson_obj_get(rpItem, "endRegisterTimeString")));
                 rp->endUnRegisterTimeString = safe_strdup(yyjson_get_str(yyjson_obj_get(rpItem, "endUnRegisterTimeString")));
             }
         }

        yyjson_doc_free(doc);
        return result;
    }
    
    __attribute__((visibility("default"))) __attribute__((used))
    struct UserResult* parse_user(const char* json_str) {
        struct UserResult* result = (struct UserResult*)calloc(1, sizeof(struct UserResult));
        if (!json_str) { result->errorMessage = strdup("Null JSON"); return result; }
        
        yyjson_doc *doc = yyjson_read(json_str, strlen(json_str), 0);
        if (!doc) { result->errorMessage = strdup("Parse Error"); return result; }
        
        yyjson_val *root = yyjson_doc_get_root(doc);
        if (!root || !yyjson_is_obj(root)) {
             result->errorMessage = strdup("Not an object");
             yyjson_doc_free(doc);
             return result;
        }
        
        result->user = (struct UserNative*)calloc(1, sizeof(struct UserNative));
        result->user->studentId = safe_strdup(yyjson_get_str(yyjson_obj_get(root, "username")));
        result->user->fullName = safe_strdup(yyjson_get_str(yyjson_obj_get(root, "displayName")));
        result->user->email = safe_strdup(yyjson_get_str(yyjson_obj_get(root, "email")));
        
        yyjson_val *person = yyjson_obj_get(root, "person");
        if (person && yyjson_is_obj(person)) {
            result->user->id = get_json_int(yyjson_obj_get(person, "id"));
        }
        
        yyjson_doc_free(doc);
        return result;
    }

    // --- Token ---
    struct TokenResponseNative {
        char* access_token;
        char* token_type;
        char* refresh_token;
        char* scope;
        int expires_in;
    };
    
    struct TokenResponseResult {
        struct TokenResponseNative* token;
        char* errorMessage;
    };

    __attribute__((visibility("default"))) __attribute__((used))
    void free_token_result(struct TokenResponseResult* result) {
        if (!result) return;
        if (result->token) {
            free(result->token->access_token);
            free(result->token->token_type);
            free(result->token->refresh_token);
            free(result->token->scope);
            free(result->token);
        }
        free(result->errorMessage);
        free(result);
    }
    
    __attribute__((visibility("default"))) __attribute__((used))
    struct TokenResponseResult* parse_token(const char* json_str) {
        struct TokenResponseResult* result = (struct TokenResponseResult*)calloc(1, sizeof(struct TokenResponseResult));
        if (!json_str) { result->errorMessage = strdup("Null JSON"); return result; }
        
        yyjson_doc *doc = yyjson_read(json_str, strlen(json_str), 0);
        if (!doc) { result->errorMessage = strdup("Parse Error"); return result; }
        
        yyjson_val *root = yyjson_doc_get_root(doc);
        if (!root || !yyjson_is_obj(root)) {
             result->errorMessage = strdup("Not an object");
             yyjson_doc_free(doc);
             return result;
        }
        
        result->token = (struct TokenResponseNative*)calloc(1, sizeof(struct TokenResponseNative));
        result->token->access_token = safe_strdup(yyjson_get_str(yyjson_obj_get(root, "access_token")));
        result->token->token_type = safe_strdup(yyjson_get_str(yyjson_obj_get(root, "token_type")));
        result->token->refresh_token = safe_strdup(yyjson_get_str(yyjson_obj_get(root, "refresh_token")));
        result->token->scope = safe_strdup(yyjson_get_str(yyjson_obj_get(root, "scope")));
        result->token->expires_in = get_json_int(yyjson_obj_get(root, "expires_in"));
        
        yyjson_doc_free(doc);
        return result;
    }

    __attribute__((visibility("default"))) __attribute__((used))
    struct RegistrationResult* parse_registration_data(const char* json_str) {
        struct RegistrationResult* result = (struct RegistrationResult*)calloc(1, sizeof(struct RegistrationResult));
        if (!json_str) { result->errorMessage = strdup("Null JSON"); return result; }
        
        yyjson_doc *doc = yyjson_read_opts((char*)json_str, strlen(json_str), YYJSON_READ_INSITU | YYJSON_READ_STOP_WHEN_DONE, NULL, NULL);
        if (!doc) { result->errorMessage = strdup("Parse Error"); return result; }
        
        yyjson_val *root = yyjson_doc_get_root(doc);
        if (!root || !yyjson_is_obj(root)) {
             result->errorMessage = strdup("Not an object");
             yyjson_doc_free(doc);
             return result;
        }

        result->data = (struct RegistrationPeriodNative*)calloc(1, sizeof(struct RegistrationPeriodNative));
        struct RegistrationPeriodNative* period = result->data;
        
        period->id = get_json_int(yyjson_obj_get(root, "Id"));
        if (period->id == 0) period->id = get_json_int(yyjson_obj_get(root, "id"));

        yyjson_val *viewObj = yyjson_obj_get(root, "CourseRegisterViewObject");
        if (!viewObj) viewObj = yyjson_obj_get(root, "courseRegisterViewObject");

        if (viewObj && yyjson_is_obj(viewObj)) {
            yyjson_val *listSubject = yyjson_obj_get(viewObj, "ListSubjectRegistrationDtos");
            if (!listSubject) listSubject = yyjson_obj_get(viewObj, "listSubjectRegistrationDtos");

            if (yyjson_is_arr(listSubject)) {
                period->subjectsCount = (int)yyjson_arr_size(listSubject);
                period->subjects = (struct SubjectRegistrationNative*)calloc(period->subjectsCount, sizeof(struct SubjectRegistrationNative));
                
                size_t s_idx, s_max;
                yyjson_val *sItem;
                yyjson_arr_foreach(listSubject, s_idx, s_max, sItem) {
                    struct SubjectRegistrationNative* s = &period->subjects[s_idx];
                    s->subjectName = safe_strdup(yyjson_get_str(yyjson_obj_get(sItem, "SubjectName")));
                    s->numberOfCredit = get_json_int(yyjson_obj_get(sItem, "NumberOfCredit"));
                    
                    yyjson_val *courseSubjects = yyjson_obj_get(sItem, "CourseSubjectDtos");
                    if (yyjson_is_arr(courseSubjects)) {
                         s->courseSubjectsCount = (int)yyjson_arr_size(courseSubjects);
                         s->courseSubjects = (struct CourseSubjectNative*)calloc(s->courseSubjectsCount, sizeof(struct CourseSubjectNative));
                         
                         size_t c_idx, c_max;
                         yyjson_val *cItem;
                         yyjson_arr_foreach(courseSubjects, c_idx, c_max, cItem) {
                             struct CourseSubjectNative* c = &s->courseSubjects[c_idx];
                             c->id = get_json_int(yyjson_obj_get(cItem, "Id"));
                             c->code = safe_strdup(yyjson_get_str(yyjson_obj_get(cItem, "Code")));
                             c->displayCode = safe_strdup(yyjson_get_str(yyjson_obj_get(cItem, "DisplayCode")));
                             c->maxStudent = get_json_int(yyjson_obj_get(cItem, "MaxStudent"));
                             c->numberStudent = get_json_int(yyjson_obj_get(cItem, "NumberStudent"));
                             c->isSelected = yyjson_get_bool(yyjson_obj_get(cItem, "IsSelected"));
                             c->isFull = yyjson_get_bool(yyjson_obj_get(cItem, "IsFullClass"));
                             c->credits = get_json_int(yyjson_obj_get(cItem, "NumberOfCredit"));
                             c->status = safe_strdup(yyjson_get_str(yyjson_obj_get(cItem, "Status")));

                             yyjson_val *timetables = yyjson_obj_get(cItem, "Timetables");
                             if (yyjson_is_arr(timetables)) {
                                 c->timetablesCount = (int)yyjson_arr_size(timetables);
                                 c->timetables = (struct TimetableNative*)calloc(c->timetablesCount, sizeof(struct TimetableNative));
                                 size_t t_idx, t_max;
                                 yyjson_val *tItem;
                                 yyjson_arr_foreach(timetables, t_idx, t_max, tItem) {
                                     struct TimetableNative* t = &c->timetables[t_idx];
                                     t->id = get_json_int(yyjson_obj_get(tItem, "id"));
                                     t->startDate = get_json_int64(yyjson_obj_get(tItem, "startDate"));
                                     t->endDate = get_json_int64(yyjson_obj_get(tItem, "endDate"));
                                     t->fromWeek = get_json_int(yyjson_obj_get(tItem, "fromWeek"));
                                     t->toWeek = get_json_int(yyjson_obj_get(tItem, "toWeek"));
                                     t->dayOfWeek = get_json_int(yyjson_obj_get(tItem, "weekIndex"));
                                     
                                     yyjson_val *startH = yyjson_obj_get(tItem, "startHour");
                                     if (yyjson_is_obj(startH)) t->startHour = get_json_int(yyjson_obj_get(startH, "indexNumber"));
                                     
                                     yyjson_val *endH = yyjson_obj_get(tItem, "endHour");
                                     if (yyjson_is_obj(endH)) t->endHour = get_json_int(yyjson_obj_get(endH, "indexNumber"));
                                     
                                     t->roomName = safe_strdup(yyjson_get_str(yyjson_obj_get(tItem, "roomName")));
                                     t->teacherName = safe_strdup(yyjson_get_str(yyjson_obj_get(tItem, "teacherName")));
                                 }
                             }
                         }
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
         // ...
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
