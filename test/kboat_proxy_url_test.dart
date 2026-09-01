import 'package:boat_racing/core/constants/supabase_constants.dart';
import 'package:boat_racing/core/network/dio_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const proxyBase =
      '${SupabaseConstants.url}/functions/v1/kboat-proxy';

  test('KBOAT 경로를 프록시 주소로 바꾸면서 경로를 그대로 유지한다', () {
    expect(
      kboatProxiedUrl('https://www.kboat.or.kr/main/race/result'),
      '$proxyBase/main/race/result',
    );
    expect(
      kboatProxiedUrl('https://www.kboat.or.kr/race/dividendrate/final/2026/35/2/01'),
      '$proxyBase/race/dividendrate/final/2026/35/2/01',
    );
  });

  test('쿼리 문자열을 보존한다', () {
    expect(
      kboatProxiedUrl('https://www.kboat.or.kr/race/card/decision?stndYear=2026&tms=36'),
      '$proxyBase/race/card/decision?stndYear=2026&tms=36',
    );
  });

  test('KBOAT 이외의 주소는 바꾸지 않는다', () {
    const dataGoKr =
        'https://apis.data.go.kr/B551014/SRVC_OD_API_MBR_RACE_RESULT/TODZ_API_MBR_RACE_RESULT_I';
    expect(kboatProxiedUrl(dataGoKr), dataGoKr);
    expect(kboatProxiedUrl(proxyBase), proxyBase);
  });

  test('이미 프록시를 거친 주소를 다시 감싸지 않는다', () {
    const proxied = '$proxyBase/main/race/result';
    expect(kboatProxiedUrl(proxied), proxied);
  });
}
