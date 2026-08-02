import { withinRateLimit } from "./db";

/** 429 guard for the auth endpoints, keyed by client IP + route. Returns a Response to send
 * when the caller is over the limit, null otherwise. Fails open on DB trouble — rate limiting
 * must never take sign-in down with it. */
export async function rateLimited(
  request: Request, route: string, limit: number, windowSeconds: number,
): Promise<Response | null> {
  const ip = request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "unknown";
  try {
    if (await withinRateLimit(`${route}:${ip}`, limit, windowSeconds)) return null;
  } catch {
    return null;
  }
  return Response.json({ error: "rate_limited" }, { status: 429 });
}
