"""The countries the radar ("Servizi per animali") is built for.

One registry read by the offline importers (which Overture country code
and which OpenStreetMap areas to ask for), by the API (which country a
point is in, and whether its places are imported) and by the address
formatter. A country is added here and nowhere else.

The rectangles are deliberately coarse: they only decide which country's
import to look at. Near a border a point may fall in the wrong country's
rectangle (Dublin is inside the one of Great Britain); the radar then finds
no imported place around it and falls back to the live provider, exactly as
for a country it does not know (see ListNearbyRadarPlacesService).
"""

from dataclasses import dataclass

from packages.core.domain.geo.models import Coordinates


@dataclass(frozen=True)
class GeoBounds:
    min_latitude: float
    max_latitude: float
    min_longitude: float
    max_longitude: float

    def contains(self, point: Coordinates) -> bool:
        return (
            self.min_latitude <= point.latitude <= self.max_latitude
            and self.min_longitude <= point.longitude <= self.max_longitude
        )

    @property
    def area_square_degrees(self) -> float:
        return (self.max_latitude - self.min_latitude) * (self.max_longitude - self.min_longitude)


@dataclass(frozen=True)
class OsmRegion:
    """One OpenStreetMap area imported on its own: an ISO 3166-2 code
    (`area["ISO3166-2"="..."]` in Overpass) and its name for the logs."""

    code: str
    name: str


@dataclass(frozen=True)
class RadarCountry:
    code: str  # ISO 3166-1 alpha-2, the key of every table and the Overture filter
    name: str  # English; the app localizes its own labels
    flag: str
    language: str  # main language of place names and addresses
    bounds: tuple[GeoBounds, ...]
    regions: tuple[OsmRegion, ...]

    @property
    def nominatim_code(self) -> str:
        """Value of Nominatim's `countrycodes` parameter."""
        return self.code.lower()

    def contains(self, point: Coordinates) -> bool:
        return any(bounds.contains(point) for bounds in self.bounds)

    @property
    def area_square_degrees(self) -> float:
        return sum(bounds.area_square_degrees for bounds in self.bounds)

    @property
    def region_codes(self) -> tuple[str, ...]:
        return tuple(region.code for region in self.regions)


def _regions(*pairs: tuple[str, str]) -> tuple[OsmRegion, ...]:
    return tuple(OsmRegion(code, name) for code, name in pairs)


_ITALY = RadarCountry(
    code="IT",
    name="Italy",
    flag="🇮🇹",
    language="it",
    bounds=(GeoBounds(35.2, 47.2, 6.5, 18.8),),
    regions=_regions(
        ("IT-21", "Piemonte"),
        ("IT-23", "Valle d'Aosta"),
        ("IT-25", "Lombardia"),
        ("IT-32", "Trentino-Alto Adige"),
        ("IT-34", "Veneto"),
        ("IT-36", "Friuli-Venezia Giulia"),
        ("IT-42", "Liguria"),
        ("IT-45", "Emilia-Romagna"),
        ("IT-52", "Toscana"),
        ("IT-55", "Umbria"),
        ("IT-57", "Marche"),
        ("IT-62", "Lazio"),
        ("IT-65", "Abruzzo"),
        ("IT-67", "Molise"),
        ("IT-72", "Campania"),
        ("IT-75", "Puglia"),
        ("IT-77", "Basilicata"),
        ("IT-78", "Calabria"),
        ("IT-82", "Sicilia"),
        ("IT-88", "Sardegna"),
    ),
)

_UNITED_KINGDOM = RadarCountry(
    code="GB",
    name="United Kingdom",
    flag="🇬🇧",
    language="en",
    bounds=(GeoBounds(49.8, 60.9, -8.7, 1.85),),
    # The four nations. England is one big query: the importer falls back
    # to one category at a time when the whole area is refused.
    regions=_regions(
        ("GB-ENG", "England"),
        ("GB-SCT", "Scotland"),
        ("GB-WLS", "Wales"),
        ("GB-NIR", "Northern Ireland"),
    ),
)

_UNITED_STATES = RadarCountry(
    code="US",
    name="United States",
    flag="🇺🇸",
    language="en",
    bounds=(
        GeoBounds(24.3, 49.5, -125.0, -66.8),  # contiguous states
        GeoBounds(51.0, 71.5, -170.0, -129.9),  # Alaska
        GeoBounds(18.8, 22.4, -160.6, -154.7),  # Hawaii
    ),
    regions=_regions(
        ("US-AL", "Alabama"),
        ("US-AK", "Alaska"),
        ("US-AZ", "Arizona"),
        ("US-AR", "Arkansas"),
        ("US-CA", "California"),
        ("US-CO", "Colorado"),
        ("US-CT", "Connecticut"),
        ("US-DE", "Delaware"),
        ("US-DC", "District of Columbia"),
        ("US-FL", "Florida"),
        ("US-GA", "Georgia"),
        ("US-HI", "Hawaii"),
        ("US-ID", "Idaho"),
        ("US-IL", "Illinois"),
        ("US-IN", "Indiana"),
        ("US-IA", "Iowa"),
        ("US-KS", "Kansas"),
        ("US-KY", "Kentucky"),
        ("US-LA", "Louisiana"),
        ("US-ME", "Maine"),
        ("US-MD", "Maryland"),
        ("US-MA", "Massachusetts"),
        ("US-MI", "Michigan"),
        ("US-MN", "Minnesota"),
        ("US-MS", "Mississippi"),
        ("US-MO", "Missouri"),
        ("US-MT", "Montana"),
        ("US-NE", "Nebraska"),
        ("US-NV", "Nevada"),
        ("US-NH", "New Hampshire"),
        ("US-NJ", "New Jersey"),
        ("US-NM", "New Mexico"),
        ("US-NY", "New York"),
        ("US-NC", "North Carolina"),
        ("US-ND", "North Dakota"),
        ("US-OH", "Ohio"),
        ("US-OK", "Oklahoma"),
        ("US-OR", "Oregon"),
        ("US-PA", "Pennsylvania"),
        ("US-RI", "Rhode Island"),
        ("US-SC", "South Carolina"),
        ("US-SD", "South Dakota"),
        ("US-TN", "Tennessee"),
        ("US-TX", "Texas"),
        ("US-UT", "Utah"),
        ("US-VT", "Vermont"),
        ("US-VA", "Virginia"),
        ("US-WA", "Washington"),
        ("US-WV", "West Virginia"),
        ("US-WI", "Wisconsin"),
        ("US-WY", "Wyoming"),
    ),
)

_AUSTRALIA = RadarCountry(
    code="AU",
    name="Australia",
    flag="🇦🇺",
    language="en",
    bounds=(GeoBounds(-43.8, -9.0, 112.9, 153.7),),
    regions=_regions(
        ("AU-NSW", "New South Wales"),
        ("AU-VIC", "Victoria"),
        ("AU-QLD", "Queensland"),
        ("AU-WA", "Western Australia"),
        ("AU-SA", "South Australia"),
        ("AU-TAS", "Tasmania"),
        ("AU-ACT", "Australian Capital Territory"),
        ("AU-NT", "Northern Territory"),
    ),
)

_GERMANY = RadarCountry(
    code="DE",
    name="Germany",
    flag="🇩🇪",
    language="de",
    bounds=(GeoBounds(47.2, 55.1, 5.8, 15.1),),
    regions=_regions(
        ("DE-BW", "Baden-Württemberg"),
        ("DE-BY", "Bayern"),
        ("DE-BE", "Berlin"),
        ("DE-BB", "Brandenburg"),
        ("DE-HB", "Bremen"),
        ("DE-HH", "Hamburg"),
        ("DE-HE", "Hessen"),
        ("DE-MV", "Mecklenburg-Vorpommern"),
        ("DE-NI", "Niedersachsen"),
        ("DE-NW", "Nordrhein-Westfalen"),
        ("DE-RP", "Rheinland-Pfalz"),
        ("DE-SL", "Saarland"),
        ("DE-SN", "Sachsen"),
        ("DE-ST", "Sachsen-Anhalt"),
        ("DE-SH", "Schleswig-Holstein"),
        ("DE-TH", "Thüringen"),
    ),
)

_FRANCE = RadarCountry(
    code="FR",
    name="France",
    flag="🇫🇷",
    language="fr",
    # Metropolitan France and Corsica; overseas territories are left out.
    bounds=(GeoBounds(41.2, 51.2, -5.3, 9.7),),
    regions=_regions(
        ("FR-ARA", "Auvergne-Rhône-Alpes"),
        ("FR-BFC", "Bourgogne-Franche-Comté"),
        ("FR-BRE", "Bretagne"),
        ("FR-CVL", "Centre-Val de Loire"),
        ("FR-COR", "Corse"),
        ("FR-GES", "Grand Est"),
        ("FR-HDF", "Hauts-de-France"),
        ("FR-IDF", "Île-de-France"),
        ("FR-NOR", "Normandie"),
        ("FR-NAQ", "Nouvelle-Aquitaine"),
        ("FR-OCC", "Occitanie"),
        ("FR-PDL", "Pays de la Loire"),
        ("FR-PAC", "Provence-Alpes-Côte d'Azur"),
    ),
)

_SPAIN = RadarCountry(
    code="ES",
    name="Spain",
    flag="🇪🇸",
    language="es",
    bounds=(
        GeoBounds(35.8, 43.9, -9.5, 4.4),  # peninsula, Balearic Islands, Ceuta, Melilla
        GeoBounds(27.5, 29.5, -18.4, -13.3),  # Canary Islands
    ),
    regions=_regions(
        ("ES-AN", "Andalucía"),
        ("ES-AR", "Aragón"),
        ("ES-AS", "Asturias"),
        ("ES-IB", "Illes Balears"),
        ("ES-CN", "Canarias"),
        ("ES-CB", "Cantabria"),
        ("ES-CL", "Castilla y León"),
        ("ES-CM", "Castilla-La Mancha"),
        ("ES-CT", "Cataluña"),
        ("ES-CE", "Ceuta"),
        ("ES-EX", "Extremadura"),
        ("ES-GA", "Galicia"),
        ("ES-RI", "La Rioja"),
        ("ES-MD", "Madrid"),
        ("ES-ML", "Melilla"),
        ("ES-MC", "Murcia"),
        ("ES-NC", "Navarra"),
        ("ES-PV", "País Vasco"),
        ("ES-VC", "Comunitat Valenciana"),
    ),
)

# Italy first: it is the country the radar was built and measured on.
RADAR_COUNTRIES: tuple[RadarCountry, ...] = (
    _ITALY,
    _UNITED_KINGDOM,
    _UNITED_STATES,
    _AUSTRALIA,
    _GERMANY,
    _FRANCE,
    _SPAIN,
)

_BY_CODE = {country.code: country for country in RADAR_COUNTRIES}


def get_radar_country(code: str) -> RadarCountry | None:
    return _BY_CODE.get(code.strip().upper())


def radar_country_for_point(point: Coordinates) -> RadarCountry | None:
    """The supported country whose rectangle holds the point; the smallest
    one when rectangles overlap. None outside every supported country."""
    candidates = [country for country in RADAR_COUNTRIES if country.contains(point)]
    return min(candidates, key=lambda country: country.area_square_degrees, default=None)
