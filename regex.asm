# ===================================================================
# Authors: Crawford Barnett, Tyler Hintz, Matt Weber
# 
# Description: 
#
# ===================================================================

.data
	# Prompts for user input
	prompt_regex:  .asciiz "Enter regular expression: "
	prompt_text:   .asciiz "Enter text to match: "
	
	# Buffers for storing input strings
	regex_buffer:  .space 256        # Buffer for regex pattern
	text_buffer:   .space 1024       # Buffer for text to match
	
	# Output formatting
	newline:       .asciiz "\n"
	comma:         .asciiz ", "
	
	# Temporary storage
	.align 2
	matches:       .space 4096       # Buffer to store matched substrings

.text
.globl main

# ===================================================================
# Main function
# ===================================================================
main:
	# Prompt for and read regular expression
	li $v0, 4
	la $a0, prompt_regex
	syscall
	
	li $v0, 8
	la $a0, regex_buffer
	li $a1, 256
	syscall
	
	# Prompt for and read text to match
	li $v0, 4
	la $a0, prompt_text
	syscall
	
	li $v0, 8
	la $a0, text_buffer
	li $a1, 1024
	syscall
	
	# TODO: Remove newline characters from input strings
	# (syscall 8 includes newline in the input)
	
	# TODO: Call regex matching function
	# la $a0, regex_buffer
	# la $a1, text_buffer
	# jal match_regex
	
	# Exit program
	j exit

# ===================================================================
# Function: match_regex
# Parameters: $a0 = address of regex pattern
#             $a1 = address of text to match
# Description: Main regex matching function - processes the pattern
#              and finds all matches in the text
# ===================================================================
match_regex:
	# TODO: Implement regex matching logic
	# This function should:
	# 1. Parse the regex pattern character by character
	# 2. Handle special characters: *, ., \, ^, []
	# 3. Find all matches in the text
	# 4. Print matches (separated by comma or newline)
	
	jr $ra

# ===================================================================
# Function: match_single_char
# Parameters: $a0 = character to match
#             $a1 = address of text
#             $a2 = current position in text
# Returns: $v0 = 1 if match, 0 if no match
#          $v1 = next position after match
# Description: Matches a single character
# ===================================================================
match_single_char:
	# TODO: Implement single character matching
	jr $ra

# ===================================================================
# Function: match_star
# Parameters: $a0 = character to match (or pattern)
#             $a1 = address of text
#             $a2 = current position in text
# Returns: $v0 = length of match
#          $v1 = next position after match
# Description: Matches zero or more occurrences (a*)
# ===================================================================
match_star:
	# TODO: Implement * matching (zero or more)
	jr $ra

# ===================================================================
# Function: match_dot
# Parameters: $a0 = address of text
#             $a1 = current position in text
# Returns: $v0 = 1 if match (any char except newline), 0 otherwise
#          $v1 = next position after match
# Description: Matches any single character (.)
# ===================================================================
match_dot:
	# TODO: Implement . matching (any character)
	jr $ra

# ===================================================================
# Function: match_char_class
# Parameters: $a0 = address of character class pattern (e.g., [a-z])
#             $a1 = address of text
#             $a2 = current position in text
# Returns: $v0 = 1 if match, 0 if no match
#          $v1 = next position after match
#          $v2 = end position of character class in pattern
# Description: Matches character classes like [a-z], [abc], [^a-z]
# ===================================================================
match_char_class:
	# TODO: Implement character class matching [abc], [a-z], [^a-z]
	jr $ra

# ===================================================================
# Function: is_escape_char
# Parameters: $a0 = address of pattern
#             $a1 = current position in pattern
# Returns: $v0 = 1 if next char is escaped, 0 otherwise
#          $v1 = the escaped character if $v0 = 1
# Description: Checks if current position has escape character (\)
# ===================================================================
is_escape_char:
	# TODO: Implement escape character handling (\)
	jr $ra

# ===================================================================
# Function: print_match
# Parameters: $a0 = address of match start
#             $a1 = length of match
# Description: Prints a single match
# ===================================================================
print_match:
	# TODO: Print the matched substring
	# Format: print match, then comma or newline
	jr $ra

# ===================================================================
# Function: remove_newline
# Parameters: $a0 = address of string
# Description: Removes trailing newline from string (from syscall 8)
# ===================================================================
remove_newline:
	# TODO: Remove newline character from end of string
	jr $ra

# ===================================================================
# Function: is_valid_char
# Parameters: $a0 = character (byte)
# Returns: $v0 = 1 if valid (a-z, A-Z, 0-9), 0 otherwise
# Description: Checks if character is in valid range
# ===================================================================
is_valid_char:
	# TODO: Check if character is a-z, A-Z, or 0-9
	jr $ra

# ===================================================================
# Exit program
# ===================================================================
exit:
	li $v0, 10
	syscall
