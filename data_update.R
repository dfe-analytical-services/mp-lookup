library(mnis)
library(dfeR)
library(dplyr)
library(tidyr)
library(testthat)

# Create lookup ===============================================================
mp_lookup <- dfeR::fetch_pcons(2024, "England") |>
  dplyr::mutate(pcon_name_lower = tolower(pcon_name)) |>
  dplyr::left_join(
    mnis::mnis_mps_on_date() |>
      dplyr::select(full_title, display_as, member_from, party_text) |>
      dplyr::mutate(member_from = tolower(member_from)),
    by = c("pcon_name_lower" = "member_from")
  ) |>
  dplyr::mutate(
    dplyr::across(
      c(full_title, display_as, party_text),
      ~ tidyr::replace_na(.x, "Vacant")
    )
  ) |>
  dplyr::select(-pcon_name_lower)

# QA ==========================================================================
test_that("mp_lookup has expected columns", {
  expect_true(all(
    c("pcon_code", "pcon_name", "full_title", "display_as", "party_text") %in%
      colnames(mp_lookup)
  ))
})

test_that("mp_lookup has no missing values in key columns", {
  expect_true(all(!is.na(mp_lookup$pcon_code)))
  expect_true(all(!is.na(mp_lookup$pcon_name)))
  expect_true(all(!is.na(mp_lookup$full_title)))
  expect_true(all(!is.na(mp_lookup$display_as)))
  expect_true(all(!is.na(mp_lookup$party_text)))
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
