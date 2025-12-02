# ===================================================================
# Authors: Crawford Barnett, Tyler Hintz, Matt Weber
# 
# Description: MIPS assembly program that matches regular expressions
# Supports: single chars, dot (.), star (*), character ranges [a-z], 
# negation [^], and escape sequences (\)
#
# ===================================================================

.data
# Prompts for user input
prompt_regex: .asciiz "Enter regular expression: "
prompt_text: .asciiz "Enter text to match: "
newline: .asciiz "\n"
comma: .asciiz ", "

# Input buffers
regex_buffer: .space 256 
text_buffer: .space 1024

# Register usage:
# $s0 = regex string address
# $s1 = text string address  
# $s2 = current position in text
# $s3 = match length
# $s4 = first match flag (for comma printing)

.text
.globl main

main:
    # Get regular expression from user
    li $v0, 4                 
    la $a0, prompt_regex      
    syscall

    li $v0, 8                 
    la $a0, regex_buffer      
    li $a1, 256               
    syscall                   
    move $s0, $a0             # save regex address
    jal clean_newline         

    # Get text to search from user  
    li $v0, 4                 
    la $a0, prompt_text   
    syscall

    li $v0, 8                 
    la $a0, text_buffer   
    li $a1, 1024              
    syscall                   
    move $s1, $a0             # save text address
    jal clean_newline         
    
    # Setup for searching
    move $s2, $s1             # start at beginning of text
    li $s4, 0                 # no matches found yet

# Main loop - try to find matches starting at each position in the text
outer_loop:
    # Check if we've reached the end of the text
    lb $t0, 0($s2)            
    beq $t0, $zero, end_search

    # Try to match the regex pattern starting at current position
    move $a0, $s0             # regex pattern
    move $a1, $s2             # current text position
    
    jal match_pattern         
    move $s3, $v0             # save match length (0 means no match)

    # If we found a match, go print it
    bgt $s3, $zero, match_found

    # No match at this position, try next character
    addi $s2, $s2, 1
    j outer_loop

match_found:
    # Print comma if this isn't the first match
    beq $s4, $zero, skip_comma 
    li $v0, 4
    la $a0, comma
    syscall
skip_comma:
    li $s4, 1                 # remember we've printed at least one match

    # Print the matched text
    move $a0, $s2             # start of match
    move $a1, $s3             # length of match
    jal print_substring       

    # Move past the match and keep looking
    add $s2, $s2, $s3         
    j outer_loop              

end_search:
    # Print newline and exit
    li $v0, 4
    la $a0, newline
    syscall

    li $v0, 10                
    syscall
    
# match_pattern: tries to match the whole regex pattern starting at a position
# inputs: $a0 = regex pattern, $a1 = text position
# returns: $v0 = length of match (0 if no match)
match_pattern:
    addi $sp, $sp, -4         
    sw $ra, 0($sp)

    # use these registers to keep track of where we are
    move $s5, $a0             # regex pointer
    move $s6, $a1             # text pointer
    li $t4, 0                 # total match length so far

full_match_loop:
    # check if we've matched the whole regex pattern
    lb $t0, 0($s5)
    beq $t0, $zero, success_match # if end of pattern, we succeeded!

    # need to look ahead for star, but position depends on pattern type
    lb $t5, 0($s5)
    
    # Check if this is a character class [...]
    li $t9, '['
    bne $t5, $t9, check_escape_star
    
    # It's a character class - find the closing bracket first
    move $t3, $s5
    addi $t3, $t3, 1          # skip [
find_bracket:
    lb $t6, 0($t3)
    li $t9, ']'
    beq $t6, $t9, found_bracket
    beq $t6, $zero, no_star  # safety check
    addi $t3, $t3, 1
    j find_bracket
found_bracket:
    # Now check if there's a star after the ]
    lb $t1, 1($t3)           # character after ]
    li $t2, '*'
    beq $t1, $t2, handle_star
    j no_star

check_escape_star:
    # Check if this is an escape sequence
    li $t9, 92              # backslash
    bne $t5, $t9, check_normal_star
    
    # It's an escape - star would be at position 2
    lb $t1, 2($s5)
    li $t2, '*'
    beq $t1, $t2, handle_star
    j no_star

check_normal_star:
    # Normal character - star at position 1
    lb $t1, 1($s5)           
    li $t2, '*'
    beq $t1, $t2, handle_star

no_star:
    # no star, so just try to match this one character
    move $a0, $s5             
    move $a1, $s6             
    jal single_token_match    # returns 1 if match, 0 if no match
    move $t3, $v0             
    
    # if this character didn't match, the whole pattern fails
    beq $t3, $zero, fail_match 
    
    # character matched! now we need to advance both pointers
    lb $t5, 0($s5)          

    # check what type of character we just matched
    li $t9, '['
    beq $t5, $t9, advance_past_range

    li $t9, 92              # backslash
    beq $t5, $t9, advance_past_escape

    # regular character, just move forward one
    addi $s5, $s5, 1
    j advance_text

handle_star:
    # found a star! try to match as many as possible
    move $a0, $s5             
    move $a1, $s6               
    jal match_star_pattern    # this handles the X* matching
    
    add $t4, $t4, $v0        # add to total match length
    add $s6, $s6, $v0        # move text pointer forward
    
    # now skip past the character and star in the pattern
    lb $t5, 0($s5)          
    li $t9, '['
    beq $t5, $t9, advance_past_range_star

    li $t9, 92              # backslash
    beq $t5, $t9, advance_past_escape_star

    # regular character + star
    addi $s5, $s5, 2          # skip both the char and *
    j full_match_loop

advance_past_escape_star:
    addi $s5, $s5, 3          # skip \, char, and *
    j full_match_loop

advance_past_range_star:
    # skip past [...]*
    addi $s5, $s5, 1          # skip [
range_star_loop:
    lb $t6, 0($s5)
    li $t9, ']'
    beq $t6, $t9, done_range_star
    beq $t6, $zero, done_range_star  # just in case
    addi $s5, $s5, 1
    j range_star_loop
done_range_star:
    addi $s5, $s5, 2          # skip ] and *
    j full_match_loop

advance_past_escape:
    # skip backslash and the escaped character
    addi $s5, $s5, 2
    j advance_text

advance_past_range:
    # skip past [...]
    addi $s5, $s5, 1
range_loop:
    lb $t6, 0($s5)
    li $t9, ']'
    beq $t6, $t9, done_range
    beq $t6, $zero, done_range  
    addi $s5, $s5, 1
    j range_loop
done_range:
    addi $s5, $s5, 1

advance_text:
    addi $s6, $s6, 1          # move to next text character
    addi $t4, $t4, 1          # add to match length
    j full_match_loop      

success_match:
    move $v0, $t4             # return total match length
    j return_pattern

fail_match:
    li $v0, 0                 # return 0 (no match)
    j return_pattern

return_pattern:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra                  

# match_star_pattern: handles the * part of regex (match zero or more)
# $a0 = what character to match multiple times
# $a1 = where we are in the text
# returns $v0 = how many characters we matched
match_star_pattern:
    addi $sp, $sp, -16
    sw $ra, 12($sp)
    sw $s0, 8($sp)          # count of how many we matched
    sw $s1, 4($sp)          # current text position
    sw $s2, 0($sp)          # the pattern we're matching
    
    li $s0, 0               # start with 0 matches
    move $s1, $a1             
    move $s2, $a0             

star_loop:
    # try to match the character at current position
    move $a0, $s2             # pattern token
    move $a1, $s1             # current text address
    jal single_token_match
    
    # if it doesn't match, we're done (star can match zero times)
    beq $v0, $zero, star_done
    
    # it matched! move forward and try again
    addi $s1, $s1, 1          # move to next character in text
    addi $s0, $s0, 1          # increment match count
    j star_loop

star_done:
    move $v0, $s0             # return how many we matched
    
    lw $ra, 12($sp)
    lw $s0, 8($sp)
    lw $s1, 4($sp)
    lw $s2, 0($sp)
    addi $sp, $sp, 16
    jr $ra

# single_token_match: checks if one character matches the pattern
# $a0 = pattern character, $a1 = text character
# returns 1 if match, 0 if no match
single_token_match:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    lb $t0, 0($a0)           # get pattern character
    lb $t2, 0($a1)           # get text character
    
    # if we hit end of text, no match
    beq $t2, $zero, no_match 

    # check for special characters
    li $t9, 92              # backslash (escape)
    beq $t0, $t9, handle_escape 
    
    li $t9, '.'             # dot (matches anything)
    beq $t0, $t9, yes_match 

    li $t9, '['             # start of character range
    beq $t0, $t9, handle_range

    # regular character - just compare them
    beq $t0, $t2, yes_match 
    
    j no_match

handle_escape:
    # get the character after the backslash
    lb $t0, 1($a0)            
    bne $t0, $zero, check_escaped 
    j no_match         
    
check_escaped:
    beq $t0, $t2, yes_match # match the literal character
    j no_match

handle_range:
    # save registers we'll need
    addi $sp, $sp, -16
    sw $ra, 12($sp)
    sw $a0, 8($sp)            
    sw $t2, 4($sp)            
    sw $s5, 0($sp)            

    move $s7, $t2               # character we're trying to match
    move $t3, $a0               # range pattern pointer (use $t3 instead of $s5)
    addi $t3, $t3, 1            # skip past '['

    li $t8, 0                 # negation flag (0=normal, 1=negated with ^)
    li $t6, 0                 # did we find a match? (0=no, 1=yes)
    
    # check if first character is ^ (negation)
    lb $t0, 0($t3)            
    li $t9, '^'
    beq $t0, $t9, set_negation

range_check_loop:
    lb $t0, 0($t3)
    li $t9, ']'
    beq $t0, $t9, range_done # found closing bracket
    beq $t0, $zero, range_done # safety check for end of string

    # check if this is a range like a-z
    lb $t1, 1($t3)            # look at next character
    li $t9, '-'
    bne $t1, $t9, check_single_char # not a range, just check single character
    
    # this is a range like a-z
    lb $t5, 0($t3)            # start of range
    lb $t7, 2($t3)            # end of range
    
    # is our character in this range?
    slt $t9, $s7, $t5          
    bne $t9, $zero, skip_range # too low
    
    slt $t9, $t7, $s7          
    bne $t9, $zero, skip_range # too high
    
    # it's in the range!
    li $t6, 1                 
    j range_done      

check_single_char:
    # just check if characters are equal
    beq $t0, $s7, found_match 
    
    addi $t3, $t3, 1           # move to next character in range
    j range_check_loop     

skip_range:
    addi $t3, $t3, 3           # skip past a-z
    j range_check_loop     

set_negation:
    li $t8, 1                 # set negation flag
    addi $t3, $t3, 1            # skip past ^
    j range_check_loop      

found_match:
    li $t6, 1                 # we found a match
    j range_done              # once we find a match, we're done

range_done:
    # now decide if we matched based on negation
    beq $t8, $zero, check_normal # not negated

    # negated - we want the opposite of what we found
    bne $t6, $zero, range_no_match # found match but negated = no match
    j range_yes_match          # didn't find match but negated = yes match

check_normal:
    # normal - we want exactly what we found
    bne $t6, $zero, range_yes_match # found match = yes match
    j range_no_match                  # didn't find match = no match

range_yes_match:
    # restore registers and return success
    lw $s5, 0($sp)            
    lw $t2, 4($sp)            
    lw $a0, 8($sp)            
    lw $ra, 12($sp)
    addi $sp, $sp, 16
    j yes_match

range_no_match:
    # restore registers and return failure
    lw $s5, 0($sp)            
    lw $t2, 4($sp)            
    lw $a0, 8($sp)            
    lw $ra, 12($sp)
    addi $sp, $sp, 16
    j no_match

yes_match:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    li $v0, 1
    jr $ra

no_match:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    li $v0, 0
    jr $ra

# Helper functions

# clean_newline: removes the newline that syscall 8 adds to input
# $a0 = string to clean
clean_newline:
    move $t1, $a0             # start at beginning of string
clean_loop:
    lb $t0, 0($t1)            
    beq $t0, $zero, clean_done 
    
    # check for newline or carriage return
    li $t2, 10              
    beq $t0, $t2, remove_it
    li $t2, 13              
    beq $t0, $t2, remove_it
    
    # not a newline, keep looking
    addi $t1, $t1, 1          
    j clean_loop
    
remove_it:
    sb $zero, 0($t1)        # replace with null terminator
    
clean_done:
    jr $ra

# print_substring: prints part of a string
# $a0 = where to start printing, $a1 = how many characters
print_substring:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    move $s5, $a1             # length to print
    move $s6, $a0             # start address
    
    # save the character after our substring so we can restore it
    add $t8, $s6, $s5        
    lb $t7, 0($t8)          
    
    # put a null terminator there temporarily
    sb $zero, 0($t8)
    
    # print the string
    li $v0, 4                 
    move $a0, $s6             
    syscall
    
    # put back the original character
    sb $t7, 0($t8)            
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
    
exit:
    li   $v0, 10
    syscall
