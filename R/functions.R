
# Define function to check for double species names and return standard genus species
remove_third_if_duplicate <- function(string_vec) {
  # string_vec is a vector of strings.

  # 1. Split each element of string_vec by whitespace to produce a list of character vectors.
  #    strsplit(string_vec, "\\s+") splits on one or more spaces.
  word_lists <- strsplit(string_vec, "\\s+")

  # 2. Apply a function to each element (each list of words) using sapply.
  #    For each vector of words:
  #       - Check if it has at least 3 words.
  #       - Check if the second and third words are identical.
  #       - If so, return the first two words joined by a space.
  #       - Otherwise, return the original words joined by a space.
  processed_strings <- sapply(word_lists, function(words) {
    if (length(words) >= 3 && words[2] == words[3]) {
      # If second and third words match, return only the first two words
      paste(words[1:2], collapse = " ")
    } else {
      # Otherwise, return the full, original string
      paste(words, collapse = " ")
    }
  })

  # 3. The result is a character vector of processed strings.
  return(processed_strings)
}


remove_parenthesis_text <- function(string_vec) {
  # string_vec is a vector of strings.
  # This function uses a regular expression to match and remove
  # all text within parentheses, including the parentheses themselves.

  # The pattern "\\(.*?\\)" matches:
  #   "\\(" : a literal "(" character
  #   ".*?" : any number of characters, as few as possible (non-greedy)
  #   "\\)" : a literal ")" character

  # Use gsub to globally substitute these patterns with an empty string.
  cleaned_strings <- gsub("\\(.*?\\)", "", string_vec)

  #Remove extra internal space
  trimmed_strings <- stringr::str_squish(cleaned_strings)

  return(trimmed_strings)
}

keep_first_two_words <- function(x) {
  # x is a vector of strings.

  # 1. Split each string by whitespace.
  word_lists <- strsplit(x, "\\s+")

  # 2. For each vector of words, select the first two if available;
  #    otherwise, return all words if fewer than two exist.
  sapply(word_lists, function(words) {
    if (length(words) > 2) {
      paste(words[1:2], collapse = " ")
    } else {
      paste(words, collapse = " ")
    }
  })
}

# Example usage:
# df <- df %>%
#   mutate(shortened_col = keep_first_two_words(text_col))




head(unlist(strsplit(toohey_occurrences$scientificName, " ")))

