# VitalTrack SDK 예제

검색 → 연결 → 채널 선택 → 측정 시작/정지 → CSV 저장까지 보여 주는 앱입니다.

```bash
flutter run
```

- Android에서는 처음 검색할 때 블루투스(또는 위치) 권한을 묻습니다.
- CSV 저장 위치는 화면 위쪽에 표시됩니다. Android는 `Android/data/<패키지>/files`(USB로 PC에서 꺼낼 수 있음), 다른 플랫폼은 문서 폴더입니다.
