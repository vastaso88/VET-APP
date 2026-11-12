"use client";

import { useEffect, useRef } from "react";
import type { Map as LeafletMap } from "leaflet";

import type {
  GeographicCoverage,
  GeographicUser,
} from "../lib/admin-api";

const freshnessPalette = [
  { label: "Recent", color: "#2e7d32" },
  { label: "Fresh", color: "#7cb342" },
  { label: "Aging", color: "#f9a825" },
  { label: "Stale", color: "#ef6c00" },
  { label: "Obsolete", color: "#c62828" },
];

function freshnessIndex(cell: GeographicCoverage, now: number): number {
  const refreshed = new Date(cell.refreshed_at).getTime();
  const expires = new Date(cell.expires_at).getTime();
  if (!Number.isFinite(refreshed) || !Number.isFinite(expires) || expires <= refreshed) {
    return 4;
  }
  if (now >= expires) return 4;
  const progress = Math.max(0, (now - refreshed) / (expires - refreshed));
  if (progress < 0.2) return 0;
  if (progress < 0.4) return 1;
  if (progress < 0.6) return 2;
  if (progress < 0.8) return 3;
  return 4;
}

function popupNode(lines: Array<[string, string | number | null | undefined]>): HTMLElement {
  const root = document.createElement("div");
  root.className = "map-popup";
  for (const [label, raw] of lines) {
    const row = document.createElement("div");
    const key = document.createElement("strong");
    const value = document.createElement("span");
    key.textContent = label;
    value.textContent = raw === null || raw === undefined || raw === "" ? "—" : String(raw);
    row.append(key, value);
    root.append(row);
  }
  return root;
}

export function GeographicWorldMap({
  users,
  coverage,
}: {
  users: GeographicUser[];
  coverage: GeographicCoverage[];
}) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<LeafletMap | null>(null);

  useEffect(() => {
    let active = true;

    void import("leaflet").then((L) => {
      if (!active || !containerRef.current || mapRef.current) return;

      const map = L.map(containerRef.current, {
        worldCopyJump: true,
        minZoom: 2,
      }).setView([20, 0], 2);
      mapRef.current = map;

      L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
        attribution: "&copy; OpenStreetMap contributors",
        maxZoom: 19,
      }).addTo(map);

      const now = Date.now();
      const bounds: Array<[number, number]> = [];

      for (const cell of coverage) {
        const index = freshnessIndex(cell, now);
        const palette = freshnessPalette[index];
        const center: [number, number] = [cell.center_latitude, cell.center_longitude];
        bounds.push(center);

        L.circle(center, {
          radius: Math.max(cell.radius_km, 0.1) * 1000,
          color: palette.color,
          weight: 1.5,
          fillColor: palette.color,
          fillOpacity: 0.3,
        })
          .bindPopup(
            popupNode([
              ["Coverage", cell.coverage_key],
              ["Freshness", palette.label],
              ["Places", cell.place_count],
              ["Source", cell.source_name],
              ["Refreshed", new Date(cell.refreshed_at).toLocaleString("it-IT")],
              ["Expires", new Date(cell.expires_at).toLocaleString("it-IT")],
            ]),
          )
          .addTo(map);
      }

      const userIcon = L.divIcon({
        className: "user-map-pin-shell",
        html: '<span class="user-map-pin"></span>',
        iconSize: [24, 32],
        iconAnchor: [12, 30],
        popupAnchor: [0, -28],
      });

      for (const user of users) {
        const point: [number, number] = [user.latitude, user.longitude];
        bounds.push(point);
        L.marker(point, { icon: userIcon })
          .bindPopup(
            popupNode([
              ["User", user.email ?? user.owner_id],
              ["City", user.city],
              ["Address", user.address_label],
              ["Owner ID", user.owner_id],
            ]),
          )
          .addTo(map);
      }

      if (bounds.length) {
        map.fitBounds(bounds, {
          padding: [30, 30],
          maxZoom: 8,
        });
      }

      const legend = new L.Control({ position: "bottomright" });
      legend.onAdd = () => {
        const node = L.DomUtil.create("div", "map-legend");
        const title = document.createElement("strong");
        title.textContent = "Coverage freshness";
        node.append(title);
        for (const item of freshnessPalette) {
          const row = document.createElement("div");
          const swatch = document.createElement("span");
          swatch.style.background = item.color;
          const label = document.createElement("span");
          label.textContent = item.label;
          row.append(swatch, label);
          node.append(row);
        }
        const userRow = document.createElement("div");
        const pin = document.createElement("span");
        pin.className = "legend-user-pin";
        const userLabel = document.createElement("span");
        userLabel.textContent = "User";
        userRow.append(pin, userLabel);
        node.append(userRow);
        return node;
      };
      legend.addTo(map);
    });

    return () => {
      active = false;
      mapRef.current?.remove();
      mapRef.current = null;
    };
  }, [users, coverage]);

  return <div ref={containerRef} className="geographic-world-map" aria-label="Geographic coverage map" />;
}
