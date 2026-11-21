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
  searchParams: Promise<{ q?: string; page?: string; species?: string; status?: string; country?: string; region?: string }>;
}) {
  const params = await searchParams;
  const q = (params.q ?? "").slice(0, 200);
  const species = speciesOptions.some(([key]) => key === params.species) ? params.species! : "";
  const status = ["active", "inactive", "exotic", "memorial"].includes(params.status ?? "")
    ? params.status! : "";
  const country = (params.country ?? "").slice(0, 2).toUpperCase();
  const region = (params.region ?? "").slice(0, 200);
  const parsedPage = Number(params.page);
  const page = Number.isInteger(parsedPage) && parsedPage > 0 ? Math.min(parsedPage, 2000) : 1;
  const data = await getAdminPets(q, page, species, status, country, region);
  const pageUrl = (target: number) =>
    `/pets?${new URLSearchParams({ q, species, status, country, region, page: String(target) })}`;

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
          <form id="pet-table-filters" action="/pets" />
          <div className="pets-filter-actions">
            <button className="ghost-button" type="submit" form="pet-table-filters">Apply filters</button>
            <Link className="ghost-button" href="/pets">Clear</Link>
          </div>
          <div className="pets-table-scroll">
            <table className="users-table">
              <thead><tr>
                <th>Name<input aria-label="Filter by pet name or ID" form="pet-table-filters" type="search" name="q" defaultValue={q} placeholder="Search name / ID" /></th>
                <th>Species<select aria-label="Filter species" form="pet-table-filters" name="species" defaultValue={species}><option value="">All</option>{speciesOptions.map(([key, label]) => <option key={key} value={key}>{label}</option>)}</select></th>
                <th>Breed</th>
                <th>Status<select aria-label="Filter status" form="pet-table-filters" name="status" defaultValue={status}><option value="">All</option><option value="active">Active</option><option value="inactive">Inactive</option><option value="exotic">Exotic</option><option value="memorial">Memorial</option></select></th>
                <th>Country<input aria-label="Filter country" form="pet-table-filters" name="country" maxLength={2} defaultValue={country} placeholder="ISO code" /></th>
                <th>Region / city<input aria-label="Filter locality" form="pet-table-filters" name="region" maxLength={200} defaultValue={region} placeholder="City" /></th>
                <th>Owner</th><th>Pet ID</th>
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
                    <td>{pet.country || "—"}</td>
                    <td>{pet.region || pet.city || "—"}</td>
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
