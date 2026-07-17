#!/bin/bash
# Watches flutter_passive.log for crash signatures during manual open attempts.
LOG="/Users/arazabbasov/balanzo-app/tool/live_test/flutter_passive.log"
OUT="/Users/arazabbasov/balanzo-app/tool/live_test/crash_events.log"
touch "$LOG" "$OUT"
echo "Watching $LOG — force-quit Balanzo between attempts, then reopen from home screen." | tee -a "$OUT"
attempt=0
while true; do
  if grep -q "\[INIT\] WidgetsFlutterBinding" "$LOG" 2>/dev/null; then
    attempt=$((attempt + 1))
    ts=$(date -u +%H:%M:%S)
    echo "===== LAUNCH DETECTED #$attempt at $ts =====" | tee -a "$OUT"
    tail -30 "$LOG" | rg "INIT|SIGKILL|fatal|Exception|Error|exited|FAILED" | tee -a "$OUT" || true
    # Clear marker so next launch is detected
    sleep 3
  fi
  sleep 1
done
