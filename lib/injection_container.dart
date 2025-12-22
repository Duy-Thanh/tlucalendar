import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tlucalendar/core/network/network_client.dart';

import 'package:tlucalendar/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:tlucalendar/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:tlucalendar/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:tlucalendar/features/auth/domain/repositories/auth_repository.dart';
import 'package:tlucalendar/providers/auth_provider.dart';
import 'package:tlucalendar/providers/schedule_provider.dart';
import 'package:tlucalendar/providers/exam_provider.dart';
import 'package:tlucalendar/providers/theme_provider.dart';

import 'package:tlucalendar/features/auth/domain/usecases/login_usecase.dart';
import 'package:tlucalendar/features/auth/domain/usecases/get_user_usecase.dart';
import 'package:tlucalendar/features/schedule/data/datasources/schedule_local_data_source.dart';
import 'package:tlucalendar/features/schedule/data/datasources/schedule_remote_data_source.dart';
import 'package:tlucalendar/features/schedule/data/repositories/schedule_repository_impl.dart';
import 'package:tlucalendar/features/schedule/domain/repositories/schedule_repository.dart';
import 'package:tlucalendar/features/schedule/domain/usecases/get_schedule_usecase.dart';
import 'package:tlucalendar/features/schedule/domain/usecases/get_school_years_usecase.dart';
import 'package:tlucalendar/features/schedule/domain/usecases/get_current_semester_usecase.dart';
import 'package:tlucalendar/features/schedule/domain/usecases/get_course_hours_usecase.dart';
import 'package:tlucalendar/features/exam/domain/usecases/get_exam_schedules_usecase.dart';
import 'package:tlucalendar/features/exam/domain/usecases/get_exam_rooms_usecase.dart';
import 'package:tlucalendar/features/exam/domain/repositories/exam_repository.dart';
import 'package:tlucalendar/features/exam/data/repositories/exam_repository_impl.dart';
import 'package:tlucalendar/features/exam/data/datasources/exam_remote_data_source.dart';
import 'package:tlucalendar/features/exam/data/datasources/exam_local_data_source.dart';
import 'package:tlucalendar/services/database_helper.dart';

final sl = GetIt.instance;

Future<void> init() async {
  //! External
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);

  //! Features - Auth
  // UseCases
  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton(() => GetUserUseCase(sl()));

  // Repository
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: sl(), localDataSource: sl()),
  );

  // Data Sources
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(client: sl()),
  );
  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(
      sharedPreferences: sl(),
      databaseHelper: DatabaseHelper.instance,
    ),
  );

  //! Features - Schedule
  // UseCases
  sl.registerLazySingleton(() => GetScheduleUseCase(sl()));

  // Repository
  sl.registerLazySingleton<ScheduleRepository>(
    () => ScheduleRepositoryImpl(remoteDataSource: sl(), localDataSource: sl()),
  );

  //! Features - Exam
  // UseCases
  sl.registerLazySingleton(() => GetExamSchedulesUseCase(sl()));
  sl.registerLazySingleton(() => GetExamRoomsUseCase(sl()));

  // Schedule Feature
  sl.registerLazySingleton(() => GetSchoolYearsUseCase(sl()));
  sl.registerLazySingleton(() => GetCurrentSemesterUseCase(sl()));
  sl.registerLazySingleton(() => GetCourseHoursUseCase(sl()));

  // Repository
  sl.registerLazySingleton<ExamRepository>(
    () => ExamRepositoryImpl(remoteDataSource: sl(), localDataSource: sl()),
  );

  // Data Sources
  // Data Sources
  sl.registerLazySingleton<ExamRemoteDataSource>(
    () => ExamRemoteDataSourceImpl(client: sl()),
  );
  sl.registerLazySingleton<ExamLocalDataSource>(
    () => ExamLocalDataSourceImpl(databaseHelper: DatabaseHelper.instance),
  );

  // Data Sources
  sl.registerLazySingleton<ScheduleRemoteDataSource>(
    () => ScheduleRemoteDataSourceImpl(client: sl()),
  );
  sl.registerLazySingleton<ScheduleLocalDataSource>(
    () => ScheduleLocalDataSourceImpl(databaseHelper: DatabaseHelper.instance),
  );

  //! Core
  sl.registerLazySingleton<NetworkClient>(
    () => NetworkClient(baseUrl: 'https://sinhvien1.tlu.edu.vn/education'),
  );

  //! Providers
  sl.registerLazySingleton(
    () => AuthProvider(loginUseCase: sl(), getUserUseCase: sl()),
  );
  sl.registerLazySingleton(
    () => ScheduleProvider(
      getScheduleUseCase: sl(),
      getSchoolYearsUseCase: sl(),
      getCurrentSemesterUseCase: sl(),
      getCourseHoursUseCase: sl(),
    ),
  );
  sl.registerLazySingleton(
    () => ExamProvider(
      getExamSchedulesUseCase: sl(),
      getExamRoomsUseCase: sl(),
      getSchoolYearsUseCase: sl(),
      getCourseHoursUseCase: sl(),
    ),
  );
  sl.registerLazySingleton(() => ThemeProvider());
}
