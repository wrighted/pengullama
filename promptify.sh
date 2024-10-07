#!/bin/bash

# Check if the number of commits is provided, default to 10 if not
NUM_COMMITS=${1:-10}
FILE_MASK=${2:-"*.[ch]"}

# Initialize an array to collect JSON outputs
json_array=()
commit_count=0

# Escape double quotes and handle newlines in commit messages
clean_commit_message() {
    # Replace newlines with \n using sed
    echo "$1" | sed ':a;N;$!ba;s/\n/\\n/g' |
    # Escape double quotes
    sed -e 's/"/\\"/g' |
    # Remove 'Signed-off-by' and 'Former-commit-id' lines
    sed -e '/Signed-off-by/d' -e '/Former-commit-id/d'
}

clean_git_diff() {
    echo "$1" | grep -vE '^(diff --git|index|---|\+\+\+|@@)'
}

# Iterate through the specified number of commits and output the JSON format
while IFS= read -r commit_hash; do
    # Extract the commit message
    commit_message=$(git log -1 --pretty=format:'%B' "$commit_hash")

    # Skip if the commit hash or message is empty or invalid
    if [ -z "$commit_hash" ] || [ -z "$commit_message" ]; then
        continue
    fi

    # Get the previous commit hash
    parent_commit=$(git rev-list --parents -n 1 "$commit_hash" | cut -d' ' -f2)

    # Skip if the parent commit is empty (e.g., for the initial commit)
    if [ -z "$parent_commit" ]; then
        continue
    fi

    # Get the number of lines changed in the commit
    lines_changed=$(git diff --shortstat "$parent_commit" "$commit_hash" | awk '{print $4 + $6}')

    # If there are no changed files that match the mask, skip this commit
    if [ "$lines_changed" -gt 25 ]; then
        continue
    fi

    # Get the code with context (5 lines before and after changes)
    code_with_context=$(git diff -U5 "$parent_commit" "$commit_hash")

    # Filter out metadata lines: diff --git, index, ---, +++, @@
    filtered_before=$(clean_git_diff "$code_with_context")

    # Exclude added lines (+), keeping only the context and deleted lines (-)
    code_before=$(echo "$filtered_before" | grep -v '^+' | sed 's/^-//')

    # Get the diff of the commit (showing changes)
    diff=$(git diff "$parent_commit" "$commit_hash" -- | grep '^[+-]' | grep -v '^[+-][+-]')

    # Filter out metadata lines: diff --git, index, ---, +++, @@
    filtered_diff=$(clean_git_diff "$diff")

    # Sanitize commit_message to escape any problematic characters
    sanitized_commit_message=$(clean_commit_message "$commit_message")

    # Format the output into clean JSON
    json_out=$(jq -n --arg instruction "$sanitized_commit_message" --arg input "$code_before" --arg result "$filtered_diff" \
        '{
            instruction: ("There is an issue in the following code. It relates to " + $instruction + " Please fix this issue."),
            input: ("Faulty tokenized code:\n" + ($input | split("\n") | map(. | ltrimstr(" ")) | join("\n"))),
            result: ("I corrected the issue in the code by changing the following tokens:\n" + ($result | split("\n") | map(. | ltrimstr(" ")) | join("\n")) + "\nThe issue was with: " + $instruction)
        }')

    # Add the JSON output to the array
    json_array+=("$json_out")

    # Increment the commit count
    commit_count=$((commit_count + 1))

    # Stop if we've processed the desired number of commits
    if [ "$commit_count" -ge "$NUM_COMMITS" ]; then
        break
    fi

done < <(git log --pretty=format:'%H' -n "$NUM_COMMITS" -- "$FILE_MASK")

# Print the collected JSON objects, joining them with commas
if [ ${#json_array[@]} -gt 0 ]; then
    printf '[%s]\n' "$(IFS=,; echo "${json_array[*]}")"
else
    echo "[]"
fi
