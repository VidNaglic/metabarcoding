"""
resolve_collembola_codes.py
──────────────────────────
Usage:
    python resolve_collembola_codes.py "Collembola_data_landuses (1).xlsx"
The script will create `collembola_name_resolution.csv`
in the same directory.

Requires: pandas, requests, tqdm  (pip install pandas requests tqdm)
"""

import sys, time, pathlib, re, requests, pandas as pd
from tqdm import tqdm

# ------------------------------------------------------------
# 1. --- load the file and grab the codes --------------------
# ------------------------------------------------------------
xlsx_path = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else
                         "Collembola_data_landuses (1).xlsx")

df_trait = pd.read_excel(xlsx_path, sheet_name="trait")

# the column that holds the codes is usually called either
# 'species', 'sp', or similar.  Detect it automatically:
code_col = next(col for col in df_trait.columns
                if re.fullmatch(r'sp(ecies)?$', col, flags=re.I))

codes = df_trait[code_col].dropna().unique()

# ------------------------------------------------------------
# 2. --- helper that queries GBIF and interprets the result ---
# ------------------------------------------------------------
GBIF_SEARCH = "https://api.gbif.org/v1/species/search"

def best_match_for_code(code, min_conf=60):
    """
    Try to turn something like 'BRA_PAR' into a full binomial.
    Returns (scientific_name|None, gbif_key|None, confidence, note)
    """
    # split the code  (e.g. BRA_PAR -> BRA , PAR)
    m = re.match(r"([A-Z]{3})_([A-Z]{3})", code.upper())
    if not m:
        return (None, None, 0, "pattern-mismatch")

    gen_abbr, sp_abbr = m.groups()

    # build a broad query:   "bra* par* collembola"
    q = f"{gen_abbr.lower()}* {sp_abbr.lower()}* Collembola"

    try:
        resp = requests.get(GBIF_SEARCH,
                            params={"q": q,
                                    "rank": "SPECIES",
                                    "limit": 50})
        resp.raise_for_status()
    except Exception as e:
        return (None, None, 0, f"request-error:{e}")

    # Pick the *first* result that:
    #   • belongs to Collembola
    #   • genus & epithet start with our abbreviations
    #   • has reasonable confidence
    for r in resp.json().get("results", []):
        genus   = r.get("genus", "")
        epithet = r.get("specificEpithet", "")
        conf    = r.get("confidence", 0)

        if (r.get("class") == "Collembola" and
            genus.lower().startswith(gen_abbr.lower()) and
            epithet.lower().startswith(sp_abbr.lower()) and
            conf >= min_conf):
            return (r["scientificName"], r["key"], conf, "ok")

    # nothing that satisfies all filters – keep highest-conf as hint
    fallback = max(resp.json().get("results", []),
                   key=lambda r: r.get("confidence", 0),
                   default=None)
    if fallback:
        return (fallback.get("scientificName"),
                fallback.get("key"),
                fallback.get("confidence", 0),
                "low-conf")
    return (None, None, 0, "no-match")

# ------------------------------------------------------------
# 3. --- resolve all codes -----------------------------------
# ------------------------------------------------------------
records = []
for code in tqdm(codes, desc="resolving"):
    sciname, key, conf, note = best_match_for_code(code)
    records.append(dict(code=code,
                        scientificName=sciname,
                        gbifKey=key,
                        confidence=conf,
                        note=note))

out = pd.DataFrame(records)

# ------------------------------------------------------------
# 4. --- write the result & show a tiny report ---------------
# ------------------------------------------------------------
out_path = xlsx_path.with_name("collembola_name_resolution.csv")
out.to_csv(out_path, index=False)

n_total = len(out)
n_ok    = (out["note"] == "ok").sum()
print(f"\nFinished: {n_ok}/{n_total} codes matched with ≥60 % confidence.")
print(f"Results written to →  {out_path.resolve()}")
