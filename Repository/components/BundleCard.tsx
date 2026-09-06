import Link from "next/link";
import { Fragment } from "react";
import type { BundleRow } from "@/lib/db";
import { displayLanguageCodes, languageName } from "@/lib/languages";

export function BundleTags({ tags }: { tags: string[] }) {
  if (tags.length === 0) return null;

  return (
    <ul className="tag-list" aria-label="Tags">
      {tags.map((tag, index) => (
        <li className="tag" key={`${tag}-${index}`} dir="auto">
          {tag}
        </li>
      ))}
    </ul>
  );
}

export function BundleLanguages({ codes }: { codes: string[] }) {
  return (
    <>
      {displayLanguageCodes(codes).map((code, index) => (
        <Fragment key={`${code}-${index}`}>
          {index > 0 ? ", " : null}
          <span lang={code} dir="auto">
            {languageName(code)}
          </span>
        </Fragment>
      ))}
    </>
  );
}

export function DownloadLink({ id, name, compact = false }: { id: string; name: string; compact?: boolean }) {
  return (
    <a
      className={compact ? "button button-subtle" : "button button-primary"}
      href={`/api/download/${encodeURIComponent(id)}`}
      aria-label={`Download ${name} as a .prosaryprayer bundle`}
    >
      {compact ? "Download" : "Download .prosaryprayer"}
    </a>
  );
}

export function BundleCard({ bundle, showAuthor = true }: { bundle: BundleRow; showAuthor?: boolean }) {
  const downloads = Number(bundle.downloads);
  const bundleHref = `/bundle/${encodeURIComponent(bundle.id)}`;

  return (
    <article className="card bundle-card">
      <div className="bundle-card-heading">
        <div>
          <h3 dir="auto">
            <Link href={bundleHref} prefetch={false}>{bundle.name}</Link>
          </h3>
          <p className="meta">
            {showAuthor ? (
              <>
                by{" "}
                <Link href={`/u/${encodeURIComponent(bundle.author)}`} prefetch={false}>
                  {bundle.author}
                </Link>
                <span aria-hidden="true"> · </span>
              </>
            ) : null}
            <BundleLanguages codes={bundle.languages} />
          </p>
        </div>
        <DownloadLink id={bundle.id} name={bundle.name} compact />
      </div>
      {bundle.description ? (
        <p className="bundle-description" dir="auto">
          {bundle.description}
        </p>
      ) : null}
      <BundleTags tags={bundle.tags} />
      <p className="bundle-footnote">
        <code>{bundle.id}</code>
        <span aria-hidden="true"> · </span>
        {downloads} download{downloads === 1 ? "" : "s"}
      </p>
    </article>
  );
}
