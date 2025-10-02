# extract_betsi.py
import time
import pandas as pd
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from webdriver_manager.chrome import ChromeDriverManager


# 1) --- which traits do you want? --------------------------------------------
TRAITS = [
    "Body length", "Body length / width ratio", "Body mass",
    # … add as many as you want. The label must match the one shown on the page
]


# 2) --- helper utilities ------------------------------------------------------
def make_driver(*, headless: bool = False) -> webdriver.Chrome:
    opts = Options()
    if headless:
        # headless-new is less flaky than the legacy flag
        opts.add_argument("--headless=new")
    opts.add_argument("--window-size=1920,1080")      # makes elements visible
    opts.add_argument("--disable-gpu")
    opts.add_argument("--no-sandbox")
    # the next flag prevents the “DevToolsActivePort” crash on some systems
    opts.add_argument("--remote-allow-origins=*")

    service = Service(ChromeDriverManager().install())
    return webdriver.Chrome(service=service, options=opts)


def wait_click(driver, xpath, timeout=20):
    """Wait for an element to be clickable, then click it."""
    elem = WebDriverWait(driver, timeout).until(
        EC.element_to_be_clickable((By.XPATH, xpath))
    )
    elem.click()
    return elem


def scrape_group(driver, group_label: str) -> pd.DataFrame:
    driver.get("https://portail.betsi.cnrs.fr/request-traits")

    # cookie banner sometimes appears – try to close it and ignore any failure
    try:
        wait_click(driver, "//button[contains(.,'Accept')]", timeout=5)
    except Exception:
        pass

    # ------------- choose the taxon group ------------------------------------
    wait_click(driver, f"//label[contains(.,'{group_label}')]/input")

    all_parts = []

    for trait in TRAITS:
        print(f"▶  Trait: {trait}")

        # de-select the previously ticked trait (if any)
        try:
            wait_click(driver, "//label[contains(@class,'selected')]/input", 2)
        except Exception:
            pass

        # select the next trait
        wait_click(driver, f"//label[contains(.,'{trait}')]/input")

        # run the query
        wait_click(driver, "//button[contains(.,'Run request')]")

        # wait for the results table to be injected
        WebDriverWait(driver, 30).until(
            EC.visibility_of_element_located(
                (By.CSS_SELECTOR, "#results-table tbody tr"))
        )

        rows = driver.find_elements(By.CSS_SELECTOR, "#results-table tbody tr")
        # first row is the header
        header = [c.text for c in rows[0].find_elements(By.TAG_NAME, "th")]
        data = [[c.text for c in r.find_elements(By.TAG_NAME, "td")]
                for r in rows[1:]]

        if data:                                 # skip empty results
            df = pd.DataFrame(data, columns=header)
            df["trait_name"] = trait
            all_parts.append(df)

        # give the server a breather – polite scraping ☺
        time.sleep(1.0)

    if not all_parts:
        raise RuntimeError("No data were downloaded – check trait labels!")

    return pd.concat(all_parts, ignore_index=True)


# 3) --- main driver -----------------------------------------------------------
def main():
    driver = make_driver(headless=False)          # switch to True once stable
    try:
        big_df = scrape_group(driver, "Arthropoda (all)")
        big_df.to_csv("betsi_arthropoda_traits.csv", index=False,
                      encoding="utf-8")
        print("\nSaved → betsi_arthropoda_traits.csv "
              f"({len(big_df):,} rows)")
    finally:
        driver.quit()


if __name__ == "__main__":
    main()
