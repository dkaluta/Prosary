export default function Loading() {
  return (
    <main id="main-content" aria-busy="true" aria-label="Loading page">
      <div className="card loading-block" role="status">
        <span className="loading-line" aria-hidden="true" />
        <span className="loading-line" aria-hidden="true" />
        <span className="loading-line" aria-hidden="true" />
        <span>Loading…</span>
      </div>
    </main>
  );
}
