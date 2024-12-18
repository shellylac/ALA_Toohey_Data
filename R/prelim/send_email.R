library(blastula)
library(keyring)

send_email_function <- function(log_file){
  # Create a simple email body
email <- compose_email(
  body = md("Here is this week's log file for the ALA occurrence data update")
)

# Check if the file exists
if (!file.exists(log_file)) {
  stop("The log file does not exist. Please check the path and file name.")
}

# SMTP credentials
smtp_creds <- blastula::smtp_send(
  email = email,
  from = "xxxx@gmail.com", # Replace with your email
  to = "xxxx@gmail.com", # Replace with the recipient's email
  subject = "ALA occurrence update - log file",
  credentials = creds_key(
    id = "gmail", # This can be changed to a specific key name
    provider = "gmail",
    user = "xxxx@gmail.com" # Replace with your email
  ),
  attachments = c(log_file) # Attach the file
)

message("Email sent successfully!")

}



blastula::create_smtp_creds_key(
  id = "gmail", # This will be referenced in the script
  user = "xxx@gmail.com",
  provider = "gmail",
  host = "smtp.gmail.com",
  port = 465,
  use_ssl = TRUE
)
