# Hermes Agent 배포 계획 (계획 4)

**Goal:** 서버를 Cloud Run에, 화면을 Vercel에 올린다. 번들은 CI가 위키에서 만들어 이미지에 굽는다.

**Spec:** `docs/superpowers/specs/2026-08-31-hermes-agent-repo-design.md` §8

**선행 계획:** 계획 1·2·3 완료.

---

## 이 계획이 넘길 수 없는 경계

**나는 배포하지 않는다.** GCP 프로젝트, Vercel 팀, 그리고 LLM 키를 Secret Manager에 넣는 일은 사람의 승인이 필요한 행위다. 이 계획이 만드는 것은 **그 승인이 떨어지면 그대로 도는 산출물**이다 — Dockerfile, CI 워크플로, 배포 문서. 마지막 `gcloud run deploy`와 Vercel 연결은 사람이 한다.

그래서 각 태스크의 완료 기준은 "배포됐다"가 아니라 **"자격 증명 없이 검증 가능한 데까지 검증됐다"**이다. 이미지는 로컬에서 빌드해 실제로 띄워 보고, 워크플로는 문법과 단계 순서를 확인한다.

---

## 데모가 비어 있다는 사실은 배포로 해결되지 않는다

계획 3이 남긴 것: 데모 코스 uuid가 없다. 배포해도 화면에 띄울 코스가 없다.

그래도 배포를 먼저 하는 이유는, 배포가 **한적 연동의 전제**이기 때문이다. 지금 한적 백엔드는 GCP VM 안에 있고 이 노트북에서 닿지 않는다. 에이전트 서버가 같은 GCP 프로젝트에 올라가면 그때 처음으로 한적을 부를 수 있다. 순서가 뒤집힌 게 아니라, 이 순서여야 한다.

---

## Global Constraints

- **번들을 런타임에 clone하지 않는다.** CI가 위키를 체크아웃해 `scripts/build-bundle.sh hanjeok`을 돌리고 결과를 이미지에 굽는다. 런타임 clone은 위키가 잠깐 안 될 때 서버 기동을 막고, 같은 이미지가 날마다 다른 근거로 답하게 만든다.
- **번들 없이 뜬 서버는 DOWN이다.** 이미 `BundleHealthIndicator`가 그렇게 한다. Cloud Run 헬스체크가 이것을 봐야 한다 — 근거 없이 뜬 인스턴스로 트래픽이 가면 안 된다.
- **키는 이미지에 굽지 않는다.** Secret Manager → 환경 변수. `.env`는 로컬 전용이고 이미지에 들어가지 않는다.
- **프론트에는 어떤 키도 없다.** `NEXT_PUBLIC_AGENT_BASE_URL` 하나뿐이다.
- **CORS는 배포 주소를 알아야 한다.** `HERMES_CORS_ALLOWED_ORIGINS`의 기본값 `http://localhost:3000`은 운영에서 틀린 값이다. 빠뜨리면 화면이 열리는데 모든 요청이 막힌다 — 조용하지 않게 만든다.

---

## Task 1 — 컨테이너 이미지

멀티스테이지 Dockerfile. 빌드 스테이지가 `./gradlew bootJar`, 런타임 스테이지는 JRE 21에 jar와 번들만.

- 번들은 **빌드 컨텍스트로 받는다**(`COPY server/src/main/resources/prompts/`). CI가 그 자리에 미리 넣어 둔다.
- `PORT`를 Cloud Run이 준다. `SERVER_PORT=${PORT}`로 받는다.
- 이미지에 `.env`가 들어가지 않도록 `.dockerignore`를 둔다.

**검증**
- [ ] 로컬에서 이미지를 빌드한다.
- [ ] `HANJEOK_BASE_URL`을 죽은 주소로 주고 띄워, `/agent/context`가 9개 문서를 내는지 본다 — 번들이 이미지에 실제로 구워졌다는 증거다.
- [ ] 번들 파일을 지운 이미지를 만들어 `/actuator/health`가 DOWN인지 확인한다. 깨뜨려 확인하는 항목이다.
- [ ] 이미지 안에 `.env`도 API 키 문자열도 없다.

## Task 2 — 번들을 굽는 CI

`.github/workflows/build.yml`: 위키 체크아웃 → `build-bundle.sh hanjeok` → 결과를 `server/src/main/resources/prompts/hanjeok-bundle.txt`에 → `./gradlew build` → 이미지 빌드.

**번들이 커밋된 것과 다르면 실패시킨다.** 위키가 바뀌었는데 레포의 번들이 옛것이면, 화면이 보여 주는 근거와 모델이 실제로 본 근거가 갈라진다. 그 갈라짐은 조용하고, 이 프로젝트 전체가 막으려는 것이 정확히 그런 종류의 침묵이다.

**검증**
- [ ] 워크플로가 `test`만 돌리고 `eval`은 돌리지 않는다 — 평가는 돈이 든다.
- [ ] 번들 드리프트 검사가 실제로 다른 번들에서 실패한다.

## Task 3 — Cloud Run 배포 문서

`docs/deploy.md`: 필요한 것, 순서, 확인 방법. 명령은 복사해 붙일 수 있게.

- 서비스 계정과 최소 권한
- Secret Manager에 `OPENAI_API_KEY`(또는 `ANTHROPIC_API_KEY`)
- `HANJEOK_BASE_URL` — **한적 VM의 내부 주소**. 같은 VPC면 내부 IP, 아니면 공개 주소
- `HERMES_CORS_ALLOWED_ORIGINS` — Vercel 도메인
- 최소 인스턴스 0, 동시성 기본값. 상태가 없어 그대로 된다

**검증**
- [ ] 문서의 환경 변수 목록이 `application.yml`이 실제로 읽는 것과 일치한다. 어긋나면 배포가 조용히 기본값으로 돈다.

## Task 4 — Vercel

`frontend/`를 루트로. 환경 변수는 `NEXT_PUBLIC_AGENT_BASE_URL` 하나.

**검증**
- [ ] 백엔드가 없는 상태에서 `pnpm build`가 성공한다 — 계획 3에서 이미 고쳤고, 회귀하면 배포가 백엔드에 묶인다.

---

## 이 계획이 하지 않는 것

- **실제 배포** — 자격 증명이 필요하다.
- **커스텀 도메인, HTTPS 인증서** — Cloud Run과 Vercel의 기본 도메인으로 시작한다.
- **모니터링·알림** — 데모에 필요 없다. 필요해지면 그때가 설계할 시점이다.
- **데모 코스 uuid** — 한적에 코스를 만들어야 한다. 배포와 별개의 일이다.
