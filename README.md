# MP lookup <a href="https://dfe-analytical-services.github.io/mp-lookup/"><img src="images/mp-lookup-frederick.png" align="right" height="120" alt="MP-lookup user guide" /></a>

Repository that contains an up to date lookup of MPs, their constituencies, and their party affiliations.

This is a quick stop-gap, long term this will hopefully be made available from a database within DfE for analysts to access.

## How to use

The look up file is available as a CSV file you can [view and download from the repository](https://github.com/dfe-analytical-services/mp-lookup/blob/main/mp_lookup.csv). There's a [user guide available as a webpage](https://dfe-analytical-services.github.io/mp-lookup/), and a [user guide as a downloadable PDF](https://github.com/dfe-analytical-services/mp-lookup/blob/main/user-guide.pdf) to assist you in getting what you need from the lookup file.

If you want to use this lookup programmatically (e.g. R or Python), you can use the raw URL:

```         
https://raw.githubusercontent.com/dfe-analytical-services/mp-lookup/refs/heads/main/mp_lookup.csv
```

Though given the concatenated format of the location codes, we'd suggest anyone using code looks through `R/data_update.R` and the source packages. Particularly if you are wanting a location hierarchy, you should use the [dfeR package](https://github.com/dfe-analytical-services/dfeR) directly.

### Development dependencies

All packages used in this repo are based on the latest versions available, currently there is no package management in place.

To install the packages needed to run the code in this repository, run the commands that are used in the `.github/workflows/run_data_update.yaml` file.

## Sources

The MP data is sourced from the [UK Parliament API](http://data.parliament.uk/membersdataplatform/default.aspx) and the [Open Geography Portal](https://geoportal.statistics.gov.uk/) using the following R packages:

-   [mnis](https://docs.evanodell.com/mnis/)

-   [dfeR](https://github.com/dfe-analytical-services/dfeR)

The election results data is sourced from the 'candidate-level general election result data' CSV file from the [UK Parliament election results page](https://electionresults.parliament.uk/general-elections/6/political-parties).

### Other related packages

Lookup files and boundary information over time can be found on the [Open Geography Portal](https://geoportal.statistics.gov.uk/).

[dfeR](https://github.com/dfe-analytical-services/dfeR) also provides a number of curated lookups for DfE analysts using R, including a [`get_ons_api_data()`](https://dfe-analytical-services.github.io/dfeR/reference/get_ons_api_data.html) API wrapper for programmatically accessing static files from the the [Open Geography Portal](https://geoportal.statistics.gov.uk/).

If you need anything else from the [Open Geography Portal](https://geoportal.statistics.gov.uk/), or a direct connection to the latest data look at using the [boundr](https://github.com/francisbarton/boundr) package.

## Updates

Updates about MPs are done automatically every morning using GitHub Actions, these check for any changes in the MP data, and will overwrite the file with a newer version if there are.

Location updates will come through the [dfeR package](https://github.com/dfe-analytical-services/dfeR), as new boundaries are released on the [Open Geography Portal](https://geoportal.statistics.gov.uk/).

Election results data is updated manually from the Parliament website.

## Documentation

The documentation is maintained in this README (largely aimed at maintainers) and 
[user-guide.qmd](user-guide.qmd) (aimed at end users).

The user guide is kept as both a pdf and html version, with the html version 
being published to [GitHub pages](https://dfe-analytical-services.github.io/mp-lookup/) 
via an [automated workflow](.github/workflows/github-pages.yaml).

If a manual deploy of the user guide to GitHub pages is ever required, this can 
be done using the following command in the Bash terminal:

``` {sh, eval=FALSE}
quarto publish gh-pages user-guide.qmd
```

Updating the pdf is performed manually using the command:

``` {r, eval=FALSE}
quarto::quarto_render(
   "user-guide.qmd",
   output_format = "pdf",
   metadata = list(
      papersize = "A4",
      format = list(
         pdf = list(
            toc = TRUE, 
            `number-sections` = TRUE,
            mainfont = "Arial"
         )
      )
   )
)
```

## Contact and requests

If you have any questions, or requests for additional data or changes to the existing data, please [raise an issue](https://github.com/dfe-analytical-services/mp-lookup/issues/new/choose) on this repository.
