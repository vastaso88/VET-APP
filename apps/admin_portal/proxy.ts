import { NextRequest, NextResponse } from "next/server";

import {
  ADMIN_COOKIE,
  ADMIN_REFRESH_COOKIE,
  ADMIN_REFRESH_MAX_AGE,
  supabasePublishableKey,
  supabaseUrl,
} from "./lib/admin-auth-config";

type RefreshResponse = {
  access_token?: string;
  refresh_token?: string;
  expires_in?: number;
};

// The token's decoded expiry is only a scheduling hint. The backend verifies
// the JWT signature and admin role on EVERY API call.
function secondsUntilExpiry(token: string): number {
  try {
    const payload = JSON.parse(atob(token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/"))) as {
      exp?: number;
    };
    return typeof payload.exp === "number" ? payload.exp - Date.now() / 1000 : 0;
  } catch {
    return 0;
  }
}

export async function proxy(request: NextRequest) {
  const access = request.cookies.get(ADMIN_COOKIE)?.value;
  const refresh = request.cookies.get(ADMIN_REFRESH_COOKIE)?.value;
  // A user who logged in before this rollout needs to reauthenticate once to
  // acquire a refresh cookie; never trust a locally invented refresh session.
  if (!refresh || (access && secondsUntilExpiry(access) > 75)) {
    return NextResponse.next();
  }

  try {
    const provider = await fetch(`${supabaseUrl()}/auth/v1/token?grant_type=refresh_token`, {
      method: "POST",
      headers: {
        apikey: supabasePublishableKey(),
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify({ refresh_token: refresh }),
      signal: AbortSignal.timeout(6500),
      cache: "no-store",
    });
    if (!provider.ok) {
      // Transient Supabase issues must not destroy login state. A confirmed
      // invalid refresh is handled by /admin/me if the access token expired.
      return NextResponse.next();
    }
    const result = (await provider.json()) as RefreshResponse;
    if (!result.access_token || !result.refresh_token) return NextResponse.next();

    // Pass refreshed token to this SAME render, not only the next request.
    request.cookies.set(ADMIN_COOKIE, result.access_token);
    request.cookies.set(ADMIN_REFRESH_COOKIE, result.refresh_token);
    const response = NextResponse.next({ request: { headers: request.headers } });
    const options = {
      httpOnly: true,
      secure: process.env.NODE_ENV === "production",
      sameSite: "lax" as const,
      path: "/",
    };
    response.cookies.set(ADMIN_COOKIE, result.access_token, {
      ...options,
      maxAge: Math.max(60, result.expires_in ?? 3600),
    });
    response.cookies.set(ADMIN_REFRESH_COOKIE, result.refresh_token, {
      ...options,
      maxAge: ADMIN_REFRESH_MAX_AGE,
    });
    // Never let an intermediary cache Set-Cookie on a personalized response.
    response.headers.set("Cache-Control", "private, no-store, max-age=0");
    return response;
  } catch {
    return NextResponse.next();
  }
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico)$).*)"],
};
