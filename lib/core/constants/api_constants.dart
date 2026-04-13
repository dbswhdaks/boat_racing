import 'package:shared_preferences/shared_preferences.dart';

/// 공공데이터포털 경정 API - 경주사업총괄본부 (B551014)
class ApiConstants {
  static const String baseUrl = 'https://apis.data.go.kr/B551014';

  static const String _defaultServiceKey = String.fromEnvironment(
    'API_SERVICE_KEY',
    defaultValue: '788d1f62af9d665d2f002057f9526ac8f2776910fef87b0e95d27e232fe0967f',
  );

  static String _runtimeServiceKey = '';

  static String get serviceKey =>
      _runtimeServiceKey.isNotEmpty ? _runtimeServiceKey : _defaultServiceKey;

  static Future<void> loadServiceKey() async {
    final prefs = await SharedPreferences.getInstance();
    _runtimeServiceKey = prefs.getString('boat_racing_service_key') ?? '';
  }

  static Future<void> saveServiceKey(String key) async {
    _runtimeServiceKey = key.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('boat_racing_service_key', _runtimeServiceKey);
  }

  static bool get isCustomKeySet => _runtimeServiceKey.isNotEmpty;

  // ─── 경정 API 엔드포인트 ───

  /// 경정 출주표 목록 (경주정보 + 출전선수)
  static const String raceInfo =
      '$baseUrl/SRVC_OD_API_VWEB_MBR_RACE_INFO/TODZ_API_VWEB_MBR_RACE_I';

  /// 경정 선수 회차별 성적 정보 조회
  static const String racerTmsInfo =
      '$baseUrl/SRVC_OD_API_VWEB_MBR_RACER_TMS_INFO/TODZ_API_VWEB_RACER_TMS_I';

  /// 경정경주결과 목록조회
  static const String raceResult =
      '$baseUrl/SRVC_OD_API_MBR_RACE_RESULT/TODZ_API_MBR_RACE_RESULT_I';

  /// 경주결과순위 조회
  static const String raceRank =
      '$baseUrl/SRVC_MRA_RACE_RANK/TODZ_MRA_RACE_RANK';

  /// 경정배당률 목록조회
  static const String payoff =
      '$baseUrl/SRVC_OD_API_MBR_PAYOFF/TODZ_API_MBR_PAYOFF_I';

  /// 경정선수정보 목록조회
  static const String racerInfo =
      '$baseUrl/SRVC_VWEB_MBR_RACER_INFO/TODZ_VWEB_MBR_RACER_INFO';

  /// 경정 선수 정상출발 정보 조회
  static const String racerStrt =
      '$baseUrl/SRVC_MRA_RACER_STRT/TODZ_MRA_RACER_STRT';

  /// 경정 코스별 우승전법 조회
  static const String courseWin =
      '$baseUrl/SRVC_MRA_COURSE_WIN/TODZ_MRA_COURSE_WIN';

  /// 경정보트정보 목록조회
  static const String boatInfo =
      '$baseUrl/SRVC_OD_API_VWEB_MBR_BOAT_INFO/todz_api_vweb_mbr_boat_i';

  /// 경정모터정보 조회
  static const String motorInfo =
      '$baseUrl/SRVC_OD_API_VWEB_MBR_MOTOR_INFO/todz_api_vweb_motor_i';

  /// 경정경주동영상 정보 조회
  static const String raceVideo =
      '$baseUrl/SRVC_OD_API_WEB_BOAT_RACE_VIDEO/TODZ_API_MRA_BOAT_RACE_I';

  /// 경정 회차별 출발위반 현황 정보 조회
  static const String flInfo =
      '$baseUrl/SRVC_MRA_FL_INFO/TODZ_MRA_FL_INFO';

  /// 경정 소모품정보 목록 조회
  static const String suppCd =
      '$baseUrl/SRVC_OD_API_MRA_SUPP_CD/todz_api_mra_supp_cd_i';

  /// 경정 부품정보 목록 조회
  static const String partsInfo =
      '$baseUrl/SRVC_OD_API_MRA_SUPP_CD/todz_api_mra_parts_master_i';

  /// 경정 장비정비이력 목록조회
  static const String equipRepr =
      '$baseUrl/SRVC_OD_API_MRA_SUPP_CD/todz_api_mra_equip_repr_h';

  /// 경정 출주선수면담 목록 조회
  static const String racerInterview =
      '$baseUrl/SRVC_OD_API_MRA_SUPP_CD/TODZ_API_MAR_RACER_INTERVIEW_I';

  /// 경정 틸트각 정보 목록 조회
  static const String racerTilt =
      '$baseUrl/SRVC_OD_API_MRA_SUPP_CD/TODZ_API_MRA_RACER_TILT_I';

  /// 대상경정 연도별순위정보 조회
  static const String grndPrize =
      '$baseUrl/SRVC_OD_API_WEB_BOAT_GRND_PRIZE/todz_api_web_grnd_prize_i';

  /// 경정선수 다승순위 조회
  static const String racerWinRank =
      '$baseUrl/SRVC_TODZ_API_MRA_RACER_WIN_RANK_I/TODZ_API_MRA_RACER_WIN_RANK_I';

  /// 경정 홈페이지 출주표 정보 서비스
  static const String raceDoc =
      '$baseUrl/SRVC_OD_API_VWEB_MBR_RACE_DOC/TODZ_API_VWEB_MBR_RACE_DOC_I';

  /// 경정 선수 상대전적 정보 조회
  static const String racerRecord =
      '$baseUrl/SRVC_MRA_RACER_RECORD/TODZ_MRA_RACER_RECORD';

  /// 경기장 코드
  static const Map<int, String> venueCodes = {
    1: '미사리경정공원',
  };

  static String venueName(int code) => venueCodes[code] ?? '미사리경정공원';

  // ─── KBOAT 경주동영상 (cast.kcycle.or.kr VOD) ───

  static const String _vodBase = 'https://cast.kcycle.or.kr/vod/mbr';

  /// 경주장면 동영상 URL
  static String raceVideoUrl(String dateYmd, int raceNo) {
    final y = dateYmd.substring(0, 4);
    final m = dateYmd.substring(4, 6);
    final d = dateYmd.substring(6, 8);
    final rn = raceNo.toString().padLeft(2, '0');
    return '$_vodBase/$y/$m/$d/$dateYmd$rn.mp4';
  }

  /// 소개항주 동영상 URL
  static String introVideoUrl(String dateYmd, int raceNo) {
    final y = dateYmd.substring(0, 4);
    final m = dateYmd.substring(4, 6);
    final d = dateYmd.substring(6, 8);
    final rn = raceNo.toString().padLeft(2, '0');
    return '$_vodBase/$y/$m/$d/${dateYmd}${rn}i.mp4';
  }
}
