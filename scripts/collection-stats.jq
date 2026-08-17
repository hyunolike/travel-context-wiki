# Renders the collection-stats metrics document as a hand-drawn SVG.
#
# Pure: input is the metrics document, output is the SVG text. It never reads a
# clock or a random source. That is a contract, not a style choice — the daily
# workflow commits only when this output changes, so any non-determinism turns
# into a commit per day that says nothing.

def r: (. * 10 | round) / 10;

def esc:
  tostring | gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;");

def commas:
  (tostring | explode | reverse) as $d
  | [ range($d | length) as $i
      | ( $d[$i],
          (if ($i % 3 == 2) and ($i < ($d | length) - 1) then 44 else empty end) ) ]
  | reverse | implode;


def midx: (.[0:4] | tonumber) * 12 + (.[5:7] | tonumber) - 1;
def mstr: (. / 12 | floor) as $y | (. % 12 + 1) as $mo
  | "\($y)-\(if $mo < 10 then "0" else "" end)\($mo)";

# djb2 over the serialised metrics. Seeding from the data is what ties the
# sketch to the numbers: change a value and only that shape moves.
def seed_of($doc):
  (reduce ($doc | tojson | explode[]) as $c (5381; ((. * 33) + $c) % 2147483647))
  | if . == 0 then 1 else . end;

# MINSTD. The multiplier is chosen so every intermediate product stays below
# 2^53 and is therefore exact in the IEEE doubles jq uses; a larger one would
# lose precision and could drift between platforms, which is the one thing this
# generator cannot afford.
def noise($seed; $n):
  [ foreach range($n) as $_ ($seed; (. * 16807) % 2147483647; (. / 2147483647) - 0.5) ];

def w($N; $k): $N[((($k % 4096) + 4096) % 4096)];

# One pen stroke: a cubic whose control points are pulled off the straight line.
# Endpoints move less than the middle, so corners still read as corners.
def rline($N; $x1; $y1; $x2; $y2; $k; $amp):
    ($x1 + w($N; $k)     * $amp * 1.1) as $ax
  | ($y1 + w($N; $k + 1) * $amp * 1.1) as $ay
  | ($x2 + w($N; $k + 2) * $amp * 1.1) as $bx
  | ($y2 + w($N; $k + 3) * $amp * 1.1) as $by
  | ($x1 + ($x2 - $x1) / 3       + w($N; $k + 4) * $amp * 3.2) as $c1x
  | ($y1 + ($y2 - $y1) / 3       + w($N; $k + 5) * $amp * 3.2) as $c1y
  | ($x1 + ($x2 - $x1) * 2 / 3   + w($N; $k + 6) * $amp * 3.2) as $c2x
  | ($y1 + ($y2 - $y1) * 2 / 3   + w($N; $k + 7) * $amp * 3.2) as $c2y
  | "M\($ax|r) \($ay|r) C\($c1x|r) \($c1y|r) \($c2x|r) \($c2y|r) \($bx|r) \($by|r)";

def stroke_path($d; $colour; $width; $opacity):
  "<path d=\"\($d)\" fill=\"none\" stroke=\"\($colour)\" stroke-width=\"\($width)\" stroke-opacity=\"\($opacity)\" stroke-linecap=\"round\"/>";

# Two passes over the same edge. The divergence between them is the whole
# effect; one pass just looks like a wobbly line.
def sketch_line($N; $x1; $y1; $x2; $y2; $k; $amp; $colour; $width):
  stroke_path(rline($N; $x1; $y1; $x2; $y2; $k; $amp); $colour; $width; 1)
  + stroke_path(rline($N; $x1; $y1; $x2; $y2; $k + 8; $amp); $colour; $width; 0.75);

# Edges overshoot their corners, which is what separates a hand-drawn rectangle
# from a merely imprecise one.
def sketch_rect($N; $x; $y; $wd; $ht; $k; $amp; $colour; $width):
    ($amp * 1.4) as $o
  | sketch_line($N; $x - $o;       $y;             $x + $wd + $o; $y;             $k;      $amp; $colour; $width)
  + sketch_line($N; $x + $wd;      $y - $o;        $x + $wd;      $y + $ht + $o;  $k + 16; $amp; $colour; $width)
  + sketch_line($N; $x + $wd + $o; $y + $ht;       $x - $o;       $y + $ht;       $k + 32; $amp; $colour; $width)
  + sketch_line($N; $x;            $y + $ht + $o;  $x;            $y - $o;        $k + 48; $amp; $colour; $width);

# 45-degree fill, clipped analytically rather than with a clipPath element:
# GitHub proxies and sanitises a repository SVG, and plain <path> is the part
# of the format nothing argues with. For y = x + c the visible span is
# x from max(x0, y0 - c) to min(x1, y1 - c).
def hachure($N; $x; $y; $wd; $ht; $k; $gap; $colour; $width; $opacity):
    ($x + $wd) as $x1
  | ($y + $ht) as $y1
  | [ range((($y - $x1) / $gap | floor); (($y1 - $x) / $gap | ceil) + 1) as $i
      | ($i * $gap) as $c
      | ([$x, $y - $c] | max) as $sx
      | ([$x1, $y1 - $c] | min) as $ex
      | select($ex - $sx > 1)
      | stroke_path(rline($N; $sx; $sx + $c; $ex; $ex + $c; $k + $i * 8; 2.2); $colour; $width; $opacity) ]
  | join("");

def text_at($x; $y; $size; $colour; $anchor; $s):
  "<text x=\"\($x|r)\" y=\"\($y|r)\" font-family=\"Comic Sans MS, Chalkboard SE, Segoe Print, Bradley Hand, cursive\" font-size=\"\($size)\" fill=\"\($colour)\" text-anchor=\"\($anchor)\">\($s|esc)</text>";

"#fdfdf7" as $PAPER
| "#1e1e1e" as $INK
| "#5c5c5c" as $MUTED
| "#4c6ef5" as $ACCENT
| 900 as $W
| . as $m
| noise(seed_of($m); 4096) as $N
| ($m.periods.series) as $series
| ($series | length) as $n
| (if $n > 0 then 322 else 234 + 76 end) as $chartBottom
| ($chartBottom + 56) as $H

# Four headline numbers. A stat tile, not a chart: each is a single value with
# no comparison to make, and a bar of one bar is not a figure.
| [ {value: ($m.periods.count | tostring), caption: "수집 개월"},
    {value: ($m.periods.rows | commas),    caption: "일별 행"},
    {value: ($m.periods.regions | tostring), caption: "기초지자체"},
    {value: ($m.stations.count | commas),  caption: "대기측정소"} ] as $tiles

| ( [ range(4) as $i
      | (44 + $i * 216) as $tx
      | ($tx + 98) as $cx
      | sketch_rect($N; $tx; 88; 196; 84; 200 + $i * 96; 3.4; $INK; 1.6)
        + text_at($cx; 130; 32; $INK; "middle"; $tiles[$i].value)
        + text_at($cx; 156; 15; $MUTED; "middle"; $tiles[$i].caption) ]
    | join("") ) as $tileSvg

| ( if $n > 0 then
      ([$series[].period] | map(midx)) as $have
      | ($have | min) as $lo
      | ($have | max) as $hi
      | ($hi - $lo + 1) as $span
      | ([56, 812 / $span] | min) as $cw
      | [ range($span) as $i
          | ($lo + $i) as $mi
          | (44 + $i * $cw) as $cx
          | ($cw - 7) as $cwd
          | (1200 + $i * 640) as $k
          | (if ($have | index($mi)) then
               hachure($N; $cx; 234; $cwd; 44; $k; 11; $ACCENT; 1.2; 0.55)
               + sketch_rect($N; $cx; 234; $cwd; 44; $k + 96; 2.6; $ACCENT; 1.6)
             else
               sketch_rect($N; $cx; 234; $cwd; 44; $k + 96; 2.6; $MUTED; 1.2)
             end)
          + text_at($cx + $cwd / 2; 296; 13; $MUTED; "middle"; ($mi | mstr | .[5:7]))
          + (if ($mi % 12) == 0 or $i == 0
             then text_at($cx + $cwd / 2; 312; 12; $MUTED; "middle"; ($mi | mstr | .[0:4]))
             else "" end) ]
      | join("")
    else
      sketch_rect($N; 44; 234; 812; 60; 1200; 3.4; $MUTED; 1.4)
      + text_at(450; 270; 17; $MUTED; "middle"; "아직 수집된 기간이 없습니다")
    end ) as $chartSvg

| ( if $m.periods.first == "" then "수집 전"
    else "\($m.periods.first) – \($m.periods.last)" end ) as $range
| ( if $m.lastCollectedAt == "" then "마지막 수집 없음"
    else "마지막 수집 \($m.lastCollectedAt)" end ) as $footer

| "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\($W)\" height=\"\($H)\" viewBox=\"0 0 \($W) \($H)\" role=\"img\" aria-label=\"수집 현황: 기간 \($m.periods.count)개, 일별 행 \($m.periods.rows), 기초지자체 \($m.periods.regions), 대기측정소 \($m.stations.count)\">"
  + "<rect x=\"0\" y=\"0\" width=\"\($W)\" height=\"\($H)\" fill=\"\($PAPER)\"/>"
  + text_at(44; 58; 30; $INK; "start"; "수집 현황")
  + text_at(856; 58; 16; $MUTED; "end"; $range)
  + $tileSvg
  + text_at(44; 214; 20; $INK; "start"; "수집된 월")
  + $chartSvg
  + text_at(44; $chartBottom + 34; 15; $MUTED; "start"; $footer)
  + "</svg>"
