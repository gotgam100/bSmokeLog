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
B흡연로그 - 담배 기록
```

### 부제 (30자)
```
꾹 눌러 기록, 원형 시간표로 한눈에
```

### 홍보 문구 (170자) — 심사 없이 수시로 바꿀 수 있어요
```
담배를 피운 시각을 꾹 눌러 남기고, 24시간 원형 시간표와 달력으로 하루를 돌아보세요. 잔소리도 경고도 없이, 내 기록만 담백하게.
```

### 키워드 (100자, 쉼표로 구분, 공백 없이)
```
흡연,담배,흡연기록,담배기록,금연,흡연량,개비,전자담배,니코틴,습관,기록,위젯,통계,일지
```
> 이름·부제에 이미 있는 단어는 키워드에 넣어도 효과가 없어서 빼는 게 보통이지만, "담배"·"기록"은 검색량이 커서 넣어 두었어요. 자리가 모자라면 "일지", "습관"부터 빼세요.

### 설명 (4000자)
```
B흡연로그는 담배를 피운 시각을 가볍게 남기고, 하루를 한눈에 돌아보는 기록 앱이에요.
금연을 강요하거나 경고를 띄우지 않아요. 언제, 얼마나 피웠는지 담담하게 보여 줄 뿐이에요. 줄이고 싶을 때 가장 먼저 필요한 건 정확한 기록이니까요.

◼ 24시간 원형 시간표
하루를 24칸 도넛으로 펼쳐 놓았어요. 피운 시간대가 개수만큼 진해지고, 정확한 시각은 점으로 찍혀요.
· 어디든 꾹 누르면 그 자리의 시각으로 한 개비 추가, 가운데를 꾹 누르면 지금 시각으로 추가
· 점을 잠깐 누른 뒤 끌면 시각 변경
· 가운데에는 오늘 합계, 마지막으로 피운 지 얼마나 됐는지, 어제 이맘때와의 비교(↑↓)

◼ 달력
날짜마다 개수가 동그라미로 보이고, 테두리에 담배 종류 비율이 색으로 나뉘어요. 위에는 이달 하루 평균과 지난달 평균이 함께 있어요.
· 날짜를 꾹 눌러 바로 추가·삭제
· 여행이나 특별한 날은 "합계 제외"로 평균과 통계에서 빼기 (기록은 그대로)
· 하루 기준선을 정하면 넘은 날의 숫자 색이 살짝 바뀌어요

◼ 통계
1주 · 1개월 · 3개월 단위로 하루 평균, 합계, 평균 간격, 자주 피는 시간을 보여 줘요. 일별·시간대별·요일별 차트는 담배 종류별 색으로 쌓이고, 직전 기간과 비교한 한 줄 요약이 붙어요.

◼ 앱을 열지 않고도 기록
· 홈 화면 위젯: 오늘 개수와 마지막 시각, 버튼 한 번으로 +1
· 잠금 화면 위젯, 제어 센터 버튼, 단축어(Siri), 동작 버튼
· 매주 일요일 저녁 한 줄 요약 알림 (원할 때만)

◼ 담배 종류
연초, 전자담배, 니코틴껌처럼 종류를 나누고 색을 정할 수 있어요. 기록마다 종류를 바꾸거나 메모를 남길 수 있어요.

◼ 내 데이터는 내 손에
· 회원가입 없음, 광고 없음, 분석 도구 없음
· 기록은 기기 안에 저장되고, 원하면 내 iCloud로만 동기화
· CSV 파일로 내보내 엑셀이나 Numbers에서 열기
· 한국어 · 영어, 다크 모드 전용 디자인

B흡연로그는 만 19세 이상 성인을 위한 기록 도구이며, 흡연을 권장하지 않습니다. 의학적 조언이나 금연 치료를 제공하지 않으며, 건강에 관한 결정은 의료 전문가와 상의하세요.

문의: yogotgam@gmail.com
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
Log in a tap. See your day.
```

### Promotional Text (170)
```
Press and hold to log each cigarette, then see your day on a 24-hour clock and your month on a calendar. No nagging, no warnings — just your own numbers.
```

### Keywords (100)
```
smoking,cigarette,tracker,log,counter,quit,nicotine,vape,habit,widget,stats,diary,tobacco
```

### Description (4000)
```
B Smoke Log is a light, honest way to keep track of when you smoke — and to see your day at a glance.
It doesn't push you to quit or flash warnings. It simply shows when and how much, because an accurate record is the first thing you need if you ever want to cut down.

◼ 24-hour clock
Your day laid out as a 24-segment ring. Hours you smoked get darker with each cigarette, and every entry is a dot at its exact time.
· Press and hold anywhere to add one at that time; press and hold the center to add one right now
· Hold a dot briefly and drag to change its time
· In the middle: today's total, time since your last one, and how you compare with yesterday at this time (↑↓)

◼ Calendar
Each day shows its count in a circle, with the ring split by type in color. Above it, this month's daily average next to last month's.
· Press and hold a date to add or delete
· Mark a trip or an unusual day as "Exclude from totals" to leave it out of averages and stats (entries stay)
· Set a daily threshold and days over it change color subtly

◼ Stats
Daily average, total, average gap and your peak hour for the last week, month or 3 months. Daily, hourly and weekday charts stack by type, with a one-line comparison to the previous period.

◼ Log without opening the app
· Home Screen widget: today's count, last time, and a one-tap +1
· Lock Screen widgets, a Control Center button, Shortcuts (Siri) and the Action button
· An optional one-line summary every Sunday evening

◼ Types
Split entries into cigarettes, e-cigarettes, nicotine gum or anything you like, each with its own color. Change the type or add a note on any entry.

◼ Your data stays yours
· No account, no ads, no analytics
· Stored on your device; sync only through your own iCloud if you choose
· Export as CSV and open it in Excel or Numbers
· Korean and English, designed for dark mode

B Smoke Log is a record-keeping tool for adults and does not encourage smoking. It does not provide medical advice or cessation treatment; please consult a healthcare professional about health decisions.

Contact: yogotgam@gmail.com
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

## 6. 스크린샷 계획

필수 크기: **6.9형** (1320×2868, iPhone 16 Pro Max 등) 과 **6.5형** (1284×2778 또는 1242×2688). 세로 10장까지, 첫 3장이 검색 결과에 보여요. 시뮬레이터 iPhone 16 Pro Max / iPhone 11 Pro Max에서 `-seedSampleData -randomizeKinds`로 찍으면 돼요.

| # | 화면 | 위쪽 한 줄 문구 (한국어 / 영어) |
|---|---|---|
| 1 | 오늘 — 원형 시간표 (기록 8~10개) | 꾹 눌러 기록, 한눈에 하루 / Press and hold to log. See your whole day. |
| 2 | 오늘 — 꾹 눌러 메뉴가 뜬 순간 | 어디든 꾹 누르면 그 시각에 한 개비 / Hold anywhere to add one at that time |
| 3 | 달력 — 이달 평균 카드 + 종류 색 테두리 | 달력으로 한 달, 색으로 종류까지 / A month at a glance, colored by type |
| 4 | 통계 — 요약 카드 4개 + 종류별 비율 | 평균, 간격, 자주 피는 시간 / Average, gap and peak hour |
| 5 | 홈 화면 위젯 + 잠금 화면 위젯 | 앱을 열지 않고 +1 / Add one without opening the app |
| 6 | 설정 — 담배 종류, iCloud, CSV | 내 데이터는 내 기기와 내 iCloud에만 / Your data stays on your device and your iCloud |

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
