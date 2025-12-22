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
             for (int i = 0; i < result->count; ++i) {
                 struct CourseNative* course = &result->courses[i];
                 free(course->courseCode);
                 free(course->courseName);
                 free(course->classCode);
                 free(course->className);
                 free(course->room);
                 free(course->building);
                 free(course->campus);
                 free(course->lecturerName);
                 free(course->lecturerEmail);
                 free(course->status);
             }
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
        
        // Count total needed size (accounting for expansion)
        // This requires a pre-pass or dynamic resizing.
        // For simplicity/performance balance: Vector then copy, or optimistic?
        // Let's use std::vector for intermediate storage since we are in C++.
        std::vector<struct CourseNative> tempCourses;
        tempCourses.reserve(yyjson_arr_size(root)); // At least as many as root items

        size_t idx, max;
        yyjson_val *item;
        yyjson_arr_foreach(root, idx, max, item) {
             // Extract shared data from item
             int id = get_json_int(yyjson_obj_get(item, "id"));
             const char* subjectName = yyjson_get_str(yyjson_obj_get(item, "subjectName"));
             if (!subjectName) subjectName = yyjson_get_str(yyjson_obj_get(item, "courseName"));
             
             const char* subjectCode = yyjson_get_str(yyjson_obj_get(item, "subjectCode"));
             if (!subjectCode) subjectCode = yyjson_get_str(yyjson_obj_get(item, "courseCode"));
             
             int credits = get_json_int(yyjson_obj_get(item, "numberOfCredit"));
             if (credits == 0) credits = get_json_int(yyjson_obj_get(item, "credits"));
             
             const char* status = yyjson_get_str(yyjson_obj_get(item, "status"));
             
             double grade = 0.0;
             bool hasGrade = false;
             yyjson_val* gradeVal = yyjson_obj_get(item, "grade");
             if (gradeVal && !yyjson_is_null(gradeVal)) {
                 grade = yyjson_get_num(gradeVal);
                 hasGrade = true;
             }

             yyjson_val *courseSubject = yyjson_obj_get(item, "courseSubject");
             if (!courseSubject) {
                 // Push 1 item with minimal info if no courseSubject? Or skip?
                 // Usually valid items have courseSubject.
                 // Let's treat it as single item if no expansion possible.
                 struct CourseNative c;
                 memset(&c, 0, sizeof(c));
                 c.id = id;
                 c.courseCode = safe_strdup(subjectCode);
                 c.courseName = safe_strdup(subjectName);
                 c.credits = credits;
                 c.status = safe_strdup(status);
                 c.hasGrade = hasGrade;
                 c.grade = grade;
                 tempCourses.push_back(c);
                 continue;
             }
             
             // Extract courseSubject specific data
             const char* classCode = yyjson_get_str(yyjson_obj_get(courseSubject, "classCode"));
             const char* className = yyjson_get_str(yyjson_obj_get(courseSubject, "className"));
             
             const char* lecturerName = nullptr;
             const char* lecturerEmail = nullptr;
             yyjson_val *lecturer = yyjson_obj_get(courseSubject, "lecturer");
             if (lecturer && yyjson_is_obj(lecturer)) {
                  lecturerName = yyjson_get_str(yyjson_obj_get(lecturer, "name"));
                  lecturerEmail = yyjson_get_str(yyjson_obj_get(lecturer, "email"));
             }

             yyjson_val *timetables = yyjson_obj_get(courseSubject, "timetables");
             if (yyjson_is_arr(timetables) && yyjson_arr_size(timetables) > 0) {
                  // Iterate timetables (Expansion)
                  size_t t_idx, t_max;
                  yyjson_val *timetable;
                  yyjson_arr_foreach(timetables, t_idx, t_max, timetable) {
                       struct CourseNative c;
                       memset(&c, 0, sizeof(c));
                       
                       // Copy shared info
                       c.id = id;
                       c.courseCode = safe_strdup(subjectCode);
                       c.courseName = safe_strdup(subjectName);
                       c.credits = credits;
                       c.status = safe_strdup(status);
                       c.hasGrade = hasGrade;
                       c.grade = grade;
                       
                       c.classCode = safe_strdup(classCode);
                       c.className = safe_strdup(className);
                       c.lecturerName = safe_strdup(lecturerName);
                       c.lecturerEmail = safe_strdup(lecturerEmail);
                       
                       // Timetable specific
                       c.dayOfWeek = get_json_int(yyjson_obj_get(timetable, "weekIndex"));
                       c.fromWeek = get_json_int(yyjson_obj_get(timetable, "fromWeek"));
                       c.toWeek = get_json_int(yyjson_obj_get(timetable, "toWeek"));
                       c.startDate = get_json_int64(yyjson_obj_get(timetable, "startDate"));
                       c.endDate = get_json_int64(yyjson_obj_get(timetable, "endDate"));
                       
                       // Start/End Hour logic
                       yyjson_val* startHour = yyjson_obj_get(timetable, "startHour");
                       if (startHour && yyjson_is_obj(startHour)) c.startCourseHour = get_json_int(yyjson_obj_get(startHour, "id"));
                       else c.startCourseHour = get_json_int(yyjson_obj_get(timetable, "startTime")); // fallback
                       
                       yyjson_val* endHour = yyjson_obj_get(timetable, "endHour");
                       if (endHour && yyjson_is_obj(endHour)) c.endCourseHour = get_json_int(yyjson_obj_get(endHour, "id"));
                       else c.endCourseHour = get_json_int(yyjson_obj_get(timetable, "endTime")); // fallback
                       
                       // Room logic
                       yyjson_val* roomVal = yyjson_obj_get(timetable, "room");
                       if (roomVal) {
                           if (yyjson_is_obj(roomVal)) {
                               c.room = safe_strdup(yyjson_get_str(yyjson_obj_get(roomVal, "name")));
                               // building inside room?
                               yyjson_val* b = yyjson_obj_get(roomVal, "building");
                               if(b && yyjson_is_obj(b)) c.building = safe_strdup(yyjson_get_str(yyjson_obj_get(b, "name")));
                               else if (b && yyjson_is_str(b)) c.building = safe_strdup(yyjson_get_str(b)); // sometimes simple string
                           } else if (yyjson_is_str(roomVal)) {
                               c.room = safe_strdup(yyjson_get_str(roomVal));
                           }
                       }
                       
                       if (!c.building) {
                            // try direct building field
                            yyjson_val* b = yyjson_obj_get(timetable, "building");
                             if (b && yyjson_is_str(b)) c.building = safe_strdup(yyjson_get_str(b));
                       }
                       
                       c.campus = safe_strdup(yyjson_get_str(yyjson_obj_get(timetable, "campus")));

                       tempCourses.push_back(c);
                  }
             } else {
                  // No timetables or empty. Add as single item with defaults/fallbacks?
                  // Logic in Dart was: if empty, still add it? Or try fallbacks?
                  // Assuming basic addition.
                 struct CourseNative c;
                 memset(&c, 0, sizeof(c));
                 c.id = id;
                 c.courseCode = safe_strdup(subjectCode);
                 c.courseName = safe_strdup(subjectName);
                 c.credits = credits;
                 c.status = safe_strdup(status);
                 c.hasGrade = hasGrade;
                 c.grade = grade;
                 c.classCode = safe_strdup(classCode);
                 c.className = safe_strdup(className);
                 c.lecturerName = safe_strdup(lecturerName);
                 c.lecturerEmail = safe_strdup(lecturerEmail);
                 
                 // Fallback simple fields if they exist at courseSubject level
                 c.dayOfWeek = get_json_int(yyjson_obj_get(courseSubject, "dayOfWeek"));
                 
                 yyjson_val* startHour = yyjson_obj_get(courseSubject, "startCourseHour");
                 if(startHour && yyjson_is_obj(startHour)) c.startCourseHour = get_json_int(yyjson_obj_get(startHour, "id"));
                 else if (startHour) c.startCourseHour = get_json_int(startHour);

                 yyjson_val* endHour = yyjson_obj_get(courseSubject, "endCourseHour");
                 if(endHour && yyjson_is_obj(endHour)) c.endCourseHour = get_json_int(yyjson_obj_get(endHour, "id"));
                 else if (endHour) c.endCourseHour = get_json_int(endHour);
                 
                 yyjson_val* roomVal = yyjson_obj_get(courseSubject, "room");
                 if(roomVal && yyjson_is_str(roomVal)) c.room = safe_strdup(yyjson_get_str(roomVal));

                 tempCourses.push_back(c);
             }
        }
        
        yyjson_doc_free(doc);
        
        // Convert vector to result array
        result->count = (int)tempCourses.size();
        if (result->count > 0) {
            result->courses = (struct CourseNative*)calloc(result->count, sizeof(struct CourseNative));
            // Start copying. Be careful with ownership.
            // Since elements in tempCourses used strdup, they own the memory.
            // We can memcpy the structs shallowly, as the pointers inside are what matter.
            // But if std::vector reallocates/destructs, it might free them? 
            // C structs don't have destructors, but std::vector usage of C structs is POD?
            // Yes, C structs are POD. 
            // So we can just copy them over.
            for(int i=0; i<result->count; i++) {
                result->courses[i] = tempCourses[i];
            }
        }
        
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
    
    // --- Semester ---
    struct SemesterNative {
        int id;
        char* semesterCode;
        char* semesterName;
        long long startDate;
        long long endDate;
        bool isCurrent;
        int ordinalNumbers;
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
    };
    
    struct UserResult {
         struct UserNative* user;
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
