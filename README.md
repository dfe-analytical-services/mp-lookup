# MP lookup

Repository that contains an up to date lookup of MPs, their constituencies, and their party affiliations.

This is a quick stop-gap, long term this will hopefully be made available from a database within DfE for analysts to access.

## How to use

The look up file is available as a CSV file you can [view and download from the repository]().

If you want to use this programmatically (e.g. R or Python), you can use the raw URL:

```
https://raw.githubusercontent.com/dfe-analystical-services/mp-lookup/main/mp_lookup.csv
```

## Sources

The data is sourced from the [UK Parliament API](http://data.parliament.uk/membersdataplatform/default.aspx) and the [Open Geography Portal](https://geoportal.statistics.gov.uk/) using the following R packages:
- [mnis](https://docs.evanodell.com/mnis/)
- [dfeR](https://github.com/dfe-analytical-services/dfeR)

### Other related packages

Lookup files and boundary information over time can be found on the [Open Geography Portal](https://geoportal.statistics.gov.uk/).

[dfeR](https://github.com/dfe-analytical-services/dfeR) also provides a number of curated lookups for DfE analysts using R, including a [`get_ons_api_data()`](https://dfe-analytical-services.github.io/dfeR/reference/get_ons_api_data.html) API wrapper for programmatically accessing static files from the the [Open Geography Portal](https://geoportal.statistics.gov.uk/).

If you need anything else from the [Open Geography Portal](https://geoportal.statistics.gov.uk/), or a direct connection to the latest data look at using the [boundr](https://github.com/francisbarton/boundr) package.

## Updates

Updates are done automatically every Monday morning using GitHub Actions.

## Contact and requests

If you have any questions, or requests for additional data or changes to the existing data, please [raise an issue]() on this repository.