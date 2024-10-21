#!/bin/bash

# Check if the number of commits is provided, default to 10 if not
NUM_COMMITS=${1:-10}
FILE_MASK=${2:-"*.[ch]"}

# Initialize an array to collect JSON outputs
json_array=()
commit_count=0

# Escape double quotes and handle newlines in commit messages
clean_commit_message() {
    echo "$1" | sed -e '/Signed-off-by/d' -e '/Former-commit-id/d'
}

# Remove metadata from git diffs
clean_git_diff() {
    echo "$1" | grep -vE '^(diff --git|index|---|\+\+\+|@@)'
}

tokenize() {
    temp_file=$(mktemp --suffix=".cpp")

    # Safely write the input to the temporary file, preserving newlines and special characters
    printf "%s" "$1" > "$temp_file"

    # Run srcml on the temporary file, pipe to srcml2token, and extract the second column using awk
    srcml "$temp_file" | srcml2token | awk '{ print $2 }'

    # Clean up temporary file
    rm "$temp_file"
}

# Function to wrap changed tokens using diff
wrap_changed_tokens() {
    local before="$1"
    local after="$2"
    output=()

    IFS=$'\n' read -r -d '' -a before_array <<< "$before"
    IFS=$'\n' read -r -d '' -a after_array <<< "$after"

    before_length=${#before_array[@]}
    after_length=${#after_array[@]}
    max_length=$(( $before_length > $after_length ? $before_length : $after_length ))

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

    # Add remaining after tokens, if any
    for ((k=0; k<before_length; k++)); do
        if [[ k -eq i ]]; then
            output+=("<START_ERROR>")
        fi

        output+=("${before_array[k]}")

        if [[ k -eq $((before_length - j)) ]]; then
            output+=("<END_ERROR>")
        fi
    done

    printf "%s\n" "${output[@]}"
}

# Iterate through the specified number of commits and output JSON
while IFS= read -r commit_hash; do
    commit_message=$(git log -1 --pretty=format:'%B' "$commit_hash")

    if [ -z "$commit_hash" ] || [ -z "$commit_message" ]; then
        continue
    fi

    parent_commit=$(git rev-list --parents -n 1 "$commit_hash" | cut -d' ' -f2)
    if [ -z "$parent_commit" ]; then
        continue
    fi

    changed_files_count=$(git diff --name-only "$parent_commit" "$commit_hash" | wc -l)
    if [ "$changed_files_count" -ne 1 ]; then
        continue
    fi

    lines_changed=$(git diff --shortstat "$parent_commit" "$commit_hash" | awk '{print $4 + $6}')
    if [ "$lines_changed" -gt 5 ]; then
        continue
    fi

    diff=$(git diff -U3 "$parent_commit" "$commit_hash")
    clean_diff=$(clean_git_diff "$diff")

    code_before=$(echo "$clean_diff" | grep -v '^+' | sed 's/^-//')
    code_after=$(echo "$clean_diff" | grep -v '^-' | sed 's/^+//')

    code_before_tokens=$(tokenize "$code_before")
    code_after_tokens=$(tokenize "$code_after")

    wrapped_after_tokens=$(wrap_changed_tokens "$code_before_tokens" "$code_after_tokens")

    sanitized_commit_message=$(clean_commit_message "$commit_message")

    json_out=$(jq -n --arg instruction "$sanitized_commit_message" \
                     --arg input "$code_before" \
                     --arg tokenized "$code_before_tokens" \
                     --arg location "$wrapped_after_tokens" \
                     --arg fixed "$code_after_tokens" \
                     --arg result "$code_after" \
        '{
            instruction: ("I am having trouble with the following code in relation to " + $instruction + ". What''s wrong? Please fix this issue."),
            input: ("Here is the faulty code:\n\n" + ($input | split("\n") | map(. | ltrimstr(" ")) | join("\n"))),
            tokenized: ("Here is the faulty code which has been tokenized:\n\n" + ($tokenized | split("\n") | map(. | ltrimstr(" ")) | join("\n"))),
            error_location: ("I have identified the issue in the tokenized code. I have placed a <START_ERROR> before the problematic tokens and a <END_ERROR> after the problematic tokens:\n\n" + ($location | split("\n") | map(. | ltrimstr(" ")) | join("\n"))),
            error_correction: ("Here is the tokenized code with the issue corrected:\n\n" + ($fixed | split("\n") | map(. | ltrimstr(" ")) | join("\n"))),
            response: ("I corrected the issue in the code you provided:\n\n" + ($input | split("\n") | map(. | ltrimstr(" ")) | join("\n")) + "\nThe issue was with: " + $instruction + ". Here is the corrected version:\n\n" + ($result | split("\n") | map(. | ltrimstr(" ")) | join("\n")))
        }')

    json_array+=("$json_out")
    commit_count=$((commit_count + 1))

    if [ "$commit_count" -ge "$NUM_COMMITS" ]; then
        break
    fi

done < <(git log --pretty=format:'%H' -n "$NUM_COMMITS" -- "$FILE_MASK")

if [ ${#json_array[@]} -gt 0 ]; then
    printf '[%s]\n' "$(IFS=,; echo "${json_array[*]}")"
else
    echo "[]"
fi
