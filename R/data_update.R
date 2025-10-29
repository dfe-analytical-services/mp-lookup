library(mnis) # installed from GitHub
library(dfeR) # installed from GitHub
library(dplyr)
library(tidyr)
library(stringr)
library(testthat)

source("R/utils.R")

# Create lookup ===============================================================
mp_lookup <- dfeR::fetch_pcons(2024, "All") |>
  # Adding a country column to the lookup as it contains multiple countries
  dplyr::mutate(country = case_when(
    startsWith(pcon_code, "E") ~ "England",
    startsWith(pcon_code, "N") ~ "Northern Ireland",
    startsWith(pcon_code, "S") ~ "Scotland",
    startsWith(pcon_code, "W") ~ "Wales"),
    # setting case to lower case as case sensitivity is becoming an issue
    pcon_name_lower = tolower(pcon_name)) |>
  dplyr::left_join(
    mnis::mnis_mps_on_date() |>
      dplyr::select(
        member_id,
        full_title,
        display_as,
        member_from,
        party_text
      ) |>
      dplyr::mutate(
        # Renaming Welsh LAs by adding accents, matching names in fetch_pcons()
        member_from = if_else(
          member_from == "Ynys Mon",
          "Ynys Môn", member_from),
        member_from = if_else(
          member_from == "Montgomeryshire and Glyndwr",
          "Montgomeryshire and Glyndŵr", member_from),
        # setting case to lower case as case sensitivity is becoming an issue
        member_from = tolower(member_from)),
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
  "data/candidate-level-results-general-election-04-07-2024.csv"
) |>
  # Clean column names to snake case
  janitor::clean_names() |>
  # Create a column to standardise constituency names so the join works without
  dplyr::mutate(
    # setting case to lower case as case sensitivity is becoming an issue
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
  dplyr::filter(most_recent_year_included == 2025) |>
  dplyr::group_by(pcon_code) |>
  dplyr::arrange(lad_code) |>
  dplyr::summarise(
    lad_names = paste(unique(lad_name), collapse = " / "),
    lad_codes = paste(unique(lad_code), collapse = " / ")
  )

legacy24_lad_summary <- dfeR::fetch_lads(2024) |>
  dplyr::arrange(lad_code) |>
  dplyr::left_join(
    dfeR::geo_hierarchy |>
      dplyr::filter(most_recent_year_included > 2024) |>
      dplyr::select(pcon_code, lad_name),
    by = "lad_name"
  ) |>
  dplyr::group_by(pcon_code) |>
  dplyr::summarise(
    lad_codes_2024 = paste(unique(lad_code), collapse = " / ")
  )

mp_lookup <- mp_lookup |>
  dplyr::left_join(lad_summary, by = "pcon_code") |>
  dplyr::left_join(legacy24_lad_summary, by = "pcon_code")

# Add on LAs ==================================================================
la_summary <- dfeR::geo_hierarchy |>
  dplyr::filter(most_recent_year_included == 2025) |>
  dplyr::group_by(pcon_code) |>
  dplyr::arrange(new_la_code) |>
  dplyr::summarise(
    la_names = paste(unique(la_name), collapse = " / "),
    new_la_codes = paste(unique(new_la_code), collapse = " / ")
  )

legacy24_la_summary <- dfeR::fetch_las(2024) |>
  dplyr::arrange(new_la_code) |>
  dplyr::left_join(
    dfeR::geo_hierarchy |>
      dplyr::filter(most_recent_year_included > 2024) |>
      dplyr::distinct(pcon_code, la_name),
    by = "la_name"
  ) |>
  dplyr::group_by(pcon_code) |>
  dplyr::summarise(
    new_la_codes_2024 = paste(unique(new_la_code), collapse = " / "),
    old_la_codes_2024 = paste(unique(old_la_code), collapse = " / ")
  )

mp_lookup <- mp_lookup |>
  dplyr::left_join(la_summary, by = "pcon_code") |>
  dplyr::left_join(legacy24_la_summary, by = "pcon_code")

# Add on Mayoral Authorities ==================================================
mayoral_summary <- dfeR::geo_hierarchy |>
  dplyr::group_by(pcon_code) |>
  dplyr::arrange(english_devolved_area_code) |>
  dplyr::filter(english_devolved_area_name != "Not applicable") |> # add back in later to avoid
  # ...unnecessary "Not applicable" entries in the concatenated strings
  dplyr::summarise(
    mayoral_auth_names = paste(
      unique(english_devolved_area_name),
      collapse = " / "
    ),
    mayoral_auth_codes = paste(
      unique(english_devolved_area_code),
      collapse = " / "
    )
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
  "member_id",
  "full_title",
  "display_as",
  "party_text",
  "member_email",
  "election_result_summary_2024",
  "lad_names",
  "lad_codes",
  "lad_codes_2024",
  "la_names",
  "new_la_codes",
  "new_la_codes_2024",
  "old_la_codes_2024",
  "mayoral_auth_names",
  "mayoral_auth_codes"
)

test_that("mp_lookup has expected columns", {
  expect_equal(names(mp_lookup), expected_cols)
})

test_that("mp_lookup has no missing values in columns", {
  for (col in expected_cols) {
    expect_false(any(is.na(mp_lookup[[col]])))
    expect_false(any(mp_lookup[[col]] == ""))
  }
})

test_that("No duplicates in key cols", {
  for (col in c("pcon_name", "pcon_code", "display_as", "member_id")) {
    expect_equal(length(unique(mp_lookup[[col]])), nrow(mp_lookup))
  }
})

test_that("All email addresses either contain '@' or are 'No email found'", {
  expect_true(all(
    grepl("@", mp_lookup$member_email) |
      mp_lookup$member_email == "No email found"
  ))
})

test_that("There are 543 rows", {
  # Same number as we know from dfeR pcons
  expect_true(nrow(mp_lookup) == 543)
})

test_that("There are 543 unique constituencies", {
  expect_true(length(unique(mp_lookup$pcon_name)) == 543)
  expect_true(length(unique(mp_lookup$pcon_code)) == 543)
})

test_that("There are 75 PCons in GLA", {
  expect_true(
    mp_lookup |>
      dplyr::filter(mayoral_auth_names == "Greater London Authority") |>
      nrow() ==
      75
  )
})

test_that("All codes follow expected pattern", {
  expect_true(all(grepl("^[A-Za-z0-9]{9}$", mp_lookup$pcon_code)))

  main_code_pattern <- "^([A-Za-z0-9]{9}|z)( / ([A-Za-z0-9]{9}|z))*$"
  for (col in c(
    "lad_codes",
    "lad_codes_2024",
    "new_la_codes",
    "new_la_codes_2024",
    "mayoral_auth_codes"
  )) {
    expect_true(all(grepl(main_code_pattern, mp_lookup[[col]])))
  }

  three_digit_pattern <- "^([0-9]{3}|z)( / ([0-9]{3}|z))*$"
  expect_true(all(grepl(three_digit_pattern, mp_lookup$old_la_codes_2024)))
})

test_that("All constituency names are within the dfeR pcons", {
  dfeR_pcons <- dfeR::fetch_pcons(2024, "England")$pcon_name
  expect_true(all(mp_lookup$pcon_name %in% dfeR_pcons))
})

test_that("All pcon codes are within the dfeR pcons", {
  dfeR_pcons <- dfeR::fetch_pcons(2024, "England")$pcon_code
  expect_true(all(mp_lookup$pcon_code %in% dfeR_pcons))
})

# Write to CSV ================================================================
write.csv(
  mp_lookup,
  file = "mp_lookup.csv",
  row.names = FALSE
)
