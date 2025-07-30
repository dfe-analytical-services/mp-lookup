# Function to extract member id and member email address from the mnis base
# output
# To be used with mnis base output list and apply(..., 2, extract_email)
extract_email <- function(mnis_base_output_line) {
  member_id <- mnis_base_output_line |>
    magrittr::extract2("@Member_Id")
  member_emails <- mnis_base_output_line |>
    magrittr::extract2("Addresses.Address") |>
    magrittr::extract2("Email")
  # Remove NAs, trim spaces, switch to lower case and remove duplicates
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
