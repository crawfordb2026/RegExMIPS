# ===================================================================
# Authors: Crawford Barnett, Tyler Hintz, Matt Weber
# Description: Simple MIPS Regex Matcher (supports literals, ., *, [], [^], and \ escape)
# ===================================================================

.data
# --- User Prompts and Output Messages ---
prompt_regex: .asciiz "Enter Regular Expression (e.g., abc, a*, [a-z], [^0-9]*): "
prompt_sentence: .asciiz "Enter Sentence to evaluate: "
output_header: .asciiz "Matches: "
newline: .asciiz "\n"
comma_space: .asciiz ", "

# --- Buffers for Input Strings ---
regex_buffer: .space 256 
sentence_buffer: .space 1024

# --- Register Usage Convention ---
# $s0: Base address of the Regex string
# $s1: Base address of the Target Sentence
# $s2: Current search pointer in the Target Sentence (Outer Loop)
# $s3: Match length from a successful call to match_pattern
# $s4: First Match Flag (0: No comma needed, 1: Comma needed)

.text
.globl main

################################################################################
# MAIN EXECUTION
################################################################################
main:
    # 1. Read Regular Expression
    li $v0, 4                 
    la $a0, prompt_regex      
    syscall

    li $v0, 8                 
    la $a0, regex_buffer      
    li $a1, 256               
    syscall                   
    move $s0, $a0             # $s0 = Address of the Regex Buffer
    jal clean_newline         

    # 2. Read Sentence
    li $v0, 4                 
    la $a0, prompt_sentence   
    syscall

    li $v0, 8                 
    la $a0, sentence_buffer   
    li $a1, 1024              
    syscall                   
    move $s1, $a0             # $s1 = Address of the Sentence Buffer
    jal clean_newline         
    
    # 3. Initialization
    move $s2, $s1             # $s2 = Start searching from the beginning of the sentence
    li   $s4, 0               # $s4 = First match flag (0: No comma needed)

    # Print output header
    li $v0, 4                 
    la $a0, output_header
    syscall

################################################################################
# OUTER_LOOP: Iterates through the sentence, attempting a match at every position.
################################################################################
outer_loop:
    # Check if end of sentence is reached (null terminator)
    lb  $t0, 0($s2)            
    beq $t0, $zero, end_search 

    move $a0, $s0             # Regex start address
    move $a1, $s2             # Current sentence start
    
    jal  match_pattern         
    move $s3, $v0             # $s3 = Match length (0 means no match)

    # Check for successful match
    bgt  $s3, $zero, match_found

no_match_at_current_pos:
    addi $s2, $s2, 1
    j    outer_loop

match_found:
    # A match of length $s3 was found starting at $s2.
    
    # 1. Print comma separator if not the first match
    beq $s4, $zero, skip_comma 
    li  $v0, 4
    la  $a0, comma_space
    syscall
skip_comma:
    li  $s4, 1                 # Set $s4 flag to 1 (next match needs a comma)

    # 2. Print the matched substring
    move $a0, $s2             # $a0 = Start address of the match
    move $a1, $s3             # $a1 = Length of the match
    jal  print_substring       

    # 3. Advance the sentence pointer by the match length (maximal munch).
    add  $s2, $s2, $s3         # $s2 += match_length
    
    j    outer_loop              

end_search:
    # Print a final newline and exit.
    li  $v0, 4
    la  $a0, newline
    syscall

    li  $v0, 10                
    syscall
    
################################################################################
# CORE REGEX MATCHING LOGIC (match_pattern)
################################################################################

# match_pattern: Iteratively matches the entire regex against the sentence.
# Arguments: 
#   $a0 (Pattern/Regex): Start address of the regex string
#   $a1 (Text/Sentence): Start address of the sentence substring
# Returns: 
#   $v0: Length of the matched substring (0 if no match).
match_pattern:
    addi $sp, $sp, -4         # Save $ra
    sw   $ra, 0($sp)

    # $s5: Regex pointer (r_ptr)
    # $s6: Sentence pointer (s_ptr)
    # $t3: Match length of the current token (1 or more)
    # $t4: Total match length so far

    move $s5, $a0             # $s5 = r_ptr (start of regex pattern)
    move $s6, $a1             # $s6 = s_ptr (start of sentence substring)
    li   $t4, 0               # $t4 = Total Match Length

full_match_loop:
    # 1. Check if full regex pattern is consumed
    lb  $t0, 0($s5)
    beq $t0, $zero, fml_success # Regex consumed, success!

    
    # Prepare arguments for single_token_match helper
    move $a0, $s5             # $a0 = r_ptr (token address)
    move $a1, $s6             # $a1 = s_ptr (sentence char address)
    jal  single_token_match   # $v0: 1 if match, 0 if fail.
    move $t3, $v0             # $t3 = match length (1 or 0)
    
    # If match failed
    beq  $t3, $zero, fml_fail 
    
    # If match succeeded: advance regex pointer by full token, text by 1
    lb   $t5, 0($s5)          # t5 = current regex char

    # If token is a range [...]
    li   $t9, '['
    beq  $t5, $t9, fml_advance_past_range

    # If token is an escape \x
    li   $t9, '\\'
    beq  $t5, $t9, fml_advance_past_escape

    # Default: single-char token (literal or '.')
    addi $s5, $s5, 1
    j    fml_advance_sentence

fml_advance_past_escape:
    # Skip '\' and the escaped character
    addi $s5, $s5, 2
    j    fml_advance_sentence

fml_advance_past_range:
    # Move from '[' to first content char
    addi $s5, $s5, 1
fml_advance_range_loop:
    lb   $t6, 0($s5)
    li   $t9, ']'
    beq  $t6, $t9, fml_done_advance_range
    beq  $t6, $zero, fml_done_advance_range  # safety: malformed regex
    addi $s5, $s5, 1
    j    fml_advance_range_loop

fml_done_advance_range:
    # Step over closing ']'
    addi $s5, $s5, 1

fml_advance_sentence:
    addi $s6, $s6, 1          # Consumed exactly one text char
    addi $t4, $t4, 1          # Add 1 to total length
    j    full_match_loop      # Continue loop



# --- Success/Fail ---
fml_success:
    move $v0, $t4             # Return total match length
    j    return_pattern

fml_fail:
    li   $v0, 0               # Return 0 length (fail)
    j    return_pattern

return_pattern:
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra                  # Return $v0 (match length)



################################################################################
# HELPER: single_token_match 
# Matches a non-quantified regex token (Char, ., or []) against ONE sentence char.
################################################################################
single_token_match:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    # $t0: Current char from regex
    # $t2: Current char from sentence
    
    lb   $t0, 0($a0)           # $t0 = current regex char
    lb   $t2, 0($a1)           # $t2 = current sentence char
    
    # 1. Check for end of sentence 
    beq  $t2, $zero, stm_fail_return 

    # 2. Check for Escape '\'
    li   $t9, '\\'
    beq  $t0, $t9, handle_escape_char_stm 
    
    # 3. Check for Wildcard '.'
    li   $t9, '.'
    beq  $t0, $t9, stm_success_return # '.' matches any non-null char

    # 4. Check for Range '['
    li   $t9, '['
    beq  $t0, $t9, handle_range_stm

    # 5. Default: Literal Character Match
    beq  $t0, $t2, stm_success_return # Literal match
    
    j    stm_fail_return         # Literal mismatch

# --- Helper for Escape Character (\.) ---
handle_escape_char_stm:
    lb   $t0, 1($a0)            # $t0 = escaped character (e.g., '.')
    bne  $t0, $zero, escape_check_char 
    j    stm_fail_return         
    
escape_check_char:
    beq  $t0, $t2, stm_success_return # Match the literal escaped char
    j    stm_fail_return

# --- Helper for Character Range ([...]) ---
handle_range_stm:
    # Save necessary registers: $a0 (regex start), $t2 (sentence char), $s5 (range ptr)
    addi $sp, $sp, -16
    sw   $ra, 12($sp)
    sw   $a0, 8($sp)            # Save original $a0 (regex pointer from caller)
    sw   $t2, 4($sp)            # Save $t2 (sentence character)
    sw   $s5, 0($sp)            # Save $s5 (will be used for range pointer)

    move $s7, $t2               # $s7 = Sentence Character (the one we are matching)
    move $s5, $a0               # $s5 = Current position in the RANGE content (our new pointer)
    addi $s5, $s5, 1            # $s5 points past '['

    li   $t8, 0                 # $t8 = negation flag (0=match inside, 1=match outside)
    li   $t6, 0                 # $t6 = Found match inside set (0=No, 1=Yes)
    
    lb   $t0, 0($s5)            # Load first char of content
    li   $t9, '^'
    beq  $t0, $t9, set_negation_flag # Check for negation '^'

range_check_start:
    # $t0 = current regex char. (Loaded using $s5)
    lb   $t0, 0($s5)
    li   $t9, ']'
    beq  $t0, $t9, range_check_result # Found ']', finalize result

    # Check for range separator '-' (X-Y)
    lb   $t1, 1($s5)            # Lookahead for '-'
    li   $t9, '-'
    bne  $t1, $t9, range_literal_check_range # Not a range, check for single literal
    
    # --- Range: X-Y ---
    lb   $t5, 0($s5)            # $t5 = Start of range (e.g., 'A')
    lb   $t7, 2($s5)            # $t7 = End of range (e.g., 'Z')
    
    # Check if sentence char ($s7) is between start and end (inclusive)
    slt  $t9, $s7, $t5          # t9 = 1 if $s7 < $t5 (Fail low)
    bne  $t9, $zero, range_next_token_3 # too low
    
    slt  $t9, $t7, $s7          # t9 = 1 if $t7 < $s7 (Fail high)
    bne  $t9, $zero, range_next_token_3 # too high
    
    # Match found within range (no need to check other items)
    li   $t6, 1                 # Set match found flag
    j    range_check_result      # Exit loop early

range_literal_check_range:
    # --- Literal: [abc] or [A] ---
    beq  $t0, $s7, range_match_found # Match found
    
    addi $s5, $s5, 1           # Advance regex pointer
    j    range_check_start     # Check next token/range

range_next_token_3:
    addi $s5, $s5, 3           # Skip X-Y range
    j    range_check_start     # Check next token/range

set_negation_flag:
    li   $t8, 1                 # Set negation flag
    addi $s5, $s5, 1            # Skip '^'
    j    range_check_start      # Continue to check actual content

range_match_found:
    li   $t6, 1                 # Set match found flag
    j    range_check_result      # Exit loop early

range_check_result:
    # $t8 = negation flag (0=no negation, 1=negation)
    # $t6 = match status (1=inside set, 0=outside set)
    
    beq  $t8, $zero, check_non_negated_range # If not negated, proceed

    # --- Negated Check (t8 == 1) ---
    bne  $t6, $zero, stm_fail_return_range # Negated and inside set = FAIL
    j    stm_success_return_range          # Negated and outside set = SUCCESS

check_non_negated_range:
    # --- Non-Negated Check (t8 == 0) ---
    bne  $t6, $zero, stm_success_return_range # Inside set = SUCCESS
    j    stm_fail_return_range                  # Outside set = FAIL

stm_success_return_range:
    # Restore saved registers
    lw   $s5, 0($sp)            # Restore $s5
    lw   $t2, 4($sp)            # Restore $t2
    lw   $a0, 8($sp)            # Restore $a0
    lw   $ra, 12($sp)
    addi $sp, $sp, 16
    j    stm_success_return

stm_fail_return_range:
    # Restore saved registers
    lw   $s5, 0($sp)            # Restore $s5
    lw   $t2, 4($sp)            # Restore $t2
    lw   $a0, 8($sp)            # Restore $a0
    lw   $ra, 12($sp)
    addi $sp, $sp, 16
    j    stm_fail_return

stm_success_return:
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    li   $v0, 1
    jr   $ra

stm_fail_return:
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    li   $v0, 0
    jr   $ra

################################################################################
# HELPER FUNCTIONS (I/O)
################################################################################

# clean_newline: Removes the trailing newline/CR character from a string read by syscall 8.
# Argument: $a0 = string address
# Return: String is modified in place.
clean_newline:
    move $t1, $a0             # $t1 = Start address
clean_loop:
    lb   $t0, 0($t1)            
    beq  $t0, $zero, clean_end 
    
    li   $t2, 10              # Newline character (LF)
    beq  $t0, $t2, replace_char
    li   $t2, 13              # Carriage return character (CR)
    beq  $t0, $t2, replace_char
    
    addi $t1, $t1, 1          
    j    clean_loop
    
replace_char:
    sb   $zero, 0($t1)        # Replace newline/CR with null terminator
    
clean_end:
    jr   $ra                  # Return

# print_substring: Prints a substring of a given length.
# Arguments: $a0 = start address, $a1 = length
# Return: none
print_substring:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    move $s5, $a1             # $s5 = length (counter)
    move $s6, $a0             # $s6 = current address
    
    # 1. Store the original character at the end of the substring
    add  $t8, $s6, $s5        # $t8 = address of char *after* the substring
    lb   $t7, 0($t8)          # $t7 = character to restore (could be null)
    
    # 2. Temporarily place a null terminator for print_string syscall
    sb   $zero, 0($t8)
    
    # 3. Print the substring
    li   $v0, 4                 
    move $a0, $s6             
    syscall
    
    # 4. Restore the original character
    sb   $t7, 0($t8)            
    
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra
    
exit:
    li   $v0, 10
    syscall
