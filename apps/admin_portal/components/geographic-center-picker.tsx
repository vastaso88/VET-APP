"use client";

import { useEffect, useRef } from "react";
import type { Map as LeafletMap, Circle, Marker } from "leaflet";

export type GeographicCenter = {
  latitude: number;
  longitude: number;
};

// Click-to-pick map for the ingestion center. Keeps Leaflet out of the
// server bundle (dynamic import) and reads the latest onPick through a ref
// so the map is created once and not rebuilt on every parent render.
export function GeographicCenterPicker({
  center,
  radiusKm,
  onPick,
}: {
  center: GeographicCenter | null;
  radiusKm: number;
  onPick: (center: GeographicCenter) => void;
}) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<LeafletMap | null>(null);
  const markerRef = useRef<Marker | null>(null);
  const circleRef = useRef<Circle | null>(null);
  const onPickRef = useRef(onPick);

  useEffect(() => {
    onPickRef.current = onPick;
  }, [onPick]);

  useEffect(() => {
    let active = true;

    void import("leaflet").then((L) => {
      if (!active || !containerRef.current || mapRef.current) return;

      const map = L.map(containerRef.current, { worldCopyJump: true, minZoom: 2 }).setView(
        [45.4642, 9.19],
        5,
      );
      mapRef.current = map;

      L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
        attribution: "&copy; OpenStreetMap contributors",
        maxZoom: 19,
      }).addTo(map);

      map.on("click", (event) => {
        onPickRef.current({
          latitude: Number(event.latlng.lat.toFixed(6)),
          longitude: Number(event.latlng.lng.toFixed(6)),
        });
      });
    });

    return () => {
      active = false;
      mapRef.current?.remove();
      mapRef.current = null;
      markerRef.current = null;
      circleRef.current = null;
    };
  }, []);

  useEffect(() => {
    const map = mapRef.current;
    if (!map || !center) return;

    void import("leaflet").then((L) => {
      const point: [number, number] = [center.latitude, center.longitude];
      const radiusMeters = Math.max(radiusKm, 0.1) * 1000;

      if (!markerRef.current) {
        markerRef.current = L.marker(point).addTo(map);
      } else {
        markerRef.current.setLatLng(point);
      }

      if (!circleRef.current) {
        circleRef.current = L.circle(point, {
          radius: radiusMeters,
          color: "#1565c0",
          weight: 1.5,
          fillOpacity: 0.15,
        }).addTo(map);
      } else {
        circleRef.current.setLatLng(point).setRadius(radiusMeters);
      }
    });
  }, [center, radiusKm]);

  return (
    <div
      ref={containerRef}
      className="geographic-world-map geographic-center-picker"
      aria-label="Mappa per scegliere il centro dell'ingestion"
    />
  );
}
