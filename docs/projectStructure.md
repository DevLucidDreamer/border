# BORDER 프로젝트 구조 (projectStructure.md)

경계선지능 청년을 위한 학습 앱. **강의 자료를 받아 → AI가 쉬운글·복습 문항으로 정리 →
간격 반복(3단계) 복습을 앱이 자동으로 관리**한다. 백엔드 서버 없이 전부 기기 로컬(Hive)에 저장한다.

핵심 원칙 두 가지:
1. **자료 1건 = 단원 1개** — AI가 내용을 개념 단위로 쪼개지 않는다.
2. **복습 주기는 앱이 판단** — 사용자는 목록을 뒤지지 않고, "학습하기"만 누르면
   오늘 마감된 복습 → 신규 학습 순서로 자동 진행된다.

---

## 1. 전체 흐름 (한 장 요약)

```
[입력]  녹음 / 음성파일 / PDF
          │
          ▼
  RecordingController  ── 원본 로컬 저장(Lecture)
          │  STT(음성) 또는 텍스트추출(PDF) → 원문(rawTranscript)
          ▼
  AiOrchestrator.run()  ── 원문 → 쉬운글 → 키워드카드 + OX/유사문제 + 쉬운글음성 + 삽화
          │
          ▼
  UnitRepository.save(Unit)   ← [DB: units 박스]  ★학습 콘텐츠 확정
          │
          ▼
[학습]  LearnController.start()
          │  ① reviewRepo.all() 중 오늘 마감분(due) → 낮은 단계 우선
          │  ② unitRepo.all() 중 아직 안 배운 신규 단원
          ▼
  화면 진행: (복습 1→2→3단계) ... → (신규 학습)
          │
          ├─ 신규 학습 완료 → Unit.learned=true 저장 + 1단계 복습 등록  [DB: units, reviews]
          └─ 복습 응답     → ReviewEngine.apply() 결과 저장            [DB: reviews]
```

즉 **입력→정리는 `RecordingController`**, **학습→복습은 `LearnController`**가 담당하고,
그 사이를 잇는 저장소가 `Unit`(콘텐츠)과 `ReviewSchedule`(복습 상태)이다.

---

## 2. 디렉터리 구조 (`lib/`)

| 경로 | 역할 |
|------|------|
| `main.dart` | 진입점. `.env` 로드 → `LocalStore.init()` → `AppClock.load()` → `runApp` |
| `app.dart` | 앱 루트 위젯 |
| `core/` | `service_locator.dart`(전역 의존성 조립), `app_config.dart`(키 판별), `app_clock.dart`(데모 날짜 오프셋) |
| `models/` | `unit.dart`, `review_schedule.dart`, `lecture.dart`, `keyword_card.dart`, `quiz.dart`, `enums.dart` — 전부 `toMap/fromMap` 자체 직렬화 |
| `data/` | Hive 박스 접근 저장소: `local_store.dart`(박스 초기화) + `*_repository.dart` |
| `controllers/` | `recording_controller.dart`(입력→정리), `learn_controller.dart`(학습→복습) |
| `services/ai/` | `ai_orchestrator.dart` + `pipeline_stages.dart`(인터페이스) + `claude/` `openai/` `clova/` `mock/` 구현 |
| `services/stt/` | Whisper STT + Mock 폴백 |
| `services/review/` | `review_engine.dart` — 3단계 간격 반복 상태 머신(순수 로직) |
| `services/files/` · `services/audio/` · `services/ocr/` | 파일 임포트, 녹음, 시간표 OCR |
| `ui/` | 화면: `home_screen`, `recording_screen`, `learn_screen`, `timetable_*`, `splash_screen` |

---

## 3. 데이터베이스 (Hive, 로컬 전용)

`LocalStore.init()`에서 박스를 연다. 모델은 `TypeAdapter` 대신 **`Map` 직렬화**로 보관해
build_runner 의존을 피한다.

| 박스 | 키 | 값 | 언제 쓰나 |
|------|----|----|-----------|
| `lectures` | lecture id | `Lecture` | 입력 원본·처리 상태. 녹음은 정리 후 원본 폐기 |
| `units` | unit id (= lecture id) | `Unit` | **학습 콘텐츠**(쉬운글·키워드카드·문항·음성경로·학습완료여부) |
| `reviews` | unitId | `ReviewSchedule` | **복습 상태**(단계·다음예정일·pending/completed) |
| `timetable` | — | 시간표 | 녹음 시각 → 과목 매칭 |
| `settings` | — | 데모 오프셋 등 | `clearAll()` 대상 아님 |

### DB 반영 지점 (데이터가 실제로 들어가는 곳)
- **콘텐츠 저장**: `_runPipeline` → `unitRepo.save(unit)` (`recording_controller.dart:197`).
  중첩된 `keywordCards`/`quizzes`도 각 `toMap()`으로 함께 직렬화되어 저장됨(`unit.dart:78-79`).
- **신규 학습 완료**: `learnController.completeLearn` → `unitRepo.save(learned=true)` +
  `reviewRepo.save(engine.onLearned(...))` = 1단계 복습 등록(`learn_controller.dart:82`).
- **복습 응답 반영**: `answerReview` → `reviewRepo.save(engine.apply(...))`(`learn_controller.dart:93`).
- **읽기 반영**: `start()`가 매번 `reviewRepo.all()` / `unitRepo.all()`을 새로 읽으므로
  저장 즉시 다음 세션에 반영됨(`learn_controller.dart:53`).

Hive 박스는 디스크에 영속되고 앱 시작 시 다시 열리므로, 앱을 껐다 켜도 단원·복습 상태가 유지된다.

---

## 4. 3단계 복습 엔진 (`review_engine.dart`)

순수 함수 모음(저장은 컨트롤러가 담당). 규칙:

- **단원 학습 완료** → 1단계 등록, `dueDate = 완료시각 + 1일`.
- **`due()`** — `pending` 이면서 `dueDate <= 오늘`인 것만, **낮은 단계 우선** 정렬.
- **`apply(correct)`**
  - 정답 & 마지막(3)단계 → `completed`.
  - 정답 & 그 외 → `stage+1`, 다음날, `attemptCount=0`.
  - 오답 → `stage-1`(1단계는 유지), 다음날, `attemptCount+1`.
- 단계별 화면: 1=키워드+뜻 재인지, 2=OX, 3=유사문제(`learn_screen.dart` `_Step`).
- `reviewInterval`(기본 1일)을 줄이면 데모에서 즉시 확인 가능.

---

## 5. AI 파이프라인 (`ai_orchestrator.dart`)

원문 → `summarizer.summarize`(쉬운글) → `contentBuilder.build`(키워드+OX+유사문제)
→ 동시에 `tts.synthesize`(쉬운글 음성) + `imageGenerator.illustrate`(키워드 삽화) → `Unit`.

- 쉬운글이 비면 이후가 무의미하므로 **즉시 중단**하고 에러 표시(`ai_orchestrator.dart:42`).
- 삽화 실패는 파이프라인을 막지 않고 그림 없는 카드로 진행(`_cardWithImage`).

### 구현 선택 (키 유무로 자동 전환 — `service_locator.dart`)
| 기능 | 키 있을 때 | 없을 때 |
|------|-----------|---------|
| 정리·문항·과목분류·시간표OCR | Claude(Sonnet 5) | Mock |
| STT | OpenAI Whisper | Mock |
| 쉬운글 음성(TTS) | OpenAI > CLOVA | Mock |
| 키워드 삽화 | OpenAI 이미지 | 플레이스홀더 |

키는 `--dart-define` 또는 `.env`로 주입. **키가 하나도 없어도 Mock 샘플로 끝까지 동작**한다.

---

## 6. 화면 (`ui/`)

- `HomeScreen` — 학습하기 / 녹음하기 / 자료 넣기.
- `RecordingScreen` — 녹음·업로드, 처리 상태 표시.
- `LearnScreen` — `LearnController` 기반. 복습→신규 순서로 자동 진행하고,
  오늘 할 게 없으면 목록 대신 "오늘 복습·학습을 마쳤어요" 안내만 표시(단원 목록 브라우징 없음).
- `Timetable*` — 시간표 업로드·확인(녹음 과목 매칭용).
