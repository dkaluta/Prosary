import { sendHeartbeatEmail } from "@/lib/email";

const HEARTBEAT_TO = "mail@dkaluta.com";

// Vercel invokes cron paths with GET and, when CRON_SECRET is set, an
// Authorization: Bearer header carrying it — reject anything else so the
// endpoint can't be used to spam heartbeats.
export async function GET(request: Request) {
  const secret = process.env.CRON_SECRET;
  if (secret && request.headers.get("authorization") !== `Bearer ${secret}`) {
    return Response.json({ error: "unauthorized" }, { status: 401 });
  }
  await sendHeartbeatEmail(HEARTBEAT_TO);
  return Response.json({ ok: true });
}
