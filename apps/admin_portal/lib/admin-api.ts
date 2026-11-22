// Public entry point of the admin API client. The pages import from here; the
// code lives in one module per function (QK-21): admin-api-core (session and
// request helpers), -users, -dashboard, -moderation, -ingestion.

export {
  ADMIN_COOKIE,
  ADMIN_REFRESH_COOKIE,
  ADMIN_REFRESH_MAX_AGE,
  apiBaseUrl,
  supabaseUrl,
  supabasePublishableKey,
} from "./admin-auth-config";
export { getAdminSession, requireAdminSession, type AdminUser } from "./admin-api-core";
export * from "./admin-api-users";
export * from "./admin-api-dashboard";
export * from "./admin-api-moderation";
export * from "./admin-api-ingestion";
