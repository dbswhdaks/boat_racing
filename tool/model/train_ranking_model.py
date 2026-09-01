#!/usr/bin/env python3
"""PredictionEngine(ranking-v3) 계수를 재현·재학습하는 파이프라인.

사용법:
    python train_ranking_model.py --service-key <공공데이터포털 키> --fetch
    python train_ranking_model.py            # 이미 내려받은 캐시로 재학습

단계
    1. 공공데이터포털에서 출주표(RACE_DOC)와 경주결과(RACE_RESULT)를 연도별로 수집
    2. (연도, 회차, 일차, 경주번호) 로 조인해 경주별 데이터셋 구축
    3. 2023~2024 로 학습, 2025 로 softmax 온도 선택, 2026 으로 한 번만 최종 평가
    4. lib/core/services/prediction_engine.dart 에 넣을 계수 출력

미래정보 누출이 없는 이유
    RACE_DOC 의 선수/장비 통계는 해당 경주 시점까지의 누적치다. 같은 선수의
    win_ratio 가 날짜별로 변하는 것으로 확인했다(시즌 종료 후 스냅샷이 아님).
    반대로 단승 배당은 경주가 끝난 뒤에만 공개돼 예측 시점에 쓸 수 없으므로
    피처에서 제외했다.
"""

from __future__ import annotations

import argparse
import collections
import json
import math
import pathlib
import time
import urllib.parse
import urllib.request

import numpy as np

BASE = "https://apis.data.go.kr/B551014"
DOC_PATH = "/SRVC_OD_API_VWEB_MBR_RACE_DOC/TODZ_API_VWEB_MBR_RACE_DOC_I"
RESULT_PATH = "/SRVC_OD_API_MBR_RACE_RESULT/TODZ_API_MBR_RACE_RESULT_I"

YEARS = (2023, 2024, 2025, 2026)
CACHE = pathlib.Path(__file__).parent / "cache"

TRAIN_END = "20250101"
VALID_END = "20260101"

CIRCLE = "①②③④⑤⑥⑦⑧⑨⑩"
GRADES = ("A1", "A2", "B1")   # B2 = 기준 범주
COURSES = (1, 2, 3, 4, 5)     # 6코스 = 기준 범주

# 공공 API(RACE_DOC)와 KBOAT 확정출주표에서 '같은 정의'로 얻을 수 있는 값만 쓴다.
# 이 제약이 없으면 학습과 실제 예측이 다른 지표를 보게 된다.
FEATURES = (
    "avg_rank_point",     # 선수 연간 평균착순점        <-> 출주표 연간성적 평균착순점
    "top2_rate",          # 선수 연간 연대율            <-> 출주표 연간성적 연대율
    "motor_rank_point",   # 모터 연간 평균착순점        <-> 모터성적 평균착순점
    "motor_top2_rate",    # 모터 연간 이연대율          <-> 모터성적 이연대율
    "motor_top3_rate",    # 모터 연간 삼연대율          <-> 모터성적 삼연대율
    "boat_rank_point",    # 보트 연간 평균착순점        <-> 보트성적 평균착순점
    "boat_top2_rate",     # 보트 연간 연대율            <-> 보트성적 연대율
)

SOURCE_KEYS = {
    "avg_rank_point": "avg_rank",
    "top2_rate": "high_rate",
    "motor_rank_point": "mot_avg_rank_scr",
    "motor_top2_rate": "mot_high_rank_ratio",
    "motor_top3_rate": "mot_high_3_rank_ratio",
    "boat_rank_point": "boat_avg_rank_scr",
    "boat_top2_rate": "boat_high_rank_ratio",
}


# ────────────────────────────── 수집 ──────────────────────────────

def fetch_all(service_key: str) -> None:
    CACHE.mkdir(parents=True, exist_ok=True)
    for year in YEARS:
        for path, tag, pages in ((DOC_PATH, "doc", 22), (RESULT_PATH, "res", 2)):
            for page in range(1, pages + 1):
                target = CACHE / f"{tag}_{year}_{page}.json"
                if target.exists() and target.stat().st_size > 2000:
                    continue
                query = urllib.parse.urlencode({
                    "serviceKey": service_key,
                    "pageNo": page,
                    "numOfRows": 1000,
                    "resultType": "json",
                    "stnd_yr": year,
                })
                # 초당 요청 제한이 있어 순차로 받는다.
                for attempt in range(3):
                    try:
                        with urllib.request.urlopen(f"{BASE}{path}?{query}", timeout=30) as res:
                            body = res.read()
                        if len(body) > 2000:
                            target.write_bytes(body)
                            break
                    except Exception:
                        pass
                    time.sleep(2)
                print(f"  {target.name}", flush=True)


def load_items(path: pathlib.Path) -> list[dict]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return []
    items = payload.get("response", {}).get("body", {}).get("items")
    if not items:
        return []
    node = items["item"] if isinstance(items, dict) else items
    if node is None:
        return []
    return node if isinstance(node, list) else [node]


# ───────────────────────────── 데이터셋 ─────────────────────────────

def to_int(value):
    try:
        return int(str(value).strip())
    except (TypeError, ValueError):
        return None


def to_float(value):
    try:
        return float(str(value).strip())
    except (TypeError, ValueError):
        return None


def podium_course(raw) -> int | None:
    """'①류해광' -> 1"""
    text = str(raw or "").strip()
    if not text or text[0] not in CIRCLE:
        return None
    return CIRCLE.index(text[0]) + 1


def build_dataset() -> list[dict]:
    docs: dict[tuple, dict] = {}
    for path in sorted(CACHE.glob("doc_*.json")):
        for row in load_items(path):
            key = (
                row.get("stnd_yr"),
                to_int(row.get("week_tcnt")),
                to_int(row.get("day_tcnt")),
                to_int(row.get("race_no")),
                str(row.get("racer_no") or ""),
            )
            if None not in key[:4] and key[4]:
                docs[key] = row

    results: dict[tuple, dict] = {}
    for path in sorted(CACHE.glob("res_*.json")):
        for row in load_items(path):
            key = (
                row.get("stnd_yr"),
                to_int(row.get("week_tcnt")),
                to_int(row.get("day_tcnt")),
                to_int(row.get("race_no")),
            )
            if None not in key:
                results[key] = row

    grouped = collections.defaultdict(list)
    for key, row in docs.items():
        grouped[key[:4]].append(row)

    races = []
    for key, rows in grouped.items():
        result = results.get(key)
        if result is None:
            continue
        podium = [podium_course(result.get(f"rank{i}")) for i in (1, 2, 3)]
        if podium[0] is None:
            continue

        by_course = {}
        for row in rows:
            course = to_int(row.get("race_reg_no"))
            if course is None or not 1 <= course <= 6 or course in by_course:
                continue
            by_course[course] = {
                "course": course,
                "grade": str(row.get("racer_grd_cd") or "").strip(),
                "date": str(row.get("race_ymd") or ""),
                **{name: to_float(row.get(SOURCE_KEYS[name])) for name in FEATURES},
            }

        entries = [by_course[c] for c in sorted(by_course)]
        if len(entries) < 2 or podium[0] not in by_course:
            continue
        races.append({
            "date": next((e["date"] for e in entries if e["date"]), ""),
            "entries": entries,
            "podium": podium,
        })

    races.sort(key=lambda race: race["date"])
    return races


# ────────────────────────── 피처 행렬 ──────────────────────────

def feature_names() -> list[str]:
    return (
        [f"course{c}" for c in COURSES]
        + [f"grade{g}" for g in GRADES]
        + list(FEATURES)
        + [f"course{c}_x_topGrade" for c in (1, 2)]
    )


def raw_matrix(races: list[dict]) -> np.ndarray:
    rows = []
    for race in races:
        for entry in race["entries"]:
            top_grade = 1.0 if entry["grade"] in ("A1", "A2") else 0.0
            rows.append(
                [1.0 if entry["course"] == c else 0.0 for c in COURSES]
                + [1.0 if entry["grade"] == g else 0.0 for g in GRADES]
                + [np.nan if entry[name] is None else entry[name] for name in FEATURES]
                + [top_grade if entry["course"] == c else 0.0 for c in (1, 2)]
            )
    return np.array(rows, dtype=float)


def standardize(matrix: np.ndarray, names: list[str]):
    means = np.nanmean(matrix, axis=0)
    stds = np.nanstd(matrix, axis=0)
    stds[stds < 1e-9] = 1.0
    for index, name in enumerate(names):
        if name not in FEATURES:      # 더미 변수는 그대로 둔다
            means[index] = 0.0
            stds[index] = 1.0
    return means, stds


def pack(races: list[dict], means, stds):
    """(경주 수, 6, 피처 수) 텐서 + 마스크 + 착순 인덱스."""
    matrix = raw_matrix(races)
    standardized = (np.where(np.isnan(matrix), means, matrix) - means) / stds

    features = np.zeros((len(races), 6, standardized.shape[1]))
    mask = np.zeros((len(races), 6), dtype=bool)
    podium = np.full((len(races), 3), -1, dtype=int)

    cursor = 0
    for index, race in enumerate(races):
        size = min(len(race["entries"]), 6)
        features[index, :size] = standardized[cursor : cursor + size]
        mask[index, :size] = True
        cursor += len(race["entries"])
        courses = [e["course"] for e in race["entries"][:size]]
        for position, course in enumerate(race["podium"]):
            if course in courses:
                podium[index, position] = courses.index(course)
    return features, mask, podium


# ─────────────────── Plackett-Luce 학습 ───────────────────

def loss_and_grad(weights, features, mask, podium, l2):
    """1~3착을 순차적으로 고르는 우도의 음의 로그와 기울기."""
    utilities = features @ weights
    alive = mask.copy()
    rows = np.arange(len(utilities))
    loss = 0.0
    grad = np.zeros_like(weights)

    for position in range(3):
        chosen = podium[:, position]
        safe = np.maximum(chosen, 0)
        valid = (chosen >= 0) & alive[rows, safe]
        if not valid.any():
            break

        scores = np.where(alive, utilities, -1e30)
        scores = scores - scores.max(axis=1, keepdims=True)
        exps = np.where(alive, np.exp(scores), 0.0)
        totals = exps.sum(axis=1, keepdims=True)

        loss -= float((scores[rows, safe] - np.log(totals[:, 0]))[valid].sum())

        residual = exps / np.maximum(totals, 1e-300)
        residual[rows, safe] -= 1.0
        residual[~valid] = 0.0
        grad += np.einsum("rn,rnf->f", residual, features)

        alive[rows[valid], chosen[valid]] = False

    return loss + l2 * float(weights @ weights), grad + 2 * l2 * weights


def fit(features, mask, podium, l2=1e-4, steps=1500, learning_rate=0.08):
    weights = np.zeros(features.shape[2])
    moment1 = np.zeros_like(weights)
    moment2 = np.zeros_like(weights)

    for step in range(1, steps + 1):
        _, grad = loss_and_grad(weights, features, mask, podium, l2)
        grad /= len(features)
        moment1 = 0.9 * moment1 + 0.1 * grad
        moment2 = 0.999 * moment2 + 0.001 * grad * grad
        weights -= learning_rate * (moment1 / (1 - 0.9**step)) / (
            np.sqrt(moment2 / (1 - 0.999**step)) + 1e-8
        )
    return weights


# ───────────────────────────── 평가 ─────────────────────────────

def utilities_for(race, weights, means, stds):
    matrix = raw_matrix([race])
    standardized = (np.where(np.isnan(matrix), means, matrix) - means) / stds
    return standardized @ weights


def evaluate(races, weights, means, stds, temperature=1.0):
    stats = collections.Counter()
    logloss = 0.0
    for race in races:
        courses = [e["course"] for e in race["entries"]]
        utilities = utilities_for(race, weights, means, stds) / temperature
        order = [courses[i] for i in np.argsort(-utilities)]
        actual = race["podium"]

        stats["races"] += 1
        if order[0] == actual[0]:
            stats["top1"] += 1
        if actual[0] in order[:2]:
            stats["win"] += 1
        if actual[1]:
            pairs = [set(order[:2])] + ([{order[0], order[2]}] if len(order) > 2 else [])
            if any(p == {actual[0], actual[1]} for p in pairs):
                stats["place"] += 1
            exacta = [(order[0], order[1])] + ([(order[0], order[2])] if len(order) > 2 else [])
            if any(e == (actual[0], actual[1]) for e in exacta):
                stats["quinella"] += 1
        stats["unordered3"] += len(set(order[:3]) & {c for c in actual if c})

        shifted = utilities - utilities.max()
        probabilities = np.exp(shifted) / np.exp(shifted).sum()
        logloss -= math.log(max(probabilities[courses.index(actual[0])], 1e-12))

    stats["logloss_sum"] = logloss
    return stats


def report(label, stats):
    n = stats["races"]
    return (
        f"{label:26s} n={n:5d}  1착 {stats['top1']/n*100:5.2f}%  "
        f"단승2점 {stats['win']/n*100:5.2f}%  복승 {stats['place']/n*100:5.2f}%  "
        f"쌍승 {stats['quinella']/n*100:5.2f}%  3연대 {stats['unordered3']/n/3*100:5.2f}%  "
        f"logloss {stats['logloss_sum']/n:.4f}"
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--service-key")
    parser.add_argument("--fetch", action="store_true")
    args = parser.parse_args()

    if args.fetch:
        if not args.service_key:
            parser.error("--fetch 에는 --service-key 가 필요합니다")
        fetch_all(args.service_key)

    races = build_dataset()
    train = [r for r in races if r["date"] < TRAIN_END]
    valid = [r for r in races if TRAIN_END <= r["date"] < VALID_END]
    test = [r for r in races if r["date"] >= VALID_END]
    print(f"학습 {len(train)} / 검증 {len(valid)} / 홀드아웃 {len(test)}\n")

    names = feature_names()

    # 온도는 검증 구간에서만 고른다.
    means, stds = standardize(raw_matrix(train), names)
    warmup = fit(*pack(train, means, stds))
    best = min(
        (round(0.4 + 0.05 * i, 2) for i in range(41)),
        key=lambda t: evaluate(valid, warmup, means, stds, t)["logloss_sum"],
    )
    print(f"검증셋 최적 softmax 온도: {best}\n")

    # 최종 계수는 학습+검증 전체로 재학습.
    fit_races = train + valid
    means, stds = standardize(raw_matrix(fit_races), names)
    weights = fit(*pack(fit_races, means, stds))

    print("=== 홀드아웃 (한 번만 평가) ===")
    print(report("ranking-v3", evaluate(test, weights, means, stds, best)))

    # softmax 는 평행이동에 불변이라 표준화 평균은 상쇄되고 표준편차만 나누면 된다.
    raw = dict(zip(names, weights / stds))
    print("\n=== prediction_engine.dart 상수 ===")
    print(f"  _softmaxTemperature = {best}")
    for course in COURSES:
        print(f"  코스 {course}: {raw[f'course{course}']:.6f}")
    for grade in GRADES:
        print(f"  등급 {grade}: {raw[f'grade{grade}']:.6f}")
    grade_mean = float(np.mean([
        raw.get(f"grade{e['grade']}", 0.0) for r in fit_races for e in r["entries"]
    ]))
    print(f"  등급 미상 대체값: {grade_mean:.6f}")
    for name in FEATURES:
        print(f"  {name:18s} weight={raw[name]:+.6f}  fallback={means[names.index(name)]:.4f}")
    for course in (1, 2):
        print(f"  코스{course} x 상위등급: {raw[f'course{course}_x_topGrade']:.6f}")


if __name__ == "__main__":
    main()
