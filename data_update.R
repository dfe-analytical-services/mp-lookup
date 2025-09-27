library(mnis) # installed from GitHub
library(dfeR) # installed from GitHub
library(dplyr)
library(tidyr)
library(stringr)
library(testthat)

source("R/utils.R")

# Create lookup ===============================================================
mp_lookup <- dfeR::fetch_pcons(2024, "England") |>
  dplyr::mutate(pcon_name_lower = tolower(pcon_name)) |>
  dplyr::left_join(
    mnis::mnis_mps_on_date() |>
      dplyr::select(
        member_id,
        full_title,
        display_as,
        member_from,
        party_text
      ) |>
      dplyr::mutate(member_from = tolower(member_from)),
    by = c("pcon_name_lower" = "member_from")
  )
# Add on e-mail addresses =====================================================
address_list <- mnis_base("House=Commons|IsEligible=true/Addresses") |>
  apply(2, extract_email, simplify = TRUE)
addresses <- data.frame(matrix(
  unlist(address_list),
  nrow = length(address_list),
  byrow = TRUE
))
names(addresses) <- c("member_id", "member_email")

mp_lookup <- mp_lookup |>
  left_join(addresses, by = "member_id")

mp_lookup <- mp_lookup |>
  dplyr::mutate(
    dplyr::across(
      c(full_title, display_as, party_text),
      ~ tidyr::replace_na(.x, "Vacant")
    )
  ) |>
  dplyr::select(-pcon_name_lower, member_id)

# Read in election results and add them on ====================================
election_results <- read.csv(
  "candidate-level-results-general-election-04-07-2024.csv"
) |>
  # Clean column names to snake case
  janitor::clean_names() |>
  # Create a column to standardise constituency names so the join works without
  # case sensitivity becoming an issue
  dplyr::mutate(
    constituency_name = tolower(constituency_name)
  ) |>
  # Select relevant columns
  dplyr::select(
    pcon_code = constituency_geographic_code,
    pcon_name_join = constituency_name,
    election_result_summary_2024 = election_result_summary
  )

# join the data
mp_lookup <- mp_lookup |>
  # Create a column to standardise constituency names so the join works without
  # case sensitivity becoming an issue
  dplyr::mutate(
    pcon_name_join = tolower(pcon_name)
  ) |>
  # Join with election results
  dplyr::left_join(election_results, by = c("pcon_code", "pcon_name_join")) |>
  # Remove duplicates
  dplyr::distinct() |>
  # unselect pcon_name_join
  dplyr::select(-pcon_name_join)

# Add on LADs =================================================================
lad_summary <- dfeR::geo_hierarchy |>
  dplyr::group_by(pcon_code) |>
  dplyr::arrange(lad_code) |>
  dplyr::summarise(
    lad_names = paste(unique(lad_name), collapse = " / "),
    lad_codes = paste(unique(lad_code), collapse = " / ")
  )

mp_lookup <- mp_lookup |>
  dplyr::left_join(lad_summary, by = "pcon_code")

# Add on LAs ==================================================================
la_summary <- dfeR::geo_hierarchy |>
  dplyr::group_by(pcon_code) |>
  dplyr::arrange(new_la_code) |>
  dplyr::summarise(
    la_names = paste(unique(la_name), collapse = " / "),
    old_la_codes = paste(unique(old_la_code), collapse = " / "),
    new_la_codes = paste(unique(new_la_code), collapse = " / ")
  ) |>
  # strip out " / z" from old_la_codes (as GIAS doesn't yet have 2025)
  dplyr::mutate(
    old_la_codes = gsub(" / z$", "", old_la_codes)
  )

mp_lookup <- mp_lookup |>
  dplyr::left_join(la_summary, by = "pcon_code")

# Add on Mayoral Authorities ==================================================
mayoral_summary <- dfeR::geo_hierarchy |>
  dplyr::group_by(pcon_code) |>
  dplyr::arrange(cauth_code) |>
  # Add in GLA based on LAD being London borough
  dplyr::mutate(
    cauth_name = dplyr::if_else(
      stringr::str_starts(lad_code, "E090"),
      "Greater London Authority",
      cauth_name
    ),
    cauth_code = dplyr::if_else(
      stringr::str_starts(lad_code, "E090"),
      "E61000001",
      cauth_code
    )
  ) |>
  dplyr::filter(cauth_name != "Not applicable") |> # add back in later to avoid
  # ...unnecessary "Not applicable" entries in the concatenated strings
  dplyr::summarise(
    mayoral_auth_names = paste(unique(cauth_name), collapse = " / "),
    mayoral_auth_codes = paste(unique(cauth_code), collapse = " / ")
  )

mp_lookup <- mp_lookup |>
  dplyr::left_join(mayoral_summary, by = "pcon_code") |>
  dplyr::mutate(
    mayoral_auth_names = dplyr::if_else(
      is.na(mayoral_auth_names),
      "Not applicable",
      mayoral_auth_names
    ),
    mayoral_auth_codes = dplyr::if_else(
      is.na(mayoral_auth_codes),
      "z",
      mayoral_auth_codes
    )
  )

# Set a consistent order ======================================================
mp_lookup <- dplyr::arrange(mp_lookup, pcon_code)

# QA ==========================================================================
expected_cols <- c(
  "pcon_code",
  "pcon_name",
  "full_title",
  "display_as",
  "party_text",
  "member_email",
  "election_result_summary_2024",
  "lad_names",
  "lad_codes",
  "la_names",
  "new_la_codes",
  "old_la_codes",
  "mayoral_auth_names",
  "mayoral_auth_codes"
)

test_that("mp_lookup has expected columns", {
  expect_setequal(
    colnames(mp_lookup),
    union(colnames(mp_lookup), expected_cols)
  )
})

test_that("mp_lookup has no missing values in key columns", {
  expect_false(any(is.na(mp_lookup[expected_cols])))
})

test_that("No duplicate rows", {
  expect_true(nrow(mp_lookup) == nrow(dplyr::distinct(mp_lookup)))
})

test_that("There are 543 rows", {
  # same number as we know from dfeR pcons
  expect_true(nrow(mp_lookup) == 543)
})

test_that("There are 75 PCons in GLA", {
  # same number as we know from dfeR pcons
  expect_true(
    mp_lookup |>
      dplyr::filter(mayoral_auth_names == "Greater London Authority") |>
      nrow() ==
      75
  )
})

# Write to CSV ================================================================
write.csv(
  mp_lookup,
  file = "mp_lookup.csv",
  row.names = FALSE
)
