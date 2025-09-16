library(mnis)
library(dfeR)
library(dplyr)
library(tidyr)
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
  #create a column to standardise constituency names so the join works without
  #case sensitivity becoming an issue
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
  #create a column to standardise constituency names so the join works without
  #case sensitivity becoming an issue
  dplyr::mutate(
    pcon_name_join = tolower(pcon_name)
  ) |>
  # Join with election results
  dplyr::left_join(election_results, by = c("pcon_code", "pcon_name_join")) |>
  # Remove duplicates
  dplyr::distinct() |>
  #unselect pcon_name_join
  dplyr::select(-pcon_name_join)

# Add on LADs =================================================================

# Add on LAs ==================================================================

# Add on Mayoral Authorities ==================================================

# QA ==========================================================================
test_that("mp_lookup has expected columns", {
  expect_true(all(
    c(
      "pcon_code",
      "pcon_name",
      "full_title",
      "display_as",
      "party_text",
      "member_email",
      "election_result_summary_2024"
    ) %in%
      colnames(mp_lookup)
  ))
})

test_that("mp_lookup has no missing values in key columns", {
  expect_true(all(!is.na(mp_lookup$pcon_code)))
  expect_true(all(!is.na(mp_lookup$pcon_name)))
  expect_true(all(!is.na(mp_lookup$full_title)))
  expect_true(all(!is.na(mp_lookup$display_as)))
  expect_true(all(!is.na(mp_lookup$party_text)))
  expect_true(all(!is.na(mp_lookup$member_email)))
  expect_true(all(!is.na(mp_lookup$election_result_summary_2024)))
})

test_that("No duplicate rows", {
  expect_true(nrow(mp_lookup) == nrow(dplyr::distinct(mp_lookup)))
})

test_that("There are 543 rows", {
  # same number as we know from dfeR pcons
  expect_true(nrow(mp_lookup) == 543)
})

# Write to CSV ================================================================
write.csv(
  mp_lookup,
  file = "mp_lookup.csv",
  row.names = FALSE
)
