#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

build_apk() {
    echo "프로젝트 APK 빌드"
    flutter pub get
    flutter build apk
    echo "빌드 완료: build/app/outputs/flutter-apk/app-release.apk"
}

build_appbundle() {
    echo "프로젝트 App Bundle 빌드"
    flutter pub get
    flutter build appbundle
    echo "빌드 완료: build/app/outputs/bundle/release/app-release.aab"
}

if [[ "${1:-}" == "build" || "${1:-}" == "apk" ]]; then
    build_apk
    exit 0
fi

if [[ "${1:-}" == "aab" || "${1:-}" == "appbundle" ]]; then
    build_appbundle
    exit 0
fi

echo "자동화 스크립트 목록입니다."
echo
echo "[1] CodegenLoader 생성"
echo "[2] LocaleKeys 생성"
echo "[3] 프로젝트 APK 빌드"
echo "[4] 프로젝트 웹호스팅"
echo "[5] 디버그 설치 (기존 앱 삭제 후)"
echo "[6] 프로젝트 App Bundle 빌드"
echo
read -p "Run: " selection

case $selection in

    1)
    echo "CodegenLoader 생성"
    flutter pub run easy_localization:generate -S assets/translations
    ;;

    2)
    echo "LocaleKeys 생성"
    flutter pub run easy_localization:generate -f keys -o locale_keys.g.dart -S assets/translations
    ;;

    3)
    build_apk
    ;;

    4)
    echo "프로젝트 웹호스팅"
    flutter build web
    firebase deploy --only hosting
    ;;

    5)
    echo "기존 앱 삭제 후 디버그 설치"
    adb uninstall com.happy.kdrive
    flutter install
    ;;

    6)
    build_appbundle
    ;;

    *)
    echo "Unknown command!!"
    ;;

esac