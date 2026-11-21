import type { UserAccount, UserActionInput } from "./admin-api";

export const accessLabels: Record<UserAccount["access"], string> = {
  developer: "Sviluppatore · senza limiti",
  test: "Periodo di test",
  not_started: "Prova non avviata",
  plan: "Piano assegnato",
  trial: "Prova attiva",
  expired: "Prova scaduta",
};
export const actionLabels: Record<UserActionInput["action"], string> = {
  restrict_marketplace: "Sospendi dal Mercatino",
  lift_marketplace: "Revoca sospensione Mercatino",
  revoke_devices: "Revoca dispositivi app",
};
export function userDate(value: string | null | undefined): string {
  if (!value || Number.isNaN(new Date(value).getTime())) return "—";
  return new Intl.DateTimeFormat("it-IT", {
    dateStyle: "short",
    timeStyle: "short",
    timeZone: "Europe/Rome",
  }).format(new Date(value));
}
export function countryName(code: string | null | undefined): string {
  if (!code || code === "unknown") return "Nazione non disponibile";
  try {
    return new Intl.DisplayNames(["it"], { type: "region" }).of(code) ?? code;
  } catch {
    return code;
  }
}
