import Link from "next/link";
import { AdminShell } from "../../components/admin-shell";
import { getAdminPets } from "../../lib/admin-api";

const speciesLabels: Record<string, string> = {
  dog: "Dogs", cat: "Cats", small_mammal: "Small mammals",
  bird: "Birds", reptile_amphibian: "Reptiles / amphibians",
  fish: "Fish", other: "Other", unknown: "Unknown",
};
const speciesOptions = Object.entries(speciesLabels);

export default async function PetsPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; page?: string; species?: string; status?: string }>;
}) {
  const params = await searchParams;
  const q = (params.q ?? "").slice(0, 200);
  const species = speciesOptions.some(([key]) => key === params.species) ? params.species! : "";
  const status = ["active", "inactive", "exotic", "memorial"].includes(params.status ?? "")
    ? params.status! : "";
  const parsedPage = Number(params.page);
  const page = Number.isInteger(parsedPage) && parsedPage > 0 ? Math.min(parsedPage, 2000) : 1;
  const data = await getAdminPets(q, page, species, status);
  const pageUrl = (target: number) =>
    `/pets?${new URLSearchParams({ q, species, status, page: String(target) })}`;

  return (
    <AdminShell title="Pets" eyebrow="Profiles & support" className="users-shell">
      <section className="panel users-panel">
        <div className="panel-heading">
          <div>
            <p className="eyebrow">Pet directory</p>
            <h2>Registered animals</h2>
          </div>
          <span className="tag">read-only</span>
        </div>
        <form className="job-filters users-search" action="/pets">
          <label>
            Search by name, breed, pet ID or owner ID
            <input type="search" name="q" maxLength={200} defaultValue={q} placeholder="Search pets" />
          </label>
          <label>
            Species
            <select name="species" defaultValue={species}>
              <option value="">All species</option>
              {speciesOptions.map(([key, label]) => <option key={key} value={key}>{label}</option>)}
            </select>
          </label>
          <label>
            Status
            <select name="status" defaultValue={status}>
              <option value="">All statuses</option>
              <option value="active">Active</option>
              <option value="inactive">Inactive</option>
              <option value="exotic">Exotic</option>
              <option value="memorial">Memorial</option>
            </select>
          </label>
          <button className="ghost-button" type="submit">Filter</button>
          {(q || species || status) && <Link className="ghost-button" href="/pets">Clear</Link>}
        </form>
      </section>
      {!data ? (
        <section className="panel" role="alert">
          <h2>Pet directory unavailable</h2>
          <p className="muted">The backend must expose the admin pets endpoint. Check the API deployment.</p>
        </section>
      ) : (
        <section className="panel users-panel">
          <div className="panel-heading">
            <h2>Pets</h2>
            <span className="muted">
              {data.total ? (data.page - 1) * data.page_size + 1 : 0}–
              {Math.min(data.page * data.page_size, data.total)} of {data.total}
            </span>
          </div>
          <div className="pets-table-scroll">
            <table className="users-table">
              <thead><tr>
                <th>Name</th><th>Species</th><th>Breed</th><th>Status</th><th>Owner</th><th>Pet ID</th>
              </tr></thead>
              <tbody>
                {data.pets.map((pet) => (
                  <tr key={pet.id}>
                    <td><strong>{pet.name}</strong></td>
                    <td>{speciesLabels[pet.species_group ?? pet.species] ?? pet.species}</td>
                    <td>{pet.breed || "—"}</td>
                    <td>{[
                      pet.is_active === true ? "Active" : pet.is_active === false ? "Inactive" : null,
                      pet.is_exotic ? "Exotic" : null,
                      pet.is_memorial ? "Memorial" : null,
                    ].filter(Boolean).join(" · ") || "—"}</td>
                    <td><Link className="table-action-link" href={`/users/${encodeURIComponent(pet.owner_id)}`}>{pet.owner_id}</Link></td>
                    <td><code>{pet.id}</code></td>
                  </tr>
                ))}
              </tbody>
            </table>
            {!data.pets.length && <p className="table-empty">No pets match the selected filters.</p>}
          </div>
          <nav className="users-pagination" aria-label="Pet pages">
            {data.page > 1 && <Link className="ghost-button" href={pageUrl(data.page - 1)}>Previous</Link>}
            <span>Page {data.page} of {Math.max(1, Math.ceil(data.total / data.page_size))}</span>
            {data.page * data.page_size < data.total && <Link className="ghost-button" href={pageUrl(data.page + 1)}>Next</Link>}
          </nav>
        </section>
      )}
    </AdminShell>
  );
}
