# SimpleSSD version 2.0
Open-Source Licensed Educational SSD Simulator for High-Performance Storage and Full-System Evaluations

This project is managed by [CAMELab](http://camelab.org).
For more information, please visit [SimpleSSD homepage](http://simplessd.org).

## Licenses
SimpleSSD is released under the GPLv3 license. See `LICENSE` file for details.

## 빌드와 실행 (FAST 멀티채널 / greedy GC 실험)

### 저장소 받기
`simplessd`는 서브모듈이다. 서브모듈 주소가 SSH 형식이라 SSH 키가 없으면 HTTPS로 바꿔서 받는다.

```bash
git clone --recurse-submodules git@github.com:EunsooSoh/simplessd-standalone.git
# SSH 키가 없을 때: git config submodule.simplessd.url https://github.com/EunsooSoh/SimpleSSD.git
```

### 빌드
DRAMPower 경로는 자동으로 `lib/drampower/src`가 쓰인다. 최근 GCC에서는 DRAMPower 쪽 경고가 오류로 처리되어 `-Wno-error`가 필요할 수 있다.

```bash
mkdir build && cd build
cmake .. -DCMAKE_CXX_FLAGS=-Wno-error
make -j8
```

### 실행
`./simplessd-standalone <시뮬레이터 설정> <SSD 설정> <출력 폴더>` 형식이고, 통계는 출력 폴더의 `log.txt`에 저장된다.
시뮬레이터 설정은 `config/sample.cfg`를 복사해서 쓰고, trace를 재생하려면 `Mode = 1`로 두고 `[trace]`의 `File`에 trace 경로를 넣는다.
trace는 `trace/converted/`에 넣는다(저장소에 포함되지 않는다).

### FAST와 victim 선택 정책
SSD 설정(`simplessd/config/nexus5.cfg` 또는 `sample.cfg`)에서 아래를 바꾼다.

| 설정 | 값 |
|---|---|
| `[pal]` `SuperblockSize` | `C` (FAST는 반드시 필요) |
| `[ftl]` `MappingMode` | `1` (FAST), `0`은 page mapping |
| `[ftl]` `FASTRWLogBlocks` | RW 로그 블록 수 (기본 8) |
| `[ftl]` `FASTRWGCPolicy` | `0`: 가장 오래된 RW 로그(기존), `1`: greedy(유효 sector가 가장 적은 RW 로그) |

SW 로그는 블록이 1개뿐이라 정책은 RW 로그에만 적용된다.
결과 통계는 `log.txt`의 `ftl.fast.*` 항목이다(`waf`, `rw_victims`, `merge.switch/partial/full`, `merge.sector_copies`).
주기 로그가 여러 번 찍히므로 마지막 값이 최종 결과이다.

### 테스트
```bash
mkdir build-test && cd build-test
cmake ../simplessd -DBUILD_TESTS=ON -DDRAMPOWER_SOURCE_DIR=$(pwd)/../lib/drampower/src
make test_fast
./test_fast ../simplessd/config/sample.cfg
```
정책 0/1 조합의 내부 정합성과 victim 선택을 매 단계 검사한다.
`-DCMAKE_CXX_FLAGS=-DFAST_VERIFY_VICTIM`으로 빌드하면 시뮬레이션 실행 중에도 victim 선택을 검사하고, 종료 시 검사 횟수를 stderr에 출력한다.
