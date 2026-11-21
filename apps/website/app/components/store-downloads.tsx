type Store = {
  name: string;
  platform: "ios" | "android";
  url: string | null;
};

export function StoreDownloads({
  ios,
  android,
}: {
  ios: string | null;
  android: string | null;
}) {
  const stores: Store[] = [
    { name: "App Store", platform: "ios", url: ios },
    { name: "Google Play", platform: "android", url: android },
  ];
  return (
    <div className="store-downloads">
      <div className="store-buttons" aria-label="Scarica Quokka dagli store">
        {stores.map((store) => {
          const content = (
            <>
              <StoreIcon platform={store.platform} />
              <span>
                <small>Scarica su</small>
                <strong>{store.name}</strong>
              </span>
            </>
          );
          return store.url ? (
            <a
              className="store-button"
              href={store.url}
              key={store.platform}
              aria-label={`Scarica Quokka da ${store.name}`}
            >
              {content}
            </a>
          ) : (
            <button
              className="store-button"
              type="button"
              disabled
              key={store.platform}
              aria-label={`${store.name}: collegamento disponibile a breve`}
            >
              {content}
            </button>
          );
        })}
      </div>
      {(!ios || !android) && (
        <p className="store-note">
          I collegamenti per il download saranno disponibili a breve.
        </p>
      )}
    </div>
  );
}

function StoreIcon({ platform }: { platform: Store["platform"] }) {
  return platform === "ios" ? (
    <svg viewBox="0 0 24 28" fill="currentColor" aria-hidden="true">
      <path d="M16.5 4.5c1.1-1.3 1.7-2.9 1.6-4.5-1.6.1-3.4 1.1-4.5 2.4-1 1.1-1.8 2.8-1.6 4.3 1.8.1 3.4-.9 4.5-2.2ZM21.8 21c-.6 1.4-.9 2-1.7 3.3-1.1 1.7-2.6 3.8-4.5 3.7-1.7 0-2.1-1.1-4.4-1.1-2.2 0-2.7 1.1-4.4 1.1-1.9.1-3.3-1.8-4.4-3.5C-.7 19.8-.9 13.4 1 10.5 2.4 8.4 4.5 7.2 6.5 7.2c2.1 0 3.4 1.1 5.1 1.1 1.6 0 2.6-1.1 5-1.1 1.8 0 3.6 1 5 2.6-4.4 2.4-3.7 8.5.2 11.2Z" />
    </svg>
  ) : (
    <svg viewBox="0 0 26 28" fill="none" aria-hidden="true">
      <path d="M2 2 16 14 2 26Z" fill="currentColor" />
      <path d="m4 1 17 10-4 2Z" fill="currentColor" opacity=".65" />
      <path d="m4 27 17-10-4-2Z" fill="currentColor" opacity=".65" />
      <path d="m18 14 5-3 3 3-3 3Z" fill="currentColor" opacity=".85" />
    </svg>
  );
}
