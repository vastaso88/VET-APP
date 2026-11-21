import { NextRequest, NextResponse } from "next/server";

const ACCESS_COOKIE = "vet_admin_access_token";
const REFRESH_COOKIE = "vet_admin_refresh_token";
const THIRTY_DAYS = 60 * 60 * 24 * 30;

function expiresSoon(token: string | undefined): boolean {
  if (!token) return true;
  try {
    const payload = JSON.parse(atob(token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/"))) as { exp?: number };
    return !payload.exp || payload.exp <= Date.now() / 1000 + 120;
  } catch {
    return true;
  }
}

export async function middleware(request: NextRequest) {
  const access = request.cookies.get(ACCESS_COOKIE)?.value;
  const refresh = request.cookies.get(REFRESH_COOKIE)?.value;
  if (!refresh || !expiresSoon(access)) return NextResponse.next();

  const url = process.env.ADMIN_SUPABASE_URL ?? process.env.NEXT_PUBLIC_SUPABASE_URL ?? "https://ywbuzgwbkrmkukkpysbz.supabase.co";
  const key = process.env.ADMIN_SUPABASE_PUBLISHABLE_KEY ?? process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? "sb_publishable_t5vFAehg91FYPh_rFLOiUQ_Wv9tFh5m";
  if (!url || !key) return NextResponse.next();

  try {
    const response = await fetch(`${url}/auth/v1/token?grant_type=refresh_token`, {
      method: "POST",
      headers: { apikey: key, "Content-Type": "application/json" },
      body: JSON.stringify({ refresh_token: refresh }),
      cache: "no-store",
    });
    if (!response.ok) {
      // Network and server errors must not destroy a valid refresh session.
      if (response.status !== 400 && response.status !== 401) return NextResponse.next();
      const destination = new URL("/login", request.url);
      const redirect = NextResponse.redirect(destination);
      redirect.cookies.delete(ACCESS_COOKIE);
      redirect.cookies.delete(REFRESH_COOKIE);
      return redirect;
    }
    const tokens = (await response.json()) as { access_token?: string; refresh_token?: string };
    if (!tokens.access_token || !tokens.refresh_token) return NextResponse.next();

    // Forward the new access token to this server-rendered request as well
    // as the browser; otherwise the first request after expiry still fails.
    const headers = new Headers(request.headers);
    const cookieHeader = request.headers.get("cookie") ?? "";
    const remaining = cookieHeader.split(";").map(v => v.trim()).filter(v =>
      v && !v.startsWith(`${ACCESS_COOKIE}=`) && !v.startsWith(`${REFRESH_COOKIE}=`));
    remaining.push(`${ACCESS_COOKIE}=${tokens.access_token}`);
    remaining.push(`${REFRESH_COOKIE}=${tokens.refresh_token}`);
    headers.set("cookie", remaining.join("; "));
    const next = NextResponse.next({ request: { headers } });
    const options = {
      httpOnly: true, secure: process.env.NODE_ENV === "production",
      sameSite: "lax" as const, path: "/", maxAge: THIRTY_DAYS,
    };
    next.cookies.set(ACCESS_COOKIE, tokens.access_token, options);
    next.cookies.set(REFRESH_COOKIE, tokens.refresh_token, options);
    return next;
  } catch {
    return NextResponse.next();
  }
}

export const config = {
  matcher: ["/((?!login|_next/static|_next/image|favicon.ico).*)"],
};
