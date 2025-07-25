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


# QA ==========================================================================
test_that("mp_lookup has expected columns", {
  expect_true(all(
    c(
      "pcon_code",
      "pcon_name",
      "full_title",
      "display_as",
      "party_text",
      "member_email"
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

# Function to extract member id and member email address from the mnis base
# output
# To be used with mnis base output list and apply(..., 2, extract_email)
extract_email <- function(mnis_base_output_line) {
  member_id <- mnis_base_output_line |>
    magrittr::extract2("@Member_Id")
  member_emails <- mnis_base_output_line |>
    magrittr::extract2("Addresses.Address") |>
    magrittr::extract2("Email")
  member_emails <- member_emails[!is.na(member_emails)] |>
    stringr::str_trim() |>
    tolower() |>
    unique()
  # Choose a preferred email in the case of multiple and "No email found" in the
  # case of a NULL result
  if (any(grepl("mp@parliament.uk", member_emails))) {
    member_email <- member_emails[grepl("mp@parliament.uk", member_emails)][1]
  } else if (any(grepl("parliament.uk", member_emails))) {
    member_email <- member_emails[grepl("parliament.uk", member_emails)][1]
  } else if (length(member_emails) > 1) {
    member_email <- member_emails[1]
  } else if (length(member_emails) == 0) {
    member_email <- "No email found"
    warning("No email found for member_id: ", member_id)
  } else {
    member_email <- member_emails
  }
  return(list(member_id = member_id, member_email = member_email))
}
