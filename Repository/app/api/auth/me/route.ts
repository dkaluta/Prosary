import { getCurrentUser } from "@/lib/auth";

export async function GET() {
  const user = await getCurrentUser();
  return Response.json(user ? { username: user.username } : { username: null });
}
