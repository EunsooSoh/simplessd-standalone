#!/usr/bin/env bash
# SimpleSSD-Standalone 실행 스크립트
#  - 실행할 때마다 <출력루트>/<YYYYmmdd_HHMMSS>/ 폴더를 만들고
#    그 안에 log.txt(통계 로그), debug.txt(디버그 로그), console.txt(화면 출력)를 저장한다.
#  - 설정 파일(config/sample.cfg)은 수정하지 않는다. 읽을 때만 LogFile/DebugLogFile 값을
#    바꿔서 시뮬레이터에 전달한다.
#
# 사용법:
#   ./run_sim.sh [시뮬레이터 cfg] [SimpleSSD cfg] [출력 루트]
#   (모두 생략 가능. 기본값: config/sample.cfg simplessd/config/sample.cfg out)
#
# 선택 환경변수:
#   DEBUG_LOG=0    디버그 로그(debug.txt)를 끈다
#   LOG_PERIOD=0   주기적 통계 로그를 끄고 종료 시점의 마지막 로그만 log.txt에 저장

set -euo pipefail

cd "$(dirname "$0")"

SIM_CFG="${1:-config/sample.cfg}"
SSD_CFG="${2:-simplessd/config/sample.cfg}"
OUT_ROOT="${3:-output}"

if [ ! -x ./simplessd-standalone ]; then
  echo "simplessd-standalone 실행 파일이 없습니다. 먼저 빌드하세요: make -j 8" >&2
  exit 1
fi
for f in "$SIM_CFG" "$SSD_CFG"; do
  if [ ! -f "$f" ]; then
    echo "설정 파일을 찾을 수 없습니다: $f" >&2
    exit 1
  fi
done

# 실행 시각 이름의 출력 폴더 생성 (같은 초에 겹치면 _1, _2 ... 를 붙임)
OUT="$OUT_ROOT/$(date +%Y%m%d_%H%M%S)"
n=0
while [ -e "$OUT" ]; do
  n=$((n + 1))
  OUT="$OUT_ROOT/$(date +%Y%m%d_%H%M%S)_$n"
done
mkdir -p "$OUT"

# 설정 파일을 읽을 때만 로그 파일 이름을 덮어쓴다 (출력 폴더 기준의 상대 경로)
SED_ARGS=(-e 's/^LogFile = .*/LogFile = log.txt/'
          -e 's/^DebugLogFile = .*/DebugLogFile = debug.txt/')
# DEBUG_LOG=0 이면 debug.txt를 만들지 않는다 (GC가 많은 실험은 수 GB로 커짐)
if [ "${DEBUG_LOG:-1}" = "0" ]; then
  SED_ARGS=(-e 's/^LogFile = .*/LogFile = log.txt/'
            -e 's/^DebugLogFile = .*/DebugLogFile =/')
fi
if [ -n "${LOG_PERIOD:-}" ]; then
  SED_ARGS+=(-e "s/^LogPeriod = .*/LogPeriod = ${LOG_PERIOD}/")
fi

# 재현을 위해 사용한 설정을 출력 폴더에 함께 보관
cp "$SIM_CFG" "$OUT/sim_config.cfg"
cp "$SSD_CFG" "$OUT/ssd_config.cfg"

echo "출력 폴더: $OUT"

./simplessd-standalone <(sed "${SED_ARGS[@]}" "$SIM_CFG") "$SSD_CFG" "$OUT" 2>&1 \
  | tee "$OUT/console.txt"
status="${PIPESTATUS[0]}"

# FTL이 현재 디렉터리에 만든 분석용 CSV를 출력 폴더로 옮김
for f in gc_events.csv block_erase.csv; do
  [ -f "$f" ] && mv "$f" "$OUT/$f"
done

echo "종료 코드: $status / 저장 위치: $OUT"
exit "$status"
