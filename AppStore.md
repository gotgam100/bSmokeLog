# B흡연로그 — App Store 출시 자료

App Store Connect에 그대로 붙여 넣을 수 있게 항목별로 정리했어요. 괄호 안은 글자 수 / 제한이에요.
(글자 수는 `python3 design/count_appstore.py`로 다시 셀 수 있어요.)

---

## 1. 기본 정보

| 항목 | 값 |
|---|---|
| 번들 ID | `com.seunghwabaek.bsmokelog` |
| SKU | `bsmokelog-ios` |
| 기본 언어 | 한국어 (Korean) |
| 추가 언어 | 영어 (English, U.S.) |
| 버전 / 빌드 | 1.0 / 1 |
| 가격 | 무료 (인앱 결제 없음) |
| 판매 국가 | 모든 국가 |
| 기본 카테고리 | 건강 및 피트니스 (Health & Fitness) |
| 보조 카테고리 | 라이프스타일 (Lifestyle) |
| 저작권 | `2026 bSmokeLog` |
| 지원 URL | https://gotgam100.github.io/bSmokeLog/support.html |
| 마케팅 URL (선택) | https://gotgam100.github.io/bSmokeLog/ |
| 개인정보 처리방침 URL | https://gotgam100.github.io/bSmokeLog/privacy.html |
| 이용약관 (EULA) | Apple 표준 EULA 사용 (별도 입력 안 함). 앱 안 링크는 https://gotgam100.github.io/bSmokeLog/terms.html |
| 지원 이메일 | yogotgam@gmail.com |

---

## 2. 한국어 (기본)

### 이름 (30자)
```
B흡연로그
```

### 부제 (30자)
```
손쉬운 흡연 기록, 스스로 줄이는 습관
```

### 홍보 문구 (170자) — 심사 없이 수시로 바꿀 수 있어요
```
흡연 기록을 손쉽게 남기고 확인하세요. 자기 관리를 통해 스스로 흡연을 줄여가세요.
```

### 키워드 (100자, 쉼표로 구분, 공백 없이)
```
흡연,담배,흡연기록,담배기록,금연,흡연량,개비,전자담배,니코틴,습관,기록,위젯,통계,일지,비흡연,B흡연,로그
```
> 이름이 "B흡연로그"로 짧아져서 "B흡연", "로그", "비흡연"도 키워드에 넣었어요. 자리가 모자라면 "일지", "습관"부터 빼세요.

### 설명 (4000자)
```
내 흡연 횟수와 습관을 정확히 아는 것이 금연의 시작이라고 생각합니다.
제가 원하는 것은 경고나 잔소리 없이, 그저 내가 언제 얼마나 피웠는지를 보여주는 앱이었습니다.
기록하고, 돌아보고, 줄여나가기.
B흡연로그는 그 자기 관리의 과정을 간단하고 손쉽게 기록하는 앱이에요.

◼ 24시간 원형 시간표
하루를 24칸으로 펼쳐 놓았어요. 피운 시간대가 개수만큼 진해지고, 정확한 시각은 점으로 찍혀요.

◼ 달력
매일 얼마나 피웠는지, 어제와 얼마나 달라졌는지 확인하고 비교할 수 있어요.

◼ 통계
1주 · 1개월 · 3개월 단위로 하루 평균, 합계, 평균 간격, 자주 피는 시간을 보여 줘요.

◼ 기록이 자기 관리가 되도록
· 어제 이맘때, 지난달, 직전 기간과 비교해 줄어드는 흐름을 확인
· 하루 기준선으로 나만의 목표를 정하고, 넘은 날은 달력에서 바로 보기
· 첫 담배를 늦추고 간격을 늘리는 것처럼, 작은 목표부터 숫자로 확인

◼ 앱을 열지 않고도 기록
· 홈 화면 위젯을 통해 버튼 한 번으로 +1 기록

◼ 담배 종류
연초, 전자담배, 니코틴껌처럼 종류를 나누고 색을 정할 수 있어요. 

◼ 내 데이터는 내 손에
· 회원가입 없음, 광고 없음, 분석 도구 없음
· 기록은 기기 안에 저장되고, 원하면 내 iCloud로만 동기화
· CSV 파일로 내보내 엑셀이나 Numbers에서 열기
· 한국어 · 영어 설정 가능

'B흡연로그'는 만 19세 이상 성인이 스스로 흡연을 줄이고 끊을 수 있도록 돕는 기록 도구이며, 흡연을 권장하지 않습니다. 의학적 조언이나 금연 치료를 대신하지 않아요. 도움이 필요하면 보건소 금연클리닉이나 금연상담전화(1544-9030)를 함께 이용해 보세요.
```

### 새로운 기능 (4000자) — 1.0
```
B흡연로그 첫 출시예요.
· 24시간 원형 시간표에서 꾹 눌러 기록하고, 점을 끌어 시각을 바꿔요
· 달력과 1주·1개월·3개월 통계, 담배 종류별 색 구분
· 위젯 · 제어 센터 · 단축어에서 앱을 열지 않고 +1
· iCloud 동기화, CSV 내보내기, 주간 한 줄 요약 알림
· 한국어 · 영어
```

### 심사 메모 (Notes for Review)
```
- 로그인이나 계정이 없습니다. 바로 사용할 수 있습니다.
- 흡연 "기록" 앱이며, 흡연을 권장하거나 담배를 판매하지 않습니다. 금연 치료나 의학적 조언도 제공하지 않습니다.
- iCloud 동기화는 사용자의 비공개 CloudKit 데이터베이스만 사용합니다(개발자 서버 없음). 꺼도 모든 기능이 동작합니다.
- 알림 권한은 설정에서 "주간 한 줄 요약"을 켤 때만 요청합니다.
- 위젯/제어 센터/단축어의 "한 개비 기록"은 App Intents로 같은 App Group 저장소에 기록합니다.
- 빈 상태에서 보시려면: 오늘 화면의 원형 시간표를 꾹 누르면 "한 개비 추가" 메뉴가 뜹니다.
```

---

## 3. English (U.S.)

### Name (30)
```
B Smoke Log: Cigarette Log
```

### Subtitle (30)
```
Easy smoking log, cut back
```

### Promotional Text (170)
```
Log your smoking with ease and check it anytime. Cut down on your own through self-care.
```

### Keywords (100)
```
smoking,quit,tracker,counter,nicotine,vape,e-cigarette,habit,widget,stats,diary,tobacco,nonsmoking
```

### Description (4000)
```
I believe knowing exactly how often and when you smoke is where quitting begins.
What I wanted was an app with no warnings and no nagging, one that simply shows when and how much I smoked.
Log it, look back, cut down.
B Smoke Log makes that process of self-care quick and easy to keep track of.

◼ 24-hour clock
Your day laid out as 24 segments. Hours you smoked get darker with each cigarette, and every entry is a dot at its exact time.

◼ Calendar
See how much you smoked each day, and compare how today differs from yesterday.

◼ Stats
Daily average, total, average gap and your peak hour for the last week, month or 3 months.

◼ Turn your log into self-care
· Compare with yesterday at this time, last month and the previous period to see the trend going down
· Set a daily threshold as your own goal and spot the days over it right on the calendar
· Start small, like delaying your first cigarette or stretching the gap, and watch it in numbers

◼ Log without opening the app
· One tap on the Home Screen widget adds +1

◼ Types
Split entries into cigarettes, e-cigarettes, nicotine gum and more, each with its own color.

◼ Your data stays yours
· No account, no ads, no analytics
· Stored on your device; sync only through your own iCloud if you choose
· Export as CSV and open it in Excel or Numbers
· Available in Korean and English

B Smoke Log is a record-keeping tool that helps adults cut down and quit smoking on their own, and it does not encourage smoking. It is not a substitute for medical advice or cessation treatment. If you need support, please reach out to a healthcare professional or a local quitline.
```

### What's New (4000) — 1.0
```
First release of B Smoke Log.
· Press and hold the 24-hour clock to log, drag dots to change the time
· Calendar plus 1-week, 1-month and 3-month stats, colored by type
· Add one from widgets, Control Center and Shortcuts without opening the app
· iCloud sync, CSV export, weekly one-line summary
· Korean and English
```

---

## 4. 연령 등급 (Age Rating) 설문 답변

| 질문 | 답 | 이유 |
|---|---|---|
| 알코올, 담배 또는 약물 사용 또는 언급 | **빈번함/강함** | 앱 전체가 흡연 기록이라 "가끔/약함"으로 넣으면 심사에서 바뀔 수 있어요 |
| 그 외 항목(폭력, 성적 콘텐츠, 도박, 공포 등) | 없음 | |
| 무제한 웹 접근 | 아니오 | |
| 의료/치료 정보 | 아니오 | 기록 도구일 뿐 치료·조언 없음 |

→ 예상 등급 **17+**. (한국 등 일부 국가에서는 이 등급으로 자동 제한이 걸려요. 흡연 기록 앱 대부분이 같은 등급이에요.)

---

## 5. 앱 개인정보 (App Privacy) 설문 답변

- **데이터 수집 여부:** "아니요, 이 앱에서 데이터를 수집하지 않습니다."
  - 이유: 모든 기록은 기기 안에 있고, iCloud 동기화는 사용자 본인의 비공개 CloudKit DB라 Apple 기준으로 "개발자가 수집"하는 데이터가 아니에요. 분석 도구·광고 SDK도 없어요.
- 결과 라벨: **데이터가 수집되지 않음 (Data Not Collected)**
- 개인정보 처리방침 URL: https://gotgam100.github.io/bSmokeLog/privacy.html

---

## 6. 스크린샷 (완성본)

완성 파일은 `design/appstore/`에 있어요. 순서대로 올리면 되고, 첫 3장이 검색 결과에 보여요.

- **6.9형** 1320×2868: `design/appstore/ko-6.9/01.png` ~ `07.png`
- **6.5형** 1284×2778: `design/appstore/ko-6.5/01.png` ~ `07.png`
- 앱스토어에서 보일 모습 미리보기: `design/appstore/preview/search-result.png`, `product-header.png`
- 시뮬레이터 원본: `design/appstore/raw-ko/`

예시 데이터는 연초만 쓴 한 달 반치 기록이에요(10월 하루 평균 9.3개비 → 11월 7.5개비). 디버그 빌드에서 실행 인자 `-screenshotData`로 만들고, 문구를 바꾸면 `swift design/appstore/make_screenshots.swift`로 다시 만들어요.

| # | 화면 | 큰 문구 / 작은 문구 |
|---|---|---|
| 1 | 오늘: 11월 13일 원형 시간표, 전날보다 3 ↓ | 하루가 한눈에 / 24시간 원형 시간표에 한 개비씩 쌓여요 |
| 2 | 오늘: 원형표를 꾹 눌러 메뉴가 뜬 순간 | 꾹 누르면 기록 끝 / 누른 자리의 시각으로 바로 추가·삭제 |
| 3 | 달력: 이달 평균 7.5 vs 지난달 9.3 | 한 달은 달력으로 / 이달 하루 평균을 지난달과 비교해요 |
| 4 | 달력: 날짜를 꾹 눌러 추가·삭제·합계 제외 | 달력에서도 꾹 / 추가, 삭제, 합계에서 빼기까지 |
| 5 | 통계 1개월: 요약 카드 4개 | 숫자로 보는 내 습관 / 하루 평균, 평균 간격, 자주 피는 시간 |
| 6 | 통계: 일별·시간대별·요일별 차트 | 언제 많이 피는지 / 일별·시간대별·요일별로 나눠 봐요 |
| 7 | 설정: 연초 하나, iCloud, CSV | 계정 없이, 내 기기에 / iCloud 동기화와 CSV 내보내기 |

영어 스크린샷은 아직 없어요. 없으면 영어 페이지에도 한국어 스크린샷이 보여요.

---

## 7. 제출 전 체크리스트

- [ ] Xcode: `MARKETING_VERSION` 1.0, `CURRENT_PROJECT_VERSION` 1 (project.yml에 넣어 두었어요)
- [ ] Signing: 팀 선택, 앱·위젯 두 타깃 모두 App Group `group.com.seunghwabaek.bsmokelog`, iCloud 컨테이너 `iCloud.com.seunghwabaek.bsmokelog` 켜기
- [ ] App Store Connect → 앱 생성 (번들 ID, SKU, 기본 언어 한국어)
- [ ] 위 2·3절 텍스트 입력 (한국어 → 영어 순)
- [ ] 스크린샷 6.9형 · 6.5형 업로드
- [ ] 앱 개인정보: 데이터 수집 안 함
- [ ] 연령 등급 설문 (4절)
- [ ] 가격: 무료, 모든 국가
- [ ] 심사 메모 붙여 넣기, 연락처 전화번호·이메일 입력
- [ ] 실기기에서 마지막 확인: 위젯 표시, 제어 센터 버튼, iCloud 켠 뒤 재실행, 알림 권한 요청, 영어로 바꿨을 때 홈 화면 앱 이름(iOS는 기기 언어를 따름)
