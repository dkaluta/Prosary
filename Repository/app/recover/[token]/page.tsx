import { RecoverPanel } from "@/components/RecoverPanel";

export const dynamic = "force-dynamic";

export default async function RecoverPage({ params }: { params: Promise<{ token: string }> }) {
  const { token } = await params;
  return (
    <main>
      <RecoverPanel token={token} />
    </main>
  );
}
