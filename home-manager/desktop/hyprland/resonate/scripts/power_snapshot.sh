#!/bin/sh
# One snapshot of cumulative usage counters for resonate's power overview.
# Cheap reads only: nothing here touches a device (no power_state, no
# nvidia-smi), so it can't wake a sleeping one. Output, one record per line:
#   T <clk_tck>
#   P <pid> <ppid> <cpu_ticks> <comm>   every process (stat is world-readable)
#   E <pid> <exe path>                  where readable (own processes)
#   G <pid> <drm-client-id> <gfx_ns>    iGPU engine time per DRM client (own processes)
#   D <pci addr> <driver> <runtime_status> <active_ms> <suspended_ms>
#   B <brightness percent>
#   M <monitor> <WxH> <refresh Hz>

echo "T $(getconf CLK_TCK)"

# One cat for all stat files (one line each): cat skips a pid that exits
# mid-read, where awk given the files directly aborts and drops every pid
# after it. comm is in parentheses and may contain spaces; utime/stime are
# the 12th and 13th fields after the closing paren.
cat /proc/[0-9]*/stat 2>/dev/null | awk '{
    pid = $1
    i = index($0, "(")
    j = match($0, /\) [A-Za-z] /)
    comm = substr($0, i + 1, j - i - 1)
    gsub(/ /, "_", comm)
    split(substr($0, j + 2), r, " ")
    print "P", pid, r[2], r[12] + r[13], comm
  }'

ls -l /proc/[0-9]*/exe 2>/dev/null | awk '/ -> / { split($(NF-2), p, "/"); print "E", p[3], $NF }'

grep -H -E "^drm-client-id|^drm-engine-gfx" /proc/[0-9]*/fdinfo/* 2>/dev/null | awk -F'[/:\t ]+' '
  $6 == "drm-client-id"  { id[$3 "/" $5] = $7 }
  $6 == "drm-engine-gfx" { print "G", $3, id[$3 "/" $5], $7 }'

for d in /sys/bus/pci/devices/*; do
  [ -e "$d/driver" ] || continue
  drv=$(readlink "$d/driver")
  read -r s < "$d/power/runtime_status"
  read -r a < "$d/power/runtime_active_time"
  read -r u < "$d/power/runtime_suspended_time"
  echo "D ${d##*/} ${drv##*/} $s $a $u"
done

brightnessctl -d 'amdgpu_bl*' -m i 2>/dev/null | awk -F, '{ sub(/%/, "", $4); print "B", $4 }'

hyprctl monitors 2>/dev/null | awk '/^Monitor/ { n = $2 } /^\t[0-9]+x[0-9]+@/ { split($1, a, "@"); printf "M %s %s %.0f\n", n, a[1], a[2] }'
