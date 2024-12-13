#!/bin/bash

# Check for script parameters
NUM_COMMITS=${1:-10}
FILE_MASK=${2:-"*.[ch]"}
EXCLUDE_COUNT=${3:-2}
MAX_TOKEN_CHANGES=${4:-40}

# Set of words we're looking for
INCLUDE_WORDS=("bug" "fix" "error" "issue" "patch" "clean" "refactor" "typo" "minor" "correct" "resolve" "patch")

# Initialize JSON arrays
json_array=()
excluded_json_array=()
commit_count=0

# Escape double quotes and handle newlines in commit messages
clean_commit_message() {
    echo "$1" | sed -e '/Signed-off-by/d' -e '/Former-commit-id/d'
}

# Remove metadata from git diffs
clean_git_diff() {
    echo "$1" | grep -vE '^(diff --git|index|---|\+\+\+|@@)'
}

# Function to tokenize source code
tokenize() {
    temp_file=$(mktemp --suffix=".cpp")

    # Safely write the input to the temporary file, preserving newlines and special characters
    printf "%s" "$1" > "$temp_file"

    # Run srcml on the temporary file, pipe to srcml2token, and extract the second column using awk
    srcml "$temp_file" | srcml2token | sed '1d;$d' | awk '{ print $2 }'

    # Clean up temporary file
    rm "$temp_file"
}

# Function to add error location markers
wrap_changed_tokens() {
    local before="$1"
    local after="$2"
    output=()

    # Split input into arrays by newlines
    IFS=$'\n' read -r -d '' -a before_array <<< "$before"
    IFS=$'\n' read -r -d '' -a after_array <<< "$after"

    before_length=${#before_array[@]}
    after_length=${#after_array[@]}
    max_length=$(( $before_length > $after_length ? $before_length : $after_length ))

    # Initialize i and j to find start and end of error
    i=-1
    j=-1

    # First pass: Find <START_ERROR>
    for ((i=0; i<before_length; i++)); do
        before_token=${before_array[i]}
        after_token=${after_array[i]}

        if [[ "$before_token" != "$after_token" ]]; then
            break
        fi
    done

    # Second pass: Find <END_ERROR>
    for ((j=1; j<before_length; j++)); do
        after_token=${after_array[after_length - j]}
        before_token=${before_array[before_length - j]}

        if [[ "$before_token" != "$after_token" ]]; then
            break
        fi
    done

    # Add tokens to the output array and insert error markers
    for ((k=0; k<max_length; k++)); do
        # Add START_ERROR when reaching the change point
        if [[ k -eq i ]]; then
            output+=("<START_ERROR>")
        fi

        # Check if we still have tokens in the before array
        if [[ k -lt before_length ]]; then
            output+=("${before_array[k]}")
        fi

        # Add END_ERROR when reaching the end change point
        if [[ k -eq $((before_length - j)) ]]; then
            output+=("<END_ERROR>")
        fi
    done

    # Output the final tokenized result
    printf "%s\n" "${output[@]}"
}

# Function to check for a set of words
contains_include_words() {
    local message="$1"
    for word in "${INCLUDE_WORDS[@]}"; do
        if [[ "$message" =~ $word ]]; then
            return 0
        fi
    done
    return 1
}

# Function to count tokens
count_tokens() {
    echo "$1" | wc -w
}

# Get all commit hashes for the specified file mask
commit_hashes=($(git log --pretty=format:'%H' -- "$FILE_MASK"))

filtered_commits=()
for commit_hash in "${commit_hashes[@]}"; do
    commit_message=$(git log -1 --pretty=format:'%B' "$commit_hash")

    # Skip commits with empty hash or message
    if [ -z "$commit_hash" ] || [ -z "$commit_message" ]; then
        continue
    fi

    # Filter by inclusion words
    if ! contains_include_words "$commit_message"; then
        continue
    fi

    # Get parent commit and ensure it exists
    parent_commit=$(git rev-list --parents -n 1 "$commit_hash" | cut -d' ' -f2)
    if [ -z "$parent_commit" ]; then
        continue
    fi

    # Esnure only one file was changed
    changed_files_count=$(git diff --name-only "$parent_commit" "$commit_hash" | wc -l)
    if [ "$changed_files_count" -ne 1 ]; then
        continue
    fi

    # Tokenize and check token changes
    diff=$(git diff -U3 "$parent_commit" "$commit_hash")
    clean_diff=$(clean_git_diff "$diff")

    code_before=$(echo "$clean_diff" | grep -v '^+' | sed 's/^-//')
    code_after=$(echo "$clean_diff" | grep -v '^-' | sed 's/^+//')

    code_before_tokens=$(tokenize "$code_before")
    code_after_tokens=$(tokenize "$code_after")

    before_token_count=$(count_tokens "$code_before_tokens")

    # Esnure token counts are within bounds
    if [ "${before_token_count#-}" -gt "$MAX_TOKEN_CHANGES" ]; then
        continue
    fi

    # If all filters pass, add commit to filtered list
    filtered_commits+=("$commit_hash")

    # Break early if enough commits are collected
    if [ "${#filtered_commits[@]}" -ge "$NUM_COMMITS" ]; then
        break
    fi
done

# Randomly select excluded commits from filtered commits
excluded_commits=($(shuf -e "${filtered_commits[@]}" | head -n "$EXCLUDE_COUNT"))

# Output JSON for included and excluded commits
commit_count=0
for commit_hash in "${filtered_commits[@]}"; do
    # Generate JSON as before
    sanitized_commit_message=$(clean_commit_message "$(git log -1 --pretty=format:'%B' "$commit_hash")")
    sanitized_commit_title=$(clean_commit_message "$(git log -1 --pretty=format:'%s' "$commit_hash")")

    parent_commit=$(git rev-list --parents -n 1 "$commit_hash" | cut -d' ' -f2)
    diff=$(git diff -U3 "$parent_commit" "$commit_hash")
    clean_diff=$(clean_git_diff "$diff")

    code_before=$(echo "$clean_diff" | grep -v '^+' | sed 's/^-//')
    code_after=$(echo "$clean_diff" | grep -v '^-' | sed 's/^+//')

    code_before_tokens=$(tokenize "$code_before")
    code_after_tokens=$(tokenize "$code_after")
    wrapped_after_tokens=$(wrap_changed_tokens "$code_before_tokens" "$code_after_tokens")

    json_out=$(jq -n --arg hash "$commit_hash" \
                     --arg instruction "$sanitized_commit_title" \
                     --arg input "$code_before" \
                     --arg tokenized "$code_before_tokens" \
                     --arg location "$wrapped_after_tokens" \
                     --arg fixed "$code_after_tokens" \
                     --arg result "$code_after" \
                     --arg response "$sanitized_commit_message" \
        '{
            commit_hash: $hash,
            instruction: ("I am having trouble with the following code in relation to " + $instruction + ". What''s wrong? Please fix this issue."),
            input: ("Here is the faulty code:\n\n" + ($input | split("\n") | map(. | ltrimstr(" ")) | join("\n"))),
            tokenized: ("Here is the faulty code which has been tokenized:\n\n" + ($tokenized | split("\n") | map(. | ltrimstr(" ")) | join("\n"))),
            error_location: ("I have identified the issue in the tokenized code. I have placed a <START_ERROR> before the problematic tokens and a <END_ERROR> after the problematic tokens:\n\n" + ($location | split("\n") | map(. | ltrimstr(" ")) | join("\n"))),
            error_correction: ("Here is the tokenized code with the issue corrected:\n\n" + ($fixed | split("\n") | map(. | ltrimstr(" ")) | join("\n"))),
            response: ("I corrected the issue in the code you provided:\n\n" + ($input | split("\n") | map(. | ltrimstr(" ")) | join("\n")) + "\nThe issue was with: " + $response + ". Here is the corrected version:\n\n" + ($result | split("\n") | map(. | ltrimstr(" ")) | join("\n")))
        }')

    # Categorize as included or excluded
    if [[ " ${excluded_commits[*]} " =~ " $commit_hash " ]]; then
        excluded_json_array+=("$json_out")
    else
        included_json_array+=("$json_out")
    fi

    commit_count=$((commit_count + 1))
    if [ "$commit_count" -ge "$NUM_COMMITS" ]; then
        break
    fi
done

# Output included JSON array to stdout
if [ ${#included_json_array[@]} -gt 0 ]; then
    printf '[%s]\n' "$(IFS=,; echo "${included_json_array[*]}")"
else
    echo "[]"
fi

# Write excluded JSON array to a separate file
excluded_file="excluded_commits.json"
if [ ${#excluded_json_array[@]} -gt 0 ]; then
    printf '[%s]\n' "$(IFS=,; echo "${excluded_json_array[*]}")" > "$excluded_file"
else
    echo "[]" > "$excluded_file"
fi
