# Hermes Agent API 서버 구현 계획 (계획 2)

> **실행 완료 (2026-09-01).** `hyunolike/hermes-agent` 커밋 `5345b1a..08a31d2`,
> 태스크 8개, 테스트 98개. 이 문서는 실행된 계획의 기록이며 그대로 두었다 —
> 아래는 **계획이 틀렸던 지점**이고, 코드는 계획이 아니라 이쪽을 따랐다.
>
> - **계층이 역전돼 있었다.** `ExplanationUnavailableException`을 `presentation`에
>   두게 해서 application 층이 presentation을 import하게 만든다 — 이 계획이 강제하려는
>   경계를 계획 자신이 깬다. 코드는 `com.hermes.explain`에 둔다.
> - **경계 테스트가 Task 7과 자기모순이다.** `org.springframework.web.*`를 전부
>   금지하는데 Task 7의 설정이 `web.client.RestClient`를 쓴다. 아웃바운드 두 접두사
>   (`…web.client.`, `…http.client.`)는 면제한다.
> - **Jackson 2와 3이 한 클래스패스에 공존한다.** Spring Boot 4.1이 웹·RestClient에
>   Jackson 3을 물리는데 코드베이스는 Jackson 2다. `.body(JsonNode::class.java)`는
>   실패하고, 응답 직렬화는 Jackson 2 노드를 `{"array":false,...}`로 망가뜨린다.
>   코드는 String으로 받아 파싱하고, 응답은 `RawValue`로 싣는다.
> - **`server.error.*`는 Boot 4.1에서 아무것에도 바인딩되지 않는다.** `ErrorProperties`가
>   `ServerProperties`가 아니라 `WebProperties` 아래 있다. 올바른 접두사는
>   **`spring.web.error.*`**. 틀린 접두사로 쓴 첫 버전은 죽은 YAML이었고, 그 경로를
>   행사하는 테스트가 없어 아무도 몰랐다.
> - **`ContextController`에 charset이 없으면 한국어 문서가 깨진다.** `text/plain`에
>   `;charset=UTF-8`이 필요하다. 이 엔드포인트의 존재 이유가 "모델이 본 바로 그
>   바이트"인데 조용히 전부 훼손할 뻔했다.
> - **캐치올 예외 핸들러가 클라이언트 오류를 삼키면 안 된다.** 첫 구현이 깨진 JSON까지
>   503으로 바꿨다. 4xx는 4xx로 남되 본문만 불투명해야 한다.
> - **테스트 픽스처가 병렬을 검증하지 못했다.** `items`가 `visitOrder` 순서대로
>   나열돼 있어 `minByOrNull`을 `first()`로 바꿔도 전 스위트가 통과한다.
>
> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 계획 1의 에이전트 코어에 한적 클라이언트와 HTTP 층을 붙여, `courseUuid` 하나를 받아 근거 인용이 붙은 설명을 돌려주는 서버를 만든다.

**Architecture:** `com.hermes.facts`가 한적 공개 API를 3회(왕복 2회) 호출해 `BackendFacts`를 만들고, `com.hermes.explain.presentation`이 엔드포인트 4개로 그것을 밖에 낸다. **`presentation` 바깥의 어떤 패키지도 인바운드 HTTP를 몰라야 하고, 이번 계획에서 그 경계를 Modulith 테스트로 처음 강제한다.** 계획 1이 픽스처로 주입하던 facts를 실제 호출로 바꾸되, **평가 하네스와 운영이 같은 facts 모양을 보도록 투영 로직을 공유한다.**

**Tech Stack:** Kotlin 2.2.21, JDK 21, Spring Boot 4.1 (`webmvc`, `restclient`, `actuator`), Spring Modulith 2.1, JUnit 5, AssertJ, `java.util.concurrent.CompletableFuture`

**Spec:** `docs/superpowers/specs/2026-08-31-hermes-agent-repo-design.md` (§3 계약, §4 엔드포인트, §7 데모 코스, §9 평가) — 선행 `2026-08-17-hermes-agent-design.md` §8 실패 처리는 그대로 정본이다.

**선행 계획:** `docs/superpowers/plans/2026-08-31-hermes-agent-core.md` (완료, `hermes-agent` 커밋 `3e965f4..74d418f`)

## Global Constraints

- **레포**: `~/Library/Mobile Documents/com~apple~CloudDocs/Workspace/hermes-agent`, 브랜치 `main`, 원격 `origin` = `https://github.com/hyunolike/hermes-agent` (공개).
- **Gradle 모듈은 하나.** `settings.gradle.kts`에 `include(...)`를 쓰지 않는다.
- **`org.springframework.web.*` import는 `com.hermes.explain.presentation` 안에서만 허용한다.** 다른 어떤 패키지에서도 금지. Task 1이 이를 테스트로 강제한다.
- **아웃바운드 HTTP는 이 금지의 대상이 아니다.** 최종 리뷰가 판정했다 — 스펙의 경계는 *인바운드*(요청을 받는 것)에 관한 것이고, `facts`가 한적을 부르거나 `llm`이 프로바이더를 부르는 것은 Anthropic SDK가 내부적으로 HTTP를 하는 것과 같은 부류다. 하네스가 서버 없이 application 층을 구동하는 능력이 훼손되지 않으면 된다.
- **한적 호출은 3회, 왕복 2회.** 코스 1회 → 그 응답에서 파생한 혼잡도·대안 2회 **병렬**. `GET /api/v1/attractions/{id}`는 부르지 않는다.
- **Hermes는 스스로 재시도하지 않는다.** 스펙 §8 — 한적 실패는 재시도 없이 503, LLM 429/5xx는 SDK 기본 재시도 2회 뒤 503. 따라서 `Failed`에 retryable 플래그를 **넣지 않는다**(최종 리뷰가 계획 2 마찰로 지목했으나, 스펙이 재시도를 배제하므로 필요 없다).
- **실패는 전부 503 `{"code":"EXPLANATION_UNAVAILABLE"}`.** 설명이 없는 것은 안전한 실패다 — 한적의 규칙 기반 문구가 남는다.
- **번들 적재 실패 시 `/actuator/health`는 DOWN.** 근거 없이 뜨면 안 된다.
- **어떤 단위 테스트도 API 키나 네트워크를 요구하지 않는다.** `eval` 태스크는 `test`/`build` 밖에 머문다.
- **커밋은 태스크마다.** 각 태스크 끝에 `./gradlew build`가 통과해야 한다.

---

## File Structure

| 파일 | 책임 |
|---|---|
| `build.gradle.kts` | webmvc·restclient·actuator·modulith 의존 추가 |
| `server/src/main/kotlin/com/hermes/HermesApplication.kt` | `@Modulith` 선언 추가 |
| `server/src/main/kotlin/com/hermes/explain/FactsProjection.kt` | facts JSON 투영 — 필드 목록과 직렬화 순서의 단일 출처 |
| `server/src/main/kotlin/com/hermes/harness/FactsNormalizer.kt` | 픽스처 → facts. 투영을 `FactsProjection`에 위임하도록 수정 |
| `server/src/main/kotlin/com/hermes/facts/HanjeokResponses.kt` | 한적 응답 봉투와 DTO |
| `server/src/main/kotlin/com/hermes/facts/HanjeokClient.kt` | 엔드포인트 3종 호출, 봉투 해제 |
| `server/src/main/kotlin/com/hermes/facts/FactsSource.kt` | 코스 1회 → 병렬 2회 → `BackendFacts` |
| `server/src/main/kotlin/com/hermes/explain/ExplanationCache.kt` | `courseUuid` → 설명, LRU 1000 |
| `server/src/main/kotlin/com/hermes/explain/CourseExplainer.kt` | facts 조회 + 설명 생성 + 캐시를 잇는 application 진입점 |
| `server/src/main/kotlin/com/hermes/explain/presentation/ExplainController.kt` | `POST /agent/explain` |
| `server/src/main/kotlin/com/hermes/explain/presentation/ContextController.kt` | `GET /agent/context`, `GET /agent/context/{path}` |
| `server/src/main/kotlin/com/hermes/explain/presentation/ApiErrorHandler.kt` | 도메인 실패 → 503 매핑 |
| `server/src/main/kotlin/com/hermes/shared/config/HermesConfig.kt` | 빈 구성 · CORS · 한적 base URL |
| `server/src/main/kotlin/com/hermes/shared/config/BundleHealthIndicator.kt` | 번들 적재 실패 시 DOWN |
| `server/src/main/kotlin/com/hermes/shared/config/DemoCourses.kt` | 고정 데모 코스 uuid 3개 |
| `harness/src/main/kotlin/com/hermes/harness/DemoReachabilityMain.kt` | 데모 코스가 한적에서 아직 조회되는지 검사 |

---

### Task 1: 웹 의존성과 Modulith 경계 강제

**Files:**
- Modify: `build.gradle.kts`
- Modify: `server/src/main/kotlin/com/hermes/HermesApplication.kt`
- Test: `server/src/test/kotlin/com/hermes/ModuleBoundaryTest.kt`

**Interfaces:**
- Consumes: 계획 1의 단일 모듈 구조
- Produces: `@Modulith` 선언된 애플리케이션. `com.hermes.explain.presentation` 밖에서 `org.springframework.web.*`를 쓰면 실패하는 테스트.

- [ ] **Step 1: 실패하는 경계 테스트를 쓴다**

`server/src/test/kotlin/com/hermes/ModuleBoundaryTest.kt`:

```kotlin
package com.hermes

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import java.io.File

/**
 * 스펙 §2.2 — presentation 밖의 어떤 패키지도 인바운드 HTTP 를 몰라야 한다.
 * 그래야 harness 가 서버를 띄우지 않고 application 층을 직접 구동할 수 있다.
 *
 * 소스를 직접 읽는다. 이 규율은 컴파일러가 강제하지 않으므로 테스트가 유일한
 * 방어선이고, 테스트를 지우면 경계도 사라진다 — 지워도 되는 테스트가 아니다.
 *
 * 아웃바운드 클라이언트는 대상이 아니다. facts 가 한적을 부르고 llm 이
 * 프로바이더를 부르는 것은 인바운드 HTTP 를 아는 것과 범주가 다르다.
 */
class ModuleBoundaryTest {

    private val sourceRoot = File("server/src/main/kotlin/com/hermes")

    private fun kotlinFiles(): List<File> =
        sourceRoot.walkTopDown().filter { it.isFile && it.extension == "kt" }.toList()

    @Test
    fun `소스 루트를 실제로 찾았다`() {
        // 경로가 틀리면 아래 검사들이 빈 목록을 훑고 조용히 통과한다.
        assertThat(kotlinFiles()).hasSizeGreaterThan(5)
    }

    @Test
    fun `presentation 밖에서는 인바운드 웹 타입을 쓰지 않는다`() {
        val offenders = kotlinFiles()
            .filterNot { it.path.contains("/explain/presentation/") }
            .filter { file ->
                file.readLines().any { line ->
                    line.startsWith("import org.springframework.web.") ||
                        line.startsWith("import org.springframework.http.")
                }
            }
            .map { it.relativeTo(sourceRoot).path }

        assertThat(offenders)
            .describedAs("presentation 밖에서 인바운드 웹 타입을 import 한 파일")
            .isEmpty()
    }

    @Test
    fun `presentation 은 llm 프로바이더 구현을 직접 부르지 않는다`() {
        // 컨트롤러가 프로바이더를 직접 잡으면 인용 검증을 건너뛸 수 있다.
        val presentation = kotlinFiles().filter { it.path.contains("/explain/presentation/") }
        assertThat(presentation).isNotEmpty()

        val offenders = presentation.filter { file ->
            file.readLines().any { it.startsWith("import com.hermes.llm.Anthropic") || it.startsWith("import com.hermes.llm.OpenRouter") }
        }.map { it.name }

        assertThat(offenders).isEmpty()
    }
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인한다**

Run: `./gradlew test --tests 'com.hermes.ModuleBoundaryTest'`
Expected: `presentation 은 llm 프로바이더 구현을 직접 부르지 않는다`가 FAIL — `presentation` 디렉터리가 아직 없어 `isNotEmpty()`가 깨진다. 나머지 둘은 PASS.

- [ ] **Step 3: 의존성과 `@Modulith` 선언을 더한다**

`build.gradle.kts`의 `dependencies` 블록에 추가:

```kotlin
    implementation("org.springframework.boot:spring-boot-starter-webmvc")
    implementation("org.springframework.boot:spring-boot-starter-restclient")
    implementation("org.springframework.boot:spring-boot-starter-actuator")
    implementation("org.springframework.modulith:spring-modulith-starter-core")
    testImplementation("org.springframework.modulith:spring-modulith-starter-test")
    testImplementation("org.springframework.boot:spring-boot-starter-webmvc-test")
```

같은 파일에 Modulith BOM을 더한다(`dependencies` 블록 위):

```kotlin
dependencyManagement {
    imports {
        mavenBom("org.springframework.modulith:spring-modulith-bom:2.1.0")
    }
}
```

`server/src/main/kotlin/com/hermes/HermesApplication.kt`:

```kotlin
package com.hermes

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication
import org.springframework.modulith.Modulith

@Modulith
@SpringBootApplication
class HermesApplication

fun main(args: Array<String>) {
    runApplication<HermesApplication>(*args)
}
```

`presentation` 패키지 디렉터리를 만들고 자리표시자 대신 실제 컨트롤러가 들어갈 때까지 테스트가 붉게 남는 것이 정상이다 — Task 6이 채운다. 이 태스크에서는 빈 디렉터리 대신 아래 파일을 둔다.

`server/src/main/kotlin/com/hermes/explain/presentation/ApiErrorHandler.kt`:

```kotlin
package com.hermes.explain.presentation

import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.ExceptionHandler
import org.springframework.web.bind.annotation.RestControllerAdvice

/** 스펙 §8 — 설명이 없는 것은 안전한 실패다. 사유는 로그에 남고 본문에는 나가지 않는다. */
class ExplanationUnavailableException(val diagnosticReason: String) : RuntimeException(diagnosticReason)

@RestControllerAdvice
class ApiErrorHandler {

    @ExceptionHandler(ExplanationUnavailableException::class)
    fun onUnavailable(e: ExplanationUnavailableException): ResponseEntity<Map<String, String>> =
        ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
            .body(mapOf("code" to "EXPLANATION_UNAVAILABLE"))
}
```

- [ ] **Step 4: 테스트가 통과하는지 확인한다**

Run: `./gradlew test --tests 'com.hermes.ModuleBoundaryTest'`
Expected: PASS — 3개 통과. 계획 1의 46개도 그대로 통과해야 한다: `./gradlew build`

- [ ] **Step 5: 커밋**

```bash
git add build.gradle.kts server/src/main/kotlin/com/hermes/HermesApplication.kt \
        server/src/main/kotlin/com/hermes/explain/presentation/ApiErrorHandler.kt \
        server/src/test/kotlin/com/hermes/ModuleBoundaryTest.kt
git commit -m "feat: add the web stack and enforce the presentation-only HTTP boundary"
```

---

### Task 2: facts 투영을 하나의 출처로

**Files:**
- Create: `server/src/main/kotlin/com/hermes/explain/FactsProjection.kt`
- Modify: `server/src/main/kotlin/com/hermes/harness/FactsNormalizer.kt`
- Test: `server/src/test/kotlin/com/hermes/explain/FactsProjectionTest.kt`

**Interfaces:**
- Consumes: 없음
- Produces:
  - `object FactsProjection` — `val ITEM_FIELDS: List<String>`, `val ALTERNATIVE_FIELDS: List<String>`, `val DIAGNOSIS_FIELDS: List<String>`, `fun project(node: JsonNode, fields: List<String>): ObjectNode`, `fun assemble(course: JsonNode, alternatives: JsonNode, congestion: JsonNode): ObjectNode`

**왜 이 태스크가 먼저인가.** 평가 하네스는 픽스처에서, 운영은 한적 HTTP에서 facts를 만든다. 두 경로가 각자 투영하면 **하네스가 측정한 프롬프트와 운영이 보내는 프롬프트가 달라진다** — 그러면 평가 수치가 운영에 대해 아무것도 말해주지 않는다. 투영을 한 곳에 두고 둘 다 그것을 부른다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`server/src/test/kotlin/com/hermes/explain/FactsProjectionTest.kt`:

```kotlin
package com.hermes.explain

import com.fasterxml.jackson.databind.ObjectMapper
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test

class FactsProjectionTest {

    private val mapper = ObjectMapper()

    private val course = mapper.readTree(
        """
        {"targetDate":"2026-08-15","title":"혼잡한 경복궁을 피하는 하루",
         "congestionReductionRate":34,"summary":"요약",
         "recommendedDate":{"date":"2026-08-19","congestionReductionRate":41},
         "items":[{"attractionId":1001,"name":"경복궁","visitOrder":1,"timeLabel":"오전 10:00",
                   "grade":"VERY_CROWDED","reason":"첫 방문지","travelMinutesFromPrev":null}]}
        """.trimIndent(),
    )

    private val alternatives = mapper.readTree(
        """
        [{"attractionId":1003,"name":"북촌 한옥마을","grade":"NORMAL","concentration":62.0,
          "distanceKm":0.6,"relationScore":0.9,"score":0.704,"recommendReason":"여유롭다","travelMinutes":8}]
        """.trimIndent(),
    )

    private val congestion = mapper.readTree(
        """
        {"diagnosis":{"concentration":87.3,"percentile":92,"grade":"VERY_CROWDED","message":"붐빈다"},
         "betterDates":[{"date":"2026-08-19","concentration":48.6,"grade":"RELAXED"}]}
        """.trimIndent(),
    )

    @Test
    fun `검사기가 읽는 두 경로가 최상위에 있다`() {
        // ForbiddenBehaviours 는 /items 와 /alternatives 를 최상위에서 읽는다.
        // 여기가 어긋나면 평가에서 모든 지명이 오탐되고 순서 검사가 무력해진다.
        val facts = FactsProjection.assemble(course, alternatives, congestion)

        assertThat(facts.at("/items/0/name").asText()).isEqualTo("경복궁")
        assertThat(facts.at("/alternatives/0/name").asText()).isEqualTo("북촌 한옥마을")
    }

    @Test
    fun `백분위와 점수가 살아남는다`() {
        // percentile 없이는 congestion-diagnosis.md 를, score 없이는
        // alternative-scoring.md 를 설명할 근거가 사라진다.
        val facts = FactsProjection.assemble(course, alternatives, congestion)

        assertThat(facts.at("/congestion/percentile").asInt()).isEqualTo(92)
        assertThat(facts.at("/alternatives/0/score").asDouble()).isEqualTo(0.704)
    }

    @Test
    fun `같은 입력이면 바이트 단위로 같은 JSON 이 나온다`() {
        val a = FactsProjection.assemble(course, alternatives, congestion).toString()
        val b = FactsProjection.assemble(course, alternatives, congestion).toString()

        assertThat(a).isEqualTo(b)
    }

    @Test
    fun `필드가 빠지면 조용히 넘어가지 않고 그 필드를 지목해 실패한다`() {
        val itemMissingName = mapper.readTree("""{"attractionId":1001,"visitOrder":1}""")

        assertThatThrownBy { FactsProjection.project(itemMissingName, FactsProjection.ITEM_FIELDS) }
            .hasMessageContaining("name")
    }
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인한다**

Run: `./gradlew test --tests 'com.hermes.explain.FactsProjectionTest'`
Expected: FAIL — `Unresolved reference: FactsProjection`

- [ ] **Step 3: 투영을 구현한다**

`server/src/main/kotlin/com/hermes/explain/FactsProjection.kt`:

```kotlin
package com.hermes.explain

import com.fasterxml.jackson.databind.JsonNode
import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.databind.node.ObjectNode

/**
 * facts JSON 의 모양을 정하는 단일 출처.
 *
 * 평가 하네스(픽스처에서)와 운영(한적 HTTP 에서)이 **둘 다 여기를 부른다.**
 * 각자 투영하면 하네스가 측정한 프롬프트와 운영이 보내는 프롬프트가 달라지고,
 * 그러면 평가 수치가 운영에 대해 아무것도 말해주지 않는다.
 *
 * 필드 순서가 곧 직렬화 순서다(ObjectNode 는 LinkedHashMap 기반). facts 는
 * 요청마다 달라지는 유일한 부분이므로, 같은 입력에서 같은 바이트가 나와야
 * 실행 간 비교가 의미를 가진다.
 */
object FactsProjection {

    private val MAPPER = ObjectMapper()

    val ITEM_FIELDS: List<String> =
        listOf("attractionId", "name", "visitOrder", "timeLabel", "grade", "reason", "travelMinutesFromPrev")

    val ALTERNATIVE_FIELDS: List<String> =
        listOf(
            "attractionId", "name", "grade", "concentration", "distanceKm",
            "relationScore", "score", "recommendReason", "travelMinutes",
        )

    val DIAGNOSIS_FIELDS: List<String> = listOf("concentration", "percentile", "grade", "message")

    fun project(node: JsonNode, fields: List<String>): ObjectNode {
        val out = MAPPER.createObjectNode()
        fields.forEach { field ->
            out.set<JsonNode>(field, node.get(field) ?: error("expected field '$field' on $node"))
        }
        return out
    }

    /**
     * @param course 코스 응답의 `data`
     * @param alternatives 대안 응답의 `data` (배열)
     * @param congestion 혼잡도 응답의 `data`
     */
    fun assemble(course: JsonNode, alternatives: JsonNode, congestion: JsonNode): ObjectNode {
        val diagnosis = congestion.get("diagnosis") ?: error("congestion response has no diagnosis")

        val items = MAPPER.createArrayNode()
        (course.get("items") ?: error("course response has no items"))
            .forEach { items.add(project(it, ITEM_FIELDS)) }

        val alternativeNodes = MAPPER.createArrayNode()
        alternatives.forEach { alternativeNodes.add(project(it, ALTERNATIVE_FIELDS)) }

        val congestionNode = project(diagnosis, DIAGNOSIS_FIELDS)
        congestionNode.set<JsonNode>("betterDates", congestion.get("betterDates") ?: MAPPER.createArrayNode())

        val facts = MAPPER.createObjectNode()
        facts.set<JsonNode>("items", items)
        facts.set<JsonNode>("alternatives", alternativeNodes)
        facts.put("targetDate", (course.get("targetDate") ?: error("course response has no targetDate")).asText())
        facts.put("title", (course.get("title") ?: error("course response has no title")).asText())
        facts.put(
            "congestionReductionRate",
            (course.get("congestionReductionRate") ?: error("course response has no congestionReductionRate")).asInt(),
        )
        facts.put("summary", (course.get("summary") ?: error("course response has no summary")).asText())
        facts.set<JsonNode>("recommendedDate", course.get("recommendedDate") ?: MAPPER.nullNode())
        facts.set<JsonNode>("congestion", congestionNode)

        return facts
    }
}
```

- [ ] **Step 4: `FactsNormalizer`가 투영을 위임하게 고친다**

`server/src/main/kotlin/com/hermes/harness/FactsNormalizer.kt`를 통째로 교체한다. 필드 목록과 조립 로직은 더 이상 여기 없다.

```kotlin
package com.hermes.harness

import com.fasterxml.jackson.databind.JsonNode
import com.fasterxml.jackson.databind.node.ObjectNode
import com.hermes.explain.FactsProjection

/**
 * 픽스처의 `backendResponses`(엔드포인트 문자열을 키로 갖는 응답들)를 facts 로 만든다.
 *
 * 투영 자체는 하지 않는다 — `FactsProjection` 에 위임한다. 운영 경로가 같은 것을
 * 부르므로, 하네스가 측정한 프롬프트와 서버가 보내는 프롬프트가 같은 모양이다.
 */
object FactsNormalizer {

    /**
     * `GET /api/v1/attractions/1001` 은 뺀다 — 유일하게 고유한 필드인 `area` 를
     * 설명이 쓰지 않으므로 스펙이 이 호출 자체를 쳐냈다.
     */
    fun normalize(fixture: JsonNode): ObjectNode {
        val backendResponses = fixture.get("backendResponses") ?: error("fixture missing backendResponses")

        fun dataOf(endpoint: String): JsonNode =
            (backendResponses.get(endpoint) ?: error("fixture missing endpoint: $endpoint"))
                .get("data") ?: error("endpoint '$endpoint' response has no data")

        return FactsProjection.assemble(
            course = dataOf("GET /api/v1/courses/{uuid}"),
            alternatives = dataOf("GET /api/v1/attractions/1001/alternatives?date=2026-08-15&radius=15"),
            congestion = dataOf("GET /api/v1/attractions/1001/congestion?date=2026-08-15"),
        )
    }
}
```

- [ ] **Step 5: 기존 `FactsNormalizerTest`가 그대로 통과하는지 확인한다**

Run: `./gradlew test --tests 'com.hermes.harness.FactsNormalizerTest' --tests 'com.hermes.explain.FactsProjectionTest'`
Expected: PASS — 기존 1개 + 새 4개. 기존 테스트가 손대지 않고 통과하는 것이 이 리팩터링이 동작을 바꾸지 않았다는 증거다.

- [ ] **Step 6: 커밋**

```bash
git add server/src/main/kotlin/com/hermes/explain/FactsProjection.kt \
        server/src/main/kotlin/com/hermes/harness/FactsNormalizer.kt \
        server/src/test/kotlin/com/hermes/explain/FactsProjectionTest.kt
git commit -m "refactor: give the harness and production one facts projection"
```

---

### Task 3: 한적 클라이언트

**Files:**
- Create: `server/src/main/kotlin/com/hermes/facts/HanjeokResponses.kt`
- Create: `server/src/main/kotlin/com/hermes/facts/HanjeokClient.kt`
- Test: `server/src/test/kotlin/com/hermes/facts/HanjeokClientTest.kt`

**Interfaces:**
- Consumes: 없음
- Produces:
  - `class HanjeokUnavailableException(message: String, cause: Throwable? = null) : RuntimeException(message, cause)`
  - `interface HanjeokClient` — `fun course(courseUuid: String): JsonNode`, `fun congestion(attractionId: Long, date: String): JsonNode`, `fun alternatives(attractionId: Long, date: String, radiusKm: Int): JsonNode`. 각각 응답 봉투를 벗긴 `data`를 돌려주고, 실패 시 `HanjeokUnavailableException`을 던진다.
  - `class RestHanjeokClient(private val rest: RestClient) : HanjeokClient`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

봉투 해제와 실패 처리만 본다. 네트워크는 쓰지 않는다 — `RestClient`를 `MockRestServiceServer`로 감싼다.

`server/src/test/kotlin/com/hermes/facts/HanjeokClientTest.kt`:

```kotlin
package com.hermes.facts

import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import org.springframework.http.MediaType
import org.springframework.test.web.client.MockRestServiceServer
import org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo
import org.springframework.test.web.client.response.MockRestResponseCreators.withServerError
import org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess
import org.springframework.web.client.RestClient

class HanjeokClientTest {

    private val builder = RestClient.builder().baseUrl("http://hanjeok.test")
    private val server = MockRestServiceServer.bindTo(builder).build()
    private val client = RestHanjeokClient(builder.build())

    @Test
    fun `코스 응답의 봉투를 벗겨 data 를 돌려준다`() {
        server.expect(requestTo("http://hanjeok.test/api/v1/courses/abc"))
            .andRespond(
                withSuccess(
                    """{"success":true,"error":null,"data":{"targetDate":"2026-08-15","items":[]}}""",
                    MediaType.APPLICATION_JSON,
                ),
            )

        assertThat(client.course("abc").at("/targetDate").asText()).isEqualTo("2026-08-15")
    }

    @Test
    fun `success 가 false 면 실패로 다룬다`() {
        // HTTP 200 에 success:false 가 오는 경로다. 상태 코드만 보면 통과한다.
        server.expect(requestTo("http://hanjeok.test/api/v1/courses/abc"))
            .andRespond(
                withSuccess(
                    """{"success":false,"error":"NOT_FOUND","data":null}""",
                    MediaType.APPLICATION_JSON,
                ),
            )

        assertThatThrownBy { client.course("abc") }
            .isInstanceOf(HanjeokUnavailableException::class.java)
            .hasMessageContaining("NOT_FOUND")
    }

    @Test
    fun `5xx 는 예외로 바뀐다`() {
        server.expect(requestTo("http://hanjeok.test/api/v1/courses/abc")).andRespond(withServerError())

        assertThatThrownBy { client.course("abc") }
            .isInstanceOf(HanjeokUnavailableException::class.java)
    }

    @Test
    fun `혼잡도와 대안 URL 이 스펙대로 조립된다`() {
        server.expect(requestTo("http://hanjeok.test/api/v1/attractions/1001/congestion?date=2026-08-15"))
            .andRespond(withSuccess("""{"success":true,"error":null,"data":{"diagnosis":{}}}""", MediaType.APPLICATION_JSON))
        server.expect(
            requestTo("http://hanjeok.test/api/v1/attractions/1001/alternatives?date=2026-08-15&radius=15"),
        ).andRespond(withSuccess("""{"success":true,"error":null,"data":[]}""", MediaType.APPLICATION_JSON))

        client.congestion(1001, "2026-08-15")
        client.alternatives(1001, "2026-08-15", 15)

        server.verify()
    }
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인한다**

Run: `./gradlew test --tests 'com.hermes.facts.HanjeokClientTest'`
Expected: FAIL — `Unresolved reference: RestHanjeokClient`

- [ ] **Step 3: 구현한다**

`server/src/main/kotlin/com/hermes/facts/HanjeokResponses.kt`:

```kotlin
package com.hermes.facts

/** 한적은 모든 응답을 이 봉투에 담는다. HTTP 200 에 success=false 가 올 수 있다. */
class HanjeokUnavailableException(message: String, cause: Throwable? = null) : RuntimeException(message, cause)
```

`server/src/main/kotlin/com/hermes/facts/HanjeokClient.kt`:

```kotlin
package com.hermes.facts

import com.fasterxml.jackson.databind.JsonNode
import org.springframework.web.client.RestClient

interface HanjeokClient {
    fun course(courseUuid: String): JsonNode
    fun congestion(attractionId: Long, date: String): JsonNode
    fun alternatives(attractionId: Long, date: String, radiusKm: Int): JsonNode
}

/**
 * 한적 공개 API 클라이언트.
 *
 * 아웃바운드 호출이므로 스펙 §2.2 의 HTTP 금지 대상이 아니다 — 그 금지는
 * 인바운드(요청을 받는 것)에 관한 것이고, 하네스는 이 클라이언트를 대역으로
 * 갈아끼워 서버 없이 application 층을 구동한다.
 *
 * 재시도하지 않는다. 스펙 §8 이 한적 실패를 재시도 없는 503 으로 규정한다 —
 * 설명이 없는 것은 안전한 실패이고, 한적의 규칙 기반 문구가 남는다.
 */
class RestHanjeokClient(private val rest: RestClient) : HanjeokClient {

    override fun course(courseUuid: String): JsonNode =
        get("/api/v1/courses/{uuid}", mapOf("uuid" to courseUuid))

    override fun congestion(attractionId: Long, date: String): JsonNode =
        get("/api/v1/attractions/{id}/congestion?date={date}", mapOf("id" to attractionId, "date" to date))

    override fun alternatives(attractionId: Long, date: String, radiusKm: Int): JsonNode =
        get(
            "/api/v1/attractions/{id}/alternatives?date={date}&radius={radius}",
            mapOf("id" to attractionId, "date" to date, "radius" to radiusKm),
        )

    private fun get(template: String, vars: Map<String, Any>): JsonNode {
        val body: JsonNode = try {
            rest.get().uri(template, vars).retrieve().body(JsonNode::class.java)
                ?: throw HanjeokUnavailableException("hanjeok returned an empty body for $template")
        } catch (e: HanjeokUnavailableException) {
            throw e
        } catch (e: Exception) {
            throw HanjeokUnavailableException("hanjeok call failed for $template: ${e::class.simpleName}", e)
        }

        if (!body.path("success").asBoolean(false)) {
            throw HanjeokUnavailableException(
                "hanjeok answered success=false for $template: ${body.path("error").asText("unknown")}",
            )
        }

        return body.get("data") ?: throw HanjeokUnavailableException("hanjeok response carried no data for $template")
    }
}
```

- [ ] **Step 4: 테스트가 통과하는지 확인한다**

Run: `./gradlew test --tests 'com.hermes.facts.HanjeokClientTest'`
Expected: PASS — 4개 통과

- [ ] **Step 5: 커밋**

```bash
git add server/src/main/kotlin/com/hermes/facts/ server/src/test/kotlin/com/hermes/facts/
git commit -m "feat: call hanjeok and unwrap its response envelope"
```

---

### Task 4: facts 조회 — 코스 1회, 그 다음 병렬 2회

**Files:**
- Create: `server/src/main/kotlin/com/hermes/facts/FactsSource.kt`
- Test: `server/src/test/kotlin/com/hermes/facts/FactsSourceTest.kt`

**Interfaces:**
- Consumes: `HanjeokClient`, `HanjeokUnavailableException` (Task 3); `FactsProjection.assemble` (Task 2); `BackendFacts(courseUuid, json)` (계획 1, `com.hermes.explain`)
- Produces: `class FactsSource(private val client: HanjeokClient, private val radiusKm: Int = 15, private val executor: java.util.concurrent.ExecutorService)` — `fun fetch(courseUuid: String): BackendFacts`, 실패 시 `HanjeokUnavailableException`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`server/src/test/kotlin/com/hermes/facts/FactsSourceTest.kt`:

```kotlin
package com.hermes.facts

import com.fasterxml.jackson.databind.JsonNode
import com.fasterxml.jackson.databind.ObjectMapper
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import java.util.concurrent.Executors

class FactsSourceTest {

    private val mapper = ObjectMapper()

    private val courseJson = """
        {"targetDate":"2026-08-15","title":"제목","congestionReductionRate":34,"summary":"요약",
         "recommendedDate":null,
         "items":[{"attractionId":1001,"name":"경복궁","visitOrder":1,"timeLabel":"오전 10:00",
                   "grade":"VERY_CROWDED","reason":"첫 방문지","travelMinutesFromPrev":null},
                  {"attractionId":1003,"name":"북촌 한옥마을","visitOrder":2,"timeLabel":"오전 11:38",
                   "grade":"NORMAL","reason":"한산","travelMinutesFromPrev":8}]}
    """.trimIndent()

    private val congestionJson =
        """{"diagnosis":{"concentration":87.3,"percentile":92,"grade":"VERY_CROWDED","message":"붐빈다"},
            "betterDates":[]}"""

    private val alternativesJson =
        """[{"attractionId":1003,"name":"북촌 한옥마을","grade":"NORMAL","concentration":62.0,
             "distanceKm":0.6,"relationScore":0.9,"score":0.704,"recommendReason":"여유","travelMinutes":8}]"""

    private open inner class FakeClient : HanjeokClient {
        val calls = mutableListOf<String>()
        override fun course(courseUuid: String): JsonNode {
            calls += "course:$courseUuid"; return mapper.readTree(courseJson)
        }
        override fun congestion(attractionId: Long, date: String): JsonNode {
            calls += "congestion:$attractionId:$date"; return mapper.readTree(congestionJson)
        }
        override fun alternatives(attractionId: Long, date: String, radiusKm: Int): JsonNode {
            calls += "alternatives:$attractionId:$date:$radiusKm"; return mapper.readTree(alternativesJson)
        }
    }

    private val executor = Executors.newFixedThreadPool(2)

    @Test
    fun `호출은 3회이고 대상과 날짜를 코스 응답에서 파생한다`() {
        // 목적지는 언제나 visitOrder 1 이다 — CourseRoutePolicy.bestOrder 가
        // listOf(originId) + best 를 반환하므로 첫 항목이 목적지다.
        val client = FakeClient()

        FactsSource(client, radiusKm = 15, executor = executor).fetch("abc")

        assertThat(client.calls).hasSize(3)
        assertThat(client.calls).contains("course:abc", "congestion:1001:2026-08-15", "alternatives:1001:2026-08-15:15")
        // attractions/{id} 는 부르지 않는다 — 스펙 §3 이 잘라냈다.
        assertThat(client.calls).noneMatch { it.startsWith("attraction:") }
    }

    @Test
    fun `조립된 facts 가 검사기와 프롬프트가 읽는 모양이다`() {
        val facts = FactsSource(FakeClient(), 15, executor).fetch("abc")
        val parsed = mapper.readTree(facts.json)

        assertThat(facts.courseUuid).isEqualTo("abc")
        assertThat(parsed.at("/items/0/name").asText()).isEqualTo("경복궁")
        assertThat(parsed.at("/alternatives/0/score").asDouble()).isEqualTo(0.704)
        assertThat(parsed.at("/congestion/percentile").asInt()).isEqualTo(92)
    }

    @Test
    fun `병렬 호출 중 하나가 실패하면 전체가 실패한다`() {
        // 반쪽짜리 facts 로 설명을 만들면 없는 근거를 지어내라고 시키는 것과 같다.
        val client = object : FakeClient() {
            override fun alternatives(attractionId: Long, date: String, radiusKm: Int): JsonNode =
                throw HanjeokUnavailableException("boom")
        }

        assertThatThrownBy { FactsSource(client, 15, executor).fetch("abc") }
            .isInstanceOf(HanjeokUnavailableException::class.java)
    }

    @Test
    fun `코스에 항목이 없으면 실패한다`() {
        val client = object : FakeClient() {
            override fun course(courseUuid: String): JsonNode =
                mapper.readTree("""{"targetDate":"2026-08-15","items":[]}""")
        }

        assertThatThrownBy { FactsSource(client, 15, executor).fetch("abc") }
            .isInstanceOf(HanjeokUnavailableException::class.java)
    }
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인한다**

Run: `./gradlew test --tests 'com.hermes.facts.FactsSourceTest'`
Expected: FAIL — `Unresolved reference: FactsSource`

- [ ] **Step 3: 구현한다**

`server/src/main/kotlin/com/hermes/facts/FactsSource.kt`:

```kotlin
package com.hermes.facts

import com.fasterxml.jackson.databind.JsonNode
import com.hermes.explain.BackendFacts
import com.hermes.explain.FactsProjection
import java.util.concurrent.CompletableFuture
import java.util.concurrent.CompletionException
import java.util.concurrent.ExecutorService

/**
 * 한적에서 사실을 모은다 — 호출 3회, 왕복 2회.
 *
 * 코스를 먼저 받아야 대상 관광지와 날짜를 알 수 있고, 그 둘이 정해지면 혼잡도와
 * 대안은 서로를 기다릴 이유가 없으므로 병렬로 간다.
 *
 * 목적지는 언제나 `visitOrder` 가 가장 작은 항목이다. `CourseRoutePolicy.bestOrder`
 * 가 `listOf(originId) + best` 를 반환하므로 목적지는 늘 첫 방문지이고 뒤로 밀리지
 * 않는다(concepts/travel-context-layer.md).
 */
class FactsSource(
    private val client: HanjeokClient,
    private val radiusKm: Int = 15,
    private val executor: ExecutorService,
) {

    fun fetch(courseUuid: String): BackendFacts {
        val course = client.course(courseUuid)

        val items = course.get("items")
        if (items == null || !items.isArray || items.isEmpty) {
            throw HanjeokUnavailableException("course $courseUuid carried no items")
        }

        val destination = items.minByOrNull { it.path("visitOrder").asInt(Int.MAX_VALUE) }
            ?: throw HanjeokUnavailableException("course $courseUuid has no destination item")
        val attractionId = destination.path("attractionId").asLong(0L)
        if (attractionId == 0L) throw HanjeokUnavailableException("destination item has no attractionId")

        val date = course.path("targetDate").asText(null)
            ?: throw HanjeokUnavailableException("course $courseUuid has no targetDate")

        val congestionFuture = CompletableFuture.supplyAsync({ client.congestion(attractionId, date) }, executor)
        val alternativesFuture =
            CompletableFuture.supplyAsync({ client.alternatives(attractionId, date, radiusKm) }, executor)

        val congestion = join(congestionFuture, "congestion")
        val alternatives = join(alternativesFuture, "alternatives")

        val facts = try {
            FactsProjection.assemble(course = course, alternatives = alternatives, congestion = congestion)
        } catch (e: IllegalStateException) {
            // 투영은 필드가 빠지면 error() 를 던진다. 반쪽짜리 facts 로 설명을
            // 만들면 없는 근거를 지어내라고 시키는 것과 같으므로 여기서 멈춘다.
            throw HanjeokUnavailableException("hanjeok response did not carry the expected fields: ${e.message}", e)
        }

        return BackendFacts(courseUuid = courseUuid, json = facts.toString())
    }

    private fun join(future: CompletableFuture<JsonNode>, what: String): JsonNode = try {
        future.join()
    } catch (e: CompletionException) {
        val cause = e.cause
        if (cause is HanjeokUnavailableException) throw cause
        throw HanjeokUnavailableException("hanjeok $what call failed: ${cause?.let { it::class.simpleName }}", cause)
    }
}
```

- [ ] **Step 4: 테스트가 통과하는지 확인한다**

Run: `./gradlew test --tests 'com.hermes.facts.FactsSourceTest'`
Expected: PASS — 4개 통과

- [ ] **Step 5: 커밋**

```bash
git add server/src/main/kotlin/com/hermes/facts/FactsSource.kt \
        server/src/test/kotlin/com/hermes/facts/FactsSourceTest.kt
git commit -m "feat: gather backend facts in three calls and two round trips"
```

---

### Task 5: 캐시와 application 진입점

**Files:**
- Create: `server/src/main/kotlin/com/hermes/explain/ExplanationCache.kt`
- Create: `server/src/main/kotlin/com/hermes/explain/CourseExplainer.kt`
- Test: `server/src/test/kotlin/com/hermes/explain/ExplanationCacheTest.kt`
- Test: `server/src/test/kotlin/com/hermes/explain/CourseExplainerTest.kt`

**Interfaces:**
- Consumes: `FactsSource` (Task 4), `HanjeokUnavailableException` (Task 3), `ExplanationService`/`ExplainOutcome`/`Explained`/`Unavailable`/`BackendFacts` (계획 1), `Explanation` (계획 1, `com.hermes.llm`)
- Produces:
  - `class ExplanationCache(private val maxEntries: Int = 1000)` — `fun get(courseUuid: String): Explanation?`, `fun put(courseUuid: String, explanation: Explanation)`, `fun size(): Int`
  - `data class CourseExplanation(val explanation: Explanation, val factsJson: String, val cached: Boolean)`
  - `class CourseExplainer(private val factsSource: FactsSource, private val service: ExplanationService, private val cache: ExplanationCache)` — `fun explain(courseUuid: String): CourseExplanation`, 실패 시 `ExplanationUnavailableException`

- [ ] **Step 1: 캐시의 실패하는 테스트를 쓴다**

`server/src/test/kotlin/com/hermes/explain/ExplanationCacheTest.kt`:

```kotlin
package com.hermes.explain

import com.hermes.llm.Explanation
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test

class ExplanationCacheTest {

    private fun explanation(text: String) = Explanation(text, listOf("concepts/congestion-diagnosis.md"))

    @Test
    fun `넣은 것을 돌려준다`() {
        val cache = ExplanationCache()
        cache.put("a", explanation("설명 A"))

        assertThat(cache.get("a")?.explanation).isEqualTo("설명 A")
        assertThat(cache.get("b")).isNull()
    }

    @Test
    fun `상한을 넘으면 가장 오래 안 쓴 항목부터 버린다`() {
        val cache = ExplanationCache(maxEntries = 2)
        cache.put("a", explanation("A"))
        cache.put("b", explanation("B"))
        cache.get("a")             // a 를 최근 사용으로 만든다
        cache.put("c", explanation("C"))

        assertThat(cache.size()).isEqualTo(2)
        assertThat(cache.get("b")).describedAs("가장 오래 안 쓴 b 가 밀려나야 한다").isNull()
        assertThat(cache.get("a")).isNotNull()
        assertThat(cache.get("c")).isNotNull()
    }
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인한다**

Run: `./gradlew test --tests 'com.hermes.explain.ExplanationCacheTest'`
Expected: FAIL — `Unresolved reference: ExplanationCache`

- [ ] **Step 3: 캐시를 구현한다**

`server/src/main/kotlin/com/hermes/explain/ExplanationCache.kt`:

```kotlin
package com.hermes.explain

import com.hermes.llm.Explanation
import java.util.Collections

/**
 * `courseUuid` → 설명. 코스는 불변이므로 같은 uuid 는 같은 설명이다.
 *
 * Redis 공유 캐시를 넣지 않는다(08-17 설계문 §8) — 재시작이 드물고, 필요해지면
 * 그때 붙인다. 인메모리이므로 인스턴스가 늘면 적중률이 나뉜다는 것은 알려진 대가다.
 */
class ExplanationCache(private val maxEntries: Int = 1000) {

    private val entries: MutableMap<String, Explanation> = Collections.synchronizedMap(
        object : LinkedHashMap<String, Explanation>(16, 0.75f, true) {
            override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, Explanation>): Boolean =
                size > maxEntries
        },
    )

    fun get(courseUuid: String): Explanation? = entries[courseUuid]

    fun put(courseUuid: String, explanation: Explanation) {
        entries[courseUuid] = explanation
    }

    fun size(): Int = entries.size
}
```

- [ ] **Step 4: 진입점의 실패하는 테스트를 쓴다**

`server/src/test/kotlin/com/hermes/explain/CourseExplainerTest.kt`:

```kotlin
package com.hermes.explain

import com.hermes.context.BundleLoader
import com.hermes.context.CitationValidator
import com.hermes.context.PromptAssembler
import com.hermes.explain.presentation.ExplanationUnavailableException
import com.hermes.facts.FactsSource
import com.hermes.facts.HanjeokClient
import com.hermes.facts.HanjeokUnavailableException
import com.hermes.llm.Answered
import com.hermes.llm.Explanation
import com.hermes.llm.ExplanationProvider
import com.hermes.llm.Failed
import com.hermes.llm.ProviderResult
import com.hermes.llm.ProviderUsage
import com.fasterxml.jackson.databind.JsonNode
import com.fasterxml.jackson.databind.ObjectMapper
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import java.util.concurrent.Executors

class CourseExplainerTest {

    private val mapper = ObjectMapper()
    private val bundle = BundleLoader.load()
    private val executor = Executors.newFixedThreadPool(2)

    private val courseJson = """
        {"targetDate":"2026-08-15","title":"제목","congestionReductionRate":34,"summary":"요약",
         "recommendedDate":null,
         "items":[{"attractionId":1001,"name":"경복궁","visitOrder":1,"timeLabel":"오전 10:00",
                   "grade":"VERY_CROWDED","reason":"첫 방문지","travelMinutesFromPrev":null}]}
    """.trimIndent()

    private open inner class FakeClient : HanjeokClient {
        override fun course(courseUuid: String): JsonNode = mapper.readTree(courseJson)
        override fun congestion(attractionId: Long, date: String): JsonNode = mapper.readTree(
            """{"diagnosis":{"concentration":87.3,"percentile":92,"grade":"VERY_CROWDED","message":"붐빈다"},"betterDates":[]}""",
        )
        override fun alternatives(attractionId: Long, date: String, radiusKm: Int): JsonNode = mapper.readTree("[]")
    }

    private class CountingProvider(private val result: ProviderResult) : ExplanationProvider {
        override val name = "counting"
        var calls = 0
        override fun explain(systemText: String, factsJson: String): ProviderResult {
            calls++; return result
        }
    }

    private fun explainer(
        provider: ExplanationProvider,
        client: HanjeokClient = FakeClient(),
        cache: ExplanationCache = ExplanationCache(),
    ) = CourseExplainer(
        factsSource = FactsSource(client, 15, executor),
        service = ExplanationService(PromptAssembler(bundle), CitationValidator(bundle), provider),
        cache = cache,
    )

    private fun answered() = Answered(
        Explanation("경복궁은 붐빕니다.", listOf("concepts/congestion-diagnosis.md")),
        ProviderUsage(0, 0, 0, 0),
    )

    @Test
    fun `설명과 함께 facts 를 돌려준다`() {
        // 프론트가 코스를 그리려면 facts 가 필요하고, 그래야 한적을 직접 안 부른다.
        val result = explainer(CountingProvider(answered())).explain("abc")

        assertThat(result.explanation.explanation).isEqualTo("경복궁은 붐빕니다.")
        assertThat(mapper.readTree(result.factsJson).at("/items/0/name").asText()).isEqualTo("경복궁")
        assertThat(result.cached).isFalse()
    }

    @Test
    fun `같은 uuid 를 다시 물으면 모델을 다시 부르지 않는다`() {
        val provider = CountingProvider(answered())
        val explainer = explainer(provider)

        explainer.explain("abc")
        val second = explainer.explain("abc")

        assertThat(provider.calls).describedAs("코스는 불변이므로 한 번이면 된다").isEqualTo(1)
        assertThat(second.cached).isTrue()
    }

    @Test
    fun `한적이 실패하면 설명 불가로 바뀐다`() {
        val client = object : FakeClient() {
            override fun course(courseUuid: String): JsonNode = throw HanjeokUnavailableException("down")
        }

        assertThatThrownBy { explainer(CountingProvider(answered()), client).explain("abc") }
            .isInstanceOf(ExplanationUnavailableException::class.java)
    }

    @Test
    fun `설명 생성이 실패하면 캐시에 넣지 않는다`() {
        // 실패를 캐시하면 일시적 장애가 그 코스에 영구히 눌어붙는다.
        val provider = CountingProvider(Failed("timeout"))
        val cache = ExplanationCache()
        val explainer = explainer(provider, cache = cache)

        assertThatThrownBy { explainer.explain("abc") }.isInstanceOf(ExplanationUnavailableException::class.java)

        assertThat(cache.size()).isZero()
        assertThat(cache.get("abc")).isNull()
    }
}
```

- [ ] **Step 5: 테스트가 실패하는지 확인한다**

Run: `./gradlew test --tests 'com.hermes.explain.CourseExplainerTest'`
Expected: FAIL — `Unresolved reference: CourseExplainer`

- [ ] **Step 6: 진입점을 구현한다**

`server/src/main/kotlin/com/hermes/explain/CourseExplainer.kt`:

```kotlin
package com.hermes.explain

import com.hermes.explain.presentation.ExplanationUnavailableException
import com.hermes.facts.FactsSource
import com.hermes.facts.HanjeokUnavailableException
import com.hermes.llm.Explanation
import org.slf4j.LoggerFactory

data class CourseExplanation(val explanation: Explanation, val factsJson: String, val cached: Boolean)

/**
 * facts 조회 · 설명 생성 · 캐시를 잇는 application 진입점.
 *
 * HTTP 를 모른다 — presentation 이 이것을 부른다. 하네스도 서버 없이 같은 경로를
 * 부를 수 있어야 하므로 여기에 웹 타입이 들어오면 안 된다.
 */
class CourseExplainer(
    private val factsSource: FactsSource,
    private val service: ExplanationService,
    private val cache: ExplanationCache,
) {

    private val log = LoggerFactory.getLogger(CourseExplainer::class.java)

    fun explain(courseUuid: String): CourseExplanation {
        val facts = try {
            factsSource.fetch(courseUuid)
        } catch (e: HanjeokUnavailableException) {
            log.warn("facts unavailable for course {}", courseUuid, e)
            throw ExplanationUnavailableException("facts: ${e.message}")
        }

        cache.get(courseUuid)?.let {
            return CourseExplanation(explanation = it, factsJson = facts.json, cached = true)
        }

        return when (val outcome = service.explain(facts)) {
            is Explained -> {
                // 실패는 캐시하지 않는다 — 일시적 장애가 그 코스에 영구히 눌어붙는다.
                cache.put(courseUuid, outcome.explanation)
                CourseExplanation(explanation = outcome.explanation, factsJson = facts.json, cached = false)
            }
            is Unavailable -> {
                log.warn("explanation unavailable for course {}: {}", courseUuid, outcome.reason)
                throw ExplanationUnavailableException(outcome.reason)
            }
        }
    }
}
```

- [ ] **Step 7: 테스트가 통과하는지 확인한다**

Run: `./gradlew test --tests 'com.hermes.explain.ExplanationCacheTest' --tests 'com.hermes.explain.CourseExplainerTest'`
Expected: PASS — 2개 + 4개

- [ ] **Step 8: 커밋**

```bash
git add server/src/main/kotlin/com/hermes/explain/ExplanationCache.kt \
        server/src/main/kotlin/com/hermes/explain/CourseExplainer.kt \
        server/src/test/kotlin/com/hermes/explain/ExplanationCacheTest.kt \
        server/src/test/kotlin/com/hermes/explain/CourseExplainerTest.kt
git commit -m "feat: cache explanations per course and never cache a failure"
```

---

### Task 6: 엔드포인트 4개

**Files:**
- Create: `server/src/main/kotlin/com/hermes/explain/presentation/ExplainController.kt`
- Create: `server/src/main/kotlin/com/hermes/explain/presentation/ContextController.kt`
- Test: `server/src/test/kotlin/com/hermes/explain/presentation/ExplainControllerTest.kt`
- Test: `server/src/test/kotlin/com/hermes/explain/presentation/ContextControllerTest.kt`

**Interfaces:**
- Consumes: `CourseExplainer`, `CourseExplanation` (Task 5), `ExplanationUnavailableException` (Task 1), `Bundle`, `BundleDocument` (계획 1)
- Produces:
  - `data class ExplainRequest(val courseUuid: String)`
  - `data class ExplainResponse(val explanation: String, val citations: List<String>, val facts: JsonNode, val generatedAt: String, val model: String)`
  - `data class ContextEntry(val path: String, val bytes: Int)`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`server/src/test/kotlin/com/hermes/explain/presentation/ExplainControllerTest.kt`:

```kotlin
package com.hermes.explain.presentation

import com.fasterxml.jackson.databind.ObjectMapper
import com.hermes.explain.CourseExplainer
import com.hermes.explain.CourseExplanation
import com.hermes.llm.Explanation
import org.junit.jupiter.api.Test
import org.mockito.Mockito.mock
import org.mockito.Mockito.`when`
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.setup.MockMvcBuilders
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status

class ExplainControllerTest {

    private val explainer = mock(CourseExplainer::class.java)
    private val mvc: MockMvc = MockMvcBuilders
        .standaloneSetup(ExplainController(explainer, "claude-opus-5", ObjectMapper()))
        .setControllerAdvice(ApiErrorHandler())
        .build()

    @Test
    fun `설명과 인용과 facts 를 함께 돌려준다`() {
        `when`(explainer.explain("abc")).thenReturn(
            CourseExplanation(
                explanation = Explanation("경복궁은 붐빕니다.", listOf("concepts/congestion-diagnosis.md")),
                factsJson = """{"items":[{"name":"경복궁"}]}""",
                cached = false,
            ),
        )

        mvc.perform(
            post("/agent/explain").contentType(MediaType.APPLICATION_JSON)
                .content("""{"courseUuid":"abc"}"""),
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.explanation").value("경복궁은 붐빕니다."))
            .andExpect(jsonPath("$.citations[0]").value("concepts/congestion-diagnosis.md"))
            // 프론트가 코스를 그리려면 facts 가 필요하다 — 그래야 한적을 직접 안 부른다.
            .andExpect(jsonPath("$.facts.items[0].name").value("경복궁"))
            .andExpect(jsonPath("$.model").value("claude-opus-5"))
    }

    @Test
    fun `설명 불가는 503 과 코드만 낸다`() {
        // 사유는 로그에 남고 본문에는 나가지 않는다 — 모델이 거부한 텍스트나
        // 내부 실패 사유가 클라이언트에 노출되면 안 된다.
        `when`(explainer.explain("abc")).thenThrow(ExplanationUnavailableException("citations not in bundle: x.md"))

        mvc.perform(
            post("/agent/explain").contentType(MediaType.APPLICATION_JSON)
                .content("""{"courseUuid":"abc"}"""),
        )
            .andExpect(status().isServiceUnavailable)
            .andExpect(jsonPath("$.code").value("EXPLANATION_UNAVAILABLE"))
            .andExpect(jsonPath("$.reason").doesNotExist())
    }
}
```

`server/src/test/kotlin/com/hermes/explain/presentation/ContextControllerTest.kt`:

```kotlin
package com.hermes.explain.presentation

import com.hermes.context.BundleLoader
import org.junit.jupiter.api.Test
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.setup.MockMvcBuilders
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.content
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status

class ContextControllerTest {

    private val bundle = BundleLoader.load()
    private val mvc: MockMvc = MockMvcBuilders.standaloneSetup(ContextController(bundle)).build()

    @Test
    fun `번들에 담긴 문서 목록을 낸다`() {
        mvc.perform(get("/agent/context"))
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.length()").value(9))
            .andExpect(jsonPath("$[0].path").value("concepts/travel-context-layer.md"))
    }

    @Test
    fun `문서 본문은 LLM 에 보낸 바이트 그대로다`() {
        val expected = bundle.document("concepts/congestion-diagnosis.md")!!.content

        mvc.perform(get("/agent/context/concepts/congestion-diagnosis.md"))
            .andExpect(status().isOk)
            .andExpect(content().string(expected))
    }

    @Test
    fun `번들에 없는 경로는 404 다`() {
        // 인용 검증을 통과한 경로만 존재한다. 목록 밖은 절대 안 나간다.
        mvc.perform(get("/agent/context/concepts/weather-aware-travel-recommendation.md"))
            .andExpect(status().isNotFound)
    }

    @Test
    fun `상위 디렉터리 탈출을 허용하지 않는다`() {
        mvc.perform(get("/agent/context/../../build.gradle.kts")).andExpect(status().isNotFound)
    }
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인한다**

Run: `./gradlew test --tests 'com.hermes.explain.presentation.*'`
Expected: FAIL — `Unresolved reference: ExplainController`

- [ ] **Step 3: 컨트롤러를 구현한다**

`server/src/main/kotlin/com/hermes/explain/presentation/ExplainController.kt`:

```kotlin
package com.hermes.explain.presentation

import com.fasterxml.jackson.databind.JsonNode
import com.fasterxml.jackson.databind.ObjectMapper
import com.hermes.explain.CourseExplainer
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RestController
import java.time.Instant

data class ExplainRequest(val courseUuid: String)

data class ExplainResponse(
    val explanation: String,
    val citations: List<String>,
    val facts: JsonNode,
    val generatedAt: String,
    val model: String,
)

@RestController
class ExplainController(
    private val explainer: CourseExplainer,
    private val model: String,
    private val mapper: ObjectMapper,
) {

    /**
     * 클라이언트는 `courseUuid` 만 보낸다. facts 를 실어 보내게 두면 위조된
     * 혼잡도를 LLM 이 그럴듯하게 설명해 주는 경로가 생긴다 — 사실의 출처는
     * 언제나 백엔드여야 한다(스펙 §3).
     */
    @PostMapping("/agent/explain")
    fun explain(@RequestBody request: ExplainRequest): ExplainResponse {
        val result = explainer.explain(request.courseUuid)
        return ExplainResponse(
            explanation = result.explanation.explanation,
            citations = result.explanation.citations,
            facts = mapper.readTree(result.factsJson),
            generatedAt = Instant.now().toString(),
            model = model,
        )
    }
}
```

`server/src/main/kotlin/com/hermes/explain/presentation/ContextController.kt`:

```kotlin
package com.hermes.explain.presentation

import com.hermes.context.Bundle
import org.springframework.http.MediaType
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RestController
import org.springframework.web.servlet.HandlerMapping
import jakarta.servlet.http.HttpServletRequest

data class ContextEntry(val path: String, val bytes: Int)

/**
 * 인용이 가리키는 곳.
 *
 * GitHub 링크를 쓰지 않는다 — 그건 설명이 근거한 문서가 아니라 *오늘의* 문서를
 * 연다. 서버는 이미 번들을 메모리에 들고 있으므로, 그것을 읽기 전용으로 내면
 * 설명과 근거가 같은 판본임이 보장된다(스펙 §5).
 */
@RestController
class ContextController(private val bundle: Bundle) {

    @GetMapping("/agent/context")
    fun list(): List<ContextEntry> =
        bundle.documents.map { ContextEntry(path = it.path, bytes = it.content.toByteArray(Charsets.UTF_8).size) }

    @GetMapping("/agent/context/**", produces = [MediaType.TEXT_PLAIN_VALUE])
    fun document(request: HttpServletRequest): ResponseEntity<String> {
        val full = request.getAttribute(HandlerMapping.PATH_WITHIN_HANDLER_MAPPING_ATTRIBUTE) as String
        val path = full.removePrefix("/agent/context/")

        // 번들 목록에 있는 경로만 존재한다. 정규화나 접두사 일치를 하지 않으므로
        // `..` 를 포함한 경로는 목록에 없어 그대로 404 가 된다.
        val document = bundle.document(path) ?: return ResponseEntity.notFound().build()
        return ResponseEntity.ok(document.content)
    }
}
```

- [ ] **Step 4: 테스트가 통과하는지 확인한다**

Run: `./gradlew test --tests 'com.hermes.explain.presentation.*'`
Expected: PASS — 2개 + 4개

- [ ] **Step 5: 커밋**

```bash
git add server/src/main/kotlin/com/hermes/explain/presentation/ \
        server/src/test/kotlin/com/hermes/explain/presentation/
git commit -m "feat: expose explain and serve citations from the bundled copy"
```

---

### Task 7: 스프링 구성과 헬스

**Files:**
- Create: `server/src/main/kotlin/com/hermes/shared/config/HermesConfig.kt`
- Create: `server/src/main/kotlin/com/hermes/shared/config/BundleHealthIndicator.kt`
- Create: `server/src/main/resources/application.yml`
- Test: `server/src/test/kotlin/com/hermes/shared/config/BundleHealthIndicatorTest.kt`
- Test: `server/src/test/kotlin/com/hermes/ApplicationContextTest.kt`

**Interfaces:**
- Consumes: 앞선 모든 타입
- Produces: 뜨는 애플리케이션 컨텍스트. `BundleHealthIndicator` — 번들이 비었거나 적재 실패면 DOWN.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`server/src/test/kotlin/com/hermes/shared/config/BundleHealthIndicatorTest.kt`:

```kotlin
package com.hermes.shared.config

import com.hermes.context.Bundle
import com.hermes.context.BundleDocument
import com.hermes.context.BundleLoader
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.boot.actuate.health.Status

class BundleHealthIndicatorTest {

    @Test
    fun `번들이 적재됐으면 UP 이고 문서 수와 바이트를 보고한다`() {
        val health = BundleHealthIndicator(BundleLoader.load()).health()

        assertThat(health.status).isEqualTo(Status.UP)
        assertThat(health.details["documents"]).isEqualTo(9)
        assertThat(health.details["bytes"]).isEqualTo(15681)
    }

    @Test
    fun `번들이 비었으면 DOWN 이다`() {
        // 근거 없이 뜨면 안 된다 — 인용할 것이 없는 서버는 설명을 낼 수 없다.
        val health = BundleHealthIndicator(Bundle(emptyList<BundleDocument>(), "")).health()

        assertThat(health.status).isEqualTo(Status.DOWN)
    }
}
```

`server/src/test/kotlin/com/hermes/ApplicationContextTest.kt`:

```kotlin
package com.hermes

import com.hermes.explain.CourseExplainer
import com.hermes.explain.presentation.ContextController
import com.hermes.explain.presentation.ExplainController
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest

/**
 * 배선이 실제로 물리는지 본다. 단위 테스트가 전부 통과해도 빈 하나가 빠지면
 * 서버는 뜨지 않는다 — 그 실패를 배포가 아니라 여기서 만난다.
 *
 * 어떤 외부 호출도 하지 않는다. 프로바이더는 키 없이 생성되고(호출하지 않으므로
 * 문제되지 않는다), 한적 클라이언트는 base URL 만 잡는다.
 */
@SpringBootTest(properties = ["hermes.hanjeok.base-url=http://localhost:1", "ANTHROPIC_API_KEY=not-used-in-this-test"])
class ApplicationContextTest {

    @Autowired lateinit var explainer: CourseExplainer
    @Autowired lateinit var explainController: ExplainController
    @Autowired lateinit var contextController: ContextController

    @Test
    fun `컨텍스트가 뜨고 핵심 빈이 물린다`() {
        assertThat(explainer).isNotNull()
        assertThat(explainController).isNotNull()
        assertThat(contextController).isNotNull()
    }
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인한다**

Run: `./gradlew test --tests 'com.hermes.ApplicationContextTest'`
Expected: FAIL — 빈 생성 실패(`HermesConfig`가 없다)

- [ ] **Step 3: 구성을 구현한다**

`server/src/main/resources/application.yml`:

```yaml
hermes:
  hanjeok:
    base-url: ${HANJEOK_BASE_URL:https://api.hanjeok.example}
    radius-km: 15
    timeout-seconds: 5
  llm:
    model: claude-opus-5
  cors:
    allowed-origins: ${HERMES_CORS_ALLOWED_ORIGINS:http://localhost:3000}

management:
  endpoints:
    web:
      exposure:
        include: health
  endpoint:
    health:
      show-details: always
```

`server/src/main/kotlin/com/hermes/shared/config/BundleHealthIndicator.kt`:

```kotlin
package com.hermes.shared.config

import com.hermes.context.Bundle
import org.springframework.boot.actuate.health.Health
import org.springframework.boot.actuate.health.HealthIndicator
import org.springframework.stereotype.Component

/** 근거 없이 뜨면 안 된다 — 인용할 것이 없는 서버는 설명을 낼 수 없다. */
@Component
class BundleHealthIndicator(private val bundle: Bundle) : HealthIndicator {

    override fun health(): Health {
        if (bundle.documents.isEmpty()) {
            return Health.down().withDetail("reason", "context bundle is empty").build()
        }
        return Health.up()
            .withDetail("documents", bundle.documents.size)
            .withDetail("bytes", bundle.byteSize())
            .build()
    }
}
```

`server/src/main/kotlin/com/hermes/shared/config/HermesConfig.kt`:

```kotlin
package com.hermes.shared.config

import com.anthropic.client.okhttp.AnthropicOkHttpClient
import com.fasterxml.jackson.databind.ObjectMapper
import com.hermes.context.Bundle
import com.hermes.context.BundleLoader
import com.hermes.context.CitationValidator
import com.hermes.context.PromptAssembler
import com.hermes.explain.CourseExplainer
import com.hermes.explain.ExplanationCache
import com.hermes.explain.ExplanationService
import com.hermes.facts.FactsSource
import com.hermes.facts.HanjeokClient
import com.hermes.facts.RestHanjeokClient
import com.hermes.llm.AnthropicExplanationProvider
import com.hermes.llm.ExplanationProvider
import org.springframework.beans.factory.annotation.Value
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.web.client.RestClient
import org.springframework.web.servlet.config.annotation.CorsRegistry
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer
import java.time.Duration
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

@Configuration
class HermesConfig {

    /** 부팅 시 1회 적재하고 그 뒤로는 파일을 읽지 않는다(08-17 설계문 §5). */
    @Bean
    fun bundle(): Bundle = BundleLoader.load()

    @Bean
    fun promptAssembler(bundle: Bundle): PromptAssembler = PromptAssembler(bundle)

    @Bean
    fun citationValidator(bundle: Bundle): CitationValidator = CitationValidator(bundle)

    @Bean
    fun explanationProvider(): ExplanationProvider =
        AnthropicExplanationProvider(AnthropicOkHttpClient.fromEnv())

    @Bean
    fun hanjeokRestClient(
        @Value("\${hermes.hanjeok.base-url}") baseUrl: String,
        @Value("\${hermes.hanjeok.timeout-seconds}") timeoutSeconds: Long,
    ): RestClient = RestClient.builder()
        .baseUrl(baseUrl)
        .requestFactory(
            org.springframework.http.client.SimpleClientHttpRequestFactory().apply {
                setConnectTimeout(Duration.ofSeconds(timeoutSeconds))
                setReadTimeout(Duration.ofSeconds(timeoutSeconds))
            },
        )
        .build()

    @Bean
    fun hanjeokClient(hanjeokRestClient: RestClient): HanjeokClient = RestHanjeokClient(hanjeokRestClient)

    /** 병렬 호출은 둘뿐이다. 스레드를 넉넉히 잡을 이유가 없다. */
    @Bean(destroyMethod = "shutdown")
    fun factsExecutor(): ExecutorService = Executors.newFixedThreadPool(4)

    @Bean
    fun factsSource(
        hanjeokClient: HanjeokClient,
        @Value("\${hermes.hanjeok.radius-km}") radiusKm: Int,
        factsExecutor: ExecutorService,
    ): FactsSource = FactsSource(hanjeokClient, radiusKm, factsExecutor)

    @Bean
    fun explanationCache(): ExplanationCache = ExplanationCache()

    @Bean
    fun explanationService(
        promptAssembler: PromptAssembler,
        citationValidator: CitationValidator,
        explanationProvider: ExplanationProvider,
    ): ExplanationService = ExplanationService(promptAssembler, citationValidator, explanationProvider)

    @Bean
    fun courseExplainer(
        factsSource: FactsSource,
        explanationService: ExplanationService,
        explanationCache: ExplanationCache,
    ): CourseExplainer = CourseExplainer(factsSource, explanationService, explanationCache)

    @Bean
    fun explainControllerModel(@Value("\${hermes.llm.model}") model: String): String = model

    @Bean
    fun corsConfigurer(
        @Value("\${hermes.cors.allowed-origins}") origins: String,
    ): WebMvcConfigurer = object : WebMvcConfigurer {
        override fun addCorsMappings(registry: CorsRegistry) {
            registry.addMapping("/agent/**")
                .allowedOrigins(*origins.split(",").map { it.trim() }.toTypedArray())
                .allowedMethods("GET", "POST")
        }
    }
}
```

`ExplainController`가 `String` 빈 두 개(model)와 충돌하지 않도록, 컨트롤러의 생성자 파라미터를 `@Value`로 직접 받게 바꾼다. `server/src/main/kotlin/com/hermes/explain/presentation/ExplainController.kt`의 생성자를 다음으로 교체하고 `explainControllerModel` 빈은 `HermesConfig`에서 지운다:

```kotlin
@RestController
class ExplainController(
    private val explainer: CourseExplainer,
    @org.springframework.beans.factory.annotation.Value("\${hermes.llm.model}") private val model: String,
    private val mapper: ObjectMapper,
) {
```

- [ ] **Step 4: 테스트가 통과하는지 확인한다**

Run: `./gradlew test --tests 'com.hermes.shared.config.BundleHealthIndicatorTest' --tests 'com.hermes.ApplicationContextTest'`
Expected: PASS — 2개 + 1개. 전체도 통과: `./gradlew build`

- [ ] **Step 5: 커밋**

```bash
git add server/src/main/kotlin/com/hermes/shared/ server/src/main/resources/application.yml \
        server/src/main/kotlin/com/hermes/explain/presentation/ExplainController.kt \
        server/src/test/kotlin/com/hermes/shared/ server/src/test/kotlin/com/hermes/ApplicationContextTest.kt
git commit -m "feat: wire the application and refuse to report healthy without a bundle"
```

---

### Task 8: 고정 데모 코스와 도달성 검사

**Files:**
- Create: `server/src/main/kotlin/com/hermes/shared/config/DemoCourses.kt`
- Create: `harness/src/main/kotlin/com/hermes/harness/DemoReachabilityMain.kt`
- Modify: `build.gradle.kts`
- Modify: `server/src/main/resources/application.yml`
- Test: `server/src/test/kotlin/com/hermes/shared/config/DemoCoursesTest.kt`

**Interfaces:**
- Consumes: `HanjeokClient`, `RestHanjeokClient` (Task 3), `FactsSource` (Task 4)
- Produces: `data class DemoCourse(val uuid: String, val label: String)`, `class DemoCourses(val courses: List<DemoCourse>)`; Gradle 태스크 `demoReachability`

**왜 필요한가.** 스펙 §7 — 쇼케이스에는 코스를 만드는 화면이 없으므로 한적에 미리 만들어 둔 코스 3개를 고정한다. 사실은 여전히 실시간으로 오므로, **한적이 내려가거나 코스가 지워지면 데모가 깨진다.** 그건 "사실은 백엔드에서만 온다"를 지킨 대가이고, 깨졌을 때 조용하지 않도록 검사를 둔다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`server/src/test/kotlin/com/hermes/shared/config/DemoCoursesTest.kt`:

```kotlin
package com.hermes.shared.config

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test

class DemoCoursesTest {

    @Test
    fun `설정 문자열에서 uuid 와 라벨을 읽는다`() {
        val demos = DemoCourses.parse("aaa|매우혼잡 목적지, bbb|대안 없음, ccc|다른 날 추천")

        assertThat(demos.courses).hasSize(3)
        assertThat(demos.courses[0].uuid).isEqualTo("aaa")
        assertThat(demos.courses[1].label).isEqualTo("대안 없음")
    }

    @Test
    fun `빈 설정이면 비어 있다`() {
        assertThat(DemoCourses.parse("").courses).isEmpty()
    }

    @Test
    fun `라벨이 없으면 uuid 를 라벨로 쓴다`() {
        assertThat(DemoCourses.parse("aaa").courses[0].label).isEqualTo("aaa")
    }
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인한다**

Run: `./gradlew test --tests 'com.hermes.shared.config.DemoCoursesTest'`
Expected: FAIL — `Unresolved reference: DemoCourses`

- [ ] **Step 3: 구현한다**

`server/src/main/kotlin/com/hermes/shared/config/DemoCourses.kt`:

```kotlin
package com.hermes.shared.config

data class DemoCourse(val uuid: String, val label: String)

/**
 * 쇼케이스가 보여 줄 고정 코스.
 *
 * 서버는 이 uuid 들을 특별 취급하지 않는다 — 데모 코스도 다른 코스와 똑같이
 * 한적 호출 3회를 탄다. 응답을 녹화해 폴백으로 쓰지 않는 이유는, 녹화본을 쓰면
 * "사실의 출처는 언제나 백엔드"라는 규정이 조용히 깨지기 때문이다(스펙 §7).
 *
 * 고르는 기준은 수가 아니라 종류다: (a) 목적지가 매우혼잡이고 대안이 붙은 코스,
 * (b) 대안이 비어 있는 코스, (c) recommendedDate 가 다른 날을 가리키는 코스.
 * 셋이 각각 번들의 다른 문서를 인용해야 하므로 인용 검증이 실제로 도는지가
 * 데모에서 드러난다.
 */
class DemoCourses(val courses: List<DemoCourse>) {

    companion object {
        /** `uuid|라벨, uuid|라벨` 형식. 라벨은 생략 가능하다. */
        fun parse(raw: String): DemoCourses = DemoCourses(
            raw.split(",")
                .map { it.trim() }
                .filter { it.isNotEmpty() }
                .map { entry ->
                    val parts = entry.split("|", limit = 2).map { it.trim() }
                    DemoCourse(uuid = parts[0], label = parts.getOrNull(1)?.takeIf { it.isNotEmpty() } ?: parts[0])
                },
        )
    }
}
```

`application.yml`의 `hermes` 블록에 추가:

```yaml
  demo:
    courses: ${HERMES_DEMO_COURSES:}
```

`HermesConfig`에 빈을 더한다:

```kotlin
    @Bean
    fun demoCourses(@Value("\${hermes.demo.courses}") raw: String): DemoCourses = DemoCourses.parse(raw)
```

- [ ] **Step 4: 도달성 검사를 쓴다**

`harness/src/main/kotlin/com/hermes/harness/DemoReachabilityMain.kt`:

```kotlin
package com.hermes.harness

import com.hermes.facts.FactsSource
import com.hermes.facts.HanjeokUnavailableException
import com.hermes.facts.RestHanjeokClient
import com.hermes.shared.config.DemoCourses
import org.springframework.web.client.RestClient
import java.util.concurrent.Executors
import kotlin.system.exitProcess

/**
 * 고정 데모 코스가 한적에서 아직 조회되는지 본다.
 *
 * 데모는 한적 백엔드와 그 코스 레코드가 살아 있어야 동작한다. 코스가 삭제되면
 * 쇼케이스가 조용히 깨지므로, 조용하지 않게 만드는 것이 이 검사의 전부다.
 *
 *   HANJEOK_BASE_URL=... HERMES_DEMO_COURSES="uuid1|라벨, uuid2|라벨" \
 *     ./gradlew demoReachability
 */
fun main() {
    val baseUrl = System.getenv("HANJEOK_BASE_URL") ?: error("HANJEOK_BASE_URL is not set")
    val demos = DemoCourses.parse(System.getenv("HERMES_DEMO_COURSES") ?: "")

    if (demos.courses.isEmpty()) {
        println("HERMES_DEMO_COURSES is empty — nothing to check.")
        exitProcess(1)
    }

    val executor = Executors.newFixedThreadPool(4)
    val source = FactsSource(RestHanjeokClient(RestClient.builder().baseUrl(baseUrl).build()), 15, executor)

    var failed = 0
    demos.courses.forEach { demo ->
        try {
            val facts = source.fetch(demo.uuid)
            println("OK    ${demo.uuid}  (${demo.label})  facts ${facts.json.length} chars")
        } catch (e: HanjeokUnavailableException) {
            failed++
            println("BROKEN ${demo.uuid}  (${demo.label})  ${e.message}")
        }
    }

    executor.shutdown()
    println()
    println("demo courses: ${demos.courses.size}, broken: $failed")
    if (failed > 0) exitProcess(1)
}
```

`build.gradle.kts`에 태스크를 더한다(기존 `eval` 태스크 옆):

```kotlin
tasks.register<JavaExec>("demoReachability") {
    group = "verification"
    description = "고정 데모 코스가 한적에서 아직 조회되는지 확인한다. 한적 호출이 발생한다."
    classpath = sourceSets["harness"].runtimeClasspath
    mainClass.set("com.hermes.harness.DemoReachabilityMainKt")
}
```

- [ ] **Step 5: 테스트와 빌드가 통과하는지 확인한다**

Run: `./gradlew test --tests 'com.hermes.shared.config.DemoCoursesTest'`
Expected: PASS — 3개

Run: `./gradlew build && ./gradlew compileHarnessKotlin`
Expected: BUILD SUCCESSFUL. `demoReachability`는 실행하지 않는다 — 한적 호출이 발생하고 `test`/`build` 밖에 있어야 한다.

Run: `./gradlew build --dry-run | grep -E "demoReachability|eval"`
Expected: 출력 없음 — 둘 다 기본 빌드 그래프 밖이다.

- [ ] **Step 6: 커밋**

```bash
git add server/src/main/kotlin/com/hermes/shared/config/DemoCourses.kt \
        server/src/main/kotlin/com/hermes/shared/config/HermesConfig.kt \
        server/src/main/resources/application.yml build.gradle.kts \
        harness/src/main/kotlin/com/hermes/harness/DemoReachabilityMain.kt \
        server/src/test/kotlin/com/hermes/shared/config/DemoCoursesTest.kt
git commit -m "feat: pin the demo courses and check they are still reachable"
```

---

## Self-Review

**1. Spec coverage**

| 스펙 절 | 태스크 |
|---|---|
| §2.2 presentation 밖은 HTTP 를 모른다 | Task 1 (테스트로 강제) |
| §3 한적 호출 3회, 왕복 2회, attractions/{id} 제외 | Task 3, 4 |
| §4 `POST /agent/explain` (facts 포함) | Task 6 |
| §4 `GET /agent/context`, `/agent/context/{path}` | Task 6 |
| §4 `/actuator/health` 번들 실패 시 DOWN | Task 7 |
| §5 인용은 번들 사본을 가리킨다 | Task 6 (`ContextController`) |
| §7 고정 데모 코스 3개, 녹화 폴백 없음 | Task 8 |
| §8 CORS 변경 0건 (프론트는 hermes 만 호출) | Task 7 (hermes 자신의 CORS) |
| §9 데모 코스 도달성 검사 | Task 8 |
| 08-17 §8 실패 처리 → 503 | Task 1 (`ApiErrorHandler`), Task 5 |
| 08-17 §8 인메모리 LRU 1000 | Task 5 |
| §6 화면 2개 | **계획 3** |
| §8 Cloud Run / Vercel 배포 | **계획 4** |
| §10 2단계 실제 평가 실행 | **미완 — 키 필요.** 이 계획과 독립이다 |

**2. Placeholder scan** — TBD·TODO 없음. 모든 코드 단계에 실제 코드가 있다.

**3. Type consistency** — `BackendFacts(courseUuid, json)`, `ExplanationService.explain(facts): ExplainOutcome`, `Explained(explanation)`, `Unavailable(reason)`, `Explanation(explanation, citations)`, `Bundle.document(path)`, `Bundle.documents`, `Bundle.byteSize()` 는 모두 계획 1의 실제 코드에서 확인한 시그니처다. `FactsProjection.assemble(course, alternatives, congestion)` 은 Task 2에서 정의되고 Task 4가 쓴다. `HanjeokUnavailableException` 은 Task 3에서 정의되고 Task 4·5·8이 쓴다. `ExplanationUnavailableException` 은 Task 1에서 정의되고 Task 5·6이 쓴다.

**알려진 위험 2건**

- **Task 7의 `String` 빈 충돌.** `@Value` 를 컨트롤러 생성자에 직접 두는 것으로 피했으나, Spring Boot 4.1 에서 코틀린 생성자 `@Value` 가 기대대로 물리는지는 컴파일·컨텍스트 기동으로 확인해야 한다. 실패하면 `@ConfigurationProperties` 클래스로 바꾼다.
- **Task 6의 와일드카드 경로 추출.** `HandlerMapping.PATH_WITHIN_HANDLER_MAPPING_ATTRIBUTE` 의 상수명과 반환값 형태는 Spring 버전에 민감하다. 컴파일 에러가 나면 `javap` 로 실제 상수명을 확인하고, 그래도 안 되면 `@PathVariable` 대신 `request.requestURI` 에서 접두사를 잘라낸다 — **경로가 번들 목록에 있는지로만 판정하므로 어느 쪽이든 보안 성질은 같다.**
