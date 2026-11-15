// Numbers and chart geometry of the "Consumi IA" page. Pure functions: no React,
// no server imports, so they can be checked on their own.

const LOCALE = "it-IT";

/** Euro or dollars: cents are not enough for a few answers a day, so amounts
 * under 1 show four decimals ("€ 0,0123"). */
function money(value: number, currency: "EUR" | "USD"): string {
  const small = Math.abs(value) < 1;
  return new Intl.NumberFormat(LOCALE, {
    style: "currency",
    currency,
    minimumFractionDigits: 2,
    maximumFractionDigits: small ? 4 : 2,
  }).format(value);
}

export function formatEur(value: number): string {
  return money(value, "EUR");
}

export function formatUsd(value: number): string {
  return money(value, "USD");
}

/** 0.4237 -> "42%"; null -> "—". */
export function formatPercent(share: number | null): string {
  if (share === null) return "—";
  return new Intl.NumberFormat(LOCALE, {
    style: "percent",
    maximumFractionDigits: share < 0.1 ? 1 : 0,
  }).format(share);
}

/** 1234567 -> "1,2 Mln"; small numbers as they are. */
export function formatCount(value: number): string {
  return new Intl.NumberFormat(LOCALE, {
    notation: value >= 10_000 ? "compact" : "standard",
    maximumFractionDigits: 1,
  }).format(value);
}

/** "2026-11-15" -> "15/11". The ledger's days are UTC dates, shown as written. */
export function formatDay(isoDate: string): string {
  const [, month, day] = isoDate.split("-");
  return `${day}/${month}`;
}

export type DayPoint = { date: string; eur: number; calls: number };

export type ChartBar = {
  date: string;
  x: number;
  y: number;
  width: number;
  height: number;
  /** The day reached the daily cap. */
  over: boolean;
  /** The text of the hover tip. */
  tip: string;
};

export type Chart = {
  width: number;
  height: number;
  bars: ChartBar[];
  /** Where the daily cap line sits (null without a cap). */
  capY: number | null;
  /** The euros the top of the plot stands for. */
  scaleMax: number;
  plot: { left: number; top: number; right: number; bottom: number };
};

const WIDTH = 720;
const HEIGHT = 190;
const PLOT = { left: 56, top: 10, right: 8, bottom: 26 };

/** The bars of the last days, scaled so the tallest day and the cap both fit. */
export function chartGeometry(days: DayPoint[], capEur: number | null): Chart {
  const plotWidth = WIDTH - PLOT.left - PLOT.right;
  const plotHeight = HEIGHT - PLOT.top - PLOT.bottom;
  const tallest = days.reduce((max, day) => Math.max(max, day.eur), 0);
  // Room above the tallest bar or the cap line; never zero (an empty ledger).
  const scaleMax = Math.max(tallest, capEur ?? 0, 0.0001) * 1.1;
  const slot = days.length > 0 ? plotWidth / days.length : plotWidth;
  const width = slot * 0.72;
  const baseline = PLOT.top + plotHeight;

  const bars = days.map((day, index) => {
    const height = (day.eur / scaleMax) * plotHeight;
    return {
      date: day.date,
      x: PLOT.left + index * slot + (slot - width) / 2,
      y: baseline - height,
      width,
      height,
      over: capEur !== null && day.eur >= capEur && day.eur > 0,
      tip: `${formatDay(day.date)}: ${formatEur(day.eur)} · ${day.calls} chiamate`,
    };
  });

  return {
    width: WIDTH,
    height: HEIGHT,
    bars,
    capY: capEur === null ? null : baseline - (capEur / scaleMax) * plotHeight,
    scaleMax,
    plot: { left: PLOT.left, top: PLOT.top, right: WIDTH - PLOT.right, bottom: baseline },
  };
}
