# Hermes Agent 코어 + 평가 구현 계획

> **실행 완료 (2026-08-31).** `hyunolike/hermes-agent` 커밋 `3e965f4..74d418f`,
> 태스크 9개, 테스트 48개. 이 문서는 실행된 계획의 기록이며 그대로 두었다 —
> 아래는 **계획이 틀렸던 지점**이고, 코드는 계획이 아니라 이쪽을 따랐다.
>
> - **Task 6의 `outputConfig` 경고는 틀렸다.** "두 오버로드를 동시에 부를 수 있는지
>   문서에 없다"고 적었으나, 실제로는 함께 컴파일되면서 클래스 오버로드가 앞선
>   `OutputConfig`를 통째로 덮어써 `effort=LOW`를 조용히 버린다. 판정 기준을
>   "컴파일 거부 여부"로 준 것 자체가 오류였고, 옳은 기준은 "어떤 본문이
>   만들어지는가"였다. 코드는 클래스 오버로드를 **먼저** 부르고 effort와 스키마를
>   함께 담은 `OutputConfig`를 나중에 덮어쓴다.
> - **Task 9의 `EvalMain`은 그대로 쓰면 평가를 무의미하게 만든다.** 픽스처의
>   `backendResponses`를 그대로 facts로 넘기는데 그 최상위 키가 엔드포인트 문자열이라,
>   판정기가 읽는 `/items`·`/alternatives`가 비어 모든 한글 지명이 오탐된다.
>   코드는 `FactsNormalizer`로 평탄화한 뒤 **같은 JSON을 프로바이더와 판정기 양쪽에**
>   넘긴다.
> - **Task 9의 파일 배치가 자기모순이다.** Files 블록은 `ForbiddenBehaviours.kt`를
>   harness 소스셋에, Steps는 server main에 둔다. 후자가 맞다 — 단위 테스트가
>   harness 출력에 닿지 못한다.
> - `max_tokens`는 8192가 아니라 **16000**, 번들 실측은 15,681바이트로 시작해
>   프롬프트 개정을 거치며 커졌다(현재 18,053).
>
> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 위키 번들과 백엔드 사실로 설명을 생성하고, 그 설명이 금지 행동 6종을 몇 번 어기는지 세는 에이전트 코어를 만든다. HTTP 서버도 프론트도 없다.

**Architecture:** 단일 Gradle 모듈 `server/` 안에 `com.hermes.context`(번들 적재·프롬프트 조립·인용 검증)와 `com.hermes.llm`(프로바이더 포트와 어댑터), `com.hermes.explain`(설명 루프)을 둔다. 셋 다 HTTP를 모른다. `harness/`가 이들을 직접 호출해 평가를 돌린다. 사실은 이 계획에서 픽스처로 주입하고, 한적 클라이언트는 계획 2에서 붙인다.

**Tech Stack:** Kotlin 2.2, JDK 21, Gradle Kotlin DSL, Spring Boot 4.1(의존성만 — 이 계획은 스프링 컨텍스트를 띄우지 않는다), JUnit 5, AssertJ, `com.anthropic:anthropic-java:2.34.0`

**Spec:** `docs/superpowers/specs/2026-08-31-hermes-agent-repo-design.md` (선행: `2026-08-17-hermes-agent-design.md`)

## Global Constraints

이 절의 값은 모든 태스크의 요구사항에 암묵적으로 포함된다.

- **레포 위치**: `~/Library/Mobile Documents/com~apple~CloudDocs/Workspace/hermes-agent` — 한적·위키와 형제. **가정이다.** 다르면 시작 전에 고칠 것.
- **Gradle 모듈은 하나.** `settings.gradle.kts`에 `include(...)`를 쓰지 않는다. 경계는 `com.hermes.*` 패키지와 Modulith 테스트로 긋는다. (한적·템플릿과 같은 관례)
- **`explain/presentation` 밖의 어떤 패키지도 HTTP를 몰라야 한다.** 이 계획은 `presentation`을 만들지 않으므로, 어떤 클래스도 `org.springframework.web.*`을 import하지 않는다.
- **모델**: `claude-opus-5`. 날짜 접미사를 붙이지 않는다.
- **`temperature`·`top_p`·`top_k`를 쓰지 않는다.** Claude Opus 5에서 400을 반환한다.
- **`thinking`을 명시하지 않는다.** Opus 5는 생략이 곧 adaptive이고 기본 ON이다.
- **`maxTokens` = 16000.** 스펙과 08-17 설계문의 8192를 **정정한다** — `max_tokens`는 thinking과 응답 텍스트를 합쳐 덮고 Opus 5는 thinking이 기본 ON이므로, 비스트리밍 요청의 권장 하한이 16000이다.
- **effort**: `LOW`로 시작.
- **캐시**: 번들은 `system` 블록에 `CacheControlEphemeral.Ttl.TTL_1H`로 붙인다. Opus 5의 최소 캐시 가능 접두사는 **512 토큰**이고 번들(15,681바이트)은 이를 크게 넘는다.
- **번들 문자열은 바이트 단위로 결정론적이어야 한다.** 타임스탬프·UUID·세션ID·조건부 섹션 금지. 한 바이트만 달라져도 캐시가 통째로 미스 나고, 이건 돈이 들되 아무 테스트도 실패시키지 않는다.
- **커밋은 태스크마다.** 각 태스크 끝에 `./gradlew build`가 통과해야 한다.

---

## File Structure

| 파일 | 책임 |
|---|---|
| `settings.gradle.kts`, `build.gradle.kts` | 단일 모듈 빌드 정의 |
| `server/src/main/resources/prompts/hanjeok-bundle.txt` | 위키에서 조립된 번들 (빌드 산출물, 커밋됨) |
| `server/src/main/kotlin/com/hermes/context/Bundle.kt` | `BundleDocument`, `Bundle` — 적재된 번들의 불변 표현 |
| `server/src/main/kotlin/com/hermes/context/BundleLoader.kt` | 리소스 → `Bundle` 파싱 |
| `server/src/main/kotlin/com/hermes/context/PromptAssembler.kt` | `Bundle` → 결정론적 system 문자열 |
| `server/src/main/kotlin/com/hermes/context/CitationValidator.kt` | 인용 경로가 번들에 실재하는지 검증 |
| `server/src/main/kotlin/com/hermes/llm/ExplanationProvider.kt` | 포트 — 프로바이더 교체 지점 |
| `server/src/main/kotlin/com/hermes/llm/AnthropicExplanationProvider.kt` | Anthropic 어댑터 |
| `server/src/main/kotlin/com/hermes/llm/OpenRouterExplanationProvider.kt` | OpenRouter 어댑터 |
| `server/src/main/kotlin/com/hermes/explain/BackendFacts.kt` | 사실의 도메인 표현 |
| `server/src/main/kotlin/com/hermes/explain/ExplanationService.kt` | 설명 루프 |
| `harness/src/main/kotlin/com/hermes/harness/ForbiddenBehaviours.kt` | 금지 행동 6종 판정 |
| `harness/src/main/kotlin/com/hermes/harness/EvalMain.kt` | 평가 실행 진입점 |

---

### Task 1: 레포 스캐폴드

**Files:**
- Create: `settings.gradle.kts`, `build.gradle.kts`, `gradle.properties`, `.gitignore`, `README.md`
- Create: `server/src/main/kotlin/com/hermes/HermesApplication.kt`
- Test: `server/src/test/kotlin/com/hermes/ScaffoldTest.kt`

**Interfaces:**
- Consumes: 없음
- Produces: `./gradlew build`가 통과하는 단일 모듈. 소스 루트 `server/src/main/kotlin`, 테스트 루트 `server/src/test/kotlin`, 평가 소스셋 `harness/src/main/kotlin`.

- [ ] **Step 1: 디렉터리와 Gradle 파일을 만든다**

```bash
mkdir -p ~/Library/Mobile\ Documents/com~apple~CloudDocs/Workspace/hermes-agent
cd ~/Library/Mobile\ Documents/com~apple~CloudDocs/Workspace/hermes-agent
git init
mkdir -p server/src/main/kotlin/com/hermes server/src/test/kotlin/com/hermes
mkdir -p server/src/main/resources/prompts harness/src/main/kotlin/com/hermes/harness
```

`settings.gradle.kts` — `include(...)`가 없는 것이 요점이다:

```kotlin
plugins {
    id("org.gradle.toolchains.foojay-resolver-convention") version "1.0.0"
}

rootProject.name = "hermes-agent"
```

`gradle.properties`:

```properties
org.gradle.jvmargs=-Xmx2g
org.gradle.caching=true
kotlin.code.style=official
```

`build.gradle.kts`:

```kotlin
plugins {
    kotlin("jvm") version "2.2.0"
    kotlin("plugin.spring") version "2.2.0"
    id("org.springframework.boot") version "4.1.0"
    id("io.spring.dependency-management") version "1.1.7"
}

group = "com.hermes"
version = "0.1.0"

kotlin {
    jvmToolchain(21)
    compilerOptions { freeCompilerArgs.add("-Xjsr305=strict") }
}

sourceSets {
    main {
        kotlin.srcDir("server/src/main/kotlin")
        resources.srcDir("server/src/main/resources")
    }
    test { kotlin.srcDir("server/src/test/kotlin") }
    // 평가는 단위 테스트가 아니다 — 돈이 들고 비결정적이라 `./gradlew test` 에 섞이면 안 된다.
    create("harness") {
        kotlin.srcDir("harness/src/main/kotlin")
        compileClasspath += sourceSets.main.get().output
        runtimeClasspath += sourceSets.main.get().output
    }
}

val harnessImplementation: Configuration by configurations.getting {
    extendsFrom(configurations.implementation.get())
}

repositories { mavenCentral() }

dependencies {
    implementation("org.springframework.boot:spring-boot-starter")
    implementation("org.jetbrains.kotlin:kotlin-reflect")
    implementation("com.anthropic:anthropic-java:2.34.0")
    implementation("com.fasterxml.jackson.module:jackson-module-kotlin")
    testImplementation("org.springframework.boot:spring-boot-starter-test")
}

tasks.test { useJUnitPlatform() }

tasks.register<JavaExec>("eval") {
    group = "verification"
    description = "금지 행동 6종을 센다. API 키가 필요하고 실제 비용이 발생한다."
    classpath = sourceSets["harness"].runtimeClasspath
    mainClass.set("com.hermes.harness.EvalMainKt")
}
```

- [ ] **Step 2: Gradle wrapper와 진입 클래스를 만든다**

```bash
gradle wrapper --gradle-version 8.14
```

`server/src/main/kotlin/com/hermes/HermesApplication.kt`:

```kotlin
package com.hermes

import org.springframework.boot.autoconfigure.SpringBootApplication

@SpringBootApplication
class HermesApplication
```

`.gitignore`:

```
build/
.gradle/
.DS_Store
*.log
.env
```

- [ ] **Step 3: 스캐폴드가 실제로 빌드되는지 확인하는 테스트를 쓴다**

`server/src/test/kotlin/com/hermes/ScaffoldTest.kt`:

```kotlin
package com.hermes

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test

class ScaffoldTest {
    @Test
    fun `소스셋이 연결되어 있다`() {
        assertThat(HermesApplication::class.java.packageName).isEqualTo("com.hermes")
    }
}
```

- [ ] **Step 4: 빌드가 통과하는지 확인한다**

Run: `./gradlew build`
Expected: BUILD SUCCESSFUL, `ScaffoldTest` 1개 통과

- [ ] **Step 5: 커밋**

```bash
git add -A
git commit -m "chore: scaffold the hermes-agent repo as a single gradle module"
```

---

### Task 2: 번들 적재

**Files:**
- Create: `server/src/main/resources/prompts/hanjeok-bundle.txt`
- Create: `server/src/main/kotlin/com/hermes/context/Bundle.kt`
- Create: `server/src/main/kotlin/com/hermes/context/BundleLoader.kt`
- Test: `server/src/test/kotlin/com/hermes/context/BundleLoaderTest.kt`

**Interfaces:**
- Consumes: Task 1의 모듈 구조
- Produces:
  - `data class BundleDocument(val path: String, val content: String)`
  - `class Bundle(val documents: List<BundleDocument>, val raw: String)` — `fun paths(): Set<String>`, `fun byteSize(): Int`
  - `object BundleLoader { fun load(resourcePath: String = "/prompts/hanjeok-bundle.txt"): Bundle }`

- [ ] **Step 1: 번들 파일을 위키에서 생성해 리소스로 넣는다**

```bash
cd ~/Library/Mobile\ Documents/com~apple~CloudDocs/Workspace/travel-context-wiki
scripts/build-bundle.sh hanjeok > \
  ~/Library/Mobile\ Documents/com~apple~CloudDocs/Workspace/hermes-agent/server/src/main/resources/prompts/hanjeok-bundle.txt
```

포맷은 파일마다 `----- FILE: <경로> -----` 한 줄 뒤에 내용, 그 뒤 개행 하나다. 9개 문서, 15,681바이트.

- [ ] **Step 2: 실패하는 테스트를 쓴다**

`server/src/test/kotlin/com/hermes/context/BundleLoaderTest.kt`:

```kotlin
package com.hermes.context

import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test

class BundleLoaderTest {

    @Test
    fun `번들의 9개 문서를 선언된 순서대로 읽는다`() {
        val bundle = BundleLoader.load()

        assertThat(bundle.documents).hasSize(9)
        assertThat(bundle.documents.first().path).isEqualTo("concepts/travel-context-layer.md")
        // 서비스 프롬프트는 사용자 턴에 가장 가깝게 마지막에 온다
        assertThat(bundle.documents.last().path).isEqualTo("packages/hanjeok/prompt.md")
    }

    @Test
    fun `문서 내용이 마커를 포함하지 않는다`() {
        val bundle = BundleLoader.load()

        assertThat(bundle.documents).allSatisfy { doc ->
            assertThat(doc.content).doesNotContain("----- FILE:")
            assertThat(doc.content).isNotEmpty()
        }
    }

    @Test
    fun `두 번 적재해도 raw 문자열이 바이트 단위로 같다`() {
        // 캐시는 접두사 일치다. 적재가 비결정적이면 매 요청이 캐시 미스가 되고,
        // 그건 돈이 들되 아무 테스트도 실패시키지 않는다.
        assertThat(BundleLoader.load().raw).isEqualTo(BundleLoader.load().raw)
    }

    @Test
    fun `번들이 없으면 조용히 비지 않고 예외를 던진다`() {
        assertThatThrownBy { BundleLoader.load("/prompts/does-not-exist.txt") }
            .isInstanceOf(IllegalStateException::class.java)
            .hasMessageContaining("does-not-exist.txt")
    }
}
```

- [ ] **Step 3: 테스트가 실패하는지 확인한다**

Run: `./gradlew test --tests 'com.hermes.context.BundleLoaderTest'`
Expected: FAIL — `Unresolved reference: BundleLoader`

- [ ] **Step 4: 최소 구현을 쓴다**

`server/src/main/kotlin/com/hermes/context/Bundle.kt`:

```kotlin
package com.hermes.context

data class BundleDocument(val path: String, val content: String)

class Bundle(val documents: List<BundleDocument>, val raw: String) {
    private val pathSet: Set<String> = documents.map { it.path }.toSet()

    fun paths(): Set<String> = pathSet

    fun byteSize(): Int = raw.toByteArray(Charsets.UTF_8).size

    fun document(path: String): BundleDocument? = documents.firstOrNull { it.path == path }
}
```

`server/src/main/kotlin/com/hermes/context/BundleLoader.kt`:

```kotlin
package com.hermes.context

object BundleLoader {

    private val MARKER = Regex("^----- FILE: (.+) -----$", RegexOption.MULTILINE)

    fun load(resourcePath: String = "/prompts/hanjeok-bundle.txt"): Bundle {
        val raw = BundleLoader::class.java.getResource(resourcePath)
            ?.readText(Charsets.UTF_8)
            ?: error("bundle resource not found: $resourcePath")

        val markers = MARKER.findAll(raw).toList()
        check(markers.isNotEmpty()) { "bundle has no FILE markers: $resourcePath" }

        val documents = markers.mapIndexed { i, match ->
            val contentStart = match.range.last + 2 // 마커 줄의 개행 다음
            val contentEnd = if (i + 1 < markers.size) markers[i + 1].range.first else raw.length
            BundleDocument(
                path = match.groupValues[1],
                content = raw.substring(contentStart, contentEnd).trimEnd('\n'),
            )
        }

        return Bundle(documents = documents, raw = raw)
    }
}
```

- [ ] **Step 5: 테스트가 통과하는지 확인한다**

Run: `./gradlew test --tests 'com.hermes.context.BundleLoaderTest'`
Expected: PASS — 4개 통과

- [ ] **Step 6: 커밋**

```bash
git add server/src/main/resources/prompts/hanjeok-bundle.txt \
        server/src/main/kotlin/com/hermes/context/ \
        server/src/test/kotlin/com/hermes/context/
git commit -m "feat: load the wiki context bundle as an immutable in-memory document set"
```

---

### Task 3: 프롬프트 조립

**Files:**
- Create: `server/src/main/kotlin/com/hermes/context/PromptAssembler.kt`
- Test: `server/src/test/kotlin/com/hermes/context/PromptAssemblerTest.kt`

**Interfaces:**
- Consumes: `Bundle`, `BundleLoader.load()` (Task 2)
- Produces: `class PromptAssembler(private val bundle: Bundle)` — `val systemText: String` (불변, 생성 시 1회 계산)

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`server/src/test/kotlin/com/hermes/context/PromptAssemblerTest.kt`:

```kotlin
package com.hermes.context

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test

class PromptAssemblerTest {

    private val bundle = BundleLoader.load()

    @Test
    fun `system 문자열은 번들 원문을 그대로 담는다`() {
        assertThat(PromptAssembler(bundle).systemText).isEqualTo(bundle.raw)
    }

    @Test
    fun `같은 번들로 두 번 조립하면 바이트 단위로 같다`() {
        assertThat(PromptAssembler(bundle).systemText).isEqualTo(PromptAssembler(bundle).systemText)
    }

    @Test
    fun `조립이 번들에 없던 오늘 날짜를 끼워넣지 않는다`() {
        // 캐시 무효화 요인 중 가장 흔한 것이 조립 시점에 끼어드는 현재 시각이다.
        // 번들 안의 문서가 자기 frontmatter 에 날짜를 갖는 것은 정상이므로,
        // "오늘 날짜가 조립 과정에서 새로 생겼는가"만 본다.
        val today = java.time.LocalDate.now().toString()
        val assembled = PromptAssembler(bundle).systemText

        assertThat(assembled.windowed(today.length).count { it == today })
            .isEqualTo(bundle.raw.windowed(today.length).count { it == today })
    }

    @Test
    fun `캐시 가능 최소 접두사를 넘는 크기다`() {
        // Claude Opus 5 의 최소 캐시 가능 접두사는 512 토큰이다. 보수적으로
        // 1 토큰 = 4 바이트로 잡아도 번들은 이를 크게 넘어야 한다.
        assertThat(bundle.byteSize()).isGreaterThan(512 * 4)
    }
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인한다**

Run: `./gradlew test --tests 'com.hermes.context.PromptAssemblerTest'`
Expected: FAIL — `Unresolved reference: PromptAssembler`

- [ ] **Step 3: 최소 구현을 쓴다**

`server/src/main/kotlin/com/hermes/context/PromptAssembler.kt`:

```kotlin
package com.hermes.context

/**
 * 번들을 LLM `system` 블록에 들어갈 하나의 문자열로 만든다.
 *
 * 지금은 원문을 그대로 쓴다 — build-bundle.sh 가 이미 선언된 순서로 결정론적으로
 * 조립했기 때문이다. 여기서 무언가를 덧붙이고 싶어지면, 그것이 요청마다 달라지지
 * 않는지 먼저 확인해야 한다. 한 바이트만 달라져도 캐시는 통째로 미스 난다.
 */
class PromptAssembler(bundle: Bundle) {
    val systemText: String = bundle.raw
}
```

- [ ] **Step 4: 테스트가 통과하는지 확인한다**

Run: `./gradlew test --tests 'com.hermes.context.PromptAssemblerTest'`
Expected: PASS — 4개 통과

- [ ] **Step 5: 커밋**

```bash
git add server/src/main/kotlin/com/hermes/context/PromptAssembler.kt \
        server/src/test/kotlin/com/hermes/context/PromptAssemblerTest.kt
git commit -m "feat: assemble the system prompt deterministically from the bundle"
```

---

### Task 4: 인용 검증

**Files:**
- Create: `server/src/main/kotlin/com/hermes/context/CitationValidator.kt`
- Test: `server/src/test/kotlin/com/hermes/context/CitationValidatorTest.kt`

**Interfaces:**
- Consumes: `Bundle` (Task 2)
- Produces:
  - `sealed interface CitationResult` — `data object Valid : CitationResult`, `data class Invalid(val unknownPaths: List<String>) : CitationResult`
  - `class CitationValidator(private val bundle: Bundle)` — `fun validate(citations: List<String>): CitationResult`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`server/src/test/kotlin/com/hermes/context/CitationValidatorTest.kt`:

```kotlin
package com.hermes.context

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test

class CitationValidatorTest {

    private val validator = CitationValidator(BundleLoader.load())

    @Test
    fun `번들에 있는 경로만 인용하면 통과한다`() {
        val result = validator.validate(
            listOf("concepts/congestion-diagnosis.md", "records/congestion/grade-policy.json"),
        )

        assertThat(result).isEqualTo(Valid)
    }

    @Test
    fun `번들에 없는 경로를 인용하면 그 경로를 지목해 거절한다`() {
        // 이게 이 클래스가 존재하는 이유다. LLM 이 그럴듯한 위키 경로를 지어내면
        // 응답이 나가기 전에 여기서 잡힌다.
        val result = validator.validate(
            listOf("concepts/congestion-diagnosis.md", "concepts/weather-aware-travel-recommendation.md"),
        )

        assertThat(result).isEqualTo(Invalid(listOf("concepts/weather-aware-travel-recommendation.md")))
    }

    @Test
    fun `인용이 비면 거절한다`() {
        // 근거 없는 설명은 이 서비스가 낼 수 있는 것이 아니다.
        assertThat(validator.validate(emptyList())).isEqualTo(Invalid(emptyList()))
    }

    @Test
    fun `같은 경로를 여러 번 인용해도 한 번만 문제 삼는다`() {
        val result = validator.validate(listOf("concepts/nope.md", "concepts/nope.md"))

        assertThat(result).isEqualTo(Invalid(listOf("concepts/nope.md")))
    }
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인한다**

Run: `./gradlew test --tests 'com.hermes.context.CitationValidatorTest'`
Expected: FAIL — `Unresolved reference: CitationValidator`

- [ ] **Step 3: 최소 구현을 쓴다**

`server/src/main/kotlin/com/hermes/context/CitationValidator.kt`:

```kotlin
package com.hermes.context

sealed interface CitationResult

data object Valid : CitationResult

data class Invalid(val unknownPaths: List<String>) : CitationResult

/**
 * 응답의 citations 배열이 번들에 실재하는 문서만 가리키는지 본다.
 *
 * 이 검사는 테스트가 아니라 런타임 방어선이다. 화면의 인용 칩은 번들 사본을 열기
 * 때문에, 번들에 없는 경로가 통과하면 사용자는 404 를 보게 된다.
 */
class CitationValidator(private val bundle: Bundle) {

    fun validate(citations: List<String>): CitationResult {
        if (citations.isEmpty()) return Invalid(emptyList())

        val known = bundle.paths()
        val unknown = citations.distinct().filterNot { it in known }

        return if (unknown.isEmpty()) Valid else Invalid(unknown)
    }
}
```

- [ ] **Step 4: 테스트가 통과하는지 확인한다**

Run: `./gradlew test --tests 'com.hermes.context.CitationValidatorTest'`
Expected: PASS — 4개 통과

- [ ] **Step 5: 커밋**

```bash
git add server/src/main/kotlin/com/hermes/context/CitationValidator.kt \
        server/src/test/kotlin/com/hermes/context/CitationValidatorTest.kt
git commit -m "feat: reject citations that are not in the bundle"
```

---

### Task 5: 프로바이더 포트와 사실 표현

**Files:**
- Create: `server/src/main/kotlin/com/hermes/llm/ExplanationProvider.kt`
- Create: `server/src/main/kotlin/com/hermes/explain/BackendFacts.kt`
- Test: `server/src/test/kotlin/com/hermes/llm/FakeExplanationProviderTest.kt`

**Interfaces:**
- Consumes: 없음
- Produces:
  - `data class Explanation(val explanation: String, val citations: List<String>)`
  - `data class ProviderUsage(val cacheReadTokens: Long, val cacheCreationTokens: Long, val inputTokens: Long, val outputTokens: Long)`
  - `sealed interface ProviderResult` — `data class Answered(val explanation: Explanation, val usage: ProviderUsage) : ProviderResult`, `data class Refused(val category: String?) : ProviderResult`, `data class Failed(val reason: String) : ProviderResult`
  - `interface ExplanationProvider { val name: String; fun explain(systemText: String, factsJson: String): ProviderResult }`
  - `data class BackendFacts(val courseUuid: String, val json: String)`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`server/src/test/kotlin/com/hermes/llm/FakeExplanationProviderTest.kt`:

```kotlin
package com.hermes.llm

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test

/** 포트가 세 결과를 모두 표현할 수 있는지 확인한다. 어댑터는 다음 태스크에서 붙인다. */
class FakeExplanationProviderTest {

    private class FakeProvider(private val result: ProviderResult) : ExplanationProvider {
        override val name = "fake"
        var lastSystemText: String? = null
        override fun explain(systemText: String, factsJson: String): ProviderResult {
            lastSystemText = systemText
            return result
        }
    }

    @Test
    fun `답변을 사용량과 함께 돌려준다`() {
        val provider = FakeProvider(
            Answered(
                Explanation("경복궁은 매우 붐빕니다.", listOf("concepts/congestion-diagnosis.md")),
                ProviderUsage(cacheReadTokens = 3800, cacheCreationTokens = 0, inputTokens = 120, outputTokens = 210),
            ),
        )

        val result = provider.explain("system", """{"courseUuid":"x"}""")

        assertThat(result).isInstanceOf(Answered::class.java)
        assertThat((result as Answered).usage.cacheReadTokens).isEqualTo(3800)
        assertThat(provider.lastSystemText).isEqualTo("system")
    }

    @Test
    fun `거절을 실패와 구분해 표현한다`() {
        // HTTP 200 에 stop_reason=refusal 이 오는 경로다. content 를 읽기 전에
        // 갈라야 하므로 결과 타입 자체가 달라야 한다.
        assertThat(FakeProvider(Refused("cyber")).explain("s", "f")).isEqualTo(Refused("cyber"))
    }

    @Test
    fun `실패는 이유를 들고 온다`() {
        assertThat(FakeProvider(Failed("timeout")).explain("s", "f")).isEqualTo(Failed("timeout"))
    }
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인한다**

Run: `./gradlew test --tests 'com.hermes.llm.FakeExplanationProviderTest'`
Expected: FAIL — `Unresolved reference: ExplanationProvider`

- [ ] **Step 3: 포트를 쓴다**

`server/src/main/kotlin/com/hermes/llm/ExplanationProvider.kt`:

```kotlin
package com.hermes.llm

data class Explanation(val explanation: String, val citations: List<String>)

data class ProviderUsage(
    val cacheReadTokens: Long,
    val cacheCreationTokens: Long,
    val inputTokens: Long,
    val outputTokens: Long,
)

sealed interface ProviderResult

data class Answered(val explanation: Explanation, val usage: ProviderUsage) : ProviderResult

/** HTTP 200 에 stop_reason=refusal. content 는 비어 있으므로 읽기 전에 갈라야 한다. */
data class Refused(val category: String?) : ProviderResult

data class Failed(val reason: String) : ProviderResult

/**
 * 프로바이더 교체 지점.
 *
 * 이 포트가 있는 이유는 하나다 — Anthropic 직접 호출과 OpenRouter 무료 티어를
 * **같은 프롬프트와 같은 검증** 아래에서 비교하기 위해서다. 비교가 서로 다른
 * 조립 경로를 타면 측정하는 것은 모델이 아니라 프롬프트가 된다.
 */
interface ExplanationProvider {
    val name: String

    fun explain(systemText: String, factsJson: String): ProviderResult
}
```

`server/src/main/kotlin/com/hermes/explain/BackendFacts.kt`:

```kotlin
package com.hermes.explain

/**
 * 한적에서 온 사실. 계획 1 에서는 픽스처로 주입되고, 계획 2 에서 facts 패키지가
 * 실제 호출 3회(왕복 2회)로 채운다.
 *
 * json 을 문자열로 들고 다니는 이유: 이 값이 매 요청 달라지는 부분이고,
 * 캐시 접두사 뒤의 user 턴에 그대로 들어간다. 중간에서 재직렬화하면 키 순서가
 * 흔들려 비교가 어려워진다.
 */
data class BackendFacts(val courseUuid: String, val json: String)
```

- [ ] **Step 4: 테스트가 통과하는지 확인한다**

Run: `./gradlew test --tests 'com.hermes.llm.FakeExplanationProviderTest'`
Expected: PASS — 3개 통과

- [ ] **Step 5: 커밋**

```bash
git add server/src/main/kotlin/com/hermes/llm/ExplanationProvider.kt \
        server/src/main/kotlin/com/hermes/explain/BackendFacts.kt \
        server/src/test/kotlin/com/hermes/llm/FakeExplanationProviderTest.kt
git commit -m "feat: define the provider port so two providers can be compared on one prompt"
```

---

### Task 6: Anthropic 어댑터

**Files:**
- Create: `server/src/main/kotlin/com/hermes/llm/AnthropicExplanationProvider.kt`
- Test: `server/src/test/kotlin/com/hermes/llm/AnthropicRequestShapeTest.kt`

**Interfaces:**
- Consumes: `ExplanationProvider`, `Explanation`, `ProviderUsage`, `ProviderResult` (Task 5)
- Produces: `class AnthropicExplanationProvider(private val client: AnthropicClient) : ExplanationProvider` — `companion object { fun buildParams(systemText: String, factsJson: String): StructuredMessageCreateParams<Explanation> }`

> **주의 — 컴파일로 확인해야 하는 지점이 하나 있다.** `MessageCreateParams.Builder.outputConfig`에는
> 클래스 오버로드(`.outputConfig(Explanation::class.java)` — 스키마 자동 유도)와
> `OutputConfig` 오버로드(`.outputConfig(OutputConfig.builder().effort(...).build())`)가 둘 다 있다.
> **둘을 동시에 부를 수 있는지는 문서에 없다.** 컴파일이 거부하면 수동 스키마 경로로 간다 —
> `OutputConfig.builder().format(JsonOutputFormat.builder().schema(...).build()).effort(...).build()`.
> Step 3에서 이 갈림을 명시적으로 처리한다.

- [ ] **Step 1: 요청 모양을 고정하는 테스트를 쓴다**

API를 부르지 않는다. 요청 파라미터가 캐시와 계약을 지키는지만 본다.

`server/src/test/kotlin/com/hermes/llm/AnthropicRequestShapeTest.kt`:

```kotlin
package com.hermes.llm

import com.hermes.context.BundleLoader
import com.hermes.context.PromptAssembler
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test

class AnthropicRequestShapeTest {

    private val systemText = PromptAssembler(BundleLoader.load()).systemText
    private val factsJson = """{"courseUuid":"3f6c2b18-9a4d-4c77-8b21-5e0f7c9d1a44"}"""

    @Test
    fun `번들은 system 블록에 1시간 캐시 분기점과 함께 들어간다`() {
        val params = AnthropicExplanationProvider.buildParams(systemText, factsJson)
        val body = params.rawParams()

        assertThat(body.system.single().text).isEqualTo(systemText)
        assertThat(body.system.single().cacheTtl).isEqualTo("1h")
    }

    @Test
    fun `매 요청 달라지는 사실은 캐시 분기점 뒤 user 턴에 있다`() {
        val body = AnthropicExplanationProvider.buildParams(systemText, factsJson).rawParams()

        assertThat(body.userText).isEqualTo(factsJson)
    }

    @Test
    fun `모델과 토큰 한도가 스펙과 일치한다`() {
        val body = AnthropicExplanationProvider.buildParams(systemText, factsJson).rawParams()

        assertThat(body.model).isEqualTo("claude-opus-5")
        // 8192 가 아니다 — max_tokens 는 thinking 과 응답을 합쳐 덮고,
        // Opus 5 는 thinking 이 기본 ON 이라 8192 는 잘릴 위험이 있다.
        assertThat(body.maxTokens).isEqualTo(16000L)
    }

    @Test
    fun `같은 입력이면 system 문자열이 바이트 단위로 같다`() {
        val a = AnthropicExplanationProvider.buildParams(systemText, factsJson).rawParams()
        val b = AnthropicExplanationProvider.buildParams(systemText, factsJson).rawParams()

        assertThat(a.system.single().text).isEqualTo(b.system.single().text)
    }
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인한다**

Run: `./gradlew test --tests 'com.hermes.llm.AnthropicRequestShapeTest'`
Expected: FAIL — `Unresolved reference: AnthropicExplanationProvider`

- [ ] **Step 3: 어댑터를 쓴다**

`server/src/main/kotlin/com/hermes/llm/AnthropicExplanationProvider.kt`:

```kotlin
package com.hermes.llm

import com.anthropic.client.AnthropicClient
import com.anthropic.models.messages.CacheControlEphemeral
import com.anthropic.models.messages.MessageCreateParams
import com.anthropic.models.messages.OutputConfig
import com.anthropic.models.messages.StopReason
import com.anthropic.models.messages.StructuredMessageCreateParams
import com.anthropic.models.messages.TextBlockParam

class AnthropicExplanationProvider(private val client: AnthropicClient) : ExplanationProvider {

    override val name = "anthropic"

    override fun explain(systemText: String, factsJson: String): ProviderResult = try {
        val response = client.messages().create(buildParams(systemText, factsJson))

        // refusal 을 content 읽기 전에 가른다. 거절은 HTTP 200 에 빈 content 로
        // 오므로, content[0] 을 무조건 읽는 코드는 여기서 깨진다.
        if (response.stopReason().orElse(null) == StopReason.REFUSAL) {
            Refused(response.stopDetails().map { it.category().orElse(null) }.orElse(null))
        } else {
            val explanation = response.content()
                .firstNotNullOfOrNull { it.text().orElse(null)?.text() }
                ?: return Failed("response carried no structured content")

            Answered(
                explanation = explanation,
                usage = ProviderUsage(
                    cacheReadTokens = response.usage().cacheReadInputTokens().orElse(0L),
                    cacheCreationTokens = response.usage().cacheCreationInputTokens().orElse(0L),
                    inputTokens = response.usage().inputTokens(),
                    outputTokens = response.usage().outputTokens(),
                ),
            )
        }
    } catch (e: Exception) {
        Failed(e.message ?: e::class.simpleName ?: "unknown")
    }

    companion object {
        const val MODEL = "claude-opus-5"

        // 8192 가 아니다 — thinking 과 응답 텍스트를 합쳐 덮는 한도이고
        // Opus 5 는 thinking 이 기본 ON 이다.
        const val MAX_TOKENS = 16_000L

        fun buildParams(systemText: String, factsJson: String): StructuredMessageCreateParams<Explanation> =
            MessageCreateParams.builder()
                .model(MODEL)
                .maxTokens(MAX_TOKENS)
                // thinking 을 명시하지 않는다 — Opus 5 는 생략이 곧 adaptive 다.
                // temperature/top_p/top_k 도 쓰지 않는다 — 400 을 반환한다.
                .outputConfig(OutputConfig.builder().effort(OutputConfig.Effort.LOW).build())
                .systemOfTextBlockParams(
                    listOf(
                        TextBlockParam.builder()
                            .text(systemText)
                            .cacheControl(
                                CacheControlEphemeral.builder()
                                    .ttl(CacheControlEphemeral.Ttl.TTL_1H)
                                    .build(),
                            )
                            .build(),
                    ),
                )
                .addUserMessage(factsJson)
                .outputConfig(Explanation::class.java)
                .build()
    }
}
```

**두 `outputConfig` 호출이 컴파일되지 않으면** 수동 스키마 경로로 바꾼다. 클래스 오버로드를 지우고, 대신:

```kotlin
.outputConfig(
    OutputConfig.builder()
        .effort(OutputConfig.Effort.LOW)
        .format(
            JsonOutputFormat.builder()
                .schema(
                    JsonValue.from(
                        mapOf(
                            "type" to "object",
                            "additionalProperties" to false,
                            "required" to listOf("explanation", "citations"),
                            "properties" to mapOf(
                                "explanation" to mapOf("type" to "string"),
                                "citations" to mapOf(
                                    "type" to "array",
                                    "items" to mapOf("type" to "string"),
                                ),
                            ),
                        ),
                    ),
                )
                .build(),
        )
        .build(),
)
```

이 경우 반환 타입이 `MessageCreateParams`가 되고 응답 텍스트를 Jackson으로 직접 파싱해야 한다. 테스트의 `rawParams()` 헬퍼도 그에 맞춰 고친다.

- [ ] **Step 4: `rawParams()` 헬퍼를 테스트 쪽에 만든다**

SDK 빌더는 조립된 본문을 바로 읽어 주지 않는다. 테스트가 요청 모양을 볼 수 있도록 얇은 접근자를 테스트 소스에 둔다.

`server/src/test/kotlin/com/hermes/llm/RawParams.kt`:

```kotlin
package com.hermes.llm

import com.anthropic.models.messages.StructuredMessageCreateParams

data class SystemBlockView(val text: String, val cacheTtl: String?)

data class RawParamsView(
    val model: String,
    val maxTokens: Long,
    val system: List<SystemBlockView>,
    val userText: String,
)

fun StructuredMessageCreateParams<Explanation>.rawParams(): RawParamsView {
    val body = this.rawParams()._body()
    error("컴파일 후 실제 접근자 이름으로 교체한다 — Step 5 참조")
}
```

- [ ] **Step 5: 컴파일해서 실제 접근자 이름을 알아낸다**

Run: `./gradlew compileTestKotlin`

SDK 타입 이름을 추측하지 않는다. 컴파일 에러가 가리키는 이름을 쓴다. 이름이 안 나오면:

```bash
JAR=$(find ~/.gradle/caches -name 'anthropic-java-core-2.34.0.jar' | head -1)
javap -classpath "$JAR" com.anthropic.models.messages.MessageCreateParams | grep -i 'system\|model\|maxTokens'
```

`RawParams.kt`를 그 이름으로 채운다.

- [ ] **Step 6: 테스트가 통과하는지 확인한다**

Run: `./gradlew test --tests 'com.hermes.llm.AnthropicRequestShapeTest'`
Expected: PASS — 4개 통과

- [ ] **Step 7: 커밋**

```bash
git add server/src/main/kotlin/com/hermes/llm/AnthropicExplanationProvider.kt \
        server/src/test/kotlin/com/hermes/llm/
git commit -m "feat: add the anthropic provider with a 1h cache breakpoint on the bundle"
```

---

### Task 7: 설명 루프

**Files:**
- Create: `server/src/main/kotlin/com/hermes/explain/ExplanationService.kt`
- Test: `server/src/test/kotlin/com/hermes/explain/ExplanationServiceTest.kt`

**Interfaces:**
- Consumes: `PromptAssembler`, `CitationValidator`, `CitationResult`/`Valid`/`Invalid` (Tasks 3–4), `ExplanationProvider`, `ProviderResult` 계열, `Explanation` (Task 5), `BackendFacts` (Task 5)
- Produces:
  - `sealed interface ExplainOutcome` — `data class Explained(val explanation: Explanation) : ExplainOutcome`, `data class Unavailable(val reason: String) : ExplainOutcome`
  - `class ExplanationService(private val assembler: PromptAssembler, private val validator: CitationValidator, private val provider: ExplanationProvider)` — `fun explain(facts: BackendFacts): ExplainOutcome`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`server/src/test/kotlin/com/hermes/explain/ExplanationServiceTest.kt`:

```kotlin
package com.hermes.explain

import com.hermes.context.BundleLoader
import com.hermes.context.CitationValidator
import com.hermes.context.PromptAssembler
import com.hermes.llm.Answered
import com.hermes.llm.Explanation
import com.hermes.llm.ExplanationProvider
import com.hermes.llm.Failed
import com.hermes.llm.ProviderResult
import com.hermes.llm.ProviderUsage
import com.hermes.llm.Refused
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test

class ExplanationServiceTest {

    private val bundle = BundleLoader.load()
    private val facts = BackendFacts("3f6c2b18", """{"targetDate":"2026-08-15"}""")

    private class StubProvider(private val result: ProviderResult) : ExplanationProvider {
        override val name = "stub"
        var receivedFacts: String? = null
        override fun explain(systemText: String, factsJson: String): ProviderResult {
            receivedFacts = factsJson
            return result
        }
    }

    private fun service(result: ProviderResult): Pair<ExplanationService, StubProvider> {
        val provider = StubProvider(result)
        return ExplanationService(
            PromptAssembler(bundle), CitationValidator(bundle), provider,
        ) to provider
    }

    private fun answered(vararg citations: String) = Answered(
        Explanation("경복궁은 8월 15일 매우 붐빕니다.", citations.toList()),
        ProviderUsage(0, 0, 0, 0),
    )

    @Test
    fun `유효한 인용이면 설명을 돌려준다`() {
        val (svc, provider) = service(answered("concepts/congestion-diagnosis.md"))

        val outcome = svc.explain(facts)

        assertThat(outcome).isInstanceOf(Explained::class.java)
        assertThat(provider.receivedFacts).isEqualTo(facts.json)
    }

    @Test
    fun `번들에 없는 문서를 인용하면 설명을 내보내지 않는다`() {
        // 이게 이 루프의 존재 이유다. 그럴듯한 거짓 인용이 사용자에게 나가는 것이
        // 이 저장소가 막으려는 실패다.
        val (svc, _) = service(answered("concepts/made-up.md"))

        val outcome = svc.explain(facts)

        assertThat(outcome).isInstanceOf(Unavailable::class.java)
        assertThat((outcome as Unavailable).reason).contains("concepts/made-up.md")
    }

    @Test
    fun `인용이 비면 설명을 내보내지 않는다`() {
        val (svc, _) = service(answered())

        assertThat(svc.explain(facts)).isInstanceOf(Unavailable::class.java)
    }

    @Test
    fun `거절은 실패와 구분해 이유에 남긴다`() {
        val (svc, _) = service(Refused("cyber"))

        val outcome = svc.explain(facts)

        assertThat((outcome as Unavailable).reason).contains("refusal").contains("cyber")
    }

    @Test
    fun `프로바이더 실패는 그대로 사용 불가로 이어진다`() {
        val (svc, _) = service(Failed("timeout after 8s"))

        assertThat((svc.explain(facts) as Unavailable).reason).contains("timeout after 8s")
    }
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인한다**

Run: `./gradlew test --tests 'com.hermes.explain.ExplanationServiceTest'`
Expected: FAIL — `Unresolved reference: ExplanationService`

- [ ] **Step 3: 최소 구현을 쓴다**

`server/src/main/kotlin/com/hermes/explain/ExplanationService.kt`:

```kotlin
package com.hermes.explain

import com.hermes.context.CitationValidator
import com.hermes.context.Invalid
import com.hermes.context.PromptAssembler
import com.hermes.context.Valid
import com.hermes.llm.Answered
import com.hermes.llm.Explanation
import com.hermes.llm.ExplanationProvider
import com.hermes.llm.Failed
import com.hermes.llm.Refused

sealed interface ExplainOutcome

data class Explained(val explanation: Explanation) : ExplainOutcome

/** 스펙 §8 — 설명이 없는 것은 안전한 실패다. 한적의 규칙 기반 문구가 남는다. */
data class Unavailable(val reason: String) : ExplainOutcome

class ExplanationService(
    private val assembler: PromptAssembler,
    private val validator: CitationValidator,
    private val provider: ExplanationProvider,
) {

    fun explain(facts: BackendFacts): ExplainOutcome =
        when (val result = provider.explain(assembler.systemText, facts.json)) {
            is Refused -> Unavailable("refusal (${result.category ?: "unknown"})")
            is Failed -> Unavailable(result.reason)
            is Answered -> when (val citations = validator.validate(result.explanation.citations)) {
                is Valid -> Explained(result.explanation)
                is Invalid -> Unavailable(
                    if (citations.unknownPaths.isEmpty()) {
                        "no citations"
                    } else {
                        "citations not in bundle: ${citations.unknownPaths.joinToString()}"
                    },
                )
            }
        }
}
```

- [ ] **Step 4: 테스트가 통과하는지 확인한다**

Run: `./gradlew test --tests 'com.hermes.explain.ExplanationServiceTest'`
Expected: PASS — 5개 통과

- [ ] **Step 5: 커밋**

```bash
git add server/src/main/kotlin/com/hermes/explain/ExplanationService.kt \
        server/src/test/kotlin/com/hermes/explain/ExplanationServiceTest.kt
git commit -m "feat: run the explanation loop and refuse to ship unbacked citations"
```

---

### Task 8: OpenRouter 어댑터

**Files:**
- Create: `server/src/main/kotlin/com/hermes/llm/OpenRouterExplanationProvider.kt`
- Test: `server/src/test/kotlin/com/hermes/llm/OpenRouterRequestShapeTest.kt`

**Interfaces:**
- Consumes: `ExplanationProvider` 계열 (Task 5)
- Produces: `class OpenRouterExplanationProvider(private val apiKey: String, private val model: String, private val http: java.net.http.HttpClient) : ExplanationProvider` — `companion object { fun buildBody(systemText: String, factsJson: String, model: String): String }`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`server/src/test/kotlin/com/hermes/llm/OpenRouterRequestShapeTest.kt`:

```kotlin
package com.hermes.llm

import com.fasterxml.jackson.databind.ObjectMapper
import com.hermes.context.BundleLoader
import com.hermes.context.PromptAssembler
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test

class OpenRouterRequestShapeTest {

    private val mapper = ObjectMapper()
    private val systemText = PromptAssembler(BundleLoader.load()).systemText
    private val factsJson = """{"courseUuid":"3f6c2b18"}"""

    private fun body() = mapper.readTree(
        OpenRouterExplanationProvider.buildBody(systemText, factsJson, "nvidia/nemotron-nano-9b-v2:free"),
    )

    @Test
    fun `스키마를 tool_choice 로 강제한다`() {
        // 무료 Nemotron 은 response_format 을 지원하지 않는다. tool_choice 가
        // 함수를 고정하지 않으면 모델은 산문으로 답할 자유를 얻고, 계약은
        // 아무 에러 없이 사라진다.
        assertThat(body().at("/tool_choice/function/name").asText()).isEqualTo("submit_explanation")
    }

    @Test
    fun `스키마가 두 필드를 모두 요구한다`() {
        val required = body().at("/tools/0/function/parameters/required")
            .map { it.asText() }.sorted()

        assertThat(required).containsExactly("citations", "explanation")
    }

    @Test
    fun `번들과 사실이 Anthropic 경로와 같은 내용이다`() {
        // 두 프로바이더에 다른 프롬프트를 주면 비교는 모델이 아니라 프롬프트를 잰다.
        assertThat(body().at("/messages/0/content").asText()).isEqualTo(systemText)
        assertThat(body().at("/messages/1/content").asText()).isEqualTo(factsJson)
    }

    @Test
    fun `같은 입력이면 본문이 바이트 단위로 같다`() {
        val a = OpenRouterExplanationProvider.buildBody(systemText, factsJson, "m")
        val b = OpenRouterExplanationProvider.buildBody(systemText, factsJson, "m")

        assertThat(a).isEqualTo(b)
    }
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인한다**

Run: `./gradlew test --tests 'com.hermes.llm.OpenRouterRequestShapeTest'`
Expected: FAIL — `Unresolved reference: OpenRouterExplanationProvider`

- [ ] **Step 3: 어댑터를 쓴다**

`server/src/main/kotlin/com/hermes/llm/OpenRouterExplanationProvider.kt`:

```kotlin
package com.hermes.llm

import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.module.kotlin.registerKotlinModule
import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.time.Duration

/**
 * OpenRouter 무료 티어 비교용 어댑터.
 *
 * 캐시 분기점이 없다 — 무료 티어에는 낮출 비용이 없으므로 번들이 매 요청 다시
 * 처리된다. 그것이 쓰는 것은 돈이 아니라 지연과 레이트리밋 한 칸이다.
 * 08-20 기록이 "무료 티어에서는 캐싱 논거가 약해진다"고 남긴 지점이 여기다.
 */
class OpenRouterExplanationProvider(
    private val apiKey: String,
    private val model: String,
    private val http: HttpClient = HttpClient.newBuilder()
        .connectTimeout(Duration.ofSeconds(10)).build(),
) : ExplanationProvider {

    override val name = "openrouter"

    override fun explain(systemText: String, factsJson: String): ProviderResult = try {
        val request = HttpRequest.newBuilder()
            .uri(URI.create("https://openrouter.ai/api/v1/chat/completions"))
            .timeout(Duration.ofSeconds(60))
            .header("Authorization", "Bearer $apiKey")
            .header("Content-Type", "application/json")
            .POST(HttpRequest.BodyPublishers.ofString(buildBody(systemText, factsJson, model)))
            .build()

        val response = http.send(request, HttpResponse.BodyHandlers.ofString())
        if (response.statusCode() !in 200..299) {
            Failed("openrouter http ${response.statusCode()}")
        } else {
            val root = MAPPER.readTree(response.body())
            val arguments = root.at("/choices/0/message/tool_calls/0/function/arguments").asText()
            if (arguments.isNullOrBlank()) {
                Failed("openrouter returned no tool call — the schema was not forced")
            } else {
                val parsed = MAPPER.readTree(arguments)
                Answered(
                    explanation = Explanation(
                        explanation = parsed.at("/explanation").asText(),
                        citations = parsed.at("/citations").map { it.asText() },
                    ),
                    usage = ProviderUsage(
                        cacheReadTokens = 0,
                        cacheCreationTokens = 0,
                        inputTokens = root.at("/usage/prompt_tokens").asLong(0),
                        outputTokens = root.at("/usage/completion_tokens").asLong(0),
                    ),
                )
            }
        }
    } catch (e: Exception) {
        Failed(e.message ?: e::class.simpleName ?: "unknown")
    }

    companion object {
        private val MAPPER = ObjectMapper().registerKotlinModule()

        fun buildBody(systemText: String, factsJson: String, model: String): String {
            val schema = mapOf(
                "type" to "object",
                "additionalProperties" to false,
                "required" to listOf("explanation", "citations"),
                "properties" to mapOf(
                    "explanation" to mapOf("type" to "string"),
                    "citations" to mapOf("type" to "array", "items" to mapOf("type" to "string")),
                ),
            )

            return MAPPER.writeValueAsString(
                linkedMapOf(
                    "model" to model,
                    "messages" to listOf(
                        linkedMapOf("role" to "system", "content" to systemText),
                        linkedMapOf("role" to "user", "content" to factsJson),
                    ),
                    "tools" to listOf(
                        linkedMapOf(
                            "type" to "function",
                            "function" to linkedMapOf(
                                "name" to "submit_explanation",
                                "parameters" to schema,
                            ),
                        ),
                    ),
                    "tool_choice" to linkedMapOf(
                        "type" to "function",
                        "function" to linkedMapOf("name" to "submit_explanation"),
                    ),
                ),
            )
        }
    }
}
```

- [ ] **Step 4: 테스트가 통과하는지 확인한다**

Run: `./gradlew test --tests 'com.hermes.llm.OpenRouterRequestShapeTest'`
Expected: PASS — 4개 통과

- [ ] **Step 5: 커밋**

```bash
git add server/src/main/kotlin/com/hermes/llm/OpenRouterExplanationProvider.kt \
        server/src/test/kotlin/com/hermes/llm/OpenRouterRequestShapeTest.kt
git commit -m "feat: add the openrouter provider forcing the schema through tool_choice"
```

---

### Task 9: 평가 하네스

**Files:**
- Create: `harness/fixtures/course-explanation-request.json` (위키에서 복사)
- Create: `harness/src/main/kotlin/com/hermes/harness/ForbiddenBehaviours.kt`
- Create: `harness/src/main/kotlin/com/hermes/harness/EvalMain.kt`
- Test: `server/src/test/kotlin/com/hermes/harness/ForbiddenBehavioursTest.kt`

**Interfaces:**
- Consumes: `Bundle`, `BundleLoader` (Task 2), `Explanation` (Task 5), `ExplanationService`/`Explained`/`Unavailable`, `BackendFacts` (Tasks 5, 7), `AnthropicExplanationProvider` (Task 6), `OpenRouterExplanationProvider` (Task 8)
- Produces:
  - `enum class Behaviour { INVENTED_PLACE, REORDERED_COURSE, LLM_CHOSE, UNCITED_CLAIM, DEFERRED_DESTINATION, TIME_OF_DAY_REASON }`
  - `data class Violation(val behaviour: Behaviour, val evidence: String)`
  - `object ForbiddenBehaviours { fun check(explanation: Explanation, factsJson: String, bundle: Bundle): List<Violation> }`

금지 행동 6종은 위키의 `harness/scenarios/travel-context-explanation.md`, `concepts/travel-context-layer.md`, `queries/why-this-place-today.md`가 규정한 것을 그대로 옮긴다.

| 행동 | 판정 방법 |
|---|---|
| `INVENTED_PLACE` | 설명에 나오는 관광지명이 facts의 `items[].name`과 `alternatives[].name`에 없다 |
| `REORDERED_COURSE` | 설명이 주장하는 방문 순서가 facts의 `visitOrder`와 다르다 |
| `LLM_CHOSE` | "제가 골랐", "AI가 추천", "제가 선정" 등 LLM이 순위를 정했다는 서술 |
| `UNCITED_CLAIM` | `citations`가 비었거나 번들에 없는 경로를 가리킨다 |
| `DEFERRED_DESTINATION` | 목적지를 뒤로 미뤘다는 서술 — `bestOrder`가 `listOf(originId) + best`라 항상 첫 방문지다 |
| `TIME_OF_DAY_REASON` | 방문 시각을 시간대 혼잡도로 설명 — `timeLabel`은 출발+90분+이동시간이고 혼잡도와 무관하다 |

- [ ] **Step 1: 픽스처를 위키에서 가져온다**

```bash
mkdir -p harness/fixtures
cp ~/Library/Mobile\ Documents/com~apple~CloudDocs/Workspace/travel-context-wiki/harness/fixtures/course-explanation-request.json \
   harness/fixtures/
```

- [ ] **Step 2: 실패하는 테스트를 쓴다**

`server/src/test/kotlin/com/hermes/harness/ForbiddenBehavioursTest.kt`:

```kotlin
package com.hermes.harness

import com.hermes.context.BundleLoader
import com.hermes.llm.Explanation
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test

class ForbiddenBehavioursTest {

    private val bundle = BundleLoader.load()

    private val factsJson = """
        {"items":[
          {"attractionId":1001,"name":"경복궁","visitOrder":1,"timeLabel":"오전 10:00","grade":"VERY_CROWDED"},
          {"attractionId":1003,"name":"북촌 한옥마을","visitOrder":2,"timeLabel":"오전 11:38","grade":"NORMAL"},
          {"attractionId":1002,"name":"서촌 골목길","visitOrder":3,"timeLabel":"오후 1:14","grade":"RELAXED"}],
         "alternatives":[{"attractionId":1003,"name":"북촌 한옥마을"},{"attractionId":1002,"name":"서촌 골목길"}]}
    """.trimIndent()

    private fun explanation(text: String, vararg citations: String) =
        Explanation(text, citations.toList().ifEmpty { listOf("concepts/congestion-diagnosis.md") })

    @Test
    fun `사실에 근거한 설명은 위반이 없다`() {
        val violations = ForbiddenBehaviours.check(
            explanation("경복궁은 이 날 매우 붐비지만 첫 방문지로 두었어요. 북촌 한옥마을은 한산합니다."),
            factsJson, bundle,
        )

        assertThat(violations).isEmpty()
    }

    @Test
    fun `facts 에 없는 관광지를 지어내면 잡는다`() {
        val violations = ForbiddenBehaviours.check(
            explanation("경복궁 대신 창덕궁을 추천합니다."), factsJson, bundle,
        )

        assertThat(violations.map { it.behaviour }).contains(Behaviour.INVENTED_PLACE)
        assertThat(violations.first { it.behaviour == Behaviour.INVENTED_PLACE }.evidence).contains("창덕궁")
    }

    @Test
    fun `LLM 이 골랐다는 서술을 잡는다`() {
        val violations = ForbiddenBehaviours.check(
            explanation("제가 골라 드린 코스입니다."), factsJson, bundle,
        )

        assertThat(violations.map { it.behaviour }).contains(Behaviour.LLM_CHOSE)
    }

    @Test
    fun `목적지를 뒤로 미뤘다는 서술을 잡는다`() {
        // bestOrder 는 listOf(originId) + best 를 반환한다. 목적지는 언제나
        // 첫 방문지이고 미뤄지는 일이 없다.
        val violations = ForbiddenBehaviours.check(
            explanation("경복궁은 붐벼서 오후로 미뤘어요."), factsJson, bundle,
        )

        assertThat(violations.map { it.behaviour }).contains(Behaviour.DEFERRED_DESTINATION)
    }

    @Test
    fun `시간대 혼잡도로 방문 시각을 설명하면 잡는다`() {
        // timeLabel 은 출발 10:00 + 장소당 90분 + 실측 이동시간이다.
        // 혼잡도와 아무 관계가 없다.
        val violations = ForbiddenBehaviours.check(
            explanation("오전에는 한산해서 이 시간에 배치했습니다."), factsJson, bundle,
        )

        assertThat(violations.map { it.behaviour }).contains(Behaviour.TIME_OF_DAY_REASON)
    }

    @Test
    fun `번들 밖 인용을 잡는다`() {
        val violations = ForbiddenBehaviours.check(
            explanation("경복궁은 붐빕니다.", "concepts/made-up.md"), factsJson, bundle,
        )

        assertThat(violations.map { it.behaviour }).contains(Behaviour.UNCITED_CLAIM)
    }
}
```

- [ ] **Step 3: 테스트가 실패하는지 확인한다**

Run: `./gradlew test --tests 'com.hermes.harness.ForbiddenBehavioursTest'`
Expected: FAIL — `Unresolved reference: ForbiddenBehaviours`

판정 코드는 `main` 소스셋에 두고(`server/src/main/kotlin/com/hermes/harness/`), 실행 진입점만 `harness` 소스셋에 둔다 — 그래야 단위 테스트가 판정 로직을 검증할 수 있고, 돈이 드는 실행은 `test`에서 분리된다.

- [ ] **Step 4: 판정 코드를 쓴다**

`server/src/main/kotlin/com/hermes/harness/ForbiddenBehaviours.kt`:

```kotlin
package com.hermes.harness

import com.fasterxml.jackson.databind.ObjectMapper
import com.hermes.context.Bundle
import com.hermes.llm.Explanation

enum class Behaviour {
    INVENTED_PLACE,
    REORDERED_COURSE,
    LLM_CHOSE,
    UNCITED_CLAIM,
    DEFERRED_DESTINATION,
    TIME_OF_DAY_REASON,
}

data class Violation(val behaviour: Behaviour, val evidence: String)

object ForbiddenBehaviours {

    private val MAPPER = ObjectMapper()

    private val LLM_CHOSE_PATTERNS = listOf("제가 골", "제가 선정", "제가 추천", "AI가 골", "AI가 추천")
    private val DEFER_PATTERNS = listOf("뒤로 미", "나중으로 미", "오후로 미", "마지막으로 미", "뒤로 배치")
    private val TIME_OF_DAY_PATTERNS = listOf("오전에는", "오후에는", "이 시간대", "시간대가", "아침에는", "저녁에는")

    fun check(explanation: Explanation, factsJson: String, bundle: Bundle): List<Violation> {
        val text = explanation.explanation
        val violations = mutableListOf<Violation>()
        val facts = MAPPER.readTree(factsJson)

        val knownNames = buildSet {
            facts.at("/items").forEach { add(it.at("/name").asText()) }
            facts.at("/alternatives").forEach { add(it.at("/name").asText()) }
        }

        // 지어낸 관광지. 한국어 고유명사를 형태소 없이 자르면 오탐이 나므로,
        // 2자 이상 한글 덩어리 중 아는 이름의 부분문자열이 아닌 것만 본다.
        Regex("[가-힣]{2,}").findAll(text)
            .map { it.value }
            .filter { candidate -> knownNames.none { it.contains(candidate) || candidate.contains(it) } }
            .filter { it.endsWith("궁") || it.endsWith("사") || it.endsWith("마을") || it.endsWith("골목길") }
            .distinct()
            .forEach { violations += Violation(Behaviour.INVENTED_PLACE, it) }

        // 코스 순서 주장. 설명에 등장하는 순서가 visitOrder 와 다른가.
        val declaredOrder = facts.at("/items")
            .sortedBy { it.at("/visitOrder").asInt() }
            .map { it.at("/name").asText() }
        val mentionedOrder = declaredOrder
            .filter { text.contains(it) }
            .sortedBy { text.indexOf(it) }
        val expectedSubsequence = declaredOrder.filter { it in mentionedOrder }
        if (mentionedOrder.size > 1 && mentionedOrder != expectedSubsequence) {
            violations += Violation(Behaviour.REORDERED_COURSE, mentionedOrder.joinToString(" → "))
        }

        LLM_CHOSE_PATTERNS.firstOrNull { text.contains(it) }
            ?.let { violations += Violation(Behaviour.LLM_CHOSE, it) }

        DEFER_PATTERNS.firstOrNull { text.contains(it) }
            ?.let { violations += Violation(Behaviour.DEFERRED_DESTINATION, it) }

        TIME_OF_DAY_PATTERNS.firstOrNull { text.contains(it) }
            ?.let { violations += Violation(Behaviour.TIME_OF_DAY_REASON, it) }

        val unknownCitations = explanation.citations.filterNot { it in bundle.paths() }
        if (explanation.citations.isEmpty()) {
            violations += Violation(Behaviour.UNCITED_CLAIM, "citations empty")
        } else if (unknownCitations.isNotEmpty()) {
            violations += Violation(Behaviour.UNCITED_CLAIM, unknownCitations.joinToString())
        }

        return violations
    }
}
```

- [ ] **Step 5: 테스트가 통과하는지 확인한다**

Run: `./gradlew test --tests 'com.hermes.harness.ForbiddenBehavioursTest'`
Expected: PASS — 6개 통과

- [ ] **Step 6: 실행 진입점을 쓴다**

`harness/src/main/kotlin/com/hermes/harness/EvalMain.kt`:

```kotlin
package com.hermes.harness

import com.anthropic.client.okhttp.AnthropicOkHttpClient
import com.fasterxml.jackson.databind.ObjectMapper
import com.hermes.context.BundleLoader
import com.hermes.context.CitationValidator
import com.hermes.context.PromptAssembler
import com.hermes.explain.BackendFacts
import com.hermes.explain.ExplainOutcome
import com.hermes.explain.ExplanationService
import com.hermes.explain.Explained
import com.hermes.explain.Unavailable
import com.hermes.llm.AnthropicExplanationProvider
import com.hermes.llm.ExplanationProvider
import com.hermes.llm.OpenRouterExplanationProvider
import java.io.File

/**
 * 금지 행동 6종을 센다. 실제 API 를 부르므로 돈이 든다.
 *
 * 서버를 띄우지 않는다 — presentation 을 건너뛰고 application 층을 직접 부르므로,
 * 여기서 통과한 프롬프트 조립과 인용 검증이 운영에서 도는 것과 같은 코드다.
 *
 *   ./gradlew eval --args="anthropic 5"
 *   ./gradlew eval --args="openrouter 5"
 */
fun main(args: Array<String>) {
    val providerName = args.getOrNull(0) ?: "anthropic"
    val runs = args.getOrNull(1)?.toIntOrNull() ?: 5

    val bundle = BundleLoader.load()
    val provider: ExplanationProvider = when (providerName) {
        "anthropic" -> AnthropicExplanationProvider(AnthropicOkHttpClient.fromEnv())
        "openrouter" -> OpenRouterExplanationProvider(
            apiKey = System.getenv("OPENROUTER_API_KEY")
                ?: error("OPENROUTER_API_KEY is not set"),
            model = System.getenv("OPENROUTER_MODEL") ?: "nvidia/nemotron-nano-9b-v2:free",
        )
        else -> error("unknown provider: $providerName")
    }

    val service = ExplanationService(PromptAssembler(bundle), CitationValidator(bundle), provider)

    val fixture = ObjectMapper().readTree(File("harness/fixtures/course-explanation-request.json"))
    val courseUuid = fixture.at("/courseUuid").asText()
    val factsJson = fixture.at("/backendResponses").toString()
    val facts = BackendFacts(courseUuid, factsJson)

    val tally = Behaviour.entries.associateWith { 0 }.toMutableMap()
    var explained = 0
    var unavailable = 0

    repeat(runs) { i ->
        when (val outcome: ExplainOutcome = service.explain(facts)) {
            is Explained -> {
                explained++
                val violations = ForbiddenBehaviours.check(outcome.explanation, factsJson, bundle)
                violations.forEach { tally[it.behaviour] = tally.getValue(it.behaviour) + 1 }
                println("[$i] explained — violations: ${violations.ifEmpty { "none" }}")
            }
            is Unavailable -> {
                unavailable++
                println("[$i] unavailable — ${outcome.reason}")
            }
        }
    }

    println()
    println("provider    : ${provider.name}")
    println("runs        : $runs")
    println("explained   : $explained")
    println("unavailable : $unavailable")
    println("violations  :")
    tally.forEach { (behaviour, count) -> println("  ${behaviour.name.padEnd(22)} $count") }
}
```

- [ ] **Step 7: 키 없이 컴파일과 빌드가 통과하는지 확인한다**

Run: `./gradlew build`
Expected: BUILD SUCCESSFUL. `eval`은 실행하지 않는다 — `./gradlew test`에 섞이지 않는 것이 요점이다.

- [ ] **Step 8: 커밋**

```bash
git add harness/ server/src/main/kotlin/com/hermes/harness/ server/src/test/kotlin/com/hermes/harness/
git commit -m "feat: count the six forbidden behaviours without starting a server"
```

- [ ] **Step 9: 실제 키로 평가를 돌린다 — 이 계획의 결론**

```bash
export ANTHROPIC_API_KEY=...      # 없으면 여기서 멈춘다
./gradlew eval --args="anthropic 5"

export OPENROUTER_API_KEY=...
./gradlew eval --args="openrouter 5"
```

두 출력을 `docs/eval/2026-XX-XX-provider-comparison.md`에 기록한다. 최소한 이 셋을 적는다:

- 프로바이더별 위반 건수 6종
- Anthropic 경로의 `cacheReadTokens` — 2회차 이후 0이면 캐시 무효화 요인이 있다
- 실패(`unavailable`) 건수와 사유 분포

**이 숫자가 계획 2의 전제다.** 위반이 잦으면 바뀌는 것은 서버가 아니라 프롬프트와 프로바이더다.

---

## Self-Review

**1. Spec coverage** — 이 계획은 스펙 §10의 1·2단계를 덮는다.

| 스펙 절 | 태스크 |
|---|---|
| §2 레포 구조, 단일 모듈 | Task 1 |
| §2.2 HTTP 를 모르는 코어 | 전 태스크 — `org.springframework.web.*` import 없음 |
| §5 인용은 번들 사본을 가리킨다 | Task 4 (검증), Task 7 (차단) |
| §9 평가, 금지 행동 6종 | Task 9 |
| §12-3 프로바이더 미결 | Task 6, 8, 9 Step 9 |
| §3 한적 호출 3회 | **계획 2** — 이 계획은 픽스처로 주입 |
| §4 엔드포인트 4개 | **계획 2** |
| §6 화면 2개 | **계획 3** |
| §8 배포 | **계획 4** |
| §9 고정 데모 코스 도달성 검사 | **계획 2** — 한적 클라이언트가 있어야 검사할 수 있다 |

**2. Placeholder scan** — Task 6 Step 4의 `RawParams.kt`가 의도적으로 `error(...)`를 담고 있다. 이건 미완성이 아니라 **SDK 접근자 이름을 추측하지 말고 컴파일러에게 물으라**는 지시이며, Step 5가 그 절차를 정확히 적었다. 그 외 TBD·TODO 없음.

**3. Type consistency** — `Explanation`은 Task 5에서 `com.hermes.llm`에 정의되고 Tasks 6–9가 그 패키지에서 가져온다. `Bundle.paths()`는 Task 2에서 정의되고 Tasks 4·9가 쓴다. `CitationResult`/`Valid`/`Invalid`는 Task 4에서 정의되고 Task 7이 쓴다. `BackendFacts`는 Task 5에서 `com.hermes.explain`에 정의되고 Tasks 7·9가 쓴다.

**한 가지 알려진 위험**: Task 6의 두 `outputConfig` 호출이 컴파일되지 않을 수 있다. Step 3이 대안 코드를 함께 담았고, 그 경우 Task 6의 반환 타입이 `MessageCreateParams`로 바뀌므로 Task 9의 `EvalMain`은 영향받지 않는다(포트 뒤에 있다).
