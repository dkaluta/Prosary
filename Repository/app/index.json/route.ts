import { listBundles } from "@/lib/db";

// The versioned catalog contract — what a future in-app repository browser
// consumes. Shape: { prosaryRepository: 1, bundles: [{ id, name, author,
// languages, tags, description, file }] }.
export async function GET() {
  const bundles = await listBundles({});
  return Response.json({
    prosaryRepository: 1,
    bundles: bundles.map((b) => ({
      id: b.id,
      name: b.name,
      author: b.author,
      languages: b.languages,
      tags: b.tags,
      description: b.description,
      file: `/api/download/${b.id}`,
      updatedAt: b.updated_at,
    })),
  });
}
